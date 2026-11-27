"""The jar's own sounds: glass_tink, starter_poke, lid_lift, lid_set, band_snap (docs/audio-direction.md).

The jar is thick glass (84 mm across, 3.5 mm wall) with a turned oak lid that has a plug in the neck and
a rubber band around the glass (art-direction sections 8 and 12). Every sound keeps its character above
300 Hz, so it still reads on a phone speaker.

Rebuild: python3 -I art/audio/scripts/jar.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np  # noqa: E402

import audio_lib as A  # noqa: E402

# Oak lid, about 90 mm across: a short, woody knock.
LID_FREQS = (640.0, 1530.0, 2710.0, 3920.0)
LID_TAUS = (0.030, 0.018, 0.010, 0.006)
LID_AMPS = (1.0, 0.6, 0.35, 0.15)


def glass_tink() -> np.ndarray:
    """A fingertip on the glass (ux-design section 6): a small clean ring over a soft knock, damped
    because the jar has starter in it."""
    n = A.n_of(0.6)
    ring = A.strike(A.jar_ring(n, damp=1.0, bright=1.8), 6000.0)
    knock = A.strike(A.modes(n, [420.0, 260.0], [0.012, 0.016], [0.8, 0.5]), 1500.0)
    x = A.filt(ring + 0.5 * knock, A.rbj("lowpass", 9000.0, 0.7))
    return A.finish(x, -24.0, fade_in=0.001, fade_out=0.08)


def starter_poke() -> np.ndarray:
    """A poke on the starter's top: a soft, muted blob that wobbles down in pitch, plus a little squish.
    T2 plays 1 to 3 bubble pops with it, matching the pops the view draws."""
    rand = A.Rand(201)
    n = A.n_of(0.3)
    blob = A.strike(A.modes(n, [360.0, 540.0], [0.035, 0.02], [1.0, 0.35], glide=-3.0), 900.0)
    squish = A.burst(n, rand, 0.05, 350.0, 1600.0) * 0.35
    x = A.filt(blob + squish, A.rbj("lowpass", 2000.0, 0.7))
    return A.finish(x, -27.0, fade_in=0.002, fade_out=0.06)


def lid_lift() -> np.ndarray:
    """The oak plug slides up out of the glass neck (a short stick-slip rub), then lets go with a soft
    knock and a faint ring of the glass. Starts with the lid's 0.5 s lift."""
    rand = A.Rand(202)
    n = A.n_of(0.45)
    rub = A.scrape(n, rand, 170.0, [900.0, 1750.0, 2650.0], [0.006, 0.004, 0.003], [1.0, 0.6, 0.3],
                   [(0.01, 0.0), (0.06, 0.5), (0.17, 1.0), (0.21, 0.0)], 700.0, 2800.0, 0.04, 3800.0)
    release = np.zeros(n)
    knock = A.strike(A.modes(n, LID_FREQS, LID_TAUS, [a * 0.35 for a in LID_AMPS]), 2000.0)
    puff = A.burst(n, rand, 0.018, 300.0, 1500.0) * 0.25
    glass = A.strike(A.jar_ring(n, gain=0.12, damp=0.6), 4000.0)
    A.place(release, knock + puff + glass, 0.205)
    x = rub * 0.35 + release
    return A.finish(x, -24.0, fade_in=0.005, fade_out=0.08)


def lid_set() -> np.ndarray:
    """The lid comes down on the rim: a woody knock, the glass answering, a small thump of the jar on the
    counter, then a lighter second touch as the lid settles. The first contact is 5 ms in."""
    n = A.n_of(0.45)
    hit = (A.strike(A.modes(n, LID_FREQS, LID_TAUS, LID_AMPS), 3500.0)
           + A.strike(A.jar_ring(n, gain=0.28, damp=0.6), 4000.0)
           + A.strike(A.modes(n, [310.0], [0.02], [0.5]), 900.0))
    x = np.zeros(n)
    A.place(x, hit, 0.005)
    A.place(x, hit, 0.037, gain=0.3)
    return A.finish(x, -24.0, fade_in=0.001, fade_out=0.08)


def band_snap() -> np.ndarray:
    """The rubber band slides to the new level and taps the glass: a soft, dull thup that falls in pitch,
    with a hint of glass behind it (art-direction section 8, "a soft rubber tick")."""
    rand = A.Rand(203)
    n = A.n_of(0.3)
    thup = A.strike(A.modes(n, [520.0, 870.0], [0.018, 0.01], [1.0, 0.3], glide=-14.0), 1500.0)
    glass = A.strike(A.jar_ring(n, gain=0.16, damp=0.4), 3000.0)
    snap = A.burst(n, rand, 0.006, 800.0, 3500.0, tau=0.0015) * 0.3
    x = A.filt(thup + glass + snap, A.rbj("lowpass", 5000.0, 0.7))
    return A.finish(x, -24.0, fade_in=0.001, fade_out=0.06)


def main() -> None:
    A.write_wav("glass_tink", glass_tink())
    A.write_wav("starter_poke", starter_poke())
    A.write_wav("lid_lift", lid_lift())
    A.write_wav("lid_set", lid_set())
    A.write_wav("band_snap", band_snap())


if __name__ == "__main__":
    main()
