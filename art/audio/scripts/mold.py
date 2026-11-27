"""The mold moments (narrative section 9.2, ux-design section 12): mold_found and mold_discard
(docs/audio-direction.md).

Subdued and never comic: no falling "sad" interval, no wobble, no minor-key sting, no cartoon splat.
mold_found is a slow, low swell (D4 and A4, an open fifth, a quiet D5 above and a D3 below for
headphones), dark and calm, which lets the close-up and the words carry the news. It sits higher than a
cello would, because a phone speaker loses almost everything under 250 Hz. mold_discard is the jar being
emptied and washed: two slow scrapes, a soft drop into the bin, then a gentle rinse whose pitch rises as
the jar fills.

Rebuild: python3 -I art/audio/scripts/mold.py
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np  # noqa: E402

import audio_lib as A  # noqa: E402

D3, D4, A4, D5 = 146.83, 293.66, 440.0, 587.33


def mold_found() -> np.ndarray:
    """Plays as the mold_found sheet opens and the camera moves to the colony (500 ms)."""
    rand = A.Rand(701)
    n = A.n_of(2.0)
    t = A.t_axis(n)
    x = np.zeros(n)
    for f, a in ((D3, 0.35), (D4, 1.0), (A4, 0.7), (D5, 0.2)):
        for detune in (-0.3, 0.3):
            for h, ha in ((1, 1.0), (2, 0.35), (3, 0.12)):
                x += a * ha * np.sin(2.0 * math.pi * h * (f + detune) * t)
    x *= A.env(n, [(0.0, 0.0), (0.45, 1.0), (1.05, 0.85), (2.0, 0.0)])
    breath = A.filt(rand.normal(n), A.rbj("highpass", 300.0, 0.7), A.rbj("lowpass", 900.0, 0.7))
    x += breath * A.env(n, [(0.0, 0.0), (0.5, 1.0), (1.85, 0.0)]) * 0.25
    x = A.filt(x, A.rbj("lowpass", 1800.0, 0.7))
    return A.finish(x, -23.0, fade_in=0.02, fade_out=0.2)


def mold_discard() -> np.ndarray:
    """Plays when the discard is confirmed: scrapes (0 to 0.62 s), the drop (0.72 s), the rinse
    (1.0 to 2.25 s)."""
    rand = A.Rand(702)
    n = A.n_of(2.3)
    x = np.zeros(n)
    for start in (0.0, 0.32):
        stroke = A.scrape(A.n_of(0.32), rand, 220.0, (2850.0, 4720.0), (0.004, 0.003), (0.4, 0.2),
                          [(0.0, 0.0), (0.1, 1.0), (0.24, 0.8), (0.3, 0.0)], 600.0, 2800.0, 0.06, 3000.0)
        A.place(x, stroke, start, gain=0.5)
    drop_n = A.n_of(0.3)
    drop = A.strike(A.modes(drop_n, [300.0, 480.0], [0.04, 0.025], [1.0, 0.35]), 700.0)
    drop += A.burst(drop_n, rand, 0.035, 300.0, 1500.0) * 0.4
    A.place(x, drop, 0.72, gain=0.8)
    rinse_n = A.n_of(1.3)
    pts = [(0.0, 0.0), (0.12, 1.0), (0.85, 0.9), (1.25, 0.0)]
    rinse = A.stream(rinse_n, rand, 500.0, 3500.0, pts) * 0.2
    rinse += A.bubble_field(rinse_n, rand, 90.0, 0.05, 1.15, 600.0, 2400.0, 0.004, 0.01, 8.0, 15.0, 0.1, 0.35)
    filling = A.svf(rand.normal(rinse_n), np.geomspace(700.0, 1100.0, rinse_n), 6.0, "bp")
    rinse += filling * A.env(rinse_n, pts) * 0.12
    A.place(x, rinse, 1.0)
    x = A.filt(x, A.rbj("lowpass", 5000.0, 0.7))
    return A.finish(x, -22.0, fade_in=0.005, fade_out=0.1)


def main() -> None:
    A.write_wav("mold_found", mold_found())
    A.write_wav("mold_discard", mold_discard())


if __name__ == "__main__":
    main()
