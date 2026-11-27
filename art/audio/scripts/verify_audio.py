"""Checks every file in assets/audio against docs/audio-direction.md and prints what it measures.

Per file: channels, rate, length, size, sample peak, true peak (4x), integrated and momentary-max
loudness (ITU-R BS.1770-4 K-weighting and gating, mono as one channel), spectral centroid, the share of
energy under 250 Hz (mostly lost on a phone speaker), 250 Hz to 4 kHz and above 4 kHz, attack (start to the
loudest 5 ms), tail (loudest point to 30 dB down) and the edge samples. Loops also get the jump at the wrap.

Fails (exit 1) on: a missing or unexpected file, a rate other than 44.1 or 48 kHz, a sample peak over
-3 dBFS, a loudness more than 1 LU off its target (1.5 LU for Ogg, which is lossy), a one-shot whose
first or last sample is above -60 dBFS, a loop whose length changed in decoding or whose wrap step is
larger than 99.9% of its sample steps (it would tick), or a set over 2 MB. Ogg files are decoded with ffmpeg.

Run: python3 -I art/audio/scripts/verify_audio.py
"""
import math
import shutil
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np  # noqa: E402

import audio_lib as A  # noqa: E402

# id: (extension, kind, target LUFS, measured as). The doc's sound list is the source of these numbers.
MANIFEST = {
    **{f"bubble_pop_{i}": ("wav", "oneshot", -34.0, "momentary") for i in range(1, 7)},
    "glass_tink": ("wav", "oneshot", -24.0, "momentary"),
    "starter_poke": ("wav", "oneshot", -27.0, "momentary"),
    "lid_lift": ("wav", "oneshot", -24.0, "momentary"),
    "lid_set": ("wav", "oneshot", -24.0, "momentary"),
    "band_snap": ("wav", "oneshot", -24.0, "momentary"),
    "feed_hooch": ("wav", "oneshot", -23.0, "momentary"),
    "feed_discard": ("wav", "oneshot", -21.0, "momentary"),
    "feed_scoop": ("wav", "oneshot", -21.0, "momentary"),
    "feed_pour": ("wav", "oneshot", -21.0, "momentary"),
    "feed_stir": ("wav", "oneshot", -23.0, "momentary"),
    "smell_swell": ("wav", "oneshot", -23.0, "momentary"),
    "ui_tap": ("wav", "oneshot", -32.0, "momentary"),
    "ui_tick": ("wav", "oneshot", -35.0, "momentary"),
    "ui_toggle_on": ("wav", "oneshot", -32.0, "momentary"),
    "ui_toggle_off": ("wav", "oneshot", -32.0, "momentary"),
    "sheet_open": ("wav", "oneshot", -31.0, "momentary"),
    "sheet_close": ("wav", "oneshot", -32.0, "momentary"),
    "event_chime": ("wav", "oneshot", -23.0, "momentary"),
    "event_chime_soft": ("wav", "oneshot", -26.0, "momentary"),
    "status_tick": ("wav", "oneshot", -30.0, "momentary"),
    "starter_new": ("wav", "oneshot", -24.0, "momentary"),
    "mold_found": ("wav", "oneshot", -23.0, "momentary"),
    "mold_discard": ("wav", "oneshot", -22.0, "momentary"),
    "room_day": ("ogg", "loop", -38.0, "integrated"),
    "room_night": ("ogg", "loop", -44.0, "integrated"),
}
SET_LIMIT_BYTES = 2 * 1024 * 1024


def read_wav(path: Path) -> tuple[np.ndarray, int]:
    with wave.open(str(path), "rb") as w:
        ch, sr, n = w.getnchannels(), w.getframerate(), w.getnframes()
        if w.getsampwidth() != 2:
            raise SystemExit(f"{path.name}: expected 16-bit PCM")
        x = np.frombuffer(w.readframes(n), "<i2").astype(np.float64) / 32768.0
    return (x if ch == 1 else x.reshape(-1, ch)), sr


def read_ogg(path: Path) -> tuple[np.ndarray, int]:
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        raise SystemExit("ffmpeg not found: needed to decode the Ogg loops")
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp) / "d.wav"
        subprocess.run([ffmpeg, "-nostdin", "-hide_banner", "-loglevel", "error", "-y", "-i", str(path),
                        "-c:a", "pcm_s16le", str(out)], check=True)
        return read_wav(out)


def describe(x: np.ndarray, sr: int) -> dict:
    mono = x if x.ndim == 1 else x.mean(axis=1)
    spec = np.abs(np.fft.rfft(mono)) ** 2
    f = np.fft.rfftfreq(len(mono), 1.0 / sr)
    total = max(float(spec.sum()), 1e-30)
    w = max(int(0.005 * sr), 1)
    frames = len(mono) // w
    rms = np.sqrt((mono[:frames * w].reshape(frames, w) ** 2).mean(axis=1) + 1e-20)
    db = 20.0 * np.log10(rms)
    top = int(db.argmax())
    above = np.nonzero(db >= db[top] - 30.0)[0]
    return {
        "centroid": float((f * spec).sum() / total),
        "low": float(spec[f < 250.0].sum() / total),
        "mid": float(spec[(f >= 250.0) & (f < 4000.0)].sum() / total),
        "high": float(spec[f >= 4000.0].sum() / total),
        "attack_ms": top * 5.0,
        "tail_ms": (int(above.max()) - top) * 5.0,
    }


def db(v: float) -> float:
    return 20.0 * math.log10(max(abs(v), 1e-12))


def main() -> int:
    folder = A.OUT
    failures: list[str] = []
    found = {p.stem: p for p in sorted(folder.glob("*")) if p.suffix in (".wav", ".ogg")}
    for name in sorted(set(found) - set(MANIFEST)):
        failures.append(f"{name}: not in the manifest (add it to the doc and to MANIFEST)")
    total_bytes = 0
    print(f"{'file':<22}{'ch':>3}{'s':>6}{'KB':>7}{'peak':>7}{'TP':>7}{'int':>7}{'mom':>7}{'target':>8}"
          f"{'cent Hz':>9}{'<250':>6}{'mid':>6}{'>4k':>6}{'att ms':>8}{'tail ms':>8}  edges/wrap")
    for name, (ext, kind, target, measure) in MANIFEST.items():
        path = folder / f"{name}.{ext}"
        if not path.exists():
            failures.append(f"{name}.{ext}: missing")
            continue
        total_bytes += path.stat().st_size
        x, sr = read_wav(path) if ext == "wav" else read_ogg(path)
        ch = 1 if x.ndim == 1 else x.shape[1]
        loop = kind == "loop"
        peak = db(float(np.abs(x).max()))
        tp = A.true_peak_db(x, circular=loop)
        integ = A.integrated_lufs(x, sr, loop=loop)
        mom = A.momentary_max_lufs(x, sr)
        d = describe(x, sr)
        first = x[0] if x.ndim == 1 else x[0, :]
        last = x[-1] if x.ndim == 1 else x[-1, :]
        if loop:
            steps = np.abs(np.diff(x, axis=0))
            jump = np.abs(first - last)
            if ch > 1:
                rank = max(float(np.mean(steps[:, c] < jump[c])) for c in range(ch))
            else:
                rank = float(np.mean(steps < jump))
            edge = f"wrap step larger than {rank:.1%} of steps"
            if rank > 0.999:
                failures.append(f"{name}: loop wrap step is larger than {rank:.2%} of its steps")
            if len(x) % 1024 != 0:
                failures.append(f"{name}: {len(x)} samples is not a multiple of 1024 (Vorbis padding)")
        else:
            e0, e1 = db(float(np.max(np.abs(first)))), db(float(np.max(np.abs(last))))
            edge = f"first {e0:.0f} dBFS, last {e1:.0f} dBFS"
            if e0 > -60.0 or e1 > -60.0:
                failures.append(f"{name}: edge sample above -60 dBFS (first {e0:.1f}, last {e1:.1f})")
        if sr not in (44100, 48000):
            failures.append(f"{name}: sample rate {sr}")
        if ext == "wav" and ch != 1:
            failures.append(f"{name}: one-shots are mono")
        if peak > -3.0:
            failures.append(f"{name}: sample peak {peak:.2f} dBFS is over -3")
        level = mom if measure == "momentary" else integ
        tol = 1.5 if ext == "ogg" else 1.0
        if abs(level - target) > tol and not (tp > -3.5 and level < target):
            failures.append(f"{name}: {measure} {level:.1f} LUFS, target {target:.1f}")
        limited = " (peak-limited)" if tp > -3.5 and level < target - tol else ""
        print(f"{name:<22}{ch:>3}{len(x) / sr:>6.2f}{path.stat().st_size / 1024:>7.1f}{peak:>7.1f}{tp:>7.1f}"
              f"{integ:>7.1f}{mom:>7.1f}{target:>8.1f}{d['centroid']:>9.0f}{d['low']:>6.0%}{d['mid']:>6.0%}"
              f"{d['high']:>6.0%}{d['attack_ms']:>8.0f}{d['tail_ms']:>8.0f}  {edge}{limited}")
    print(f"set size {total_bytes / 1024:.1f} KB of {SET_LIMIT_BYTES / 1024:.0f} KB")
    if total_bytes > SET_LIMIT_BYTES:
        failures.append(f"set is {total_bytes} bytes, over {SET_LIMIT_BYTES}")
    for f in failures:
        print("FAIL", f)
    print("RESULT:", "PASS" if not failures else f"FAIL ({len(failures)})")
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
