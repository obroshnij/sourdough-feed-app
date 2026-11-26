# Starter simulation spec

Owner: `sourdough-scientist`. This is the authority for every starter number. Science claims behind it live in [`sourdough-science.md`](sourdough-science.md) (cited as **SCI §n**).

**Status:** v1, Phase 1. Every equation below was run in a throwaway Python model (60 s explicit Euler) and the numbers in §15 and §18 come from that run. Readout tables in §14 were derived from the same curves but the readout functions themselves were not coded yet. Each number is marked **sourced** (with an SCI reference) or **tuned** (tuned for game).

Conventions: grams, °C, seconds in data; rates below are written **per hour**, so multiply by `dt_s / 3600`. `clamp(x, a, b)` limits x to [a, b]. All functions are pure: `step(state, env, dt_s) -> state`. No engine calls, no hidden randomness.

---

## 1. State variables

**Stored** fields are saved. **Derived** fields are recomputed from stored fields and the environment, never saved.

| Name | Unit | Range | Kind | Meaning |
|---|---|---|---|---|
| `food` | 0..1 | 0..1 | stored | Fermentable food per gram of flour. 1 = fresh flour. |
| `food_at_feed` | 0..1 | 0..1 | stored | `food` right after the last feed. Used for phase detection. |
| `yeast` | relative | 0.001..1.5 | stored | Yeast population. 1 = ripe mature starter. |
| `lab` | relative | 0.001..1.5 | stored | Lactic acid bacteria population. |
| `acid` | 0..1 | 0..1 | stored | Total acidity, normalized. Approximate pH = 6.0 - 2.6 × acid (display only, **tuned**). |
| `rise` | × height | 1.0..3.0 | stored | Height divided by height right after the last feed. |
| `peak_rise` | × height | 1.0..3.0 | stored | Highest `rise` since the last feed. Also the streak line on the glass. |
| `peak_rate` | ×/h | 0..∞ | stored | Highest rise slope since the last feed. |
| `hooch` | 0..1 | 0..1 | stored | Liquid layer on top. 1 = about 1 cm. |
| `dryness` | 0..1 | 0..1 | stored | Surface skin (0.3) to crust (0.7). |
| `vigor` | 0..1 | 0.15..1 | stored | Culture strength (health). Multiplies growth and gas. |
| `vigor_at_feed` | 0..1 | 0.15..1 | stored | `vigor` at the last feed. Drives `recovering`. |
| `maturity` | 0..1 | 0..1 | stored | How established. Never decreases. |
| `starved_h` | weighted h | 0..336 | stored | Temperature-weighted hours since food ran out. Reset by a feed. |
| `mold_risk` | 0..1 | 0..1 | stored | Mold conditions. Watch 0.3, warning 0.5, mold 1.0. |
| `moldy` | bool | | stored | Latched when `mold_risk` reaches 1.0. Never cleared. |
| `temp_c` | °C | -5..45 | stored | Temperature of the starter itself. Lags the environment. |
| `since_feed_s` | s | ≥ 0 | stored | Time since the last feed. |
| `mass_g` | g | ≥ 1 | stored | Starter in the jar. Changes only at feeds. |
| `culture_hydration` | % | 40..200 | stored | Water ÷ flour of the culture, blended at each feed. |
| `flour_mix` | share per flour id | sums to 1 | stored | Flour composition of the culture, blended at each feed. |
| `feed_jitter` | × | 0.95..1.05 | stored | Per-feed rate multiplier (§17). |
| `rise_rate` | ×/h | | derived | d rise / dt from §7. No `prev_rise` needed. |
| `gas` | relative | | derived | Gas production (§7). Drives bubbles. |
| `state`, `rise_phase` | id | | derived | §12. |
| `smells` | map | | derived | §13. |

No rolling windows. All history lives in the scalar accumulators above.

## 2. Inputs

### 2.1 Feed (`FeedAction`)
`kept_g` (≥ 1, ≤ `mass_g`), `flour_g` per flour id, `water_g`, `hooch_choice` (`pour_off` or `stir_in`). Ratio and hydration are derived: ratio = kept : Σflour : water, hydration = water ÷ Σflour × 100. A feed on a `moldy` starter is refused (no change).

### 2.2 Environment
| Location | Temp °C | RH % | Source |
|---|---|---|---|
| `counter` | 22 | 50 | tuned (agreed with game-designer) |
| `warm_spot` | 26 | 40 | tuned |
| `window_sill` | 18 | 55 | tuned |
| `fridge` | 4 | 70 | tuned (typical home fridge) |
| `proofing_box` | 26, player-set 24..30 | 60 | tuned |

RH is a fixed per-location property, not a player control (game-designer R6).

| Cover | `cover_dry` | Container | `container_dry` |
|---|---|---|---|
| `loose_lid` | 0.35 | `classic_jar` | 1.0 |
| `cloth` | 1.0 | `wide_mouth_jar` | 1.3 |
| `tight_lid` | 0.05 | `ceramic_crock` | 1.0 |
| | | `fermentation_vessel` | 0.3 |

Covers and containers affect **only** `dryness` (and through it, mold speed, capped at +40%). All values are tuned. Container values were not exercised in the script, but they fall inside the tested range of the cover factor.

## 3. Temperature response

All rates use the starter's own `temp_c`, not the room.

```
CTMI(T; Tmin, Topt, Tmax) = 0 if T <= Tmin or T >= Tmax, else
  (T - Tmax)(T - Tmin)^2 / ((Topt - Tmin)[(Topt - Tmin)(T - Topt) - (Topt - Tmax)(Topt + Tmin - 2T)])

phi_y(T) = CTMI(T; 8, 27, 36)          yeast growth       sourced (SCI §2, Gänzle 1998)
phi_l(T) = CTMI(T; 3.5, 32.5, 41)      LAB growth         sourced (SCI §2, Gänzle 1998)
ferm(T)  = CTMI(T; -2, 34, 45) / CTMI(24; -2, 34, 45)       fermentation: food use, gas, acid, hooch   tuned
dec(T)   = 2.2^((T - 24)/10), times (45 - T)/11 above 34 C  decay: starvation clock, vigor loss, death  tuned
mold_t(T)= clamp(0.05 + 0.05 (T - 3), 0, 1.6) for T > 3, else 0.05 T/3   mold conditions   tuned

temp_c <- temp_c + (T_env - temp_c)(1 - exp(-dt_h / 1.5))   starter warms or cools with a 1.5 h time constant
```

| T °C | 4 | 10 | 14 | 18 | 22 | 24 | 26 | 28 | 32 | 36 |
|---|---|---|---|---|---|---|---|---|---|---|
| phi_y | 0 | 0.03 | 0.23 | 0.53 | 0.82 | 0.93 | 0.99 | 0.99 | 0.73 | 0 |
| phi_l | 0.001 | 0.09 | 0.22 | 0.40 | 0.60 | 0.71 | 0.81 | 0.90 | 1.00 | 0.89 |
| ferm | 0.07 | 0.26 | 0.44 | 0.66 | 0.89 | 1.00 | 1.11 | 1.20 | 1.34 | 1.33 |
| dec | 0.21 | 0.33 | 0.45 | 0.62 | 0.85 | 1.00 | 1.17 | 1.37 | 1.88 | 2.32 |

**Why cardinal, not a plain Q10.** A single Q10 (about 2 to 3) fits 15 to 30 °C, but it fails at both ends. It has no optimum, so 35 °C would be the fastest setting, while yeast growth actually stops near 36 °C (Gänzle 1998). And it gives a fridge starter about a fifth of room-temperature activity, when real fridge starters keep for about a week per feed (SCI §3). The cardinal model (CTMI, Rosso et al. 1993) uses the published cardinal temperatures directly and gives zero growth outside them. Q10 is kept only for slow decay processes (starvation, loss of vigor), which do not stop at a growth minimum. The 1.5 h starter lag is a Newton-cooling estimate for about 200 g of paste in a glass jar (**tuned**).

## 4. Flour profiles

| Flour | `speed` | `acid` | `absorb` | `retain` | Observable difference |
|---|---|---|---|---|---|
| `white_bread` | 1.00 | 1.00 | 1.00 | 1.00 | Tallest smooth dome, mildest smell |
| `whole_wheat` | 1.20 | 1.35 | 1.12 | 0.85 | About 10% faster, sourer, tan with bran flecks, lower dome |
| `rye` | 1.35 | 1.70 | 1.25 | 0.65 | About 15% faster, sourest, rises least (about 1.65x), cracked or pitted top |
| `spelt` | 1.10 | 1.10 | 0.95 | 0.85 | About 8% faster, looser paste at the same hydration, lower dome |

Directions are sourced (whole grain is faster, rye adds acidity, rye holds gas poorly: SCI §5). Magnitudes are **tuned**. Mixes use the weighted average by `flour_mix`.

## 5. Hydration

```
h_eff     = culture_hydration / absorb
hyd_speed = clamp((h_eff/100)^0.6, 0.6, 1.2)
hyd_ret   = clamp((100/h_eff)^0.5, 0.6, 1.35)     stiffer paste traps more gas
hyd_acid  = clamp((100/h_eff)^0.3, 0.85, 1.2)     firm sourdough builds more total acid (SCI §4, Di Cagno 2014)
hyd_hooch = clamp((h_eff - 55)/45, 0, 1.6)        stiff starters make almost no hooch
```
Result (22 °C, 1:1:1): 60% peaks 6.9 h at 2.35x, 100% peaks 6.3 h at 2.18x, 125% peaks 6.1 h at 2.11x. Direction sourced, magnitude **tuned**.

## 6. Feeding (ratio as dilution)

Evaluated before the reset. Maturity first: if `peak_rise ≥ 1.5` and `vigor ≥ 0.6`, then `maturity += 0.01024 × w × (1 - maturity)`, where `w = min(2.5, log2(total / kept_g) / log2(3))` is the number of microbial generations this new feed buys, relative to a 1:1:1 feed (§9).
```
total       = kept_g + flour_g + water_g
p           = kept_g / total                               inoculum fraction
kept_flour  = kept_g × 100 / (100 + culture_hydration);  kept_water = kept_g - kept_flour
if stir_in:   kept_water += 5 × hooch × kept_flour / 100   (+5 hydration points per unit hooch; tuned, untested)
food        = (kept_flour × food + flour_g) / (kept_flour + flour_g)
yeast, lab  = max(0.001, x × p)
acid        = acid × p
culture_hydration = (kept_water + water_g) / (kept_flour + flour_g) × 100
flour_mix   = flour-weighted blend;  mass_g = total
reset: rise = 1, peak_rise = 1, peak_rate = 0, hooch = 0, dryness = 0, starved_h = 0, since_feed_s = 0
mold_risk   = 0.3 × mold_risk                           (only if not moldy)
food_at_feed = food;  vigor_at_feed = vigor;  feed_jitter = rng draw (§17)
```
Minimum keep is 1 g; it is simply a big dilution (1 g + 50 g flour + 50 g water peaks in about 18 h at 22 °C). Maximum mass is the container's job (UI rule), not the sim's.

## 7. Rate equations (per hour)

```
sf      = food / (0.03 + food)                      Monod food term
hunger  = max(0, 1 - sf × 1.03)                     0 while fed, 1 when food = 0
starving= food < 0.10
mat_f   = 0.7 + 0.3 × min(1, maturity / 0.5)
k       = vigor × speed × hyd_speed × feed_jitter × mat_f
inh_l   = max(0, 1 - (acid/0.95)^4)                 LAB stop near pH 3.8 (SCI §2)
inh_y   = max(0, 1 - (acid/1.15)^3)                 yeast more acid tolerant (SCI §2)

g_y = 0.405 × phi_y × k × sf × inh_y × (1 - yeast/1.5)
g_l = 0.540 × phi_l × k × sf × inh_l × (1 - lab/1.5)
d yeast = g_y × yeast - 0.012 × dec × yeast × hunger
d lab   = g_l × lab   - 0.006 × dec × lab × hunger

act     = (yeast + 0.6 lab) × ferm × sf × min(1, 0.5 + 0.5 vigor)
d food  = -0.16 × act × speed
gas     = (yeast + 0.35 lab) × ferm × sf × vigor × mat_f          (0.35: LAB also make CO2, SCI §2)
d rise  = 0.45 × gas × retain × hyd_ret - 0.085 × (rise - 1) × (1 + 0.5 acid)
d acid  = (0.22 × lab × ferm × sf + 0.02 × lab × ferm × hunger) × acid_f × hyd_acid × (1 - acid)
d starved_h = dec if starving else 0
d hooch = 0.022 × ferm × hyd_hooch × hunger      only when starved_h > 6
d vigor = -0.0075 × dec                           if starving and starved_h > 8
        = +0.11 × (1 - vigor) × sf × min(1, phi_y + phi_l)   if not starving
d dryness = 0.045 × cover_dry × container_dry × (1 - RH/100) × (1 - dryness) × min(1.5, dec)
d mold_risk: see §10
```
After each step: clamp every variable to its §1 range, then `peak_rise = max(peak_rise, rise)`, `peak_rate = max(peak_rate, d rise)`, and update `temp_c`. While `moldy`, only `since_feed_s` advances.

`acid_f` is the flour `acid` column. Every coefficient in this section is **tuned** so that §15 matches its sources.

## 8. Rise, peak, collapse, hunger, hooch (what the equations produce)

- Populations regrow from the inoculum. Gas tracks population, so rise accelerates. When food runs low, gas drops, the dome stops, and gas leaks out faster as acid weakens the gluten. That is the collapse.
- The peak comes about when food falls under 0.1. Higher ratios start from fewer cells, so they take longer: about 2.2 h extra per tripling of dilution at 22 °C.
- After the collapse the starter settles near 1.0 to 1.2x. `hooch` starts about 6 weighted hours after food runs out, faster when warm and wet.

## 9. Acid, vigor, maturity, recovery

- **Acid** rises with LAB activity, faster with whole grain and stiff paste, and creeps up while starved. A 1:1:1 feed cuts it to a third.
- **Vigor** drops only after 8 weighted hours of starvation, at 0.0075 per weighted hour. It recovers while fed: a gap closes by about 55% per normal cycle. A floor of 0.15 means starvation alone never ends a starter.
- **Recovery** needs no special code: weak vigor means slower, lower rises, and each feed closes the gap. Results are in §15.
- **Maturity** never decreases. Stage thresholds (stage ids are an open decision for the director): young < 0.33, steady 0.33, mature 0.50, seasoned 0.83. Gain per qualifying feed is weighted by generations (`w` in §6), because community selection in backslopping happens per growth cycle and a bigger dilution buys more doublings (SCI §7; reasoning, low confidence, **tuned**). The weight is capped at 2.5 so huge dilutions can't be farmed. Days to steady, mature and seasoned from 0.2:

  | Routine | Steady | Mature | Seasoned |
  |---|---|---|---|
  | twice a day, 1:2:2 (reference) | 6 | 16 | 51.5 |
  | twice a day, 1:1:1 | 9 | 23 | 75.5 |
  | twice a day, 1:5:5 | 4 | 10.5 | 34.5 |
  | once a day, 1:5:5 | 8 | 21 | 69 |
  | once a day, 1:1:1 | 18 | 46 | 151 |

  Young to mature reflects real stabilization over about 2 weeks (SCI §7). "Seasoned" is a game label with no biological claim. Maturity does **not** affect mold.

## 10. Mold risk (fires only under its real causes)

The real causes are long unfed time at room temperature (no stirring, no fresh acidification, culture in decline) and a dry surface or crust (SCI §9). `mold_risk` models those **conditions**. It is not a hidden mold colony.
```
if starving and starved_h > 24:
    mult = min(2.2, mold_t(temp_c) × (1 + 0.4 × dryness))
    d mold_risk = 0.0070 × mult × (1 - 0.6 × mold_risk)
elif not starving:
    d mold_risk = -0.02 × sf
feed: mold_risk × 0.3      moldy = true when mold_risk ≥ 1.0 (latched; feeds refused)
```
| Stage | `mold_risk` | What the player can notice |
|---|---|---|
| none | < 0.3 | Normal hunger signs only |
| watch | 0.3 to 0.5 | Faint `musty` note, always listed first. Dry skin if the cover allows it. Thick, darker hooch. Flat, no bubbles. |
| warning (`unhealthy`) | 0.5 to 1.0 | `musty` clear to strong, plus the above. Still fixed by one feed. |
| mold (`moldy`) | 1.0 | Fuzzy spots, optional pink or orange tint. Discard. |

**Guarantees** (all checked in the script):
- No accrual in the first 24 weighted starved hours. A once-a-day feeder never accrues any risk at 22 to 24 °C.
- The 2.2 multiplier cap guarantees at least 61 h from warning to mold, and at least 79 h from watch to mold, at any temperature.
- The fridge (`mold_t` = 0.06) reaches only 0.12 to 0.15 in 14 days.
- Warning signs never include fuzz or pink, orange or red color. Those appear **only** in `moldy`, because in real life they mean discard (SCI §9).
- All mold timings are **tuned**. Real mold timing is not predictable (SCI §9).

## 11. Dryness

A skin forms on an undisturbed surface: fast under `cloth` in dry air, slowly under `loose_lid`, almost never under `tight_lid`. A feed resets it to 0. Thresholds: skin 0.3, crust 0.7. At the counter, a cloth gives skin in about 0.8 days and crust in 2.6 days. A loose lid gives skin in 2.2 days. **Tuned.** Direction sourced: dried crust is where discoloration and mold show up first (SCI §9).

## 12. State derivation

### 12.1 Rise phase (always computed, exposed as `rise_phase`), first match wins
1. `hungry`: food < 0.10 and (rise ≤ 1 + 0.5 × (peak_rise - 1) or peak_rise < 1.15)
2. `freshly_fed`: since_feed_s < 3600 and rise < 1.05
3. `at_peak`: rise ≥ 0.94 × peak_rise and rise > 1.15 and rise_rate < 0.2 × peak_rate
4. `collapsing`: rise_rate < 0 and rise < 0.94 × peak_rise
5. `developing`: rise < 1.15
6. `near_peak`: rise_rate < 0.75 × peak_rate or food < 0.25 × food_at_feed
7. `active`: otherwise

### 12.2 State (the one word in the status pill), first match wins
| # | State | Rule | Safety tier |
|---|---|---|---|
| 1 | `moldy` | `moldy` latched | discard |
| 2 | `unhealthy` | mold_risk ≥ 0.5 | warning, fixable by feeding |
| 3 | `dormant` | ferm(temp_c) < 0.30 (below about 11 °C) or starved_h ≥ 60 | calm |
| 4 | `hungry` | rise_phase = `hungry` | calm |
| 5 | `recovering` | vigor < 0.6 or vigor_at_feed < 0.75 | calm |
| 6 | rise phase | `freshly_fed`, `developing`, `active`, `near_peak`, `at_peak`, `collapsing` | calm |

Typical day at 22 °C after a 1:1:1 feed: freshly_fed 0 to 0.3 h, developing to 1.0 h, active to 4.9 h, near_peak to 6.1 h, at_peak to 7.5 h, collapsing to 12.8 h, hungry after that. Counter neglect: dormant from 3.1 days, unhealthy from 4.5 days, moldy at 8.9 days.

## 13. Smell model

Final descriptor list: the vision seed list, unchanged. `wet_flour`, `mildly_fruity`, `fresh_yeasty`, `yogurt`, `pleasantly_tangy`, `strongly_acidic`, `alcohol`, `acetone`, `cheesy`, `musty`.
```
p     = clamp(1 - food / food_at_feed, 0, 1)     share of this feed's food used
gas_n = clamp(gas, 0, 1)
tri(x; a, b, c) = rises 0 to 1 from a to b, falls to 0 at c
wet_flour        = clamp(1 - p/0.3)
mildly_fruity    = 0.9 × gas_n × tri(p; 0.05, 0.3, 0.7)
fresh_yeasty     = gas_n × clamp(yeast/0.5)
yogurt           = tri(acid; 0.25, 0.45, 0.70) × clamp(0.3 + gas_n)
pleasantly_tangy = tri(acid; 0.45, 0.68, 0.88)
strongly_acidic  = clamp((acid - 0.72)/0.15)
alcohol          = 0.8 × clamp(starved_h/10) + 0.2 × hooch
acetone          = clamp((starved_h - 14)/24)
cheesy           = clamp((0.33 - maturity)/0.13) × (0.5 + 0.5 gas_n)
musty            = 0 if mold_risk < 0.3, else max(0.2, clamp((mold_risk - 0.2)/0.5))
cold damping: every intensity except musty × clamp(0.35 + 0.65 × ferm(temp_c))
moldy: {musty: 1.0} only
```
`musty` is exempt from cold damping on purpose. It is the warning sign, so it shows and comes first whenever `mold_risk ≥ 0.3`, at any temperature (game rule; real cold does mute smells).
Display the top 3 with intensity ≥ 0.15. `musty`, when present, is always listed first. Words: faint 0.15 to 0.35, clear 0.35 to 0.7, strong ≥ 0.7.

| State | Typical set from the script (22 °C) |
|---|---|
| freshly_fed | wet_flour strong, fresh_yeasty faint |
| developing, active | wet_flour fading; fresh_yeasty, mildly_fruity, yogurt |
| near_peak, at_peak | pleasantly_tangy, fresh_yeasty, yogurt |
| collapsing | pleasantly_tangy, alcohol |
| hungry | pleasantly_tangy and alcohol, then acetone after about a day, strongly_acidic after about 2.5 days |
| dormant (cold) | faint: alcohol, pleasantly_tangy, acetone |
| dormant (neglect) | alcohol, acetone, strongly_acidic |
| recovering | wet_flour longer, then yogurt and tangy (a slower version of the rise phases) |
| unhealthy | musty first, then strongly_acidic, alcohol or acetone |
| moldy | musty only. Copy: don't sniff closely, discard. |
| young (maturity < 0.33) | cheesy added to any rising or hungry set |

## 14. Inspection readouts

Readout keys are proposals for narrative-designer's copy. Thresholds come from the script's curves; the readout functions themselves are not coded yet.

| Kind | Reveals | Key (condition) |
|---|---|---|
| `bubbles` | gas, rise_phase | `none` (gas_n < 0.05 and state is hungry, dormant or unhealthy) · `few_tiny` (rise < 1.15) · `many_small` (active) · `large_at_top` (near_peak, at_peak) · `popped_craters` (collapsing, hungry with gas_n ≥ 0.05) |
| `consistency` | h_eff, acid, phase | `stiff_dough` (h_eff < 75) · `thick_batter` (75 to 110, before active) · `loose_batter` (h_eff ≥ 110, before active) · `airy_webby` (active to at_peak) · `slack_soupy` (after peak and acid ≥ 0.75) |
| `height` | rise, rise_rate, peak_rise | level: `at_mark` (< 1.1), `up_a_quarter` (< 1.4), `up_half` (< 1.75), `doubled` (< 2.25), `more_than_doubled`. trend: `rising` (rise_rate > 0.02), `steady`, `falling` (< -0.02). `streak_line` when peak_rise - rise ≥ 0.2 (it peaked, and the line on the glass shows how high). |
| `surface` | rise_rate, hooch, dryness, mold_risk, rye share | shape: `smooth_flat`, `domed` (rising, rise ≥ 1.3), `flat_bubbly` (at_peak), `sunken` (collapsing), `cracked` (rye share ≥ 0.5 and rise ≥ 1.3). hooch: `hooch_thin` (0.1 to 0.4), `hooch_layer` (0.4 to 0.8), `hooch_dark` (≥ 0.8, or ≥ 0.4 with starved_h ≥ 72). skin: `skin` (dryness ≥ 0.3), `crust` (≥ 0.7). `fuzzy_spots` only when moldy. |
| `development` | maturity, vigor, vigor_at_feed | stage: young, steady, mature, seasoned (§9). strength: `strong` (vigor ≥ 0.85), `steady` (≥ 0.6), `weakened` (< 0.6). `young` adds "rises still uneven". |

Ambiguous pairs, where the readout should suggest smelling: freshly_fed vs dormant, near_peak vs at_peak, collapsing vs hungry, dormant vs unhealthy, young vs weakened.

## 15. Calibration table

Script run, jitter 1.0, mature (maturity 0.6), `white_bread` 100%, `loose_lid`, unless noted.

| Scenario | Model result | Target | Basis |
|---|---|---|---|
| 1:1:1 at 24 °C | peak 5.5 h, 2.21x | 4 to 6 h at about 25.5 °C, "doubled" | sourced: King Arthur 2025 (SCI §3) |
| 1:2:2 at 24 °C | 7.3 h, 2.40x | peak between 4 and 8 h at 25.5 °C | sourced: same test |
| 1:4:4 at 24 °C | 9.0 h | peak between 8 and 12 h at 25.5 °C | sourced: same test |
| 1:5:5 at 24 °C | 9.8 h, 2.54x | about 10 h at about 24 °C (with 30% rye) | sourced: Perfect Loaf (SCI §3) |
| 1:1:1 at 22 °C | 6.0 to 6.3 h, 2.18x | 4 to 6 h (design ask) | tuned; 6 h is the fastest honest value |
| 1:2:2 / 1:5:5 / 1:10:10 at 22 °C | 8.0 / 10.75 / 13.0 h | 6 to 9 / 9 to 13 / none | tuned (game-designer R1) |
| 1:50:50 at 22 / 24 °C | 18.0 / 16.1 h | peaks within 24 h | tuned |
| 1:1:1 at 18 / 20 / 28 / 32 / 35 °C | 8.9 / 7.2 / 4.7 / 4.5 / 5.1 h | slower when cool, a plateau then slowdown above about 32 | direction sourced (Gänzle 1998), times tuned |
| Hungry after 1:1:1 at 22 °C | 12.4 to 12.8 h | ready to feed again after about 12 h | sourced: King Arthur 2025 |
| Hooch visible (≥ 0.1), counter | 17 h | "thin sheen" when hungry | tuned |
| Fed, then into the fridge | food out on day 3 to 4, hooch on day 7, vigor 0.64 at 14 days | weekly fridge feeding works | direction sourced (Perfect Loaf), tuned |
| Neglect at counter, loose lid | dormant 3.1 d, watch 3.1 d, unhealthy 4.5 d, mold 8.9 d | floors: unhealthy ≥ 4 d, mold ≥ 7 d, warning to mold ≥ 72 h, watch to mold ≥ 96 h | tuned (game-mechanics §9) |
| Neglect, counter cloth / tight lid | unhealthy 4.15 / 4.8 d, mold 8.2 / 10.0 d | as above | tuned |
| Neglect, warm_spot loose / cloth | 3.5 / 3.3 d, mold 7.1 / 6.6 d (gap 85 / 80 h) | gap ≥ 48 h in the worst combination | tuned |
| Neglect, 35 °C cloth, 30% RH | unhealthy 2.3 d, mold 4.8 d (gap 60 h) | gap ≥ 48 h | tuned |
| Neglect, window_sill | unhealthy 5.8 d, mold 11.4 d | | tuned |
| Away 24 h, then feeds every 12 h | first peak 2.12x (98% of normal) | ≥ 85% on feed 1 | tuned (R3) |
| Away 72 h | recovering on feed 1 (1.91x, 9.4 h), normal by feed 2 to 3 | ≤ 2 feeds | tuned (vision) |
| Unhealthy (5 d), then fed | out of unhealthy at once; feed 1 at 1.71x, 12 h; normal by feed 3 | ≤ 3 feeds | tuned (R3) |
| Fridge 14 d, then fed | recovering on feed 1 (1.76x to 1.9x, about 13 h); normal on feed 2 | 1 to 2 feeds | sourced direction (King Arthur 2023), tuned |
| Once a day, 1:1:1, 14 d at 22 / 24 °C | min vigor 0.89 / 0.83, mold 0 | "thrives" | vision |
| Three feeds 3 h apart, before peak | next peak 10.5 h instead of 6.3 h | visibly weaker (R7) | tuned |

## 16. Offline catch-up

- **Step:** fixed 60 s explicit Euler on a grid aligned to Unix time (tech-architect's design). Live play and catch-up take identical steps. Feeds and environment changes apply at the last grid point at or before the action.
- **Invariant:** one long catch-up equals any split into short ones **exactly**. Checked: 5 days split at random points (1 s to 2 h) gave a max abs difference of 0.0 on every field.
- **Accuracy:** 60 s vs 10 s steps: same peak time (to 0.01 h), peak height within 0.001, state change times within 0.02 h. 300 s steps would also work (within 0.15 h), but 60 s is cheap.
- **Cost:** 10 days (14,400 steps, with state derivation every step) took 0.12 s in CPython on the Mac. GDScript should be the same order of magnitude; phone numbers are an estimate until measured. No analytic shortcut needed.
- **14-day cap:** simulate 14 days, then hold the state and jump the clock (D-013). On the counter, that is moldy long before the cap. In the fridge, it understates weakening after very long absences (real fridge starters left 8 weeks need 2 or more days of feeds, SCI §3), but they stay recoverable, which matches biology. Accepted, with the narrative flag in Open decisions.
- **Stability:** the largest rate times dt is about 0.01 per step. No stiffness. Clamp to ranges after every step.

## 17. Randomness

Only `feed_jitter`, uniform in [0.95, 1.05], drawn once per feed from the passed-in seeded `RandomNumberGenerator` (`randf_range`, never `randfn`), then stored. It shifts peak times by up to ±0.5 h. Nothing else is random: mold onset, smells and readouts are deterministic. Every test vector below holds for every seed.

## 18. Test vectors (golden tests)

Fixture `MATURE`: start from the stored defaults (food 0.05, yeast 0.9, lab 0.95, acid 0.85, rise 1.15, peak_rise 2.2, peak_rate 0.5, vigor 1, vigor_at_feed 1, maturity 0.6, mass 100 g, 100%, white_bread, temp_c 22, everything else 0). Feed 50 g + 50 g flour + 50 g water, then run 12 h at `counter` with a `loose_lid`. Unless noted, a vector feeds `MATURE` with 50 g kept at the stated ratio, white_bread 100%, loose lid, and sets temp_c to the test temperature before feeding. Rise ranges cover jitter 0.95 to 1.05. Allow a further ±0.3 h on times and ±0.05 on rise for float drift. Every row is **tuned**, except where a sourced target is named in §15.

| ID | Inputs | Expected |
|---|---|---|
| V1 | 1:1:1, 24 °C, 48 h | peak 5.4 to 5.6 h at 2.20 to 2.22x. 2 h: active, 1.37 to 1.38. 4 h: active or near_peak, 1.87 to 1.92. 8 h: collapsing, about 1.94. 12 h: collapsing or hungry, about 1.60. 24 h: hungry, 1.16, hooch yes, smell set {pleasantly_tangy, alcohol, acetone}. 48 h: hungry, 1.01, acetone. Mold stage none throughout. |
| V2 | 1:1:1 at 20, 22, 28 °C | peaks 7.1 to 7.4 / 6.1 to 6.3 / 4.6 to 4.8 h. Order 28 < 24 < 20 for the same seed. 28 °C at 48 h: dormant (neglect). |
| V3 | 1:5:5 and 1:10:10 (10 g kept), 24 °C | peaks 9.6 to 10.1 h (2.52 to 2.55x) and 11.4 to 12.1 h (2.57 to 2.60x). Later than V1 by 4.3 and 6.2 h. |
| V4 | 1:50:50 (2 g kept), 24 °C | peaks 15.6 to 16.7 h, 2.60 to 2.64x. Yes, within 24 h. |
| V5 | rye, whole_wheat, spelt, 1:1:1, 22 °C, after 3 conversion feeds at 12 h | peaks 5.1 to 5.3 / 5.5 to 5.7 / 5.5 to 5.8 h at about 1.66 / 1.91 / 1.91x. Acid at 24 h: rye > whole_wheat > white. Speed: rye > whole_wheat ≥ spelt > white. |
| V6 | white 60% vs 100% vs 125%, 22 °C, 3 conversion feeds | peaks 6.7 to 6.9 / 6.1 to 6.3 / 6.0 to 6.2 h. 60%: 2.34 to 2.36x, hooch never ≥ 0.1 in 48 h. |
| V7 | fed, 1 h on the counter, then fridge 3 / 14 d, then fed 1:1:1 at the counter | at 3 d: dormant in the fridge, then a normal state after feeding (peak 10.2 to 10.6 h, not recovering). At 14 d: dormant, hooch ≥ 0.3, mold < 0.3, vigor 0.6 to 0.7. After feeding: recovering at 2, 4, 8, 12 h; peak 13.5 to 14.1 h at about 1.9x. The next feed is normal (not recovering). |
| V8 | 24 h unfed at the counter, then 1:1:1 | before the feed: hungry, hooch yes, vigor 0.92 to 0.96. Peak 6.7 to 6.9 h, ≥ 0.85 × the V2 22 °C peak. Not recovering. |
| V9 | unfed at the counter, loose lid, 14 d | hungry 12.4 to 12.8 h. dormant 74 to 77 h. watch (0.3) 72 to 80 h. unhealthy 104 to 111 h. moldy 207 to 219 h. Gap from warning to mold ≥ 72 h; from watch to mold ≥ 96 h. |
| V9b | V9 to 120 h (unhealthy), then 1:1:1 | out of unhealthy right after the feed (mold_risk < 0.3). recovering at 2 to 12 h. Peak 12.8 to 13.3 h at about 1.76x. Rise at peak ≥ 0.95 × normal by feed 3. |
| V10 | 12 feeds of 1:1:1, 10 min apart | all variables in range. yeast and lab at or near the floor of 0.001. state freshly_fed or developing. Next peak about 25 h later at about 2.6x. |
| V11 | keep 1 g + 1 g + 1 g; keep 1 g + 50 g + 50 g; keep 0 g | 1:1:1 behaves like V2 at 22 °C. 1:50:50 peaks about 18 h. Keep 0 is rejected by the input validation (not a feed). |
| V12 | 1:1:1 at 32 °C and 35 °C | peaks 4.5 to 4.6 h and 5.0 to 5.2 h (slower above the optimum). At 48 h: dormant with mold stage watch and musty first. |
| V13 | counter, unfed, 30 days away | catch-up caps at 14 d. moldy (latched) at about 8.9 d. Fridge variant: dormant, vigor 0.6 to 0.7, mold < 0.3. |
| V14 | moldy, then feed | the feed is refused. State stays moldy, every field unchanged except since_feed_s. |
| V15 | V7 to 14 d in the fridge (unfed after), then counter unfed | mold_risk 0.10 to 0.18 on leaving the fridge. unhealthy about 55 to 65 h after leaving; moldy about 150 to 165 h after. Gap ≥ 72 h. |
| V16 | once a day, 1:1:1, 14 d, 22 and 24 °C | vigor ≥ 0.8 always. mold_risk 0. Never recovering, dormant or unhealthy. |
| V17 | catch-up split | any split of a 5-day run equals the unsplit run exactly (same build). |

## 19. Tuning knobs (for game-designer)

| Knob | Value | Effect |
|---|---|---|
| `mu_y`, `mu_l` | 0.405, 0.540 /h | Overall speed. Scale both together. |
| `gas_gain`, `leak` | 0.45, 0.085 /h | Peak height and collapse speed |
| location temps | §2.2 | Biggest single lever on timing |
| `hungry_food` | 0.10 | When hungry starts |
| `dormant_starved_h` | 60 | Neglect dormant onset (about 3.1 d at 22 °C) |
| `vigor_grace_h`, `vigor_loss` | 8, 0.0075 | How fast neglect weakens it |
| `vigor_gain` | 0.11 | Feeds needed to recover |
| `recover_vigor`, `recover_at_feed` | 0.6, 0.75 | When `recovering` shows |
| `mold_onset_h` | 24 | Starvation before any mold risk |
| `mold_rate` | 0.0070 /h | Mold days (counter loose lid: 8.9 d) |
| `mold_mult_cap` | 2.2 | Worst-case warning window (≥ 48 h) |
| `mold_feed_keep` | 0.3 | Risk left after a feed |
| `mat_step`, `mat_w_cap` | 0.01024, 2.5 | Maturity pacing, generation weight cap |
| `feed_jitter` range | ±5% | Run-to-run variety |

Changing a knob means rerunning the §18 vectors.

## 20. Known simplifications

- One acid variable. Lactic and acetic acid are not split. The `acid` flour factor carries the "sourer" difference.
- Acetic acid bacteria, kahm yeast and contamination from dirty tools are not modeled. Mold comes only from neglect, the most common real cause (SCI §9).
- No day and night temperature swing. Each location is one constant temperature.
- No heat damage. Proofing is capped at 30 °C in game; the curves still behave sensibly to 40 °C.
- Mold timing is a game rule built on real risk factors, not a prediction.
