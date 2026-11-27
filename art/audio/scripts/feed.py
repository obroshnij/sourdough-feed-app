"""The feed sequence (ux-design section 8, Bus.feed_moment): feed_hooch, feed_discard, feed_scoop,
feed_pour, feed_stir; and starter_new, the empty jar filling (docs/audio-direction.md).

Each sound fits its beat at the normal feed speed (hooch 0.6 s, discard 0.8 s, scoop 0.9 s, pour 0.8 s,
stir 1.2 s). On the slower first feed (6 s) the beats are longer and the gaps simply grow; only the stir
runs long enough (1.8 s) to cover its stretched beat, and T2 fades it out at the next step.

Rebuild: python3 -I art/audio/scripts/feed.py
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np  # noqa: E402

import audio_lib as A  # noqa: E402

# A dessert spoon: thin steel, rings high and briefly.
SPOON_FREQS = (2850.0, 4720.0, 7900.0)
SPOON_TAUS = (0.03, 0.018, 0.008)
SPOON_AMPS = (1.0, 0.5, 0.2)


def spoon_tap(n: int, gain: float) -> np.ndarray:
    """The spoon tapping the glass rim: spoon and jar ringing together, very short."""
    x = A.modes(n, SPOON_FREQS, SPOON_TAUS, SPOON_AMPS) + A.jar_ring(n, gain=0.6, damp=0.35, bright=1.4)
    return A.strike(x, 5000.0) * gain


def wet_thud(n: int, rand: A.Rand, pitch: float) -> np.ndarray:
    """Soft starter landing on something: a damped low-mid knock plus a short wet splat."""
    knock = A.strike(A.modes(n, [pitch, pitch * 1.62], [0.04, 0.025], [1.0, 0.4]), 700.0)
    splat = A.burst(n, rand, 0.03, 400.0, 2000.0) * 0.5
    return knock + splat


def feed_hooch() -> np.ndarray:
    """Pouring the thin hooch off the lip (beat 1, only when hooch is present): a light trickle with
    fine fizz, thinner and higher than the water pour."""
    rand = A.Rand(301)
    n = A.n_of(0.6)
    pts = [(0.0, 0.0), (0.05, 1.0), (0.38, 0.9), (0.55, 0.0)]
    x = A.stream(n, rand, 1000.0, 4500.0, pts, flutter=0.5) * 0.1
    x += A.bubble_field(n, rand, 110.0, 0.04, 0.5, 1200.0, 3500.0, 0.002, 0.006, 6.0, 14.0, 0.2, 0.6)
    x = A.filt(x, A.rbj("lowpass", 5500.0, 0.7))
    return A.finish(x, -23.0, fade_in=0.004, fade_out=0.05)


def feed_discard() -> np.ndarray:
    """Spooning the discard out (beat 2): the spoon scrapes the inside of the glass, muffled by the paste,
    the starter stretches off the spoon, and it lands in a bowl with a soft wet plop at 0.52 s."""
    rand = A.Rand(302)
    n = A.n_of(0.8)
    scr = A.scrape(n, rand, 260.0, SPOON_FREQS, (0.004, 0.003, 0.002), (0.5, 0.3, 0.1),
                   [(0.02, 0.0), (0.12, 0.8), (0.28, 1.0), (0.38, 0.0)], 900.0, 3500.0, 0.05, 4000.0)
    stretch_n = A.n_of(0.24)
    sweep = np.linspace(900.0, 380.0, stretch_n)
    stretch = A.svf(rand.normal(stretch_n), sweep, 3.0, "bp")
    stretch *= A.env(stretch_n, [(0.0, 0.0), (0.06, 1.0), (0.16, 0.7), (0.24, 0.0)])
    x = scr * 0.6
    A.place(x, stretch, 0.30, gain=0.25)
    plop = wet_thud(A.n_of(0.28), rand, 330.0)
    plop += A.strike(A.modes(A.n_of(0.28), [880.0, 2350.0, 4100.0], [0.15, 0.08, 0.04], [0.12, 0.06, 0.03]),
                     2500.0)
    A.place(x, plop, 0.52)
    x = A.filt(x, A.rbj("lowpass", 6000.0, 0.7))
    return A.finish(x, -21.0, fade_in=0.004, fade_out=0.06)


def feed_scoop() -> np.ndarray:
    """A spoonful of flour (beat 3): the spoon crunches into dry flour, then the flour lands in the jar
    with a soft puff at 0.45 s (the medium haptic and the flour dust belong there), and the spoon taps
    the rim twice to knock off the last of it."""
    rand = A.Rand(303)
    n = A.n_of(0.85)
    dig_n = A.n_of(0.2)
    grains = np.zeros(dig_n)
    times = A.poisson_times(rand, 900.0, 0.0, 0.2)
    idx = np.minimum((times * A.SR).astype(np.int64), dig_n - 1)
    grains[idx] = rand.uniform(len(idx), 0.2, 1.0)
    dig = A.filt(grains, A.rbj("highpass", 2000.0, 0.7), A.rbj("lowpass", 7000.0, 0.7))
    dig += A.filt(rand.normal(dig_n), A.rbj("highpass", 1500.0, 0.7), A.rbj("lowpass", 6000.0, 0.7)) * 0.05
    dig *= A.env(dig_n, [(0.0, 0.0), (0.04, 1.0), (0.12, 0.8), (0.2, 0.0)])
    x = np.zeros(n)
    A.place(x, dig, 0.0, gain=0.5)
    trickle = A.filt(rand.normal(A.n_of(0.2)), A.rbj("highpass", 3000.0, 0.7), A.rbj("lowpass", 8000.0, 0.7))
    A.place(x, trickle * A.env(len(trickle), [(0.0, 0.0), (0.05, 1.0), (0.2, 0.0)]), 0.22, gain=0.012)
    land_n = A.n_of(0.4)
    thump = A.strike(A.modes(land_n, [300.0, 520.0], [0.03, 0.02], [1.0, 0.4]), 600.0)
    puff_src = rand.normal(land_n) * A.env(land_n, [(0.0, 0.0), (0.006, 1.0), (0.4, 0.0)])
    puff_src *= np.exp(-np.arange(land_n) / (0.07 * A.SR)) + 0.15
    puff = A.svf(puff_src, np.geomspace(3000.0, 600.0, land_n), 0.7, "lp")
    A.place(x, thump * 0.6 + puff * 0.35, 0.45)
    A.place(x, spoon_tap(A.n_of(0.4), 0.25), 0.62)
    A.place(x, spoon_tap(A.n_of(0.4), 0.17), 0.70)
    x = A.filt(x, A.rbj("lowpass", 8000.0, 0.7))
    return A.finish(x, -21.0, fade_in=0.003, fade_out=0.05)


def feed_pour() -> np.ndarray:
    """Pouring water (beat 4): a short stream over a thick paste, fizzing with small bubbles, with three
    bigger glugs at 0.10, 0.25 and 0.40 s, where ux-design puts the three light haptics."""
    rand = A.Rand(304)
    n = A.n_of(0.8)
    pts = [(0.0, 0.0), (0.05, 1.0), (0.55, 0.9), (0.72, 0.0)]
    x = A.stream(n, rand, 400.0, 3000.0, pts) * 0.22
    x += A.bubble_field(n, rand, 70.0, 0.04, 0.62, 500.0, 1800.0, 0.004, 0.012, 8.0, 16.0, 0.15, 0.5)
    for at, f0 in ((0.10, 330.0), (0.25, 300.0), (0.40, 350.0)):
        glug = A.bubble(f0, 0.035, 10.0, 1.1)
        gulp = A.burst(len(glug), rand, 0.025, 250.0, 900.0) * 0.3
        A.place(x, glug + gulp, at)
    x = A.filt(x, A.rbj("lowpass", 6000.0, 0.7))
    return A.finish(x, -21.0, fade_in=0.004, fade_out=0.06)


def feed_stir() -> np.ndarray:
    """Stirring (beat 5): the spoon folds through thick paste. A soft squelch every 180 ms (the stir's
    light haptic ticks), a slow swell per turn (0.72 s), and one light spoon touch on the glass per turn."""
    rand = A.Rand(305)
    n = A.n_of(1.8)
    t = A.t_axis(n)
    bed = A.filt(rand.normal(n), A.rbj("highpass", 250.0, 0.7), A.rbj("lowpass", 1300.0, 0.7))
    turn = 0.5 + 0.5 * np.sin(math.pi * t / 0.72) ** 2
    x = bed * turn * 0.12
    fold_n = A.n_of(0.06)
    k = 1
    while 0.18 * k < 1.75:
        src = rand.normal(fold_n) * np.hanning(fold_n)
        fold = A.svf(src, np.linspace(1200.0, 480.0, fold_n), 2.5, "bp")
        A.place(x, fold, 0.18 * k - 0.02 + rand.one(-0.012, 0.012), gain=rand.one(0.5, 1.0))
        k += 1
    turn_start = 0.36
    while turn_start < 1.7:
        A.place(x, spoon_tap(A.n_of(0.4), 0.05), turn_start + rand.one(-0.02, 0.02))
        turn_start += 0.72
    x *= A.env(n, [(0.0, 0.0), (0.06, 1.0), (1.55, 1.0), (1.8, 0.0)])
    x = A.filt(x, A.rbj("lowpass", 5000.0, 0.7))
    return A.finish(x, -23.0, fade_in=0.003, fade_out=0.05)


def starter_new() -> np.ndarray:
    """The empty jar filling with a new starter (ux-design section 14.5): a spoon touches the rim, a
    spoonful lands on the clean glass floor (an empty jar rings longer and brighter), and settles. It
    fits the 600 ms crossfade; band_snap follows when the band snaps on."""
    rand = A.Rand(306)
    n = A.n_of(0.9)
    x = np.zeros(n)
    A.place(x, spoon_tap(A.n_of(0.4), 0.12), 0.0)
    land = wet_thud(A.n_of(0.8), rand, 330.0) * 0.7
    land += A.strike(A.jar_ring(A.n_of(0.8), gain=0.35, damp=0.9, bright=1.2), 2500.0)
    A.place(x, land, 0.10)
    settle_n = A.n_of(0.3)
    settle = A.svf(rand.normal(settle_n), np.linspace(700.0, 350.0, settle_n), 2.5, "bp")
    settle *= A.env(settle_n, [(0.0, 0.0), (0.08, 1.0), (0.3, 0.0)])
    A.place(x, settle, 0.18, gain=0.12)
    x = A.filt(x, A.rbj("lowpass", 6000.0, 0.7))
    return A.finish(x, -24.0, fade_in=0.002, fade_out=0.15)


def main() -> None:
    A.write_wav("starter_new", starter_new())
    A.write_wav("feed_hooch", feed_hooch())
    A.write_wav("feed_discard", feed_discard())
    A.write_wav("feed_scoop", feed_scoop())
    A.write_wav("feed_pour", feed_pour())
    A.write_wav("feed_stir", feed_stir())


if __name__ == "__main__":
    main()
