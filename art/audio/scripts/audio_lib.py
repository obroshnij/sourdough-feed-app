"""Shared DSP for Sourdough's synthesized sounds (D-056, docs/audio-direction.md).

Standard library plus numpy only. Every generator is seeded and deterministic: the same script, numpy
build and CPU give the same bytes. Randomness comes from a counter-based SplitMix64 written here, so it
never depends on numpy's Generator streams, which may change between numpy versions.

Generators import this file by path, because `python3 -I` does not put the script's folder on sys.path.
"""
from __future__ import annotations

import hashlib
import math
import shutil
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

SR = 44100
ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets" / "audio"
PEAK_CEILING_DB = -3.0
_TP_MARGIN_DB = 0.2
_M64 = (1 << 64) - 1


# ------------------------------------------------------------------ random numbers
def _mix64(x: int) -> int:
    x = (x + 0x9E3779B97F4A7C15) & _M64
    x = ((x ^ (x >> 30)) * 0xBF58476D1CE4E5B9) & _M64
    x = ((x ^ (x >> 27)) * 0x94D049BB133111EB) & _M64
    return x ^ (x >> 31)


class Rand:
    """Counter-based random numbers. Each call draws a fresh stream from (seed, call number)."""

    def __init__(self, seed: int) -> None:
        self.seed = seed
        self.calls = 0

    def _raw(self, n: int) -> np.ndarray:
        base = _mix64((self.seed << 24) ^ self.calls)
        self.calls += 1
        i = np.arange(1, n + 1, dtype=np.uint64)
        z = np.uint64(base) + i * np.uint64(0x9E3779B97F4A7C15)
        z = (z ^ (z >> np.uint64(30))) * np.uint64(0xBF58476D1CE4E5B9)
        z = (z ^ (z >> np.uint64(27))) * np.uint64(0x94D049BB133111EB)
        return z ^ (z >> np.uint64(31))

    def uniform(self, n: int, lo: float = 0.0, hi: float = 1.0) -> np.ndarray:
        u = (self._raw(n) >> np.uint64(11)).astype(np.float64) * (1.0 / 9007199254740992.0)
        return lo + (hi - lo) * u

    def normal(self, n: int) -> np.ndarray:
        u1 = self.uniform(n)
        u2 = self.uniform(n)
        return np.sqrt(-2.0 * np.log(1.0 - u1)) * np.cos(2.0 * math.pi * u2)

    def one(self, lo: float = 0.0, hi: float = 1.0) -> float:
        return float(self.uniform(1, lo, hi)[0])


# ------------------------------------------------------------------ time and envelopes
def n_of(seconds: float) -> int:
    return int(round(seconds * SR))


def t_axis(n: int) -> np.ndarray:
    return np.arange(n, dtype=np.float64) / SR


def env(n: int, points: list[tuple[float, float]]) -> np.ndarray:
    """Piecewise envelope through (time s, value) points, cosine-eased between them, flat outside."""
    t = t_axis(n)
    out = np.full(n, points[0][1])
    for (t0, v0), (t1, v1) in zip(points[:-1], points[1:]):
        m = (t >= t0) & (t < t1)
        k = (t[m] - t0) / max(t1 - t0, 1e-9)
        out[m] = v0 + (v1 - v0) * (0.5 - 0.5 * np.cos(math.pi * k))
    out[t >= points[-1][0]] = points[-1][1]
    return out


def decay(n: int, tau: float, start: float = 0.0) -> np.ndarray:
    t = t_axis(n) - start
    return np.where(t >= 0.0, np.exp(-np.maximum(t, 0.0) / tau), 0.0)


def fades(x: np.ndarray, fade_in: float, fade_out: float) -> np.ndarray:
    y = x.copy()
    ni, no = max(n_of(fade_in), 1), max(n_of(fade_out), 1)
    y[:ni] *= 0.5 - 0.5 * np.cos(math.pi * np.arange(ni) / ni)
    y[-no:] *= 0.5 + 0.5 * np.cos(math.pi * (np.arange(no) + 1) / no)
    return y


def place(dst: np.ndarray, src: np.ndarray, at_s: float, gain: float = 1.0) -> None:
    """Adds src into dst starting at at_s. Whatever part of src lands in dst ends with a 4 ms fade, so a
    ring cut short by its buffer (or by dst's end) never clicks."""
    i = n_of(at_s)
    if i >= len(dst):
        return
    m = min(len(src), len(dst) - i)
    part = src[:m] * gain
    k = min(n_of(0.004), m)
    part[m - k:] *= 0.5 + 0.5 * np.cos(math.pi * (np.arange(k) + 1) / k)
    dst[i:i + m] += part


# ------------------------------------------------------------------ filters
def rbj(kind: str, f0: float, q: float = 0.7071, gain_db: float = 0.0, sr: int = SR) -> tuple[float, ...]:
    """RBJ cookbook biquad, returned as (b0, b1, b2, a1, a2) with a0 = 1."""
    w0 = 2.0 * math.pi * f0 / sr
    c, s = math.cos(w0), math.sin(w0)
    alpha = s / (2.0 * q)
    a = 10.0 ** (gain_db / 40.0)
    if kind == "lowpass":
        b, den = [(1 - c) / 2, 1 - c, (1 - c) / 2], [1 + alpha, -2 * c, 1 - alpha]
    elif kind == "highpass":
        b, den = [(1 + c) / 2, -(1 + c), (1 + c) / 2], [1 + alpha, -2 * c, 1 - alpha]
    elif kind == "bandpass":
        b, den = [alpha, 0.0, -alpha], [1 + alpha, -2 * c, 1 - alpha]
    elif kind == "peak":
        b, den = [1 + alpha * a, -2 * c, 1 - alpha * a], [1 + alpha / a, -2 * c, 1 - alpha / a]
    elif kind in ("lowshelf", "highshelf"):
        sa = 2.0 * math.sqrt(a) * alpha
        sg = 1.0 if kind == "lowshelf" else -1.0
        b = [a * ((a + 1) - sg * (a - 1) * c + sa), sg * 2 * a * ((a - 1) - sg * (a + 1) * c),
             a * ((a + 1) - sg * (a - 1) * c - sa)]
        den = [(a + 1) + sg * (a - 1) * c + sa, -sg * 2 * ((a - 1) + sg * (a + 1) * c),
               (a + 1) + sg * (a - 1) * c - sa]
    else:
        raise ValueError(kind)
    return (b[0] / den[0], b[1] / den[0], b[2] / den[0], den[1] / den[0], den[2] / den[0])


def _response(sections: list[tuple[float, ...]], n_fft: int) -> np.ndarray:
    z1 = np.exp(-1j * 2.0 * math.pi * np.fft.rfftfreq(n_fft))
    h = np.ones(len(z1), dtype=np.complex128)
    for b0, b1, b2, a1, a2 in sections:
        h *= (b0 + b1 * z1 + b2 * z1 * z1) / (1.0 + a1 * z1 + a2 * z1 * z1)
    return h


def filt(x: np.ndarray, *sections: tuple[float, ...], tail_s: float = 0.3, circular: bool = False) -> np.ndarray:
    """Causal biquad cascade, applied through the FFT with the exact frequency response.
    One-shots get tail_s of zero padding so the ringing never wraps; loops use circular=True,
    which keeps a loop seamless. A (n, ch) array is filtered per channel."""
    if x.ndim == 2:
        return np.stack([filt(x[:, c], *sections, tail_s=tail_s, circular=circular)
                         for c in range(x.shape[1])], axis=1)
    pad = 0 if circular else n_of(tail_s)
    n = len(x) + pad
    y = np.fft.irfft(np.fft.rfft(x, n) * _response(list(sections), n), n)
    return y[:len(x)]


def shape_noise(n: int, rand: Rand, gain_db_at) -> np.ndarray:
    """Circular (loopable) noise with any magnitude response: gain_db_at(freq_hz_array) -> dB."""
    spec = np.fft.rfft(rand.normal(n))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    g = 10.0 ** (gain_db_at(np.maximum(f, 1.0)) / 20.0)
    g[0] = 0.0
    return np.fft.irfft(spec * g, n)


def svf(x: np.ndarray, fc, q: float, mode: str = "bp") -> np.ndarray:
    """Time-varying state-variable filter (Zavalishin TPT). fc is a float or one value per sample.
    mode: lp, bp (unity peak) or hp."""
    fcs = np.broadcast_to(np.asarray(fc, dtype=np.float64), x.shape)
    g = np.tan(math.pi * np.clip(fcs, 10.0, SR * 0.45) / SR)
    k = 1.0 / q
    a1 = 1.0 / (1.0 + g * (g + k))
    a2 = g * a1
    a3 = g * a2
    out = np.empty_like(x)
    ic1 = ic2 = 0.0
    want = {"lp": 0, "bp": 1, "hp": 2}[mode]
    for i, (v0, c1, c2, c3) in enumerate(zip(x.tolist(), a1.tolist(), a2.tolist(), a3.tolist())):
        v3 = v0 - ic2
        v1 = c1 * ic1 + c2 * v3
        v2 = ic2 + c2 * ic1 + c3 * v3
        ic1 = 2.0 * v1 - ic1
        ic2 = 2.0 * v2 - ic2
        out[i] = v2 if want == 0 else (k * v1 if want == 1 else v0 - k * v1 - v2)
    return out


# ------------------------------------------------------------------ physical-ish building blocks
def modes(n: int, freqs, taus, amps, glide: float = 0.0) -> np.ndarray:
    """Sum of damped sines that all start at zero (no click). glide: pitch change in octaves per second
    (a bubble rises as it closes, a rubber band falls)."""
    t = t_axis(n)
    out = np.zeros(n)
    if glide == 0.0:
        warped = t
    else:
        r = glide * math.log(2.0)
        warped = (np.exp(r * t) - 1.0) / r
    for f, tau, a in zip(freqs, taus, amps):
        out += a * np.exp(-t / tau) * np.sin(2.0 * math.pi * f * warped)
    return out


def strike(ir: np.ndarray, soft_hz: float) -> np.ndarray:
    """Excites a resonator impulse response with a Gaussian contact pulse whose spectrum is 6 dB down at
    soft_hz. A softer contact (a finger pad, felt) has a lower soft_hz and rings the high modes less. A
    Gaussian has no spectral nulls, so no single mode vanishes by accident."""
    sigma = math.sqrt(math.log(2.0) / 2.0) / (math.pi * soft_hz)
    half = max(int(math.ceil(3.0 * sigma * SR)), 1)
    k = np.arange(-half, half + 1) / SR
    pulse = np.exp(-0.5 * (k / sigma) ** 2)
    pulse /= pulse.sum()
    return np.convolve(ir, pulse)[:len(ir)]


def burst(n: int, rand: Rand, length_s: float, lo: float, hi: float, tau: float | None = None) -> np.ndarray:
    """A short band-limited noise burst at the start of an n-sample buffer."""
    m = min(n_of(length_s), n)
    x = np.zeros(n)
    x[:m] = rand.normal(m) * (np.exp(-np.arange(m) / (tau * SR)) if tau else np.hanning(m))
    return filt(x, rbj("highpass", lo, 0.7), rbj("lowpass", hi, 0.7), tail_s=0.05)


# ------------------------------------------------------------------ shared recipes
# The glass jar's body (art-direction section 12: outer diameter 84 mm, wall 3.5 mm). Cylinder-shell modes
# sit near 1 : 2.83 : 5.42, and each splits into a slightly detuned pair, which gives real glass its shimmer.
JAR_FREQS = (1480.0, 1481.1, 4190.0, 4193.5, 8020.0)
JAR_TAUS = (0.30, 0.27, 0.11, 0.10, 0.035)
JAR_AMPS = (1.0, 0.6, 0.45, 0.3, 0.12)


def jar_ring(n: int, gain: float = 1.0, damp: float = 1.0, bright: float = 1.0) -> np.ndarray:
    """The jar's ring for a unit impulse. damp < 1 shortens it (a hand on the glass, starter inside).
    bright scales the modes above the first pair (a harder or lighter touch)."""
    amps = [a * gain * (bright if i >= 2 else 1.0) for i, a in enumerate(JAR_AMPS)]
    return modes(n, JAR_FREQS, [t * damp for t in JAR_TAUS], amps)


def poisson_times(rand: Rand, rate: float, t0: float, t1: float) -> np.ndarray:
    count = int(rate * (t1 - t0) * 2.0) + 16
    gaps = -np.log(1.0 - rand.uniform(count)) / rate
    times = t0 + np.cumsum(gaps)
    return times[times < t1]


def scrape(n: int, rand: Rand, rate: float, freqs, taus, amps, points: list[tuple[float, float]],
           bed_lo: float, bed_hi: float, bed_gain: float, brightness: float) -> np.ndarray:
    """Stick-slip friction: an irregular train of tiny catches, each ringing the touching surfaces, over
    a soft band of rubbing noise. points shape the stroke (time, level)."""
    spikes = np.zeros(n)
    times = poisson_times(rand, rate, points[0][0], points[-1][0])
    idx = np.minimum((times * SR).astype(np.int64), n - 1)
    spikes[idx] += rand.uniform(len(idx), 0.3, 1.0) * np.where(rand.uniform(len(idx)) < 0.5, -1.0, 1.0)
    ir = modes(n_of(0.05), freqs, taus, amps)
    catches = np.convolve(spikes, ir)[:n]
    bed = filt(rand.normal(n), rbj("highpass", bed_lo, 0.7), rbj("lowpass", bed_hi, 0.7)) * bed_gain
    x = (catches + bed) * env(n, points)
    return filt(x, rbj("lowpass", brightness, 0.6))


def bubble(f0: float, tau: float, glide: float, amp: float = 1.0) -> np.ndarray:
    """One small bubble closing at a liquid surface: a damped tone whose pitch rises (van den Doel)."""
    m = n_of(min(6.0 * tau, 0.25))
    return strike(modes(m, [f0], [tau], [amp], glide=glide), 4000.0)


def bubble_field(n: int, rand: Rand, rate: float, t0: float, t1: float, f_lo: float, f_hi: float,
                 tau_lo: float, tau_hi: float, glide_lo: float, glide_hi: float, amp_lo: float,
                 amp_hi: float) -> np.ndarray:
    """Many small bubbles at random times: the fizz of a pour. Pitches are log-uniform."""
    x = np.zeros(n)
    times = poisson_times(rand, rate, t0, t1)
    k = len(times)
    f = np.exp(rand.uniform(k, math.log(f_lo), math.log(f_hi)))
    tau = rand.uniform(k, tau_lo, tau_hi)
    gl = rand.uniform(k, glide_lo, glide_hi)
    a = rand.uniform(k, amp_lo, amp_hi)
    for i in range(k):
        place(x, bubble(float(f[i]), float(tau[i]), float(gl[i]), float(a[i])), float(times[i]))
    return x


def stream(n: int, rand: Rand, lo: float, hi: float, points: list[tuple[float, float]],
           flutter: float = 0.35) -> np.ndarray:
    """A falling stream of liquid: band-limited noise with a quick random flutter, shaped by points."""
    wobble = filt(rand.normal(n), rbj("lowpass", 30.0, 0.7), tail_s=0.5)
    wobble /= max(float(np.abs(wobble).max()), 1e-9)
    bed = filt(rand.normal(n), rbj("highpass", lo, 0.7), rbj("lowpass", hi, 0.7))
    return bed * (1.0 + flutter * wobble) * env(n, points)


def soft_note(n: int, f: float, length: float = 1.0) -> np.ndarray:
    """A felt mallet on a warm bar: mostly the fundamental, a little second and third harmonic, and a
    quickly fading inharmonic tine. 8 ms attack, so it never pings. length scales the decay."""
    partials = (1.0, 2.0, 3.0, 4.21, 6.73)
    taus = tuple(length * t for t in (0.75, 0.38, 0.2, 0.05, 0.018))
    amps = (1.0, 0.22, 0.07, 0.05, 0.02)
    x = modes(n, [f * p for p in partials], taus, amps)
    return x * env(n, [(0.0, 0.0), (0.008, 1.0), (1.0, 1.0)])


# ------------------------------------------------------------------ loudness (ITU-R BS.1770-4, mono)
def _k_sections(sr: int) -> list[tuple[float, ...]]:
    # The K-weighting pre-filter and RLB high-pass for any rate, as libebur128 derives them.
    f0, g, q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    k = math.tan(math.pi * f0 / sr)
    vh = 10.0 ** (g / 20.0)
    vb = vh ** 0.4996667741545416
    a0 = 1.0 + k / q + k * k
    shelf = ((vh + vb * k / q + k * k) / a0, 2.0 * (k * k - vh) / a0, (vh - vb * k / q + k * k) / a0,
             2.0 * (k * k - 1.0) / a0, (1.0 - k / q + k * k) / a0)
    f0, q = 38.13547087602444, 0.5003270373238773
    k = math.tan(math.pi * f0 / sr)
    d = 1.0 + k / q + k * k
    hp = (1.0, -2.0, 1.0, 2.0 * (k * k - 1.0) / d, (1.0 - k / q + k * k) / d)
    return [shelf, hp]


def k_weight(x: np.ndarray, sr: int = SR, circular: bool = False) -> np.ndarray:
    n = len(x) + (0 if circular else int(0.3 * sr))
    y = np.fft.irfft(np.fft.rfft(x, n) * _response(_k_sections(sr), n), n)
    return y[:len(x)]


def _channels(x: np.ndarray) -> list[np.ndarray]:
    return [x] if x.ndim == 1 else [x[:, c] for c in range(x.shape[1])]


def _block_ms(chans: list[np.ndarray], sr: int, hop_s: float) -> np.ndarray:
    """Mean square per 400 ms block, summed over channels (BS.1770 weights 1.0 for L and R)."""
    w = int(0.4 * sr)
    total = None
    for y in chans:
        c = np.concatenate(([0.0], np.cumsum(y * y)))
        starts = np.arange(0, len(y) - w + 1, max(int(hop_s * sr), 1))
        z = (c[starts + w] - c[starts]) / w
        total = z if total is None else total + z
    return total


def integrated_lufs(x: np.ndarray, sr: int = SR, loop: bool = False) -> float:
    """Gated integrated loudness of a mono (n,) or multichannel (n, ch) signal. Files shorter than 400 ms
    are padded with silence to one block. A loop is measured over one pass plus its own start, so the
    wrap counts as it will play. Mono is measured as one channel (not as dual mono, which reads 3 dB up)."""
    w = int(0.4 * sr)
    chans = []
    for c in _channels(x):
        y = k_weight(np.concatenate((c, c[:w])) if loop else c, sr)
        if len(y) < w:
            y = np.concatenate((y, np.zeros(w - len(y))))
        chans.append(y)
    z = _block_ms(chans, sr, 0.1)
    z = z[-0.691 + 10.0 * np.log10(np.maximum(z, 1e-20)) > -70.0]
    if len(z) == 0:
        return -math.inf
    rel = -0.691 + 10.0 * math.log10(z.mean()) - 10.0
    z = z[-0.691 + 10.0 * np.log10(z) > rel]
    return -0.691 + 10.0 * math.log10(z.mean())


def momentary_max_lufs(x: np.ndarray, sr: int = SR) -> float:
    """Loudest 400 ms window (10 ms hop), with silence around the file so a one-shot is fully seen."""
    pad = np.zeros(int(0.4 * sr))
    chans = [k_weight(np.concatenate((pad, c, pad)), sr) for c in _channels(x)]
    z = _block_ms(chans, sr, 0.01)
    return -0.691 + 10.0 * math.log10(max(float(z.max()), 1e-20))


def true_peak_db(x: np.ndarray, oversample: int = 4, circular: bool = False) -> float:
    """4x oversampled peak (FFT interpolation), the loudest channel."""
    peak = 0.0
    for c in _channels(x):
        y = c if circular else np.concatenate((np.zeros(64), c, np.zeros(64)))
        n = len(y)
        up = np.fft.irfft(np.fft.rfft(y), n * oversample) * oversample
        peak = max(peak, float(np.abs(up).max()))
    return 20.0 * math.log10(max(peak, 1e-12))


def sample_peak_db(x: np.ndarray) -> float:
    return 20.0 * math.log10(max(float(np.abs(x).max()), 1e-12))


# ------------------------------------------------------------------ finishing and writing
def finish(x: np.ndarray, target_lufs: float, *, measure: str = "momentary", fade_in: float = 0.002,
           fade_out: float = 0.02, loop: bool = False) -> np.ndarray:
    """DC and rumble out, fades (one-shots only; loops must stay seamless), then gain to the target
    loudness, capped so the true peak stays under PEAK_CEILING_DB."""
    y = filt(x, rbj("highpass", 30.0, 0.7), circular=loop)
    if not loop:
        y = fades(y, fade_in, fade_out)
    level = momentary_max_lufs(y) if measure == "momentary" else integrated_lufs(y, loop=loop)
    y = y * 10.0 ** ((target_lufs - level) / 20.0)
    tp = true_peak_db(y, circular=loop)
    limit = PEAK_CEILING_DB - _TP_MARGIN_DB
    if tp > limit:
        y = y * 10.0 ** ((limit - tp) / 20.0)
    return y


def to_pcm16(x: np.ndarray) -> np.ndarray:
    return np.clip(np.round(x * 32767.0), -32768, 32767).astype("<i2")


def write_wav(name: str, x: np.ndarray, channels: int = 1) -> Path:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"{name}.wav"
    pcm = to_pcm16(x)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    _report(path, pcm.astype(np.float64).reshape(-1, channels)[:, 0] / 32767.0)
    return path


def write_ogg(name: str, stereo: np.ndarray, quality: int) -> Path:
    """Stereo Ogg Vorbis through ffmpeg's built-in encoder (it only takes 2 channels). Bit-exact flags
    keep the serial number and tags fixed, so the same ffmpeg gives the same bytes."""
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        raise SystemExit("ffmpeg not found: it encodes the room tone loops (docs/audio-direction.md section 7)")
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"{name}.ogg"
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp) / "src.wav"
        with wave.open(str(src), "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(to_pcm16(stereo.reshape(-1)).tobytes())
        subprocess.run([ffmpeg, "-nostdin", "-hide_banner", "-loglevel", "error", "-y", "-i", str(src),
                        "-c:a", "vorbis", "-strict", "experimental", "-q:a", str(quality),
                        "-fflags", "+bitexact", "-flags:a", "+bitexact", "-map_metadata", "-1", str(path)],
                       check=True)
    _report(path, stereo.reshape(-1, 2)[:, 0])
    return path


def _report(path: Path, left: np.ndarray) -> None:
    digest = hashlib.sha256(path.read_bytes()).hexdigest()[:16]
    print(f"wrote {path.relative_to(ROOT)}  {len(left) / SR:5.2f} s  {path.stat().st_size / 1024:6.1f} KB  "
          f"sha256 {digest}")
