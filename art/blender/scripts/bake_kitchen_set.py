"""Kitchen set textures (art-direction §10, §17). Headless, deterministic:
    /Applications/Blender.app/Contents/MacOS/Blender -b -P art/blender/scripts/bake_kitchen_set.py
Options (after a bare "--"):
    --samples N     Cycles samples for the wall bake and the check render (default 64)
    --no-check      skip the check render

Writes:
    assets/textures/kitchen_backdrop.png     1024 x 512 RGB. The sage zellige wall under the
                                             afternoon lights, scene-linear radiance stored with
                                             the sRGB curve (no tonemap), pre-blurred by the
                                             preview lens's depth of field. Maps 1:1 onto
                                             Backdrop_placeholder's UV 0..1.
    assets/textures/counter_oak_detail.png   512 x 512 gray, tiles. Butcher-block strips, grain,
                                             glue lines and end joints. 0.36 m tile, strips along u.
    assets/textures/lid_oak_detail.png       256 x 256 gray, tiles. Oak growth rings with a
                                             cathedral arch. 64 mm tile, grain along u.
    art/previews/kitchen_set_check.png       the §7 preview pose at_peak with these textures,
                                             backdrop unshaded (emission), no depth of field,
                                             so it reads like Godot on a phone.

The detail maps are value only. Godot keeps its measured colors and mixes
dark -> light oak by the map, so they never fight the reference-look rows.
"""

import math
import os
import struct
import sys
import tempfile
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

BACKDROP_PX = (1024, 512)
BAKE_PX_PER_M = 1024.0           # bake at square texels, then resample rows to 512
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
# Backdrop: render the wall orthographically under the scene lights, then blur
# =============================================================================
def bake_backdrop(samples):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    coll = bpy.data.collections.new("Bake")
    sc.collection.children.link(coll)
    bj.build_backdrop(coll, (bj.mat_backdrop(),))
    bj.build_counter(coll, (bj.mat_counter(),))          # for the bounce at the foot of the wall
    bj.setup_world()
    bj.setup_lights_camera(coll)
    bj.setup_render(samples, 100)

    w_m, h_m = bj.BACKDROP_W, bj.BACKDROP_H
    res = (int(round(w_m * BAKE_PX_PER_M)), int(round(h_m * BAKE_PX_PER_M)))
    cd = bpy.data.cameras.new("WallCam")
    cd.type = "ORTHO"
    cd.ortho_scale = w_m
    cd.sensor_fit = "HORIZONTAL"
    cd.clip_start = 0.001
    cd.dof.use_dof = False
    cam = bpy.data.objects.new("WallCam", cd)
    cam.location = (0.0, bj.COUNTER_BACK_Y - 0.01, h_m / 2.0)   # in front of every light
    cam.rotation_euler = (math.radians(90.0), 0.0, 0.0)         # looks +Y, at the wall
    coll.objects.link(cam)
    sc.camera = cam
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.image_settings.file_format = "OPEN_EXR"
    sc.render.image_settings.color_depth = "32"
    tmp = os.path.join(tempfile.mkdtemp(prefix="wall_"), "wall.exr")
    sc.render.filepath = tmp
    bpy.ops.render.render(write_still=True)

    img = bpy.data.images.load(tmp)
    px = np.empty(res[0] * res[1] * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    lin = px.reshape(res[1], res[0], 4)[::-1, :, :3].astype(np.float64)   # top row first
    blurred = gaussian_blur(lin, BLUR_SIGMA_M * BAKE_PX_PER_M)
    # Resample rows to the power-of-two height (the image is smooth, linear is enough).
    H = BACKDROP_PX[1]
    src = (np.arange(H) + 0.5) * res[1] / H - 0.5
    y0 = np.clip(np.floor(src).astype(int), 0, res[1] - 1)
    y1 = np.clip(y0 + 1, 0, res[1] - 1)
    t = (src - np.floor(src))[:, None, None]
    out = blurred[y0] * (1.0 - t) + blurred[y1] * t
    clipped = float(np.mean(out.max(axis=2) > 1.0))
    write_rgb(os.path.join(TEX, "kitchen_backdrop.png"), srgb_encode(out))
    print("WROTE kitchen_backdrop.png %dx%d  linear max %.3f  mean %s  clipped %.4f%%"
          % (BACKDROP_PX[0], H, out.max(), np.round(out.reshape(-1, 3).mean(0), 3), 100 * clipped))


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
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    coll = bpy.data.collections.new("Check")
    sc.collection.children.link(coll)
    m_starter, sv = bj.mat_starter()
    m_liner, lv = bj.mat_liner()

    m_wall, t = bj.new_mat("M_Backdrop")
    uvn = t.n("ShaderNodeUVMap")
    img = bpy.data.images.load(os.path.join(TEX, "kitchen_backdrop.png"))
    img.colorspace_settings.name = "sRGB"
    tex = t.n("ShaderNodeTexImage")
    tex.image = img
    tex.extension = "EXTEND"
    t.put(tex.inputs["Vector"], uvn.outputs["UV"])
    em = t.n("ShaderNodeEmission")
    t.put(em.inputs["Color"], tex.outputs["Color"])
    em.inputs["Strength"].default_value = 1.0
    t.out(em.outputs[0])

    m_counter, t = bj.new_mat("M_Counter_Wood")
    tc = t.n("ShaderNodeTexCoord")
    d = detail_node(t, "counter_oak_detail.png", tc.outputs["Object"], COUNTER_TILE_M)
    col = t.mix_col(d, bj.hexcol(bj.C["counter_dk"]), bj.hexcol(bj.C["counter_lt"]))
    p = t.principled(Base_Color=col)
    t.put(p.inputs["Roughness"], t.maprange(d, 0.0, 1.0, 0.62, 0.42, smooth_step=False))
    t.out(p.outputs[0])

    m_lid, t = bj.new_mat("M_Lid_Wood")
    tc = t.n("ShaderNodeTexCoord")
    d = detail_node(t, "lid_oak_detail.png", tc.outputs["Object"], LID_TILE_M, box=True)
    col = t.mix_col(d, bj.hexcol(bj.C["lid_wood_dk"]), bj.hexcol(bj.C["lid_wood_lt"]))
    p = t.principled(Base_Color=col, Coat_Weight=0.15)
    t.put(p.inputs["Roughness"], t.maprange(d, 0.0, 1.0, 0.6, 0.4, smooth_step=False))
    t.out(p.outputs[0])

    objs = {}
    objs["Jar_Glass"] = bj.build_glass(coll, (bj.mat_glass("M_Glass"), bj.mat_glass("M_Glass_Inner")))
    objs["Starter_Body"] = bj.build_starter(coll, (m_starter,))
    objs["Starter_Liner"] = bj.build_liner(coll, (m_liner,))
    objs["Jar_Lid_Loose"] = bj.build_lid_loose(coll, (m_lid,))
    objs["Rubber_Band"] = bj.build_band(coll, (bj.mat_simple("M_Rubber_Band", bj.C["band"], 0.55, subsurf=0.1),))
    objs["Counter"] = bj.build_counter(coll, (m_counter,))
    objs["Backdrop_placeholder"] = bj.build_backdrop(coll, (m_wall,))
    bj.add_starter_shape_modifier(objs["Starter_Body"], bj.mat_mold_fuzz())
    bj.setup_world()
    bj.setup_lights_camera(coll)
    bj.setup_render(samples, 100)
    sc.camera.data.dof.use_dof = False                     # Godot on a phone has no DOF
    bj.apply_state("at_peak", objs, sv, lv)
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
    bake_backdrop(samples)
    if "--no-check" not in argv:
        check_render(samples)
    print("DONE in %.1fs" % (time.time() - t0))


if __name__ == "__main__":
    main()
