#!/usr/bin/env python3
"""Sourdough starter reference model. Implements docs/starter-simulation-spec.md v1.

Owner: sourdough-scientist. Pure Python 3, standard library only, one file.
This is the oracle the GDScript sim is tested against. It is not game code.

    python3 -I sim.py vectors       # test vectors V1 to V20 (spec §18)
    python3 -I sim.py calibration   # calibration rows (spec §15)
    python3 -I sim.py all           # both
    python3 -I sim.py trace OUTDIR  # golden JSON traces for the GDScript port

Exit code: 1 if any test-vector check fails, else 0.
"""
import math
import random
import sys
from dataclasses import dataclass, field, replace

# ------------------------------------------------------------------ parameters (spec §3 to §10, §19)
P = dict(
    y_tmin=8.0, y_topt=27.0, y_tmax=36.0,      # yeast growth, Gaenzle 1998
    l_tmin=3.5, l_topt=32.5, l_tmax=41.0,      # LAB growth, Gaenzle 1998
    mu_y=0.405, mu_l=0.540, ks_food=0.03, cap=1.5, pop_floor=0.001,
    death_y=0.012, death_l=0.006,
    eat=0.16, lab_gas=0.35, gas_gain=0.45, leak=0.085, leak_acid=0.5,
    acid_rate=0.22, acid_starve=0.02, l_acid_stop=0.95, y_acid_stop=1.15,
    hooch_rate=0.022, hooch_delay_h=6.0,
    vigor_grace_h=8.0, vigor_loss=0.0075, vigor_gain=0.11, vigor_floor=0.15,
    mold_onset_h=24.0, mold_rate=0.0070, mold_mult_cap=2.2, mold_slow=0.6,
    mold_feed_keep=0.3, mold_decay=0.02,
    dry_rate=0.045,
    mat_step=0.01024, mat_w_cap=2.5,
    hungry_food=0.10, dormant_cold_ferm=0.30, dormant_starved_h=60.0,
    recover_vigor=0.6, recover_at_feed=0.75, mold_watch=0.3, mold_warn=0.5,
    tau_h=1.5, dt_s=60.0, t_env_min=0.0, t_env_max=40.0,
)
FLOURS = {  # speed, acid, absorb, retain (spec §4)
    'white_bread': (1.00, 1.00, 1.00, 1.00),
    'whole_wheat': (1.20, 1.35, 1.12, 0.85),
    'rye':         (1.35, 1.70, 1.25, 0.65),
    'spelt':       (1.10, 1.10, 0.95, 0.85),
}
COVER_DRY = {'loose_lid': 0.35, 'cloth': 1.0, 'tight_lid': 0.05}
CONTAINER_DRY = {'classic_jar': 1.0, 'wide_mouth_jar': 1.3, 'ceramic_crock': 1.0, 'fermentation_vessel': 0.3}
LOCATIONS = {'counter': (22.0, 50.0), 'warm_spot': (26.0, 40.0), 'window_sill': (18.0, 55.0),
             'fridge': (4.0, 70.0), 'proofing_box': (26.0, 60.0)}
DESCRIPTORS = ['wet_flour', 'mildly_fruity', 'fresh_yeasty', 'yogurt', 'pleasantly_tangy',
               'strongly_acidic', 'alcohol', 'acetone', 'cheesy', 'musty']


def clamp(x, a=0.0, b=1.0):
    return a if x < a else (b if x > b else x)


# ------------------------------------------------------------------ temperature (spec §3)
def ctmi(T, tmin, topt, tmax):
    if T <= tmin or T >= tmax:
        return 0.0
    dmin = T - tmin
    num = (T - tmax) * dmin * dmin
    den = (topt - tmin) * ((topt - tmin) * (T - topt) - (topt - tmax) * (topt + tmin - 2.0 * T))
    return max(0.0, num / den)


_FERM_REF = ctmi(24.0, -2.0, 34.0, 45.0)


def ferm(T):
    return ctmi(T, -2.0, 34.0, 45.0) / _FERM_REF


def dec(T):
    m = 2.2 ** ((T - 24.0) / 10.0)
    if T > 34.0:
        m *= max(0.0, (45.0 - T) / 11.0)
    return m


def mold_t(T):
    if T > 3.0:
        return clamp(0.05 + 0.05 * (T - 3.0), 0.0, 1.6)
    return max(0.0, 0.05 * T / 3.0)


# ------------------------------------------------------------------ state and environment (spec §1, §2)
@dataclass
class Env:
    temp_c: float = 22.0
    rh: float = 50.0
    cover: str = 'loose_lid'
    container: str = 'classic_jar'


def location(name, cover='loose_lid'):
    t, rh = LOCATIONS[name]
    return Env(t, rh, cover)


@dataclass
class State:  # defaults = the MATURE seed state of spec §18
    food: float = 0.05
    food_at_feed: float = 0.0
    yeast: float = 0.9
    lab: float = 0.95
    acid: float = 0.85
    rise: float = 1.15
    peak_rise: float = 2.2
    peak_rate: float = 0.5
    hooch: float = 0.0
    dryness: float = 0.0
    vigor: float = 1.0
    vigor_at_feed: float = 1.0
    maturity: float = 0.6
    starved_h: float = 0.0
    mold_risk: float = 0.0
    moldy: bool = False
    temp_c: float = 22.0
    since_feed_s: float = 0.0
    mass_g: float = 100.0
    culture_hydration: float = 100.0
    flour_mix: dict = field(default_factory=lambda: {'white_bread': 1.0})
    feed_u: float = 0.5
    feed_jitter: float = 1.0


def copy_state(s, **kw):
    return replace(s, flour_mix=dict(s.flour_mix), **kw)


def flour_props(mix):
    sp = ac = ab = rt = 0.0
    for k, w in mix.items():
        a, b, c, d = FLOURS[k]
        sp += w * a; ac += w * b; ab += w * c; rt += w * d
    return sp, ac, ab, rt


# ------------------------------------------------------------------ feeding (spec §6)
def feed(s, kept_g, flours, water_g, feed_u=0.5, stir_in=False):
    """flours: {flour_id: grams}. feed_u: the per-feed uniform draw in [0, 1]. Refused when moldy."""
    if s.moldy:
        return s
    s = copy_state(s)
    flour_g = sum(flours.values())
    kept_g = max(1.0, min(kept_g, s.mass_g))
    total = kept_g + flour_g + water_g
    p = kept_g / total
    if s.peak_rise >= 1.5 and s.vigor >= P['recover_vigor']:
        w = min(P['mat_w_cap'], math.log(total / kept_g) / math.log(3.0))
        s.maturity = min(1.0, s.maturity + P['mat_step'] * w * (1.0 - s.maturity))
    kept_flour = kept_g * 100.0 / (100.0 + s.culture_hydration)
    kept_water = kept_g - kept_flour
    if stir_in:
        kept_water += 5.0 * s.hooch * kept_flour / 100.0
    new_flour = kept_flour + flour_g
    s.food = (kept_flour * s.food + flour_g) / new_flour
    mix = {k: w * kept_flour for k, w in s.flour_mix.items()}
    for k, g in flours.items():
        mix[k] = mix.get(k, 0.0) + g
    s.flour_mix = {k: v / new_flour for k, v in mix.items()}
    s.yeast = max(P['pop_floor'], s.yeast * p)
    s.lab = max(P['pop_floor'], s.lab * p)
    s.acid = s.acid * p
    s.culture_hydration = (kept_water + water_g) / new_flour * 100.0
    s.mass_g = total
    s.rise, s.peak_rise, s.peak_rate = 1.0, 1.0, 0.0
    s.hooch = s.dryness = s.starved_h = 0.0
    s.since_feed_s = 0.0
    s.mold_risk *= P['mold_feed_keep']
    s.food_at_feed = s.food
    s.vigor_at_feed = s.vigor
    s.feed_u = feed_u
    s.feed_jitter = 0.95 + 0.10 * feed_u
    return s


def feed_ratio(s, ratio=(1, 1, 1), flour='white_bread', hydration=100.0, kept=50.0, feed_u=0.5, stir_in=False):
    a, b, _ = ratio
    flour_g = kept * b / a
    return feed(s, kept, {flour: flour_g}, flour_g * hydration / 100.0, feed_u, stir_in)


# ------------------------------------------------------------------ rates (spec §5, §7, §10, §11)
def rates(s, env):
    T = s.temp_c
    sp, ac, ab, rt = flour_props(s.flour_mix)
    h_eff = s.culture_hydration / ab
    hyd_speed = clamp((h_eff / 100.0) ** 0.6, 0.6, 1.2)
    hyd_ret = clamp((100.0 / h_eff) ** 0.5, 0.6, 1.35)
    hyd_acid = clamp((100.0 / h_eff) ** 0.3, 0.85, 1.2)
    hyd_hooch = clamp((h_eff - 55.0) / 45.0, 0.0, 1.6)
    mat_f = 0.7 + 0.3 * min(1.0, s.maturity / 0.5)
    f, d = ferm(T), dec(T)
    phy = ctmi(T, P['y_tmin'], P['y_topt'], P['y_tmax'])
    phl = ctmi(T, P['l_tmin'], P['l_topt'], P['l_tmax'])
    sf = s.food / (P['ks_food'] + s.food)
    hunger = max(0.0, 1.0 - sf * (1.0 + P['ks_food']))
    starving = s.food < P['hungry_food']
    k = s.vigor * sp * hyd_speed * s.feed_jitter * mat_f
    al = s.acid / P['l_acid_stop']
    ay = s.acid / P['y_acid_stop']
    inh_l = max(0.0, 1.0 - al * al * al * al)
    inh_y = max(0.0, 1.0 - ay * ay * ay)
    g_y = P['mu_y'] * phy * k * sf * inh_y * (1.0 - s.yeast / P['cap'])
    g_l = P['mu_l'] * phl * k * sf * inh_l * (1.0 - s.lab / P['cap'])
    act = (s.yeast + 0.6 * s.lab) * f * sf * min(1.0, 0.5 + 0.5 * s.vigor)
    gas = (s.yeast + P['lab_gas'] * s.lab) * f * sf * s.vigor * mat_f
    r = dict(gas=gas, starving=starving)
    r['yeast'] = g_y * s.yeast - P['death_y'] * d * s.yeast * hunger
    r['lab'] = g_l * s.lab - P['death_l'] * d * s.lab * hunger
    r['food'] = -P['eat'] * act * sp
    r['rise'] = P['gas_gain'] * gas * rt * hyd_ret - P['leak'] * (s.rise - 1.0) * (1.0 + P['leak_acid'] * s.acid)
    r['acid'] = (P['acid_rate'] * s.lab * f * sf + P['acid_starve'] * s.lab * f * hunger) * ac * hyd_acid * (1.0 - s.acid)
    r['starved_h'] = d if starving else 0.0
    r['hooch'] = P['hooch_rate'] * f * hyd_hooch * hunger if s.starved_h > P['hooch_delay_h'] else 0.0
    if starving and s.starved_h > P['vigor_grace_h']:
        r['vigor'] = -P['vigor_loss'] * d
    elif not starving:
        r['vigor'] = P['vigor_gain'] * (1.0 - s.vigor) * sf * min(1.0, phy + phl)
    else:
        r['vigor'] = 0.0
    r['dryness'] = (P['dry_rate'] * COVER_DRY[env.cover] * CONTAINER_DRY[env.container]
                    * (1.0 - env.rh / 100.0) * (1.0 - s.dryness) * min(1.5, d))
    if starving and s.starved_h > P['mold_onset_h']:
        mult = min(P['mold_mult_cap'], mold_t(T) * (1.0 + 0.4 * s.dryness))
        r['mold_risk'] = P['mold_rate'] * mult * (1.0 - P['mold_slow'] * s.mold_risk)
    elif not starving:
        r['mold_risk'] = -P['mold_decay'] * sf
    else:
        r['mold_risk'] = 0.0
    return r


RANGES = dict(food=(0, 1), yeast=(0.001, 1.5), lab=(0.001, 1.5), acid=(0, 1), rise=(1, 3), hooch=(0, 1),
              dryness=(0, 1), vigor=(0.15, 1), starved_h=(0, 336), mold_risk=(0, 1))


# ------------------------------------------------------------------ step (spec §7 per-step procedure)
def step(s, env):
    dt_s = P['dt_s']
    dt_h = dt_s / 3600.0
    t_env = clamp(env.temp_c, P['t_env_min'], P['t_env_max'])          # 1
    if s.moldy:
        return copy_state(s, since_feed_s=s.since_feed_s + dt_s)
    r = rates(s, env)                                                   # 2
    n = copy_state(s)
    for name, (lo, hi) in RANGES.items():                               # 3, 4
        setattr(n, name, clamp(getattr(s, name) + r[name] * dt_h, lo, hi))
    if n.mold_risk >= 1.0:                                              # 5
        n.moldy = True
    n.peak_rise = max(s.peak_rise, n.rise)                              # 6
    n.peak_rate = max(s.peak_rate, r['rise'])
    n.temp_c = s.temp_c + (t_env - s.temp_c) * (1.0 - math.exp(-dt_h / P['tau_h']))  # 7
    n.since_feed_s = s.since_feed_s + dt_s                              # 8
    return n


def advance(s, hours, env, on_step=None):
    for i in range(int(round(hours * 3600.0 / P['dt_s']))):
        if on_step:
            on_step(i * P['dt_s'] / 3600.0, s)
        s = step(s, env)
    return s


# ------------------------------------------------------------------ derivation (spec §12)
def rise_phase(s, rr):
    if s.food < P['hungry_food'] and (s.rise <= 1.0 + 0.5 * (s.peak_rise - 1.0) or s.peak_rise < 1.15):
        return 'hungry'
    if s.since_feed_s < 3600.0 and s.rise < 1.05:
        return 'freshly_fed'
    if s.rise >= 0.94 * s.peak_rise and s.rise > 1.15 and s.peak_rate > 0.0 and rr < 0.2 * s.peak_rate:
        return 'at_peak'
    if rr < 0.0 and s.rise < 0.94 * s.peak_rise:
        return 'collapsing'
    if s.rise < 1.15:
        return 'developing'
    if rr < 0.75 * s.peak_rate or s.food < 0.25 * s.food_at_feed:
        return 'near_peak'
    return 'active'


def derive(s, env):
    """Returns (state, rise_phase, dormant_cause)."""
    if s.moldy:
        return 'moldy', None, None
    phase = rise_phase(s, rates(s, env)['rise'])
    cold = ferm(s.temp_c) < P['dormant_cold_ferm']
    if s.mold_risk >= P['mold_warn']:
        return 'unhealthy', phase, None
    if cold or s.starved_h >= P['dormant_starved_h']:
        return 'dormant', phase, ('cold' if cold else 'starved')
    if phase == 'hungry':
        return 'hungry', phase, None
    if s.vigor < P['recover_vigor'] or s.vigor_at_feed < P['recover_at_feed']:
        return 'recovering', phase, None
    return phase, phase, None


def mold_stage(s):
    r = s.mold_risk
    return 'mold' if s.moldy else ('warning' if r >= 0.5 else ('watch' if r >= 0.3 else 'none'))


# ------------------------------------------------------------------ smell (spec §13)
def tri(x, a, b, c):
    return clamp((x - a) / (b - a)) if x <= b else clamp((c - x) / (c - b))


def smell_intensities(s, env):
    if s.moldy:
        return {'musty': 1.0}
    gas_n = clamp(rates(s, env)['gas'])
    p = clamp(1.0 - s.food / s.food_at_feed) if s.food_at_feed > 0 else 1.0
    raw = {
        'wet_flour': clamp(1.0 - p / 0.3),
        'mildly_fruity': 0.9 * gas_n * tri(p, 0.05, 0.3, 0.7),
        'fresh_yeasty': gas_n * clamp(s.yeast / 0.5),
        'yogurt': tri(s.acid, 0.25, 0.45, 0.70) * clamp(0.3 + gas_n),
        'pleasantly_tangy': tri(s.acid, 0.40, 0.58, 0.72),
        'strongly_acidic': clamp((s.acid - 0.66) / 0.15),
        'alcohol': 0.8 * clamp(s.starved_h / 10.0) + 0.2 * s.hooch,
        'acetone': clamp((s.starved_h - 14.0) / 24.0),
        'cheesy': clamp((0.33 - s.maturity) / 0.13) * (0.5 + 0.5 * gas_n),
    }
    damp = clamp(0.35 + 0.65 * ferm(s.temp_c))
    out = {k: v * damp for k, v in raw.items()}
    out['musty'] = 0.0 if s.mold_risk < 0.3 else max(0.2, clamp((s.mold_risk - 0.2) / 0.5))
    return out


def smells(s, env):
    """Displayed list: top 3 with intensity >= 0.15, musty first, ties by vision.md order."""
    d = {k: v for k, v in smell_intensities(s, env).items() if v >= 0.15}
    order = sorted(d, key=lambda k: (k != 'musty', -d[k], DESCRIPTORS.index(k)))
    return [(k, round(d[k], 2)) for k in order[:3]]


# ------------------------------------------------------------------ fixtures and scenario helpers (spec §18)
COUNTER = location('counter')


def mature():
    """MATURE fixture: seed state, fed 50 g + 50 g white_bread + 50 g water, 12 h at counter, loose lid."""
    s = feed_ratio(State(temp_c=22.0))
    return advance(s, 12.0, COUNTER)


def at_temp(s, T):
    return copy_state(s, temp_c=T)


def env_at(T, rh=50.0, cover='loose_lid'):
    return Env(T, rh, cover)


def trace(s, hours, env, checkpoints=()):
    """Run and record: at_peak start, max-rise time and height, first time of each state, checkpoint rows."""
    rec = dict(at_peak=None, peak=(0.0, s.rise), first={}, rows={})
    cps = set(checkpoints)

    def on(h, x):
        st, ph, _ = derive(x, env)
        if ph == 'at_peak' and rec['at_peak'] is None:
            rec['at_peak'] = h
        if x.rise > rec['peak'][1]:
            rec['peak'] = (h, x.rise)
        rec['first'].setdefault(st, h)
        if round(h, 4) in cps:
            rec['rows'][round(h, 4)] = (st, x.rise, [k for k, _ in smells(x, env)], x.hooch >= 0.1, mold_stage(x))
    s = advance(s, hours, env, on)
    on(hours, s)
    rec['end'] = s
    return rec


U3 = (0.0, 0.5, 1.0)   # feed_u extremes and middle: jitter 0.95, 1.00, 1.05


def rng(lo_hi):
    lo, hi = min(lo_hi), max(lo_hi)
    return f"{lo:.2f}" if abs(hi - lo) < 0.005 else f"{lo:.2f} to {hi:.2f}"


def ratio_vector(name, start, ratio, T, kept, hours=48, cps=(2, 4, 8, 12, 24, 48), flour='white_bread', hyd=100.0,
                 keep_temp=False):
    """keep_temp: leave temp_c as is (a starter coming out of the fridge warms up with the 1.5 h lag)."""
    env = env_at(T)
    begin = start if keep_temp else at_temp(start, T)
    recs = [trace(feed_ratio(begin, ratio, flour, hyd, kept, u), hours, env, cps) for u in U3]
    ap = [r['at_peak'] for r in recs if r['at_peak'] is not None]
    print(f"{name}: at_peak {rng(ap)} h; peak {rng([r['peak'][0] for r in recs])} h "
          f"at {rng([r['peak'][1] for r in recs])}x")
    for c in cps:
        rows = [r['rows'][c] for r in recs]
        sts = sorted({row[0] for row in rows})
        mid = rows[1]
        print(f"    {c:>3} h: {'/'.join(sts):<22} rise {rng([row[1] for row in rows]):<13} smell {mid[2]} "
              f"hooch {'yes' if mid[3] else 'no'}, mold {mid[4]}")
    return recs


def converted(start, flour='white_bread', hyd=100.0):
    s = start
    for _ in range(3):
        s = feed_ratio(s, (1, 1, 1), flour, hyd)
        s = advance(s, 12.0, COUNTER)
    return s


def state_times(s, hours, env):
    first = {}
    marks = {}

    def on(h, x):
        st, _, _ = derive(x, env)
        first.setdefault(st, h)
        for name, ok in (('hooch>=0.1', x.hooch >= 0.1), ('watch', x.mold_risk >= 0.3)):
            if ok:
                marks.setdefault(name, h)
    end = advance(s, hours, env, on)
    return first, marks, end


def cycles(s, n, env, every_h=12.0, ratio=(1, 1, 1), kept=50.0):
    out = []
    for _ in range(n):
        s = feed_ratio(s, ratio, kept=kept)
        rec = trace(s, every_h, env)
        recovering = 'recovering' in rec['first']
        out.append(f"{rec['peak'][1]:.2f}x@{rec['peak'][0]:.1f}h{' R' if recovering else ''}")
        s = rec['end']
    return out


# ------------------------------------------------------------------ reports
TOL_T, TOL_R = 0.3, 0.05   # spec §18 drift allowances: hours, rise


class Checker:
    def __init__(self):
        self.n = 0
        self.fails = []

    def within(self, name, vals, lo, hi, tol=0.0):
        for v in (vals if isinstance(vals, (list, tuple)) else [vals]):
            self.n += 1
            if v is None or not (lo - tol <= v <= hi + tol):
                self.fails.append(f"{name}: {v} outside [{lo}, {hi}] with tolerance {tol}")

    def about(self, name, vals, x, tol):
        self.within(name, vals, 0.95 * x, 1.05 * x, tol)

    def true(self, name, cond, detail=''):
        self.n += 1
        if not cond:
            self.fails.append(f"{name}: failed. {detail}")


def _aps(recs): return [r['at_peak'] for r in recs]
def _peaks(recs): return [r['peak'][0] for r in recs]
def _heights(recs): return [r['peak'][1] for r in recs]
def _col(recs, h, i): return [r['rows'][h][i] for r in recs]


def _check_peak(c, name, recs, ap, pk, ht=None, ht_about=None):
    if ap:
        c.within(f"{name} at_peak", _aps(recs), ap[0], ap[1], TOL_T)
    c.within(f"{name} peak time", _peaks(recs), pk[0], pk[1], TOL_T)
    if ht:
        c.within(f"{name} peak height", _heights(recs), ht[0], ht[1], TOL_R)
    if ht_about:
        c.about(f"{name} peak height", _heights(recs), ht_about, TOL_R)


def _in_range(s):
    return all(lo - 1e-12 <= getattr(s, k) <= hi + 1e-12 for k, (lo, hi) in RANGES.items())


def vectors():
    """Prints V1 to V20 and asserts them against spec §18. Returns the number of failed checks."""
    c = Checker()
    base = mature()
    print("== Test vectors (spec §18). Ranges cover feed_u 0, 0.5, 1 (jitter 0.95 to 1.05). Peak = max-rise time.")
    v1 = ratio_vector('V1 1:1:1 24 C', base, (1, 1, 1), 24, 50)
    _check_peak(c, 'V1', v1, (5.3, 5.5), (5.4, 5.6), (2.20, 2.22))
    c.true('V1 2 h active', set(_col(v1, 2, 0)) == {'active'})
    c.within('V1 2 h rise', _col(v1, 2, 1), 1.37, 1.38, TOL_R)
    c.true('V1 4 h state', set(_col(v1, 4, 0)) <= {'active', 'near_peak'})
    c.within('V1 4 h rise', _col(v1, 4, 1), 1.87, 1.92, TOL_R)
    c.true('V1 8 h collapsing', set(_col(v1, 8, 0)) == {'collapsing'})
    c.about('V1 8 h rise', _col(v1, 8, 1), 1.94, TOL_R)
    c.true('V1 12 h state', set(_col(v1, 12, 0)) <= {'collapsing', 'hungry'})
    c.about('V1 12 h rise', _col(v1, 12, 1), 1.60, TOL_R)
    c.true('V1 24 h hungry', set(_col(v1, 24, 0)) == {'hungry'})
    c.within('V1 24 h rise', _col(v1, 24, 1), 1.16, 1.16, TOL_R)
    c.true('V1 24 h hooch', all(_col(v1, 24, 3)))
    for sm in _col(v1, 24, 2):
        c.true('V1 24 h smells', set(sm) == {'alcohol', 'pleasantly_tangy', 'acetone'} and sm[0] == 'alcohol', str(sm))
    c.true('V1 48 h hungry', set(_col(v1, 48, 0)) == {'hungry'})
    c.within('V1 48 h rise', _col(v1, 48, 1), 1.01, 1.01, TOL_R)
    for sm in _col(v1, 48, 2):
        c.true('V1 48 h smells', set(sm) == {'acetone', 'alcohol', 'strongly_acidic'}, str(sm))
    for h in (2, 4, 8, 12, 24, 48):
        c.true(f'V1 {h} h mold none', set(_col(v1, h, 4)) == {'none'})
    v2 = {}
    for T, ap, pk, ht in ((20, (7.0, 7.2), (7.1, 7.4), 2.12), (22, (6.0, 6.2), (6.1, 6.3), 2.17), (28, (4.5, 4.7), (4.6, 4.8), 2.23)):
        v2[T] = ratio_vector(f'V2 1:1:1 {T} C', base, (1, 1, 1), T, 50, cps=(48,))
        _check_peak(c, f'V2 {T} C', v2[T], ap, pk, ht_about=ht)
    for i in range(3):
        c.true('V2 order 28 < 24 < 20', _peaks(v2[28])[i] < _peaks(v1)[i] < _peaks(v2[20])[i])
    c.true('V2 28 C 48 h dormant', set(_col(v2[28], 48, 0)) == {'dormant'})
    v3a = ratio_vector('V3 1:5:5 24 C', base, (1, 5, 5), 24, 10, cps=())
    v3b = ratio_vector('V3 1:10:10 24 C', base, (1, 10, 10), 24, 10, cps=())
    _check_peak(c, 'V3 1:5:5', v3a, (9.5, 10.0), (9.6, 10.1), (2.52, 2.55))
    _check_peak(c, 'V3 1:10:10', v3b, (11.3, 12.0), (11.4, 12.1), (2.57, 2.60))
    c.within('V3 1:5:5 later than V1', [a - b for a, b in zip(_peaks(v3a), _peaks(v1))], 3.9, 4.6, TOL_T)
    c.within('V3 1:10:10 later than V1', [a - b for a, b in zip(_peaks(v3b), _peaks(v1))], 5.8, 6.6, TOL_T)
    v4 = ratio_vector('V4 1:50:50 24 C', base, (1, 50, 50), 24, 2, cps=(24,))
    _check_peak(c, 'V4', v4, None, (15.6, 16.7), (2.60, 2.64))
    v5 = {}
    acid24 = {}
    for fl, pk, ht in (('white_bread', None, None), ('rye', (5.1, 5.3), 1.66), ('whole_wheat', (5.5, 5.7), 1.91), ('spelt', (5.5, 5.8), 1.91)):
        conv = converted(base, fl)
        v5[fl] = ratio_vector(f'V5 {fl} 1:1:1 22 C', conv, (1, 1, 1), 22, 50, cps=(24,), flour=fl)
        acid24[fl] = advance(feed_ratio(at_temp(conv, 22), flour=fl), 24.0, COUNTER).acid
        print(f"    acid at 24 h: {acid24[fl]:.3f}")
        if pk:
            _check_peak(c, f'V5 {fl}', v5[fl], None, pk, ht_about=ht)
    c.true('V5 acid rye > whole_wheat > white', acid24['rye'] > acid24['whole_wheat'] > acid24['white_bread'], str(acid24))
    sp = {fl: _peaks(v5[fl])[1] for fl in v5}
    c.true('V5 speed rye > whole_wheat >= spelt > white',
           sp['rye'] < sp['whole_wheat'] <= sp['spelt'] < sp['white_bread'], str(sp))
    for hyd, pk in ((60.0, (6.75, 7.0)), (100.0, (6.2, 6.4)), (125.0, (6.0, 6.2))):
        rec = ratio_vector(f'V6 white {hyd:.0f}% 22 C', converted(base, hyd=hyd), (1, 1, 1), 22, 50, cps=(48,), hyd=hyd)
        _check_peak(c, f'V6 {hyd:.0f}%', rec, None, pk, (2.33, 2.35) if hyd == 60.0 else None)
        if hyd == 60.0:
            c.true('V6 60% no visible hooch in 48 h', all(r['end'].hooch < 0.1 for r in rec))
    for days in (3, 14):
        s = feed_ratio(base); s = advance(s, 1.0, COUNTER); s = advance(s, days * 24.0, location('fridge'))
        st = derive(s, location('fridge'))
        print(f"V7 fridge {days} d: before feed {st[0]}/{st[2]} hooch {s.hooch:.2f} mold {s.mold_risk:.2f} vigor {s.vigor:.2f}")
        recs = ratio_vector(f'V7 fridge {days} d then 1:1:1 22 C', s, (1, 1, 1), 22, 50, hours=24,
                            cps=(2, 4, 8, 12), keep_temp=True)
        nxt = trace(feed_ratio(recs[1]['end']), 24.0, COUNTER)
        print(f"    next feed: {nxt['peak'][1]:.2f}x@{nxt['peak'][0]:.1f}h, recovering: {'recovering' in nxt['first']}")
        c.true(f'V7 {days} d dormant in fridge', st[0] == 'dormant')
        c.true(f'V7 {days} d next feed not recovering', 'recovering' not in nxt['first'])
        if days == 3:
            c.true('V7 3 d not recovering', all('recovering' not in r['first'] for r in recs))
            _check_peak(c, 'V7 3 d', recs, None, (10.2, 10.6))
        else:
            c.true('V7 14 d hooch >= 0.3', s.hooch >= 0.3, f"{s.hooch}")
            c.true('V7 14 d mold < 0.3', s.mold_risk < 0.3)
            c.within('V7 14 d vigor', s.vigor, 0.6, 0.7)
            for h in (2, 4, 8, 12):
                c.true(f'V7 14 d {h} h recovering', set(_col(recs, h, 0)) == {'recovering'})
            _check_peak(c, 'V7 14 d', recs, None, (13.5, 14.1), ht_about=1.9)
    s = feed_ratio(base); s = advance(s, 24.0, COUNTER)
    print(f"V8 24 h unfed: {derive(s, COUNTER)[0]}, hooch {s.hooch:.2f}, vigor {s.vigor:.2f}")
    c.true('V8 hungry before feed', derive(s, COUNTER)[0] == 'hungry')
    c.true('V8 hooch before feed', s.hooch >= 0.1)
    c.within('V8 vigor before feed', s.vigor, 0.92, 0.96)
    v8 = ratio_vector('V8 then 1:1:1 22 C', s, (1, 1, 1), 22, 50, hours=24, cps=(12,))
    _check_peak(c, 'V8', v8, None, (6.7, 6.9))
    for a, b in zip(_heights(v8), _heights(v2[22])):
        c.true('V8 peak >= 0.85 x V2 22 C', a >= 0.85 * b, f"{a:.3f} vs {b:.3f}")
    c.true('V8 not recovering', all('recovering' not in r['first'] for r in v8))
    first, marks, _ = state_times(feed_ratio(base), 14 * 24.0, COUNTER)
    print("V9 unfed 14 d at counter (h): " + ", ".join(f"{k} {v:.1f}" for k, v in first.items())
          + f"; watch {marks['watch']:.1f}; gap warning to mold {first['moldy'] - first['unhealthy']:.1f} h, "
            f"watch to mold {first['moldy'] - marks['watch']:.1f} h")
    for k, lo, hi in (('hungry', 12.4, 12.8), ('dormant', 74, 77), ('unhealthy', 104, 111), ('moldy', 207, 219)):
        c.within(f'V9 {k} onset', first.get(k), lo, hi, TOL_T)
    c.within('V9 watch onset', marks.get('watch'), 72, 80, TOL_T)
    c.true('V9 warning to mold >= 72 h', first['moldy'] - first['unhealthy'] >= 72)
    c.true('V9 watch to mold >= 96 h', first['moldy'] - marks['watch'] >= 96)
    s = advance(feed_ratio(base), 120.0, COUNTER)
    print(f"V9b at 120 h: {derive(s, COUNTER)[0]}, mold {s.mold_risk:.2f}")
    c.true('V9b unhealthy at 120 h', derive(s, COUNTER)[0] == 'unhealthy')
    c.true('V9b mold < 0.3 after the feed', feed_ratio(s).mold_risk < 0.3)
    rec = ratio_vector('V9b then 1:1:1 22 C', s, (1, 1, 1), 22, 50, hours=24, cps=(2, 12))
    for h in (2, 12):
        c.true(f'V9b {h} h recovering', set(_col(rec, h, 0)) == {'recovering'})
    _check_peak(c, 'V9b', rec, None, (12.8, 13.3), ht_about=1.76)
    nxt = cycles(rec[1]['end'], 2, COUNTER)
    print(f"    mold_risk right after the feed: {feed_ratio(s).mold_risk:.2f}; next feeds: " + ' | '.join(nxt))
    normal = trace(feed_ratio(base), 12.0, COUNTER)['peak'][1]
    c.true('V9b normal (>= 0.95x) by feed 3', float(nxt[1].split('x')[0]) >= 0.95 * normal, f"{nxt[1]} vs {normal:.2f}")
    s = base
    for _ in range(12):
        s = feed_ratio(s); s = advance(s, 1 / 6, COUNTER)
    rec = trace(s, 48.0, COUNTER)
    print(f"V10 12 feeds 10 min apart: yeast {s.yeast:.4f} lab {s.lab:.4f} state {derive(s, COUNTER)[0]}; "
          f"next peak {rec['peak'][0]:.1f} h at {rec['peak'][1]:.2f}x")
    c.true('V10 in range', _in_range(s))
    c.true('V10 populations near the floor', s.yeast <= 0.002 and s.lab <= 0.002)
    c.true('V10 state', derive(s, COUNTER)[0] in ('freshly_fed', 'developing'))
    c.about('V10 next peak time', rec['peak'][0], 25.0, TOL_T)
    c.about('V10 next peak height', rec['peak'][1], 2.6, TOL_R)
    r11a = trace(feed(base, 1.0, {'white_bread': 1.0}, 1.0), 30.0, COUNTER)
    r11b = trace(feed(base, 1.0, {'white_bread': 50.0}, 50.0), 30.0, COUNTER)
    print(f"V11 keep 1 g + 1 g + 1 g: peak {r11a['peak'][0]:.1f} h at {r11a['peak'][1]:.2f}x")
    print(f"V11 keep 1 g + 50 g + 50 g: peak {r11b['peak'][0]:.1f} h at {r11b['peak'][1]:.2f}x")
    c.within('V11 1:1:1 like V2 22 C', r11a['peak'][0], 6.1, 6.3, TOL_T)
    c.about('V11 1:50:50 peak time', r11b['peak'][0], 18.0, TOL_T)
    for T, pk in ((32, (4.5, 4.6)), (35, (5.0, 5.2))):
        rec = ratio_vector(f'V12 1:1:1 {T} C', base, (1, 1, 1), T, 50, cps=(48,))
        _check_peak(c, f'V12 {T} C', rec, None, pk)
        c.true(f'V12 {T} C 48 h dormant + watch + musty first',
               set(_col(rec, 48, 0)) == {'dormant'} and set(_col(rec, 48, 4)) == {'watch'}
               and all(sm[0] == 'musty' for sm in _col(rec, 48, 2)))
    s = advance(feed_ratio(base), 14 * 24.0, COUNTER)
    print(f"V13 counter, 30 d away capped at 14 d: {derive(s, COUNTER)[0]}")
    c.true('V13 counter moldy at the cap', derive(s, COUNTER)[0] == 'moldy')
    f = feed_ratio(base); f = advance(f, 1.0, COUNTER); f = advance(f, 14 * 24.0, location('fridge'))
    print(f"V13 fridge, capped at 14 d: {derive(f, location('fridge'))[0]}, vigor {f.vigor:.2f}, mold {f.mold_risk:.2f}")
    c.true('V13 fridge dormant', derive(f, location('fridge'))[0] == 'dormant')
    c.within('V13 fridge vigor', f.vigor, 0.6, 0.7)
    c.true('V13 fridge mold < 0.3', f.mold_risk < 0.3)
    moldy = s
    fed = feed_ratio(moldy)
    print(f"V14 moldy then feed: refused = {fed is moldy}, state {derive(fed, COUNTER)[0]}")
    c.true('V14 feed refused, state unchanged', fed is moldy and derive(fed, COUNTER)[0] == 'moldy')
    later = advance(moldy, 1.0, COUNTER)
    c.true('V14 only the clock moves', later.since_feed_s == moldy.since_feed_s + 3600.0
           and all(getattr(later, k) == getattr(moldy, k) for k in RANGES))
    print(f"V15 fridge 14 d, then counter unfed: mold at exit {f.mold_risk:.2f}")
    c.within('V15 mold at exit', f.mold_risk, 0.10, 0.18)
    first, _, _ = state_times(f, 10 * 24.0, COUNTER)
    print(f"    after exit (h): unhealthy {first['unhealthy']:.1f}, moldy {first['moldy']:.1f}, "
          f"gap {first['moldy'] - first['unhealthy']:.1f}")
    c.within('V15 unhealthy after exit', first.get('unhealthy'), 55, 65, TOL_T)
    c.within('V15 moldy after exit', first.get('moldy'), 160, 170, TOL_T)
    c.true('V15 gap >= 72 h', first['moldy'] - first['unhealthy'] >= 72)
    for T in (22, 24):
        env = env_at(T); s = at_temp(base, T); minv = 1.0; maxm = 0.0; seen = set()
        for _ in range(14):
            s = feed_ratio(s)

            def on(h, x):
                nonlocal minv, maxm
                minv = min(minv, x.vigor); maxm = max(maxm, x.mold_risk); seen.add(derive(x, env)[0])
            s = advance(s, 24.0, env, on)
        print(f"V16 once a day 1:1:1 {T} C, 14 d: min vigor {minv:.2f}, max mold {maxm:.2f}, states {sorted(seen)}")
        c.true(f'V16 {T} C vigor >= 0.8', minv >= 0.8, f"{minv:.3f}")
        c.true(f'V16 {T} C mold 0', maxm == 0.0)
        c.true(f'V16 {T} C never recovering, dormant or unhealthy', not (seen & {'recovering', 'dormant', 'unhealthy'}))
    a = advance(feed_ratio(base), 5 * 24.0, COUNTER)
    b = feed_ratio(base); t = 0; total = 5 * 24 * 3600; r = random.Random(7)
    while t < total:
        nt = min(total, t + r.randint(1, 120) * 60)
        b = advance(b, (nt - t) / 3600.0, COUNTER); t = nt
    diff = max(abs(getattr(a, k) - getattr(b, k)) for k in RANGES)
    print(f"V17 5 d in one run vs random splits on the 60 s grid: max abs diff {diff}")
    c.true('V17 exact', diff == 0.0)
    v18 = ratio_vector('V18 1:2:2 22 C', base, (1, 2, 2), 22, 10, cps=())
    _check_peak(c, 'V18', v18, (8.0, 8.4), (8.1, 8.5), (2.34, 2.36))
    v19 = ratio_vector('V19 1:5:5 22 C', base, (1, 5, 5), 22, 10, cps=())
    _check_peak(c, 'V19', v19, (10.75, 11.4), (10.85, 11.5), (2.47, 2.50))
    s = advance(feed_ratio(base), 36.0, COUNTER)
    pa, sa = feed_ratio(s, stir_in=False), feed_ratio(s, stir_in=True)
    ra, rb = trace(pa, 24.0, COUNTER), trace(sa, 24.0, COUNTER)
    print(f"V20 hooch {s.hooch:.2f}: pour_off hydration {pa.culture_hydration:.1f}% peak {ra['peak'][0]:.2f} h "
          f"{ra['peak'][1]:.3f}x; stir_in {sa.culture_hydration:.1f}% peak {rb['peak'][0]:.2f} h {rb['peak'][1]:.3f}x; "
          f"acid {pa.acid:.4f} vs {sa.acid:.4f}")
    c.true('V20 hooch 0 after both', pa.hooch == 0.0 and sa.hooch == 0.0)
    c.within('V20 stir-in hydration gain', sa.culture_hydration - pa.culture_hydration, 0.5, 1.1)
    c.true('V20 peaks close', abs(ra['peak'][0] - rb['peak'][0]) <= 0.05 and abs(ra['peak'][1] - rb['peak'][1]) <= 0.01)
    c.true('V20 acid identical', pa.acid == sa.acid)
    print(f"== Checks: {c.n} run, {len(c.fails)} failed")
    for msg in c.fails:
        print("FAIL " + msg)
    return len(c.fails)


def calibration():
    base = mature()
    print("== Calibration (spec §15), feed_u 0.5")
    for T in (24, 22):
        row = []
        for ratio, kept in (((1, 1, 1), 50), ((1, 2, 2), 10), ((1, 4, 4), 10), ((1, 5, 5), 10), ((1, 10, 10), 10), ((1, 50, 50), 2)):
            rec = trace(feed_ratio(at_temp(base, T), ratio, kept=kept), 30.0, env_at(T))
            row.append(f"{ratio[1]}:{rec['peak'][0]:.2f}h/{rec['peak'][1]:.2f}x")
        print(f"ratios at {T} C: " + '  '.join(row))
    row = []
    for T in (18, 20, 22, 24, 28, 32, 35):
        rec = trace(feed_ratio(at_temp(base, T)), 30.0, env_at(T))
        row.append(f"{T}:{rec['peak'][0]:.2f}h")
    print("1:1:1 by temperature: " + '  '.join(row))
    first, marks, _ = state_times(feed_ratio(base), 48.0, COUNTER)
    print(f"1:1:1 at 22 C: hungry {first['hungry']:.1f} h, hooch visible {marks['hooch>=0.1']:.1f} h")
    f = advance(feed_ratio(base), 1.0, COUNTER)
    food_out = None; hooch_on = None; fr = location('fridge')
    for d in range(1, 15):
        f = advance(f, 24.0, fr)
        if food_out is None and f.food < 0.1:
            food_out = d
        if hooch_on is None and f.hooch >= 0.1:
            hooch_on = d
    print(f"fed then fridge: food out by day {food_out}, hooch visible by day {hooch_on}, vigor at 14 d {f.vigor:.2f}")
    for loc, cover, rh in (('counter', 'loose_lid', None), ('counter', 'cloth', None), ('counter', 'tight_lid', None),
                           ('warm_spot', 'loose_lid', None), ('warm_spot', 'cloth', None),
                           ('window_sill', 'loose_lid', None), ('proofing_box', 'loose_lid', None)):
        env = location(loc, cover)
        first, marks, _ = state_times(feed_ratio(at_temp(base, env.temp_c)), 14 * 24.0, env)
        print(f"neglect {loc} {cover}: dormant {first['dormant'] / 24:.2f} d, watch {marks['watch'] / 24:.2f} d, "
              f"unhealthy {first['unhealthy'] / 24:.2f} d, moldy {first['moldy'] / 24:.2f} d, "
              f"gap {first['moldy'] - first['unhealthy']:.1f} h")
    env = Env(35.0, 30.0, 'cloth')
    first, _, _ = state_times(feed_ratio(at_temp(base, 35.0)), 14 * 24.0, env)
    print(f"neglect 35 C cloth 30% RH: unhealthy {first['unhealthy'] / 24:.2f} d, moldy {first['moldy'] / 24:.2f} d, "
          f"gap {first['moldy'] - first['unhealthy']:.1f} h")
    ref = cycles(base, 1, COUNTER)[0]
    print(f"steady reference cycle: {ref}")
    for away in (24, 72, 120):
        s = advance(feed_ratio(base), float(away), COUNTER)
        print(f"away {away} h, then feeds every 12 h: " + ' | '.join(cycles(s, 3, COUNTER)))
    f = advance(feed_ratio(base), 1.0, COUNTER); f = advance(f, 14 * 24.0, location('fridge'))
    print("fridge 14 d, then feeds every 24 h (first cycle needs over 12 h): " + ' | '.join(cycles(f, 3, COUNTER, every_h=24.0)))


# ------------------------------------------------------------------ golden traces (qa-engineer DIFF-01)
def _feed(t_h, kept=50.0, flour='white_bread', flour_g=50.0, water_g=50.0, u=0.5, stir_in=False):
    return {'t_h': t_h, 'kind': 'feed', 'kept_g': kept, 'flours': {flour: flour_g}, 'water_g': water_g,
            'feed_u': u, 'stir_in': stir_in}


def _env(t_h, temp_c, rh=50.0, cover='loose_lid', container='classic_jar'):
    return {'t_h': t_h, 'kind': 'env', 'temp_c': temp_c, 'rh': rh, 'cover': cover, 'container': container}


def _ws(t_h):  # 1:5:5 with 10 g kept
    return _feed(t_h, kept=10.0, u=(t_h * 0.0731) % 1.0)


SCHEDULES = [
    ('T01', 'Build the MATURE fixture from the seed state', 'seed', 12, [_feed(0)]),
    ('T02', '1:1:1 at the counter, 48 h', 'mature', 48, [_feed(0)]),
    ('T03', '1:1:1 at 24 C, feed_u 0, 48 h', 'mature', 48, [_env(0, 24.0), _feed(0, u=0.0)]),
    ('T04', '1:1:1 at 28 C, feed_u 1, 48 h', 'mature', 48, [_env(0, 28.0), _feed(0, u=1.0)]),
    ('T05', '1:5:5 (10 g kept) at the counter, 48 h', 'mature', 48, [_feed(0, kept=10.0, u=0.3)]),
    ('T06', '1:10:10 (10 g kept) at 24 C, 48 h', 'mature', 48,
     [_env(0, 24.0), _feed(0, kept=10.0, flour_g=100.0, water_g=100.0, u=0.7)]),
    ('T07', 'Rye: 4 feeds 12 h apart, 84 h', 'mature', 84,
     [_feed(12 * i, flour='rye', u=u) for i, u in enumerate((0.1, 0.4, 0.6, 0.9))]),
    ('T08', 'Whole wheat at 60%: 4 feeds 12 h apart, 84 h', 'mature', 84,
     [_feed(12 * i, flour='whole_wheat', water_g=30.0, u=0.25 * i) for i in range(4)]),
    ('T09', 'Spelt at 125%: 4 feeds 12 h apart, 84 h', 'mature', 84,
     [_feed(12 * i, flour='spelt', water_g=62.5, u=0.2 + 0.2 * i) for i in range(4)]),
    ('T10', 'Neglect at the counter, loose lid, 14 d', 'mature', 336, [_feed(0)]),
    ('T11', 'Neglect at warm_spot under cloth, 14 d', 'mature', 336, [_env(0, 26.0, 40.0, 'cloth'), _feed(0)]),
    ('T12', 'Neglect at 35 C, cloth, 30% RH, wide-mouth jar, 10 d', 'mature', 240,
     [_env(0, 35.0, 30.0, 'cloth', 'wide_mouth_jar'), _feed(0)]),
    ('T13', 'Feed, 1 h out, 14 d fridge, back out and fed, 48 h more', 'mature', 385,
     [_feed(0), _env(1, 4.0, 70.0), _env(337, 22.0, 50.0), _feed(337, u=0.6)]),
    ('T14', 'Feed, 1 h out, 14 d fridge, then 10 d unfed at the counter', 'mature', 577,
     [_feed(0), _env(1, 4.0, 70.0), _env(337, 22.0, 50.0)]),
    ('T15', '12 feeds 10 minutes apart, then 48 h', 'mature', 50,
     [_feed(i / 6.0, u=(i * 0.137) % 1.0) for i in range(12)]),
    ('T16', 'Once a day 1:1:1 at the counter, 14 d', 'mature', 336,
     [_feed(24 * i, u=(i * 0.37) % 1.0) for i in range(14)]),
    ('T17', 'Twice a day 1:5:5 on the window sill, 7 d', 'mature', 168,
     [_env(0, 18.0, 55.0)] + [_ws(12 * i) for i in range(14)]),
    ('T18', 'Neglect 120 h (unhealthy), then 4 feeds 12 h apart', 'mature', 180,
     [_feed(0)] + [_feed(120 + 12 * i, u=0.5) for i in range(4)]),
    ('T19', 'Hunger 36 h, then a stir-in feed, 36 h more', 'mature', 72, [_feed(0), _feed(36, stir_in=True)]),
    ('T20', 'Moves: warm_spot at 2 h, fridge at 4 h, counter at 10 h, proofing box 30 C at 30 h', 'mature', 60,
     [_feed(0), _env(2, 26.0, 40.0), _env(4, 4.0, 70.0), _env(10, 22.0, 50.0), _env(30, 30.0, 60.0)]),
    ('T21', 'Young starter (maturity 0.2), 1:2:2 twice a day, 6 d', 'young', 144,
     [_feed(12 * i, kept=20.0, flour_g=40.0, water_g=40.0, u=(0.15 + i * 0.29) % 1.0) for i in range(12)]),
    ('T22', 'Neglect to mold, then a refused feed at 300 h', 'mature', 336, [_feed(0), _feed(300)]),
    ('T23', 'Domain edge: 40 C, 20% RH, cloth, 5 d', 'mature', 120, [_env(0, 40.0, 20.0, 'cloth'), _feed(0)]),
    ('T24', 'Domain edge: 0 C, 80% RH, fed, 5 d', 'mature', 120, [_env(0, 0.0, 80.0), _feed(0)]),
]


def _snapshot(t_h, s, env):
    st, ph, cause = derive(s, env)
    row = {'t_h': t_h}
    row.update({k: (dict(v) if isinstance(v, dict) else v) for k, v in vars(s).items()})
    row.update({'state': st, 'rise_phase': ph, 'dormant_cause': cause})
    return row


def run_schedule(start, end_h, events):
    """Rows every whole hour, taken after that minute's events and before that minute's step."""
    if start == 'seed':
        s = State(temp_c=22.0)
    else:
        s = mature()
        if start == 'young':
            s = copy_state(s, maturity=0.2)
    env = Env(22.0, 50.0)
    by_minute = {}
    for e in events:
        by_minute.setdefault(int(round(e['t_h'] * 60.0)), []).append(e)
    rows = []
    for k in range(int(round(end_h * 60.0)) + 1):
        for e in by_minute.get(k, []):
            if e['kind'] == 'env':
                env = Env(e['temp_c'], e['rh'], e['cover'], e['container'])
            else:
                s = feed(s, e['kept_g'], e['flours'], e['water_g'], e['feed_u'], e['stir_in'])
        if k % 60 == 0:
            rows.append(_snapshot(k / 60.0, s, env))
        if k < int(round(end_h * 60.0)):
            s = step(s, env)
    return rows


def write_traces(outdir):
    import json
    import os
    os.makedirs(outdir, exist_ok=True)
    manifest = {'spec': 'starter-simulation-spec.md v1', 'dt_s': P['dt_s'],
                'row_rule': 'every whole hour, after that minute\'s events, before that minute\'s step',
                'start_states': {'seed': 'State() defaults, temp_c 22',
                                 'mature': 'mature(): seed fed 50 g + 50 g white_bread + 50 g water, 12 h at the counter',
                                 'young': 'mature() with maturity set to 0.2'},
                'initial_env': 'counter: 22 C, 50% RH, loose_lid, classic_jar',
                'params': P, 'flours': FLOURS, 'cover_dry': COVER_DRY, 'container_dry': CONTAINER_DRY,
                'traces': []}
    total = 0
    for tid, desc, start, end_h, events in SCHEDULES:
        rows = run_schedule(start, end_h, events)
        total += len(rows)
        name = f"{tid}.json"
        with open(os.path.join(outdir, name), 'w') as fh:
            json.dump({'id': tid, 'description': desc, 'start': start, 'end_h': end_h, 'events': events,
                       'rows': rows}, fh, indent=1)
        manifest['traces'].append({'id': tid, 'file': name, 'description': desc, 'rows': len(rows),
                                   'final_state': rows[-1]['state']})
        print(f"{tid}: {len(rows)} rows, final state {rows[-1]['state']}  ({desc})")
    with open(os.path.join(outdir, 'manifest.json'), 'w') as fh:
        json.dump(manifest, fh, indent=1)
    print(f"wrote {len(SCHEDULES)} traces, {total} rows, to {outdir}")


if __name__ == '__main__':
    what = sys.argv[1] if len(sys.argv) > 1 else 'all'
    failed = 0
    if what in ('vectors', 'all'):
        failed = vectors()
    if what in ('calibration', 'all'):
        calibration()
    if what == 'trace':
        if len(sys.argv) < 3:
            sys.exit("usage: python3 -I sim.py trace OUTDIR")
        write_traces(sys.argv[2])
    sys.exit(1 if failed else 0)
