"""Room tone loops: room_day.ogg and room_night.ogg (docs/audio-direction.md).

A quiet kitchen in the afternoon: soft, even air with a little warmth from the room and a slow, barely
there drift, so it never sounds frozen. The night variant is darker, stiller and 6 LU quieter. No events
(no birds, no clock, no fridge), because anything recognizable would repeat every loop and could be
mistaken for something happening in the game.

Each loop is made in the frequency domain, which is circular, and its slow drift completes whole cycles,
so the wrap is seamless by construction (verify_audio.py measures the jump). Stereo, because two
independent channels sound like a room around you instead of a hiss in the middle; ffmpeg's built-in
Vorbis encoder also only takes 2 channels.

Rebuild: python3 -I art/audio/scripts/room_tone.py   (needs ffmpeg on PATH for the Ogg step)
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np  # noqa: E402

import audio_lib as A  # noqa: E402

# Day 516 x 1024 samples (11.98 s), night 344 x 1024 (7.99 s; stiller, so a shorter loop hides as well).
# A multiple of 1024 decodes to exactly this length; 12.0 s came back 16 samples longer, padded with
# near-silence, which would tick at every wrap.
DAY_N = 516 * 1024
NIGHT_N = 344 * 1024
OGG_QUALITY = 3


def spectrum_db(f: np.ndarray, hp: float, lp: float, bumps: tuple) -> np.ndarray:
    """Pink (-3 dB per octave), 2nd-order high-pass and low-pass, plus bell bumps (Hz, dB, width oct)."""
    g = -3.0 * np.log2(f / 1000.0)
    g += 10.0 * np.log10(1.0 / (1.0 + (hp / f) ** 4)) + 10.0 * np.log10(1.0 / (1.0 + (f / lp) ** 4))
    for fb, db, width in bumps:
        g += db * np.exp(-0.5 * (np.log2(f / fb) / width) ** 2)
    return g


def drift(n: int, depth: tuple[float, float], phase: float) -> np.ndarray:
    """Slow level drift that completes 1 and 3 whole cycles per loop, so it wraps cleanly."""
    t = np.arange(n) / n
    return (1.0 + depth[0] * np.sin(2.0 * math.pi * t + phase)
            + depth[1] * np.sin(2.0 * math.pi * 3.0 * t + 1.7 * phase))


def channel(seed: int, night: bool, phase: float) -> np.ndarray:
    rand = A.Rand(seed)
    n = NIGHT_N if night else DAY_N
    if night:
        bed = A.shape_noise(n, rand, lambda f: spectrum_db(f, 60.0, 2800.0, ((140.0, 2.0, 0.8),)))
        air = A.shape_noise(n, rand, lambda f: spectrum_db(f, 1500.0, 5000.0, ()))
        air_level, depth = 0.08, (0.06, 0.04)
    else:
        bed = A.shape_noise(n, rand, lambda f: spectrum_db(f, 70.0, 5500.0, ((160.0, 3.0, 0.8),
                                                                               (3000.0, -2.0, 1.0))))
        air = A.shape_noise(n, rand, lambda f: spectrum_db(f, 1500.0, 6500.0, ()))
        air_level, depth = 0.2, (0.10, 0.05)
    bed /= np.sqrt(np.mean(bed ** 2))
    air /= np.sqrt(np.mean(air ** 2))
    t = np.arange(n) / n
    air_swell = 1.0 + 0.5 * np.sin(2.0 * math.pi * 2.0 * t + 2.0 * phase)
    return bed * drift(n, depth, phase) + air_level * air * air_swell


def room(night: bool) -> np.ndarray:
    base = 900 if night else 800
    x = np.stack([channel(base + 1, night, 0.3), channel(base + 2, night, 2.1)], axis=1)
    return A.finish(x, -44.0 if night else -38.0, measure="integrated", loop=True)


def main() -> None:
    A.write_ogg("room_day", room(False), OGG_QUALITY)
    A.write_ogg("room_night", room(True), OGG_QUALITY)


if __name__ == "__main__":
    main()
