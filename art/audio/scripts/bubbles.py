"""Bubble pops on the starter's top: bubble_pop_1.wav to bubble_pop_6.wav (docs/audio-direction.md).

A bubble in thick starter: a short damped tone whose pitch rises as the hole closes, a lower and duller
body from the paste around it, and a faint tick as the skin breaks. Each variant differs in size (pitch),
thickness (decay) and how much skin it has. Quiet on purpose.

Rebuild: python3 -I art/audio/scripts/bubbles.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_lib as A  # noqa: E402

TARGET_LUFS = -34.0  # momentary max, each pop alone

# (pitch Hz, decay s, glide oct/s, skin tick, paste body). Lower pitch = a bigger bubble.
VARIANTS = (
    (680.0, 0.016, 11.0, 0.22, 0.40),
    (820.0, 0.013, 13.0, 0.28, 0.32),
    (950.0, 0.011, 10.0, 0.34, 0.26),
    (1100.0, 0.009, 14.0, 0.30, 0.22),
    (1260.0, 0.008, 12.0, 0.38, 0.18),
    (760.0, 0.021, 8.0, 0.18, 0.45),
)


def pop(index: int, f0: float, tau: float, glide: float, skin: float, body: float):
    rand = A.Rand(100 + index)
    n = A.n_of(0.12)
    ring = A.strike(A.modes(n, [f0], [tau], [1.0], glide=glide), 3000.0)
    paste = A.strike(A.modes(n, [f0 * 0.46], [tau * 0.8], [body], glide=glide * 0.5), 1500.0)
    tick = A.burst(n, rand, 0.004, 1800.0, 6500.0, tau=0.0012) * skin
    x = A.filt(ring + paste + tick, A.rbj("lowpass", 4500.0, 0.6))
    return A.finish(x, TARGET_LUFS, fade_in=0.001, fade_out=0.03)


def main() -> None:
    for i, v in enumerate(VARIANTS, start=1):
        A.write_wav(f"bubble_pop_{i}", pop(i, *v))


if __name__ == "__main__":
    main()
