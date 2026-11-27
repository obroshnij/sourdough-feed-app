"""Chimes: event_chime and event_chime_soft (Bus.event_presented), status_tick (docs/audio-direction.md).

Gentle, not a notification ping: low-mid register (G4 at 392 Hz, D5 at 587 Hz), a soft 8 ms felt attack,
mostly fundamental with little brightness, and a slow natural decay. The two notes of event_chime are
rolled 70 ms apart, so they read as one warm open fifth rather than a two-note alert. event_chime_soft is
the single G4, shorter and quieter, for info toasts.

Rebuild: python3 -I art/audio/scripts/chimes.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np  # noqa: E402

import audio_lib as A  # noqa: E402

G3, G4, D5 = 196.0, 392.0, 587.33


def felt(n: int, rand: A.Rand) -> np.ndarray:
    """The faint thock of a felt mallet."""
    return A.burst(n, rand, 0.006, 200.0, 1500.0) * 0.03


def event_chime() -> np.ndarray:
    """Nudge cards and attention sheets (not mold_found, which has its own sound)."""
    rand = A.Rand(601)
    n = A.n_of(1.3)
    x = np.zeros(n)
    A.place(x, A.soft_note(n, G4) + 0.15 * A.soft_note(n, G3) + felt(n, rand), 0.0)
    A.place(x, 0.8 * A.soft_note(n, D5) + felt(n, rand), 0.07)
    x = A.filt(x, A.rbj("lowpass", 3500.0, 0.7))
    return A.finish(x, -23.0, fade_in=0.002, fade_out=0.3)


def event_chime_soft() -> np.ndarray:
    """Info toasts: one note, shorter and quieter."""
    rand = A.Rand(602)
    n = A.n_of(1.0)
    x = A.soft_note(n, G4, length=0.7) + felt(n, rand)
    x = A.filt(x, A.rbj("lowpass", 3000.0, 0.7))
    return A.finish(x, -26.0, fade_in=0.002, fade_out=0.25)


def status_tick() -> np.ndarray:
    """A status change during the onboarding demo (ux-design section 14.4, B6): one small, quiet D5,
    the same for every status, so it marks the change without judging it."""
    rand = A.Rand(603)
    n = A.n_of(0.45)
    x = A.soft_note(n, D5, length=0.35) + felt(n, rand)
    x = A.filt(x, A.rbj("lowpass", 3500.0, 0.7))
    return A.finish(x, -30.0, fade_in=0.002, fade_out=0.12)


def main() -> None:
    A.write_wav("event_chime", event_chime())
    A.write_wav("event_chime_soft", event_chime_soft())
    A.write_wav("status_tick", status_tick())


if __name__ == "__main__":
    main()
