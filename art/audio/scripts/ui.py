"""Interface sounds: ui_tap, ui_tick, ui_toggle_on, ui_toggle_off, sheet_open, sheet_close
(docs/audio-direction.md, ux-design section 15).

The clicks are a fingertip on small pieces of hard wood: short, woody, with no ring and no beep. The
sheet sounds are a breath of air that follows the sheet's motion: the open (300 ms, ease-out) puts its
energy early and rises a little in pitch, the close (220 ms, ease-in) puts it late and falls.

Rebuild: python3 -I art/audio/scripts/ui.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np  # noqa: E402

import audio_lib as A  # noqa: E402


def click(n: int, f: float, soft_hz: float) -> np.ndarray:
    """One woody click: a bright, very short pair of modes over a small, lower body."""
    x = A.modes(n, [f, f * 1.65, f * 0.23], [0.007, 0.004, 0.009], [1.0, 0.45, 0.55])
    return A.strike(x, soft_hz)


def ui_tap() -> np.ndarray:
    """Buttons, the status pill, the long-press label (Bus.feedback &"tap", &"mix")."""
    x = click(A.n_of(0.08), 1850.0, 5000.0)
    x = A.filt(x, A.rbj("lowpass", 7000.0, 0.7))
    return A.finish(x, -32.0, fade_in=0.0005, fade_out=0.02)


def ui_tick() -> np.ndarray:
    """Chips, stepper steps and the zoom limit (Bus.feedback &"tick"): smaller and higher than a tap."""
    n = A.n_of(0.06)
    x = A.modes(n, [2500.0, 4100.0, 620.0], [0.004, 0.0025, 0.006], [1.0, 0.4, 0.35])
    x = A.filt(A.strike(x, 6000.0), A.rbj("lowpass", 8000.0, 0.7))
    return A.finish(x, -35.0, fade_in=0.0005, fade_out=0.015)


def toggle(first: float, second: float) -> np.ndarray:
    """A small latch: two clicks 28 ms apart, the second a little quieter."""
    n = A.n_of(0.11)
    x = np.zeros(n)
    A.place(x, click(A.n_of(0.06), first, 5000.0), 0.0)
    A.place(x, click(A.n_of(0.06), second, 5000.0), 0.028, gain=0.8)
    x = A.filt(x, A.rbj("lowpass", 7000.0, 0.7))
    return A.finish(x, -32.0, fade_in=0.0005, fade_out=0.02)


def sheet(open_: bool) -> np.ndarray:
    rand = A.Rand(501 if open_ else 502)
    length = 0.34 if open_ else 0.26
    n = A.n_of(length)
    if open_:
        centre = np.geomspace(450.0, 1000.0, n)
        shape = A.env(n, [(0.0, 0.0), (0.06, 1.0), (0.34, 0.0)])
    else:
        centre = np.geomspace(1000.0, 420.0, n)
        shape = A.env(n, [(0.0, 0.0), (0.15, 1.0), (0.26, 0.0)])
    x = A.svf(rand.normal(n), centre, 0.7, "bp") * shape
    x = A.filt(x, A.rbj("lowpass", 2500.0, 0.7))
    return A.finish(x, -31.0 if open_ else -32.0, fade_in=0.005, fade_out=0.02)


def main() -> None:
    A.write_wav("ui_tap", ui_tap())
    A.write_wav("ui_tick", ui_tick())
    A.write_wav("ui_toggle_on", toggle(1700.0, 2250.0))
    A.write_wav("ui_toggle_off", toggle(2150.0, 1600.0))
    A.write_wav("sheet_open", sheet(True))
    A.write_wav("sheet_close", sheet(False))


if __name__ == "__main__":
    main()
