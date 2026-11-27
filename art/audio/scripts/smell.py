"""The smell moment (ux-design section 9, Bus.smell_moment_started): smell_swell (docs/audio-direction.md).

A soft breath in that swells over 1.2 s, with three gentle lifts at 0.30, 0.63 and 0.96 s where ux-design
puts the "breathe in" haptics (light, light, medium). Under it, a very faint open fifth (A3 and E4), which
is neither happy nor sad, so the sound never hints at what the smell will be. The card says that.

Rebuild: python3 -I art/audio/scripts/smell.py
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np  # noqa: E402

import audio_lib as A  # noqa: E402

LENGTH_S = 1.25
LIFTS = ((0.30, 0.35), (0.63, 0.35), (0.96, 0.55))  # (time s, extra level): light, light, medium


def smell_swell() -> np.ndarray:
    rand = A.Rand(401)
    n = A.n_of(LENGTH_S)
    t = A.t_axis(n)
    swell = A.env(n, [(0.0, 0.0), (0.12, 0.0), (0.98, 1.0), (1.2, 0.0)])
    lifts = np.ones(n)
    for at, extra in LIFTS:
        lifts += extra * np.exp(-0.5 * ((t - at) / 0.05) ** 2)
    centre = 700.0 * 2.0 ** np.clip((t - 0.15) / 0.85, 0.0, 1.0)
    air = A.svf(rand.normal(n), centre, 0.8, "bp")
    air += 0.3 * A.filt(rand.normal(n), A.rbj("highpass", 2500.0, 0.7), A.rbj("lowpass", 6500.0, 0.7))
    air *= swell * lifts
    tone_env = A.env(n, [(0.0, 0.0), (0.3, 0.0), (1.0, 1.0), (1.22, 0.0)])
    tone = np.zeros(n)
    for f, a in ((220.0, 1.0), (330.0, 0.8), (440.0, 0.25)):
        for detune in (-0.4, 0.4):
            tone += a * np.sin(2.0 * math.pi * (f + detune) * t)
    tone *= tone_env * 0.035
    x = A.filt(air + tone, A.rbj("lowpass", 6000.0, 0.7))
    return A.finish(x, -23.0, fade_in=0.01, fade_out=0.04)


def main() -> None:
    A.write_wav("smell_swell", smell_swell())


if __name__ == "__main__":
    main()
