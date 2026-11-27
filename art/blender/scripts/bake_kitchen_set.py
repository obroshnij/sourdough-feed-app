"""Kitchen set textures (art-direction §10, §17). Headless, deterministic:
    /Applications/Blender.app/Contents/MacOS/Blender -b -P art/blender/scripts/bake_kitchen_set.py
Options (after a bare "--"):
    --samples N     Cycles samples for the check render (default 64)
    --no-check      skip the check render

Writes:
    assets/textures/counter_oak_detail.png   512 x 512 gray, tiles. Butcher-block strips, grain,
                                             glue lines and end joints. 0.36 m tile, strips along u.
    assets/textures/lid_oak_detail.png       256 x 256 gray, tiles. Oak growth rings with a
                                             cathedral arch. 64 mm tile, grain along u.
    art/previews/kitchen_set_check.png       the §7 preview pose at_peak with these textures and
                                             the kitchen wall (kitchen_wall.png, unshaded), no
                                             depth of field, so it reads like Godot on a phone.

The wall texture comes from bake_kitchen_wall.py (§18). The flat card's kitchen_backdrop.png
and its bake were removed with Backdrop_placeholder (§18.5).

The detail maps are value only. Godot keeps its measured colors and mixes
dark -> light oak by the map, so they never fight the reference-look rows.
"""

import math
import os
import struct
import sys
import time
import zlib

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_jar as bj  # noqa: E402

REPO = bj.REPO
sys.path.insert(0, os.path.join(REPO, "art", "textures"))
import make_starter_masks as msk  # noqa: E402  (periodic noise helpers, no side effects)

TEX = os.path.join(REPO, "assets", "textures")
CHECK_OUT = os.path.join(REPO, "art", "previews", "kitchen_set_check.png")
SEED = 20261127

# Preview lens (§7): 60 mm, f/2.4, focus 0.556 m. The wall is about 1.0 m from the camera,
# so its circle of confusion is about 21 mm on the wall. A Gaussian of sigma 8 mm matches it.
BLUR_SIGMA_M = 0.008
COUNTER_PX, COUNTER_TILE_M = 512, 0.36
LID_PX, LID_TILE_M = 256, 0.064


# =============================================================================
# PNG writers (no PIL)
# =============================================================================
def _png(path, arr, color_type):
    h, w = arr.shape[:2]
    raw = b"".join(b"\x00" + arr[y].tobytes() for y in range(h))

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, color_type, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)


def write_gray(path, v):
    _png(path, np.clip(np.round(v * 255.0), 0, 255).astype(np.uint8), 0)


def write_rgb(path, rgb):
    _png(path, np.clip(np.round(rgb * 255.0), 0, 255).astype(np.uint8), 2)


def srgb_encode(lin):
    lin = np.clip(lin, 0.0, 1.0)
    return np.where(lin <= 0.0031308, lin * 12.92, 1.055 * np.power(lin, 1.0 / 2.4) - 0.055)


def gaussian_blur(img, sigma):
    """Separable Gaussian, edge-padded (the wall does not tile)."""
    r = int(math.ceil(3.0 * sigma))
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2)
    k /= k.sum()
    out = img
    for axis in (0, 1):
        pad = [(0, 0)] * out.ndim
        pad[axis] = (r, r)
        p = np.pad(out, pad, mode="edge")
        acc = np.zeros_like(out)
        n = out.shape[axis]
        for i, kv in enumerate(k):
            sl = [slice(None)] * out.ndim
            sl[axis] = slice(i, i + n)
            acc += kv * p[tuple(sl)]
        out = acc
    return out


# =============================================================================
# Detail maps (numpy, tile in u and v)
# =============================================================================
def dashes(rng, h, w, n, length_px, depth):
    """Short dark dashes along u: oak pores."""
    out = np.zeros((h, w))
    xs = rng.integers(0, w, n)
    ys = rng.integers(0, h, n)
    ls = rng.integers(length_px[0], length_px[1] + 1, n)
    for x, y, ln in zip(xs, ys, ls):
        cols = (x + np.arange(ln)) % w
        out[y % h, cols] = np.maximum(out[y % h, cols], depth * rng.uniform(0.5, 1.0))
    return out


def counter_detail(rng):
    N = COUNTER_PX
    mm = COUNTER_TILE_M * 1000.0 / N
    yy, xx = np.mgrid[0:N, 0:N] + 0.5
    n_strips = 9
    edges = np.sort((np.arange(n_strips) + rng.uniform(-0.12, 0.12, n_strips)) * N / n_strips)
    sidx = (np.searchsorted(edges, yy, side="right") - 1) % n_strips
    lo = edges[sidx]
    lo = np.where(yy < edges[0], lo - N, lo)
    hi = np.where(sidx + 1 < n_strips, edges[(sidx + 1) % n_strips], edges[0] + N)
    hi = np.where(yy < edges[0], edges[0], hi)
    tone = rng.uniform(-1.0, 1.0, n_strips) * 0.07
    spacing = rng.uniform(1.8, 3.4, n_strips) / mm          # px between latewood lines
    phase = rng.uniform(0, 1, n_strips)
    warp = (msk.periodic_noise(rng, N, N, 10.0, aniso=(14.0, 1.0)) - 0.5) * 6.0
    ring = np.mod((yy - lo) / spacing[sidx] + phase[sidx] + warp / spacing[sidx], 1.0)
    late = np.clip((ring - 0.62) / 0.3, 0, 1) * np.clip((1.0 - ring) / 0.08, 0, 1)
    fine = msk.periodic_noise(rng, N, N, 1.2, aniso=(16.0, 1.0))
    low = msk.periodic_noise(rng, N, N, 45.0, aniso=(3.0, 1.0))
    d_edge = np.minimum(yy - lo, hi - yy)
    glue = np.exp(-(d_edge / 0.9) ** 2)
    joint = np.zeros((N, N))
    for s in range(n_strips):
        if rng.random() < 0.55:
            xj = rng.uniform(0, N)
            inside = sidx == s
            dx = np.abs(msk.wrap_delta(xx - xj, N))
            joint = np.where(inside, np.maximum(joint, np.exp(-(dx / 0.8) ** 2)), joint)
            side = msk.wrap_delta(xx - xj, N) > 0
            tone_shift = rng.uniform(-0.05, 0.05)
            joint_tone = np.where(inside & side, tone_shift, 0.0)
            low = low + joint_tone
    pores = dashes(rng, N, N, 2600, (3, 9), 1.0)
    v = (0.56 + tone[sidx] + 0.22 * (low - 0.5) + 0.12 * (fine - 0.5)
         - 0.16 * late - 0.16 * glue - 0.22 * joint - 0.10 * pores)
    return np.clip(v, 0.0, 1.0)


def lid_detail(rng):
    N = LID_PX
    yy, xx = np.mgrid[0:N, 0:N] + 0.5
    n_rings = 26                                            # 2.5 mm apart over the 64 mm tile
    arch = np.cos(2.0 * math.pi * xx / N)                   # one cathedral arch per tile
    warp = (msk.periodic_noise(rng, N, N, 16.0, aniso=(4.0, 1.0)) - 0.5) * 3.0
    r = yy / N * n_rings + 1.6 * arch + warp
    d = np.mod(r, 1.0)
    late = np.clip((d - 0.58) / 0.3, 0, 1) * np.clip((1.0 - d) / 0.1, 0, 1)
    fine = msk.periodic_noise(rng, N, N, 1.0, aniso=(10.0, 1.0))
    low = msk.periodic_noise(rng, N, N, 30.0)
    pores = dashes(rng, N, N, 900, (2, 6), 1.0)
    v = 0.60 + 0.18 * (low - 0.5) + 0.10 * (fine - 0.5) - 0.30 * late - 0.12 * pores
    return np.clip(v, 0.0, 1.0)


# =============================================================================
# Check render: the §7 pose with the baked textures, unshaded wall, no DOF
# =============================================================================
def detail_node(t, name, coord, tile_m, box=False):
    img = bpy.data.images.load(os.path.join(TEX, name), check_existing=True)
    img.colorspace_settings.name = "Non-Color"
    mp = t.n("ShaderNodeMapping")
    t.put(mp.inputs["Vector"], coord)
    mp.inputs["Scale"].default_value = (1.0 / tile_m,) * 3
    tex = t.n("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Linear"
    tex.extension = "REPEAT"
    if box:
        tex.projection = "BOX"
        tex.projection_blend = 0.25
    t.put(tex.inputs["Vector"], mp.outputs[0])
    return t.sep(tex.outputs["Color"])[0]


def check_render(samples):
    """The kitchen wall's preview scene: Kitchen_Wall with kitchen_wall.png unshaded, the counter
    and lid with these maps, at_peak, the §7 pose, no DOF."""
    import bake_kitchen_wall as bkw   # imported here: it imports this module
    sc = bkw.preview_scene()
    sc.cycles.samples = samples
    sc.render.filepath = CHECK_OUT
    bpy.ops.render.render(write_still=True)
    print("RENDERED", CHECK_OUT)


def main():
    t0 = time.time()
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    samples = int(argv[argv.index("--samples") + 1]) if "--samples" in argv else 64
    rng = np.random.default_rng(SEED)
    write_gray(os.path.join(TEX, "counter_oak_detail.png"), counter_detail(rng))
    print("WROTE counter_oak_detail.png %dx%d, tile %.2f m" % (COUNTER_PX, COUNTER_PX, COUNTER_TILE_M))
    write_gray(os.path.join(TEX, "lid_oak_detail.png"), lid_detail(rng))
    print("WROTE lid_oak_detail.png %dx%d, tile %.3f m" % (LID_PX, LID_PX, LID_TILE_M))
    if "--no-check" not in argv:
        check_render(samples)
    print("DONE in %.1fs" % (time.time() - t0))


if __name__ == "__main__":
    main()
