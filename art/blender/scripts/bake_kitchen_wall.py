"""Kitchen wall: a curved, baked backdrop that holds over the whole camera orbit
(art-direction.md §10, §17, §18). Headless, deterministic:
    /Applications/Blender.app/Contents/MacOS/Blender -b -P art/blender/scripts/bake_kitchen_wall.py
Options (after a bare "--"):
    --samples N          Cycles bake samples (default 256)
    --preview-samples N  Cycles samples for the preview sheet and the yaw 0 check (default 48)
    --no-preview         skip the preview sheet and the yaw 0 check
    --coverage-only      only run the camera coverage check (numpy, no baking)

Writes:
    assets/3d/kitchen_wall.glb         node Kitchen_Wall: one mesh, one surface, one placeholder
                                       material M_Kitchen_Wall. UV0 is the atlas below.
    assets/textures/kitchen_wall.png   1024 x 512 RGB atlas: the day look. The sage zellige wall
                                       and the base-cabinet front under the afternoon lights, stored
                                       like kitchen_backdrop.png (§17): scene-linear radiance with the
                                       sRGB curve, no tonemap, pre-blurred by the preview lens.
                                       Rows 0..447 wall (row 0 = wall top), 448..451 padding,
                                       452..511 cabinet front (row 452 = just under the counter).
    assets/textures/kitchen_wall_night.png  512 x 256 gray, same atlas layout at half size: the
                                       night lamp's light alone (§18), luminance normalized so the
                                       brightest wall texel is 1, stored as its square root.
    art/previews/kitchen_wall_check.png  six small in-game frames (unshaded wall, no depth of field)

The shape: an arc of a circle centered 0.65 m in front of the jar, radius 1.10 m. Its back is at
z = -0.45 m, exactly where the flat card stood, so the yaw 0 look is unchanged. The ends come
forward to the counter front at x = +-1.01 m, and a base-cabinet front closes the space under the
counter's front edge. The camera stays inside the circle at every pose (checked below).
Godot axes in comments (+Y up, the jar front faces +Z). Blender: (x, -z, y).
"""

import math
import os
import sys
import tempfile
import time

import bmesh
import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_jar as bj  # noqa: E402
import bake_kitchen_set as bks  # noqa: E402  (PNG writer, sRGB curve, blur; no side effects)

REPO = bj.REPO
TEX = os.path.join(REPO, "assets", "textures")
WALL_PNG = os.path.join(TEX, "kitchen_wall.png")
NIGHT_PNG = os.path.join(TEX, "kitchen_wall_night.png")
GLB_OUT = os.path.join(REPO, "assets", "3d", "kitchen_wall.glb")
SHEET_OUT = os.path.join(REPO, "art", "previews", "kitchen_wall_check.png")

# --- Shape (Godot meters, jar axis at x = z = 0, counter top at y = 0) -------------------
WALL_CZ = 0.65            # circle center, Godot z: in front of the jar
WALL_R = 1.10             # radius. Back of the arc = WALL_R - WALL_CZ = 0.45 m, where the card was
CAB_Z = 0.22              # the arc ends here; the cabinet front is 20 mm behind the counter edge
WALL_TOP = 0.80           # highest wall point any pose sees is 0.68 m (coverage check)
WALL_BOT = -0.02          # 2 cm into the counter slab, so the foot never shows a crack
CAB_TOP = -0.03           # just inside the slab (its underside is at -0.035)
CAB_BOT = -0.45
SEGMENTS = 64             # 2.1 degrees per column, chord error 0.2 mm
HALF_W = math.sqrt(WALL_R ** 2 - (WALL_CZ - CAB_Z) ** 2)          # 1.012 m
END = math.atan2(HALF_W, WALL_CZ - CAB_Z)                          # 67.0 degrees
ARC_LEN = WALL_R * 2.0 * END                                       # 2.57 m

# --- Atlas ---------------------------------------------------------------------------------
ATLAS_W, ATLAS_H = 1024, 512
WALL_ROWS = 448           # 2.5 mm per texel along the arc, 1.8 mm up the wall
CAB_ROW0, CAB_ROWS = 452, 60

# --- Bake ----------------------------------------------------------------------------------
BAKE_PX_PER_M = 500.0     # 2 mm texels before the blur
BLUR_SIGMA_M = bks.BLUR_SIGMA_M      # 8 mm at the back, as the card (§17)
LENS_D, LENS_FOCUS = bj.CAM_DIST, 0.556   # preview pose: camera to jar, focus distance (§7)
CAB_SIGMA_M = 0.005       # the cabinet front sits nearer than focus: less blur
CABINET = "#D6CCBA"       # warm greige paint; reads darker in the counter's shade
CAB_DOOR_W = 0.60         # doors centered on the jar, drawer line 0.15 m under the counter top
NIGHT_LAMP = (-0.10, 0.46, -0.26)   # Godot: a short under-cabinet LED bar above-left of the jar (§3)
NIGHT_LAMP_SIZE = (0.30, 0.03)      # meters along x and z; it faces straight down
NIGHT_COLOR = "#FFD7A8"
NIGHT_REF_PERCENTILE = 100.0        # normalize to the brightest wall texel: nothing clips
HOME_DIST = 0.68          # in-game home distance on a typical phone (set_jar_region)


def g2b(x, y, z):
    """Godot point to Blender."""
    return (x, -z, y)


def arc_point(psi):
    """Godot (x, z) of the wall at angle psi (radians from the back, + toward +x)."""
    return WALL_R * math.sin(psi), WALL_CZ - WALL_R * math.cos(psi)


def jar_to_wall(psi):
    return np.sqrt(WALL_R ** 2 - 2.0 * WALL_CZ * WALL_R * np.cos(psi) + WALL_CZ ** 2)


# =============================================================================
# Coverage: cast rays over the orbit and the focus presets (pure numpy)
# =============================================================================
TH = math.tan(math.radians(33.4 / 2.0))
JAR_CENTER = np.array([0.0, 0.1018, 0.0])


def coverage_poses():
    out = []
    for yaw in np.arange(-78, 78.1, 2.0):              # +-70 plus the 8 degree band
        for pitch in np.arange(-10, 40.1, 2.5):        # -5..35 plus the 5 degree band
            for d in (0.25, 0.4, 0.58, 0.7, 0.82, 0.92):   # 2.2x zoom ... 360x640 phone zoomed out
                # (frame shift, screen fraction a sheet covers): no sheet, then sheets
                for fs, cover in ((-0.05, 0.0), (0.0, 0.0), (0.1, 0.2), (0.2, 0.4), (0.3, 0.6)):
                    out.append((yaw, pitch, d, fs, cover, JAR_CENTER, "orbit"))
    for lvl in (0.030, 0.042):
        y = 0.008 + 0.55 * lvl
        off = np.array([-0.0737, 0.012, 0.1386])
        n = float(np.linalg.norm(off))
        out.append((math.degrees(math.atan2(off[0], off[2])), math.degrees(math.asin(off[1] / n)),
                    n, 0.3, 0.6, np.array([0.0, y, 0.0]), "bubbles"))
    out.append((0.0, 4.0, 0.30, 0.3, 0.6, np.array([0.0, 0.06, 0.0]), "height"))
    out.append((0.0, 50.0, 0.36, 0.3, 0.6, np.array([0.0, 0.15, 0.0]), "top"))
    out.append((0.0, 76.0, 0.20, 0.3, 0.6, np.array([0.0, 0.09, -0.004]), "surface"))
    return out


def coverage_check(counter_half_x):
    """Every ray must land on the counter top or front, the cabinet front or the wall. Rays under
    the HUD plate (top 17%), the action bar (bottom 12.5%) or an open sheet are skipped."""
    t0 = time.time()
    sx, sy = np.meshgrid(np.linspace(-1, 1, 11), np.linspace(-1, 1, 21))
    stats = {"rays": 0, "ymax": -9.0, "psimax": 0.0, "psimax_band": 0.0, "margin": 9.0}
    inside, band = {}, {}
    for (yaw, pitch, d, fs, cover, tgt, kind) in coverage_poses():
        yr, pr = math.radians(yaw), math.radians(pitch)
        back = np.array([math.cos(pr) * math.sin(yr), math.sin(pr), math.cos(pr) * math.cos(yr)])
        pos = tgt + back * d
        stats["margin"] = min(stats["margin"], WALL_R - math.hypot(pos[0], pos[2] - WALL_CZ))
        f = -back
        r = np.cross(f, [0.0, 1.0, 0.0])
        r /= np.linalg.norm(r)
        u = np.cross(r, f)
        vis = (sy >= -1 + 2 * max(cover, 0.125)) & (sy <= 1 - 2 * 0.17)
        for aspect in (390.0 / 844.0, 9.0 / 16.0, 3.0 / 4.0):
            D = f + r * (sx * aspect * TH)[vis][:, None] + u * ((sy - 2 * fs) * TH)[vis][:, None]
            n = D.shape[0]
            stats["rays"] += n
            best = np.full(n, np.inf)
            hit = np.zeros(n, bool)
            with np.errstate(divide="ignore", invalid="ignore"):
                t = -pos[1] / D[:, 1]
                p = pos + t[:, None] * D
                ok = (D[:, 1] < 0) & (pos[1] > 0) & (np.abs(p[:, 0]) <= counter_half_x) \
                    & (p[:, 2] >= -bj.COUNTER_BACK_Y - 0.02) & (p[:, 2] <= -bj.COUNTER_FRONT_Y)
                best = np.where(ok, t, best)
                t = (-bj.COUNTER_FRONT_Y - pos[2]) / D[:, 2]
                p = pos + t[:, None] * D
                ok = (D[:, 2] < 0) & (pos[2] > -bj.COUNTER_FRONT_Y) & (np.abs(p[:, 0]) <= counter_half_x) \
                    & (p[:, 1] <= 0) & (p[:, 1] >= -bj.COUNTER_T)
                best = np.where(ok & (t < best), t, best)
                t = (CAB_Z - pos[2]) / D[:, 2]
                p = pos + t[:, None] * D
                ok = (D[:, 2] < 0) & (pos[2] > CAB_Z) & (np.abs(p[:, 0]) <= HALF_W) \
                    & (p[:, 1] < -bj.COUNTER_T) & (p[:, 1] >= CAB_BOT)
                best = np.where(ok & (t < best), t, best)
                ox, oz = pos[0], pos[2] - WALL_CZ
                a = D[:, 0] ** 2 + D[:, 2] ** 2
                b = 2 * (ox * D[:, 0] + oz * D[:, 2])
                c = ox * ox + oz * oz - WALL_R ** 2
                t = (-b + np.sqrt(b * b - 4 * a * c)) / (2 * a)
                p = pos + t[:, None] * D
                psi = np.arctan2(p[:, 0], WALL_CZ - p[:, 2])
                ok = (np.abs(psi) <= END + 1e-9) & (p[:, 1] >= WALL_BOT) & (p[:, 1] <= WALL_TOP) & (t < best)
                if ok.any():
                    key = "psimax" if abs(yaw) <= 70 and -5 <= pitch <= 35 else "psimax_band"
                    stats["ymax"] = max(stats["ymax"], float(p[ok, 1].max()))
                    stats[key] = max(stats[key], float(np.degrees(np.abs(psi[ok])).max()))
                hit = np.isfinite(best) | ok
            miss = int((~hit).sum())
            if miss:
                in_limits = abs(yaw) <= 70 and -5 <= pitch <= 35
                bucket = inside if in_limits else band
                key = (kind, "camera below the counter top" if pos[1] <= 0.0 else "other")
                bucket[key] = bucket.get(key, 0) + miss
    print("COVERAGE %d rays, %d poses x 3 aspects (%.1f s). Camera inside the wall circle by >= %.3f m. "
          "Highest wall point seen %.3f m (top %.2f). Widest angle seen %.1f deg within the limits, %.1f in the bands (end %.1f)."
          % (stats["rays"], len(coverage_poses()), time.time() - t0, stats["margin"], stats["ymax"],
             WALL_TOP, stats["psimax"], stats["psimax_band"], math.degrees(END)))
    print("COVERAGE misses within the limits (yaw +-70, pitch -5..35, zoom 1..2.2, presets): %d %s"
          % (sum(inside.values()), inside))
    print("COVERAGE misses only in the rubber bands past the limits: %d %s" % (sum(band.values()), band))
    return sum(inside.values())


# =============================================================================
# Meshes
# =============================================================================
def build_wall_mesh(name, coll, mats, uv_mode):
    """uv_mode 'atlas': UV0 is the kitchen_wall.png atlas (wall and cabinet islands).
    uv_mode 'bake_wall' / 'bake_cab': only that island, UV 0..1, plus 'Unrolled' = (s, y) meters."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    unrolled = bm.loops.layers.uv.new("Unrolled") if uv_mode != "atlas" else None
    v_wall = lambda y: 1.0 - (WALL_TOP - y) / (WALL_TOP - WALL_BOT) * WALL_ROWS / ATLAS_H
    v_cab = lambda y: 1.0 - (CAB_ROW0 + (CAB_TOP - y) / (CAB_TOP - CAB_BOT) * CAB_ROWS) / ATLAS_H
    quads = []
    if uv_mode in ("atlas", "bake_wall"):
        cols = []
        for i in range(SEGMENTS + 1):
            psi = -END + 2.0 * END * i / SEGMENTS
            x, z = arc_point(psi)
            cols.append((x, z, i / SEGMENTS, WALL_R * psi))
        rows = (WALL_BOT, WALL_TOP)
        for i in range(SEGMENTS):
            a, b = cols[i], cols[i + 1]
            corners = [(a, rows[0]), (b, rows[0]), (b, rows[1]), (a, rows[1])]
            quads.append([(g2b(c[0], y, c[1]),
                           (c[2], v_wall(y)) if uv_mode == "atlas"
                           else (c[2], (y - WALL_BOT) / (WALL_TOP - WALL_BOT)),
                           (c[3], y)) for c, y in corners])
    if uv_mode in ("atlas", "bake_cab"):
        n = 8
        for i in range(n):
            xa = -HALF_W + 2 * HALF_W * i / n
            xb = -HALF_W + 2 * HALF_W * (i + 1) / n
            corners = [(xa, CAB_BOT), (xb, CAB_BOT), (xb, CAB_TOP), (xa, CAB_TOP)]
            quads.append([(g2b(x, y, CAB_Z),
                           ((x + HALF_W) / (2 * HALF_W), v_cab(y)) if uv_mode == "atlas"
                           else ((x + HALF_W) / (2 * HALF_W), (y - CAB_BOT) / (CAB_TOP - CAB_BOT)),
                           (x, y)) for x, y in corners])
    cache = {}
    for q in quads:
        vs = []
        for co, _, _ in q:
            key = tuple(round(c, 7) for c in co)
            if key not in cache:
                cache[key] = bm.verts.new(co)
            vs.append(cache[key])
        f = bm.faces.new(vs)
        for loop, (_, uvc, unr) in zip(f.loops, q):
            loop[uv].uv = uvc
            if unrolled is not None:
                loop[unrolled].uv = unr
    bm.normal_update()
    # Normals face the camera: toward the circle center for the wall, +Godot z (Blender -y) for the cabinet.
    for f in bm.faces:
        c = f.calc_center_median()
        if abs(c.y + CAB_Z) < 1e-6:
            want = -1.0 if f.normal.y > 0 else 1.0
        else:
            to_center = (0.0 - c.x, -WALL_CZ - c.y)
            want = 1.0 if f.normal.x * to_center[0] + f.normal.y * to_center[1] > 0 else -1.0
        if want < 0:
            f.normal_flip()
    bm.normal_update()
    ob = bj.make_object(name, bm, coll, mats=mats)
    ob.data.uv_layers.active = ob.data.uv_layers["UVMap"]
    ob.data.uv_layers["UVMap"].active_render = True
    return ob


# =============================================================================
# Materials for the bake
# =============================================================================
def mat_wall_tiles():
    """bj.mat_backdrop() on unrolled coordinates: at the back of the arc it is the same pattern
    the flat card had (Object coords there were (x, 0.45, height))."""
    m, t = bj.new_mat("M_Wall_bake")
    uvn = t.n("ShaderNodeUVMap")
    uvn.uv_map = "Unrolled"
    s, h, _ = t.sep(uvn.outputs["UV"])
    brick_vec = t.combine(s, t.math("MULTIPLY", h, -1.0), bj.COUNTER_BACK_Y)
    noise_vec = t.combine(s, bj.COUNTER_BACK_Y, h)
    brick = t.n("ShaderNodeTexBrick", offset=0.0, offset_frequency=1)
    t.put(brick.inputs["Vector"], brick_vec)
    brick.inputs["Scale"].default_value = 1.0
    brick.inputs["Mortar Size"].default_value = 0.0015
    brick.inputs["Mortar Smooth"].default_value = 0.3
    brick.inputs["Brick Width"].default_value = 0.065
    brick.inputs["Row Height"].default_value = 0.065
    brick.inputs["Bias"].default_value = 0.0
    brick.inputs["Color1"].default_value = bj.hexcol(bj.C["tile_a"])
    brick.inputs["Color2"].default_value = bj.hexcol(bj.C["tile_b"])
    brick.inputs["Mortar"].default_value = bj.hexcol(bj.C["grout"])
    glaze = t.n("ShaderNodeTexNoise")
    t.put(glaze.inputs["Vector"], noise_vec)
    glaze.inputs["Scale"].default_value = 30.0
    glaze.inputs["Detail"].default_value = 3.0
    bump = t.n("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.4
    t.put(bump.inputs["Height"], t.math("SUBTRACT", glaze.outputs["Fac"],
                                        t.math("MULTIPLY", brick.outputs["Fac"], 0.6)))
    rough = t.maprange(brick.outputs["Fac"], 0.0, 1.0, 0.18, 0.8, smooth_step=False)
    p = t.principled(Base_Color=brick.outputs["Color"], Roughness=rough, Coat_Weight=0.3)
    t.put(p.inputs["Normal"], bump.outputs[0])
    t.out(p.outputs[0])
    return m


def mat_cabinet():
    """Painted base-cabinet front: a drawer row on top, doors below, soft shadow gaps."""
    m, t = bj.new_mat("M_Cabinet_bake")
    uvn = t.n("ShaderNodeUVMap")
    uvn.uv_map = "Unrolled"
    x, y, _ = t.sep(uvn.outputs["UV"])
    wrap = t.n("ShaderNodeMath", operation="WRAP")
    t.put(wrap.inputs[0], x)
    wrap.inputs[1].default_value = CAB_DOOR_W
    wrap.inputs[2].default_value = 0.0
    dx = t.math("ABSOLUTE", t.math("SUBTRACT", wrap.outputs[0], CAB_DOOR_W / 2.0))
    dy = t.math("ABSOLUTE", t.math("SUBTRACT", y, -bj.COUNTER_T - 0.15))
    gap = t.math("MAXIMUM", t.maprange(dx, 0.0015, 0.004, 1.0, 0.0, smooth_step=True),
                 t.maprange(dy, 0.0015, 0.004, 1.0, 0.0, smooth_step=True))
    paint = bj.hexcol(CABINET)
    col = t.mix_col(gap, paint, tuple(c * 0.25 for c in paint[:3]) + (1.0,))
    p = t.principled(Base_Color=col, Roughness=0.45)
    t.out(p.outputs[0])
    return m


def mat_placeholder():
    m, t = bj.new_mat("M_Kitchen_Wall")
    t.out(t.principled(Base_Color=bj.hexcol("#A49F80"), Roughness=0.6).outputs[0])
    return m


# =============================================================================
# Bake
# =============================================================================
def bake_scene(night):
    """Wall, cabinet and the counter (for bounce). Day: the §3 look-dev lights and world, as the
    card's bake. Night: only the under-cabinet lamp."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    coll = bpy.data.collections.new("Bake")
    sc.collection.children.link(coll)
    wall = build_wall_mesh("Bake_Wall", coll, (mat_wall_tiles(),), "bake_wall")
    cab = build_wall_mesh("Bake_Cabinet", coll, (mat_cabinet(),), "bake_cab")
    bj.build_counter(coll, (bj.mat_counter(),))
    bj.setup_world()
    if night:
        bpy.context.scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.0
        lt = bpy.data.lights.new("NightLamp", "AREA")
        lt.shape = "RECTANGLE"
        lt.size, lt.size_y = NIGHT_LAMP_SIZE
        lt.energy = 2.0
        lt.color = bj.hexcol(NIGHT_COLOR)[:3]
        lamp = bpy.data.objects.new("NightLamp", lt)
        lamp.location = g2b(*NIGHT_LAMP)        # area lights face Blender -Z: straight down
        coll.objects.link(lamp)
        cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
        coll.objects.link(cam)
        sc.camera = cam
    else:
        bj.setup_lights_camera(coll)
    bj.setup_render(64, 100)
    return wall, cab


def bake(ob, w, h, samples):
    sc = bpy.context.scene
    sc.cycles.samples = samples
    img = bpy.data.images.new(ob.name + "_img", w, h, alpha=True, float_buffer=True)
    for slot in ob.material_slots:
        nt = slot.material.node_tree
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = img
        for nd in nt.nodes:
            nd.select = False
        node.select = True
        nt.nodes.active = node
    for o in sc.objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    sc.render.bake.view_from = "ABOVE_SURFACE"       # seen along the normal, like the card's ortho bake
    bpy.ops.object.bake(type="COMBINED", margin=2, use_clear=True, target="IMAGE_TEXTURES")
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    return px.reshape(h, w, 4)[::-1, :, :3].astype(np.float64)     # top row first


def blur_wall(lin, w):
    """The lens blur grows with the distance behind the jar (object-space circle of confusion):
    8 mm at the back, about 18 mm at the ends. Blends a few fixed-sigma blurs per column."""
    psi = -END + 2.0 * END * (np.arange(w) + 0.5) / w
    k = (LENS_D + jar_to_wall(psi) - LENS_FOCUS) / (LENS_D + (WALL_R - WALL_CZ) - LENS_FOCUS)
    sig = BLUR_SIGMA_M * k
    levels = np.linspace(sig.min(), sig.max(), 6)
    blurred = [bks.gaussian_blur(lin, s * BAKE_PX_PER_M) for s in levels]
    pos = np.interp(sig, levels, np.arange(len(levels)))
    i0 = np.clip(np.floor(pos).astype(int), 0, len(levels) - 2)
    f = (pos - i0)[None, :, None]
    out = np.empty_like(lin)
    for i in range(len(levels) - 1):
        cols = i0 == i
        out[:, cols] = blurred[i][:, cols] * (1 - f[:, cols]) + blurred[i + 1][:, cols] * f[:, cols]
    return out, sig.min(), sig.max()


def resample(img, rows_out, cols_out):
    """Bilinear sample at the output texel centers (the input is smooth after the blur)."""
    h, w = img.shape[:2]
    ys = np.clip((np.arange(rows_out) + 0.5) * h / rows_out - 0.5, 0, h - 1)
    xs = np.clip((np.arange(cols_out) + 0.5) * w / cols_out - 0.5, 0, w - 1)
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    y1 = np.minimum(y0 + 1, h - 1)
    x1 = np.minimum(x0 + 1, w - 1)
    fy = (ys - y0)[:, None, None]
    fx = (xs - x0)[None, :, None]
    top = img[y0][:, x0] * (1 - fx) + img[y0][:, x1] * fx
    bot = img[y1][:, x0] * (1 - fx) + img[y1][:, x1] * fx
    return top * (1 - fy) + bot * fy


def bake_atlas(samples):
    ww, wh = int(round(ARC_LEN * BAKE_PX_PER_M)), int(round((WALL_TOP - WALL_BOT) * BAKE_PX_PER_M))
    cw, ch = int(round(2 * HALF_W * BAKE_PX_PER_M)), int(round((CAB_TOP - CAB_BOT) * BAKE_PX_PER_M))
    out = {}
    for night in (False, True):
        t0 = time.time()
        wall, cab = bake_scene(night)
        wl = bake(wall, ww, wh, samples)
        # The cabinet front sits under the counter overhang. The look-dev area lights reach below the
        # counter top (they are studio panels), so it is baked with only the room (world) light.
        for ob in bpy.context.scene.objects:
            if ob.type == "LIGHT":
                ob.hide_render = True
        cl = bake(cab, cw, ch, samples)
        wl, s0, s1 = blur_wall(wl, ww)
        cl = bks.gaussian_blur(cl, CAB_SIGMA_M * BAKE_PX_PER_M)
        out[night] = (resample(wl, WALL_ROWS, ATLAS_W), resample(cl, CAB_ROWS, ATLAS_W))
        print("BAKED %s wall %dx%d, cabinet %dx%d, %d samples, blur sigma %.1f..%.1f mm (%.1f s)"
              % ("night" if night else "day", ww, wh, cw, ch, samples, s0 * 1000, s1 * 1000, time.time() - t0))
    rgb = np.zeros((ATLAS_H, ATLAS_W, 3))
    lum = np.zeros((ATLAS_H, ATLAS_W))
    for night in (False, True):
        w, c = out[night]
        if night:
            luma = lambda a: a @ np.array([0.2126, 0.7152, 0.0722])
            ref = float(np.percentile(luma(w), NIGHT_REF_PERCENTILE))
            lum[:WALL_ROWS] = luma(w) / ref
            lum[CAB_ROW0:] = luma(c) / ref
            lum[WALL_ROWS:WALL_ROWS + 2] = lum[WALL_ROWS - 1]
            lum[WALL_ROWS + 2:CAB_ROW0] = lum[CAB_ROW0]
        else:
            rgb[:WALL_ROWS] = w
            rgb[CAB_ROW0:] = c
            rgb[WALL_ROWS:WALL_ROWS + 2] = rgb[WALL_ROWS - 1]
            rgb[WALL_ROWS + 2:CAB_ROW0] = rgb[CAB_ROW0]
    clipped = float(np.mean(rgb.max(axis=2) > 1.0))
    srgb = bks.srgb_encode(rgb)
    bks.write_rgb(WALL_PNG, srgb)
    night = np.sqrt(np.clip(lum, 0, 1))
    night = night.reshape(ATLAS_H // 2, 2, ATLAS_W // 2, 2).mean(axis=(1, 3))     # 2x2 box: same layout
    bks.write_gray(NIGHT_PNG, night)
    print("WROTE %s %dx%d RGB, %d bytes. Day linear max %.3f, mean wall %s, mean cabinet %s, clipped %.4f%%"
          % (os.path.relpath(WALL_PNG, REPO), ATLAS_W, ATLAS_H, os.path.getsize(WALL_PNG), rgb.max(),
             np.round(rgb[:WALL_ROWS].reshape(-1, 3).mean(0), 3), np.round(rgb[CAB_ROW0:].reshape(-1, 3).mean(0), 3),
             100 * clipped))
    wl = night[:WALL_ROWS // 2] ** 2
    print("WROTE %s %dx%d gray, %d bytes. Linear night light on the wall: median %.3f, 90th pct %.3f, "
          "at the wall foot behind the jar %.3f, at the ends %.3f"
          % (os.path.relpath(NIGHT_PNG, REPO), ATLAS_W // 2, ATLAS_H // 2, os.path.getsize(NIGHT_PNG),
             float(np.median(wl)), float(np.percentile(wl, 90)), float(wl[-8:, ATLAS_W // 4 - 4:ATLAS_W // 4 + 4].mean()),
             float(wl[:, :8].mean())))
    return srgb


def compare_with_card(rgba):
    """The back of the arc against the signed-off card (kitchen_backdrop.png) over the part the
    yaw 0 pose sees: x -0.3..0.3 m, height 0.05..0.65 m. sRGB 8-bit means."""
    card_path = os.path.join(TEX, "kitchen_backdrop.png")
    if not os.path.exists(card_path):
        return
    img = bpy.data.images.load(card_path)
    w, h = img.size
    px = np.empty(w * h * img.channels, dtype=np.float32)
    img.pixels.foreach_get(px)
    card = px.reshape(h, w, img.channels)[::-1, :, :3]
    xs = np.linspace(-0.3, 0.3, 61)
    ys = np.linspace(0.05, 0.65, 61)
    cx = np.clip(((xs + bj.BACKDROP_W / 2) / bj.BACKDROP_W * w).astype(int), 0, w - 1)
    cy = np.clip(((bj.BACKDROP_H - ys) / bj.BACKDROP_H * h).astype(int), 0, h - 1)
    a = card[cy][:, cx]
    nx = np.clip(((xs / WALL_R + END) / (2 * END) * ATLAS_W).astype(int), 0, ATLAS_W - 1)
    ny = np.clip(((WALL_TOP - ys) / (WALL_TOP - WALL_BOT) * WALL_ROWS).astype(int), 0, WALL_ROWS - 1)
    b = rgba[ny][:, nx]
    print("CARD vs ARC (yaw 0 view, sRGB 0..255): card mean %s, arc mean %s, mean abs diff %.1f"
          % (np.round(a.reshape(-1, 3).mean(0) * 255, 1), np.round(b.reshape(-1, 3).mean(0) * 255, 1),
             float(np.abs(a - b).mean() * 255)))


# =============================================================================
# GLB
# =============================================================================
def export_glb():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    coll = bpy.data.collections.new("GLB_Export")
    sc.collection.children.link(coll)
    ob = build_wall_mesh("Kitchen_Wall", coll, (mat_placeholder(),), "atlas")
    ob["wall_center_z_m"] = WALL_CZ
    ob["wall_radius_m"] = WALL_R
    ob["wall_end_deg"] = round(math.degrees(END), 3)
    ob["wall_top_m"] = WALL_TOP
    ob["cabinet_z_m"] = CAB_Z
    ob["texture"] = "kitchen_wall.png"
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    os.makedirs(os.path.dirname(GLB_OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=GLB_OUT, export_format="GLB", use_selection=True,
        export_apply=False, export_yup=True, export_extras=True,
        export_cameras=False, export_lights=False, export_animations=False,
        export_texcoords=True, export_normals=True, export_tangents=False,
        export_materials="EXPORT")
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    print("EXPORTED %s %d bytes, Kitchen_Wall %d tris" % (os.path.relpath(GLB_OUT, REPO), os.path.getsize(GLB_OUT), tris))


# =============================================================================
# Previews: the jar at_peak in front of the wall, as Godot draws it on a phone
# =============================================================================
def preview_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    coll = bpy.data.collections.new("Check")
    sc.collection.children.link(coll)
    m_starter, sv = bj.mat_starter()
    m_liner, lv = bj.mat_liner()

    m_wall, t = bj.new_mat("M_Kitchen_Wall")
    uvn = t.n("ShaderNodeUVMap")
    uvn.uv_map = "UVMap"
    img = bpy.data.images.load(WALL_PNG)
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
    d = bks.detail_node(t, "counter_oak_detail.png", tc.outputs["Object"], bks.COUNTER_TILE_M)
    col = t.mix_col(d, bj.hexcol(bj.C["counter_dk"]), bj.hexcol(bj.C["counter_lt"]))
    p = t.principled(Base_Color=col)
    t.put(p.inputs["Roughness"], t.maprange(d, 0.0, 1.0, 0.62, 0.42, smooth_step=False))
    t.out(p.outputs[0])

    m_lid, t = bj.new_mat("M_Lid_Wood")
    tc = t.n("ShaderNodeTexCoord")
    d = bks.detail_node(t, "lid_oak_detail.png", tc.outputs["Object"], bks.LID_TILE_M, box=True)
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
    objs["Kitchen_Wall"] = build_wall_mesh("Kitchen_Wall", coll, (m_wall,), "atlas")
    bj.add_starter_shape_modifier(objs["Starter_Body"], bj.mat_mold_fuzz())
    bj.setup_world()
    bj.setup_lights_camera(coll)
    bj.setup_render(48, 100)                               # Cycles, AgX Medium High Contrast (§7)
    sc.camera.data.dof.use_dof = False                     # Godot on a phone has no DOF
    bj.apply_state("at_peak", objs, sv, lv)
    return sc


def place_camera(cam, yaw, pitch, dist, target):
    y, p = math.radians(yaw), math.radians(pitch)
    pos = (target[0] + dist * math.cos(p) * math.sin(y), target[1] + dist * math.sin(p),
           target[2] + dist * math.cos(p) * math.cos(y))
    cam.location = g2b(*pos)
    bj.aim(cam, g2b(*target))


def render_to_array(sc, w, h, samples):
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.resolution_percentage = 100
    sc.cycles.samples = samples
    path = os.path.join(tempfile.mkdtemp(prefix="wallchk_"), "f.png")
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(path)
    px = np.empty(w * h * img.channels, dtype=np.float32)
    img.pixels.foreach_get(px)
    return px.reshape(h, w, img.channels)[::-1, :, :3]


def patch_hsv(arr, x, y, r=15):
    m = arr[y - r:y + r + 1, x - r:x + r + 1].reshape(-1, 3).mean(0)
    mx, mn = m.max(), m.min()
    hue = 0.0
    if mx > mn:
        if mx == m[0]:
            hue = (60 * ((m[1] - m[2]) / (mx - mn))) % 360
        elif mx == m[1]:
            hue = 60 * ((m[2] - m[0]) / (mx - mn)) + 120
        else:
            hue = 60 * ((m[0] - m[1]) / (mx - mn)) + 240
    hx = "#%02X%02X%02X" % tuple(int(round(c * 255)) for c in m)
    return "%s (H %.0f, S %.0f%%, V %.0f%%)" % (hx, hue, 100 * (mx - mn) / max(mx, 1e-6), 100 * mx)


SHEET_POSES = [   # (yaw, pitch, distance): top row at home pitch, bottom row at the limits
    (-70.0, 15.0, HOME_DIST), (0.0, 15.0, HOME_DIST), (70.0, 15.0, HOME_DIST),
    (0.0, -5.0, HOME_DIST), (-70.0, 35.0, HOME_DIST), (70.0, -5.0, HOME_DIST / 2.2),
]


def previews(samples):
    t0 = time.time()
    sc = preview_scene()
    cam = sc.camera
    # 1. The §7 preview pose at full size, to measure the tile row against the signed-off check.
    arr = render_to_array(sc, bj.RENDER_RES[0], bj.RENDER_RES[1], max(samples, 64))
    print("CHECK yaw 0 preview pose, tile row (360, 150): %s. Signed-off card check: #A49F80 (H 52, S 22%%, V 64%%)"
          % patch_hsv(arr, 360, 150))
    # 2. The sheet: six phone-shaped frames (390 x 844 aspect), 200 x 433.
    pw, ph = 200, 433
    sheet = np.zeros((ph * 2, pw * 3, 3))
    target = tuple(JAR_CENTER)
    for k, (yaw, pitch, dist) in enumerate(SHEET_POSES):
        place_camera(cam, yaw, pitch, dist, target)
        a = render_to_array(sc, pw, ph, samples)
        r, c = divmod(k, 3)
        sheet[r * ph:(r + 1) * ph, c * pw:(c + 1) * pw] = a
        print("SHEET panel %d: yaw %+.0f, pitch %+.0f, distance %.2f m, top-left patch (12, 60) %s"
              % (k + 1, yaw, pitch, dist, patch_hsv(a, 12, 60, 6)))
    sheet[:, pw - 1:pw + 1] = 1.0
    sheet[:, 2 * pw - 1:2 * pw + 1] = 1.0
    sheet[ph - 1:ph + 1, :] = 1.0
    bks._png(SHEET_OUT, np.clip(np.round(sheet * 255.0), 0, 255).astype(np.uint8), 2)
    print("WROTE %s %dx%d, %d bytes (%.1f s)" % (os.path.relpath(SHEET_OUT, REPO), sheet.shape[1], sheet.shape[0],
                                                 os.path.getsize(SHEET_OUT), time.time() - t0))


def main():
    t0 = time.time()
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    samples = int(argv[argv.index("--samples") + 1]) if "--samples" in argv else 256
    psamples = int(argv[argv.index("--preview-samples") + 1]) if "--preview-samples" in argv else 48
    print("WALL arc: center z %.2f m, radius %.2f m, ends +-%.1f deg at x +-%.3f m, length %.3f m. Counter half width %.2f m"
          % (WALL_CZ, WALL_R, math.degrees(END), HALF_W, ARC_LEN, bj.COUNTER_X / 2))
    assert abs((WALL_R - WALL_CZ) - bj.COUNTER_BACK_Y) < 1e-9, "the back of the arc must sit where the card was"
    assert bj.COUNTER_X / 2 > HALF_W + 0.05, "the counter must reach under the wall ends"
    misses = coverage_check(bj.COUNTER_X / 2)
    if "--coverage-only" in argv:
        sys.exit(1 if misses else 0)
    rgba = bake_atlas(samples)
    compare_with_card(rgba)
    export_glb()
    if "--no-preview" not in argv:
        previews(psamples)
    print("DONE in %.1fs" % (time.time() - t0))
    if misses:
        sys.exit(1)


if __name__ == "__main__":
    main()
