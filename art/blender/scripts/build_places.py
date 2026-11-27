"""Places (Phase 4, art-direction.md §19): the `window_sill` and `proofing_box` sets.

Headless, seeded, 1.5 to 6.5 minutes on an M4 (the first run of a session compiles Cycles kernels):
    /Applications/Blender.app/Contents/MacOS/Blender -b -P art/blender/scripts/build_places.py
Options (after a bare "--"):
    --samples N          Cycles bake samples (default 256)
    --preview-samples N  Cycles samples for the preview sheet (default 40)
    --no-preview         skip the preview sheet and the pose measurements
    --preview-only       skip the bakes and the GLB; re-render the sheet from the files on disk
    --check-only         only the ray checks (about 30 s, exit 1 on any blocked ray or wall miss)

The jar never moves (tech-architect, 2026-11-27): every place keeps the jar root at the origin and
swaps the set around it. So the camera rig, the +-70 degree orbit and every focus preset are the
same in every place, and the kitchen wall's coverage (§18.1) still holds.

  window_sill   The Kitchen_Wall mesh with a second baked atlas in the same UV layout: a curved bay
                of tall windows, linen cafe curtains on the lower panes, a painted apron under the
                counter edge. The counter is recolored as a painted sill (shader values in §19).
  proofing_box  A new mesh, Place_Proofing_Box: an open warm box standing on the counter around the
                jar, front door folded down, lid propped open behind. One surface, one baked texture.

Writes:
    assets/3d/places.glb                         node Place_Proofing_Box (one mesh, one surface,
                                                 placeholder material M_Proofing_Box)
    assets/textures/place_window_sill.png        1024 x 512 RGB, the kitchen_wall.png atlas layout:
                                                 day radiance, sRGB curve, no tonemap, pre-blurred
    assets/textures/place_window_sill_night.png  512 x 256 gray: the night lamp's light alone, as
                                                 kitchen_wall_night.png (same shader night path)
    assets/textures/place_proofing_box.png       512 x 512 RGB: the box's day radiance, same encoding
    art/previews/places_check.png                small sheet: each place at yaw -70, home, +70, night
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
import bake_kitchen_set as bks  # noqa: E402  (PNG writers, sRGB curve, blur)
import bake_kitchen_wall as bkw  # noqa: E402  (wall mesh, bake, lens blur, coverage poses)

REPO = bj.REPO
TEX = os.path.join(REPO, "assets", "textures")
WIN_PNG = os.path.join(TEX, "place_window_sill.png")
WIN_NIGHT_PNG = os.path.join(TEX, "place_window_sill_night.png")
BOX_PNG = os.path.join(TEX, "place_proofing_box.png")
GLB_OUT = os.path.join(REPO, "assets", "3d", "places.glb")
SHEET_OUT = os.path.join(REPO, "art", "previews", "places_check.png")
g2b = bkw.g2b

# =============================================================================
# window_sill: the bay (unrolled wall coordinates: s = meters along the arc from the back center,
# + toward +x; y = height above the counter top)
# =============================================================================
POST_PITCH = 0.42         # a pane sits right behind the jar; posts at s = +-0.21, +-0.63, +-1.05
POST_HALF = 0.026
JAMB_S = 1.075            # painted plaster past the last post (seen only near yaw +-70)
RAIL_TOP = 0.045          # bottom rail of the frames, just above the sill
TRANSOM = (0.420, 0.448)  # horizontal bar between the lower and upper panes
ROD = (0.168, 0.176)      # the cafe-curtain rod, one per pane: a short curtain, the garden above it
HEM = 0.052               # curtain hem, just above the rail
STRIPES = ((0.066, 0.075), (0.080, 0.084))   # the linen's sage stripes, near the hem
FOLD_M = 0.046            # gathered folds
WIN = {
    "frame": "#ECE7DD",    # warm white paint
    "jamb": "#E4DED2",
    "apron": "#E3DDD1",    # painted boards under the sill's front edge
    "rod": "#8E9F86",      # sage, as the linen stripe
    "daylight": "#F1F4F6", # overcast daylight behind the curtain: neutral, a touch cool
    "sky": "#DCE5EB",
    "foliage": "#9AA887",  # muted garden green, very soft
    "glass_night": "#14181B",
}
CURTAIN_T = 0.62          # how much daylight the sheer linen lets through
CURTAIN_GAIN = 1.7        # emission strength of the lit curtain: glows, under 0.5% of texels clip
SKY_GAIN = 1.15
SILL_LT, SILL_DK = "#D3CABB", "#C2B8A6"   # the counter, painted, as T2's oak_light / oak_dark

# =============================================================================
# proofing_box: the box (Godot meters; jar axis at x = z = 0, counter top y = 0)
# =============================================================================
BOX_HX = 0.300            # outer half width. Wide on purpose: the side walls stay clear of the
                          # jar up to yaw 70 (the ray check below)
BOX_T = 0.018             # wall thickness
BOX_BACK = -0.158         # outer back face; inner back face at -0.140, 98 mm behind the jar's glass
BOX_FRONT = 0.064         # front edge of the side walls, 22 mm in front of the jar's glass
BOX_H = 0.210             # wall top. The jar with its lid is 0.195 m; the lid lifts 8 mm to smell
PLATE_T = 0.0015          # the heat plate on the box floor. The jar root stays at y = 0, so the
                          # glass base sinks 1.5 mm into the plate, which never shows
DOOR_T = 0.008            # front door, folded down flat onto the counter
LID_T = 0.018
LID_OPEN_DEG = 100.0      # propped past vertical, leaning back 10 degrees
PAD = (0.150, -0.115, 0.050, 0.012)   # heat pad: half width, z0, z1, corner radius
BOX_COL = {"exterior": "#A6B59E", "interior": "#CDBEA4", "plate": "#D2C6B1", "pad": "#C4BEB3"}
BOX_PX = 512
BOX_NIGHT_MULT = (0.27, 0.255, 0.24)   # starting value for T2's night tint (§19)

# =============================================================================
# Light presets as Blender look-dev ratios (Godot values are in §19; these only mirror them
# closely enough to judge the look in Cycles)
# =============================================================================
PRESETS = {
    #               key color, key x, rim x, rim color, top x, world x, world top
    "counter":      ("#FFEAD6", 1.00, 1.00, "#FFEEDD", 1.0, 1.00, bj.C["world_top"]),
    "window_sill":  ("#FBF1E4", 1.00, 1.60, "#EEF3F8", 1.1, 1.10, "#EFEEEA"),
    "proofing_box": ("#FFE3CA", 0.90, 0.40, "#FFEEDD", 0.8, 0.80, "#F5E6D2"),
}
NIGHT = {"key": 0.55, "key_color": "#FFDCC0", "rim": 0.35, "world": 0.60, "lamp_w": 0.55,
         "lamp_color": "#FFE6CC", "lamp": (-0.10, 0.44, -0.26)}
HOME_YAW, HOME_PITCH = -12.0, 15.0


def lin(hexc):
    return np.array(bj.hexcol(hexc)[:3])


# =============================================================================
# Ray checks (numpy): nothing between the camera and the jar, and the camera never inside the box
# =============================================================================
def box_parts():
    """Every solid of the proofing box as (name, center, half extents, rotation about x in radians,
    pivot). The lid rotates about its hinge; the rest are axis-aligned."""
    x0, x1 = BOX_HX - BOX_T, BOX_HX
    zmid = (BOX_BACK + BOX_FRONT) / 2
    parts = [
        ("wall_left", (-(x0 + x1) / 2, BOX_H / 2, zmid), (BOX_T / 2, BOX_H / 2, (BOX_FRONT - BOX_BACK) / 2)),
        ("wall_right", ((x0 + x1) / 2, BOX_H / 2, zmid), (BOX_T / 2, BOX_H / 2, (BOX_FRONT - BOX_BACK) / 2)),
        ("wall_back", (0.0, BOX_H / 2, BOX_BACK + BOX_T / 2), (x0, BOX_H / 2, BOX_T / 2)),
        ("plate", (0.0, PLATE_T / 2, (BOX_BACK + BOX_T + BOX_FRONT) / 2),
         (x0, PLATE_T / 2, (BOX_FRONT - BOX_BACK - BOX_T) / 2)),
        ("door", (0.0, DOOR_T / 2, BOX_FRONT + BOX_H / 2), (BOX_HX, DOOR_T / 2, BOX_H / 2)),
    ]
    out = [(n, np.array(c), np.array(h), 0.0, None) for n, c, h in parts]
    # Lid: closed it would sit on the walls; open it turns LID_OPEN_DEG about the back top edge.
    depth = BOX_FRONT - BOX_BACK
    c_closed = np.array([0.0, BOX_H + LID_T / 2, BOX_BACK + depth / 2])
    out.append(("lid", c_closed, np.array([BOX_HX, LID_T / 2, depth / 2]), math.radians(LID_OPEN_DEG),
                np.array([0.0, BOX_H, BOX_BACK])))
    return out


def rot_x(v, ang, pivot):
    """Rotate points about the x axis through pivot. Positive turns +z toward +y (the lid opening)."""
    c, s = math.cos(ang), math.sin(ang)
    p = v - pivot
    y = p[..., 1] * c + p[..., 2] * s
    z = -p[..., 1] * s + p[..., 2] * c
    out = p.copy()
    out[..., 1], out[..., 2] = y, z
    return out + pivot


def segment_hits_box(o, d, center, half, ang, pivot):
    """Rays o + t d, t in (0, 1): True where they cross the (possibly rotated) box."""
    if ang:
        # Into the lid's closed frame: rotate by -ang about the same pivot.
        o = rot_x(o, -ang, pivot)
        d = rot_x(d + pivot, -ang, pivot) - pivot
    lo, hi = center - half, center + half
    with np.errstate(divide="ignore", invalid="ignore"):
        t1 = (lo - o) / d
        t2 = (hi - o) / d
    tmin = np.nanmax(np.where(np.isnan(np.minimum(t1, t2)), -np.inf, np.minimum(t1, t2)), axis=-1)
    tmax = np.nanmin(np.where(np.isnan(np.maximum(t1, t2)), np.inf, np.maximum(t1, t2)), axis=-1)
    inside_slab = np.all((d != 0) | ((o >= lo) & (o <= hi)), axis=-1)
    return inside_slab & (tmax >= tmin) & (tmax > 1e-6) & (tmin < 1.0 - 1e-6)


def point_in_box(p, center, half, ang, pivot):
    if ang:
        p = rot_x(p, -ang, pivot)
    return bool(np.all(np.abs(p - center) <= half))


def jar_samples(cam):
    """Points on the jar the player must see. 'tell': the glass from the starter floor to the
    highest possible paste (rise 3.0 at the 0.042 m level: 0.134 m), on the half facing the camera.
    'lid': the glass above that and the lid. Plus the paste top seen through the mouth."""
    az = math.atan2(cam[0], cam[2])
    phis = az + np.radians(np.linspace(-70, 70, 9))
    tell, lid = [], []
    for y in np.linspace(0.012, 0.134, 9):
        tell += [(0.0425 * math.sin(p), y, 0.0425 * math.cos(p)) for p in phis]
    for y in np.linspace(0.145, 0.195, 4):
        lid += [(0.0425 * math.sin(p), y, 0.0425 * math.cos(p)) for p in phis]
    for r in (0.0, 0.015, 0.03):
        for p in phis[::2]:
            for y in (0.040, 0.077, 0.134):
                tell.append((r * math.sin(p), y, r * math.cos(p)))
    return np.array(tell), np.array(lid)


def check_poses():
    """The wall's coverage poses (yaw -78..78, pitch -10..40, zoom 2.2x to a zoomed-out small phone)
    by camera position only, plus every focus preset at the lowest and highest starter."""
    out = []
    seen = set()
    for (yaw, pitch, d, _fs, _cov, tgt, kind) in bkw.coverage_poses():
        key = (yaw, pitch, d, kind, tuple(np.round(tgt, 4)))
        if key in seen:
            continue
        seen.add(key)
        out.append((yaw, pitch, d, np.array(tgt, float), kind))
    for top in (0.036, 0.085, 0.134):                   # starter_top_y: unhealthy, at_peak, max rise
        out.append((-20.0, 38.0, 0.17, np.array([0.0, top + 0.006, 0.0]), "mold"))
        out.append((0.0, 76.0, math.hypot(0.194, 0.0524), np.array([0.0, top, -0.004]), "surface"))
        y = max(0.008 + 0.55 * 0.030, top - 0.028)
        out.append((-28.0, 4.4, 0.36, np.array([0.0, y, 0.0]), "bubbles_rule"))
        out.append((0.0, 4.0, 0.30, np.array([0.0, (0.038 + top) / 2, 0.0]), "height_rule"))
    return out


def occlusion_check():
    t0 = time.time()
    parts = box_parts()
    blocked_in, blocked_band, lid_blocked, cam_inside, rays, skipped = {}, {}, 0, [], 0, 0
    worst = (0.0, None)
    where = {}
    for (yaw, pitch, d, tgt, kind) in check_poses():
        yr, pr = math.radians(yaw), math.radians(pitch)
        back = np.array([math.cos(pr) * math.sin(yr), math.sin(pr), math.cos(pr) * math.cos(yr)])
        cam = tgt + back * d
        if cam[1] < 0.02:            # D-049: the camera never goes under 20 mm above the counter
            skipped += 1
            continue
        for (name, c, h, ang, piv) in parts:
            if point_in_box(cam, c, h, ang, piv):
                cam_inside.append((kind, yaw, pitch, d, name))
        tell, lid = jar_samples(cam)
        in_limits = kind != "orbit" or (abs(yaw) <= 70 and -5 <= pitch <= 35)
        for pts, is_lid in ((tell, False), (lid, True)):
            dvec = pts - cam
            hit = np.zeros(len(pts), bool)
            for (name, c, h, ang, piv) in parts:
                hit |= segment_hits_box(np.broadcast_to(cam, pts.shape), dvec, c, h, ang, piv)
            rays += len(pts)
            n = int(hit.sum())
            if not n:
                continue
            if is_lid:
                lid_blocked += n if in_limits else 0
                continue
            bucket = blocked_in if in_limits else blocked_band
            bucket[kind] = bucket.get(kind, 0) + n
            if in_limits:
                hit_parts = sorted({name for (name, c, h, ang, piv) in parts
                                    if segment_hits_box(np.broadcast_to(cam, pts.shape), dvec, c, h, ang, piv).any()})
                key = (round(yaw), round(pitch, 1), round(d, 2), ",".join(hit_parts))
                where[key] = where.get(key, 0) + n
            if in_limits and n / len(pts) > worst[0]:
                worst = (n / len(pts), (kind, yaw, pitch, d))
    print("OCCLUSION %d rays from %d poses (%.1f s); %d poses skipped (camera under the 20 mm clearance, D-049)"
          % (rays, len(check_poses()), time.time() - t0, skipped))
    print("OCCLUSION starter and glass (y 0.012..0.134) blocked by the box within the limits "
          "(yaw +-70, pitch -5..35, zoom 1..2.2x, every preset): %d %s" % (sum(blocked_in.values()), blocked_in))
    print("OCCLUSION lid and upper glass (y 0.145..0.195) blocked within the limits: %d" % lid_blocked)
    print("OCCLUSION blocked only in the rubber bands past the limits: %d %s" % (sum(blocked_band.values()), blocked_band))
    print("OCCLUSION camera inside a box part: %d %s" % (len(cam_inside), cam_inside[:4]))
    if where:
        top = sorted(where.items(), key=lambda kv: -kv[1])[:12]
        print("OCCLUSION worst poses within the limits (yaw, pitch, distance, parts): %s" % top)
        print("OCCLUSION worst share of one pose's rays: %.3f at %s" % worst)
    return sum(blocked_in.values()) + len(cam_inside)


# =============================================================================
# Materials
# =============================================================================
def unrolled(t):
    uvn = t.n("ShaderNodeUVMap")
    uvn.uv_map = "Unrolled"
    s, y, _ = t.sep(uvn.outputs["UV"])
    return s, y


def band(t, v, a, b, soft=0.002):
    """1 inside [a, b], soft edges."""
    return t.math("MULTIPLY", t.maprange(v, a - soft, a + soft), t.maprange(v, b + soft, b - soft))


def mat_window_wall(night):
    """The bay on the curved wall. Day: the panes are light sources (curtain or sky). Night: the
    panes are dark glass and only the frames and the linen catch the lamp."""
    m, t = bj.new_mat("M_Window_bake")
    s, y = unrolled(t)
    abs_s = t.math("ABSOLUTE", s)
    w = t.n("ShaderNodeMath", operation="WRAP")
    t.put(w.inputs[0], s)
    w.inputs[1].default_value = POST_PITCH
    w.inputs[2].default_value = 0.0
    post = t.maprange(t.math("ABSOLUTE", t.math("SUBTRACT", w.outputs[0], POST_PITCH / 2)),
                      POST_HALF + 0.002, POST_HALF - 0.002)
    jamb = t.maprange(abs_s, JAMB_S - 0.002, JAMB_S + 0.002)
    rail = t.maprange(y, RAIL_TOP + 0.002, RAIL_TOP - 0.002)
    transom = band(t, y, *TRANSOM)
    frame = t.math("MAXIMUM", t.math("MAXIMUM", post, jamb), t.math("MAXIMUM", rail, transom))
    open_pane = t.math("SUBTRACT", 1.0, frame, clamp=True)
    rod = t.math("MULTIPLY", band(t, y, *ROD), open_pane)
    curtain = t.math("MULTIPLY", band(t, y, HEM, ROD[0]), open_pane)

    # Gathered folds: a warped sine across each pane, brighter toward the rod.
    warp = t.n("ShaderNodeTexNoise")
    t.put(warp.inputs["Vector"], t.combine(t.math("MULTIPLY", s, 6.0), t.math("MULTIPLY", y, 2.0), 0.0))
    warp.inputs["Scale"].default_value = 1.0
    warp.inputs["Detail"].default_value = 2.0
    phase = t.math("ADD", t.math("MULTIPLY", s, 2 * math.pi / FOLD_M), t.math("MULTIPLY", warp.outputs["Fac"], 5.0))
    fold = t.math("ADD", 0.80, t.math("MULTIPLY", t.math("ADD", 0.5, t.math("MULTIPLY", t.math("SINE", phase), 0.5)), 0.24))
    lift = t.maprange(y, HEM, ROD[0], 0.90, 1.06, smooth_step=False)
    stripe = t.math("MAXIMUM", band(t, y, *STRIPES[0], 0.0015), band(t, y, *STRIPES[1], 0.0015))
    linen = bj.hexcol(bj.C["linen"])
    stripe_col = bj.hexcol(bj.C["linen_stripe"])

    if not night:
        day = lin(WIN["daylight"])
        lit_linen = tuple(day * np.array(linen[:3]) * CURTAIN_T) + (1.0,)
        lit_stripe = tuple(day * np.array(stripe_col[:3]) * CURTAIN_T * 0.55) + (1.0,)
        ccol = t.mix_col(stripe, lit_linen, lit_stripe)
        cstr = t.math("MULTIPLY", t.math("MULTIPLY", fold, lift), CURTAIN_GAIN)
        # Upper panes and the gap under the hem: soft foliage low, pale sky high.
        fol = t.n("ShaderNodeTexNoise")
        t.put(fol.inputs["Vector"], t.combine(s, y, 0.0))
        fol.inputs["Scale"].default_value = 9.0
        fol.inputs["Detail"].default_value = 3.0
        green = t.math("MULTIPLY", t.maprange(y, 0.40, 0.22), t.maprange(fol.outputs["Fac"], 0.40, 0.60))
        green = t.math("MAXIMUM", green, t.maprange(y, HEM + 0.004, RAIL_TOP))
        scol = t.mix_col(green, bj.hexcol(WIN["sky"]), bj.hexcol(WIN["foliage"]))
        sky = t.math("MULTIPLY", t.math("SUBTRACT", t.math("SUBTRACT", open_pane, curtain, clamp=True), rod, clamp=True), 1.0)
        em_col = t.mix_col(curtain, scol, ccol)
        em_str = t.math("ADD", t.math("MULTIPLY", curtain, cstr), t.math("MULTIPLY", sky, SKY_GAIN))
        em = t.n("ShaderNodeEmission")
        t.put(em.inputs["Color"], em_col)
        t.put(em.inputs["Strength"], em_str)
        paint = t.mix_col(jamb, bj.hexcol(WIN["frame"]), bj.hexcol(WIN["jamb"]))
        paint = t.mix_col(rod, paint, bj.hexcol(WIN["rod"]))
        p = t.principled(Base_Color=paint, Roughness=0.5)
        mix = t.n("ShaderNodeMixShader")
        t.put(mix.inputs["Fac"], t.math("ADD", curtain, sky))
        t.put(mix.inputs[1], p.outputs[0])
        t.put(mix.inputs[2], em.outputs[0])
        t.out(mix.outputs[0])
    else:
        # Night: the lamp lights paint and linen; the glass between is dark.
        ccol = t.mix_col(stripe, linen, stripe_col)
        ccol = t.mix_col(t.math("SUBTRACT", 1.0, fold), ccol, tuple(c * 0.8 for c in linen[:3]) + (1.0,))
        col = t.mix_col(curtain, bj.hexcol(WIN["glass_night"]), ccol)
        paint = t.mix_col(jamb, bj.hexcol(WIN["frame"]), bj.hexcol(WIN["jamb"]))
        paint = t.mix_col(rod, paint, bj.hexcol(WIN["rod"]))
        col = t.mix_col(t.math("MAXIMUM", frame, rod), col, paint)
        p = t.principled(Base_Color=col, Roughness=0.55)
        t.out(p.outputs[0])
    return m


def mat_apron():
    """Painted boards under the sill's front edge (the atlas's cabinet rows)."""
    m, t = bj.new_mat("M_Apron_bake")
    s, y = unrolled(t)
    w = t.n("ShaderNodeMath", operation="WRAP")
    t.put(w.inputs[0], s)
    w.inputs[1].default_value = 0.09
    w.inputs[2].default_value = 0.0
    groove = t.maprange(t.math("ABSOLUTE", t.math("SUBTRACT", w.outputs[0], 0.045)), 0.0025, 0.0012)
    paint = bj.hexcol(WIN["apron"])
    col = t.mix_col(t.math("MULTIPLY", groove, 0.7), paint, tuple(c * 0.35 for c in paint[:3]) + (1.0,))
    t.out(t.principled(Base_Color=col, Roughness=0.5).outputs[0])
    return m


def mat_sill(name="M_Counter_Wood"):
    """The counter as a painted sill: T2's counter shader with paint colors in the oak slots."""
    m, t = bj.new_mat(name)
    tc = t.n("ShaderNodeTexCoord")
    d = bks.detail_node(t, "counter_oak_detail.png", tc.outputs["Object"], bks.COUNTER_TILE_M)
    col = t.mix_col(d, bj.hexcol(SILL_DK), bj.hexcol(SILL_LT))
    p = t.principled(Base_Color=col, Coat_Weight=0.1)
    t.put(p.inputs["Roughness"], t.maprange(d, 0.0, 1.0, 0.56, 0.46, smooth_step=False))
    t.out(p.outputs[0])
    return m


def mat_oak_counter(name="M_Counter_Wood", box_shadow=False):
    """The signed-off oak counter as Godot draws it (§17). With box_shadow, the analytic contact
    shadow T2 adds around the proofing box's foot (§19.4)."""
    m, t = bj.new_mat(name)
    tc = t.n("ShaderNodeTexCoord")
    obj = tc.outputs["Object"]
    d = bks.detail_node(t, "counter_oak_detail.png", obj, bks.COUNTER_TILE_M)
    col = t.mix_col(d, bj.hexcol(bj.C["counter_dk"]), bj.hexcol(bj.C["counter_lt"]))
    if box_shadow:
        col = t.mix_col(t.math("SUBTRACT", 1.0, box_contact(t, obj)), col, (0.0, 0.0, 0.0, 1.0))
    p = t.principled(Base_Color=col)
    t.put(p.inputs["Roughness"], t.maprange(d, 0.0, 1.0, 0.62, 0.42, smooth_step=False))
    t.out(p.outputs[0])
    return m


def box_contact(t, obj):
    """Shade factor (1 = none) from a rounded-rectangle distance around the box's footprint.
    Mirrors the GLSL in §19.4. Blender object coords: x, y = -Godot z."""
    ox, oy, _ = t.sep(obj)
    cz = -(BOX_BACK + BOX_FRONT + BOX_H) / 2.0          # footprint incl. the folded door, Blender y
    hz = (BOX_FRONT + BOX_H - BOX_BACK) / 2.0
    qx = t.math("MAXIMUM", t.math("SUBTRACT", t.math("ABSOLUTE", ox), BOX_HX), 0.0)
    qy = t.math("MAXIMUM", t.math("SUBTRACT", t.math("ABSOLUTE", t.math("SUBTRACT", oy, cz)), hz), 0.0)
    dist = t.math("SQRT", t.math("ADD", t.math("MULTIPLY", qx, qx), t.math("MULTIPLY", qy, qy)))
    return t.math("ADD", 0.55, t.math("MULTIPLY", t.maprange(dist, 0.0, 0.035), 0.45))


def mat_box(kind):
    m, t = bj.new_mat("M_Box_%s_bake" % kind)
    if kind != "plate":
        t.out(t.principled(Base_Color=bj.hexcol(BOX_COL[kind]), Roughness=0.42 if kind == "exterior" else 0.5).outputs[0])
        return m
    # The floor: cream, with a warm-gray heat pad under the jar (rounded rectangle).
    tc = t.n("ShaderNodeTexCoord")
    ox, oy, _ = t.sep(tc.outputs["Object"])
    hx, z0, z1, r = PAD
    cy = -(z0 + z1) / 2.0
    hy = (z1 - z0) / 2.0
    qx = t.math("MAXIMUM", t.math("SUBTRACT", t.math("ABSOLUTE", ox), hx - r), 0.0)
    qy = t.math("MAXIMUM", t.math("SUBTRACT", t.math("ABSOLUTE", t.math("SUBTRACT", oy, cy)), hy - r), 0.0)
    dist = t.math("SUBTRACT", t.math("SQRT", t.math("ADD", t.math("MULTIPLY", qx, qx), t.math("MULTIPLY", qy, qy))), r)
    pad = t.maprange(dist, 0.0015, -0.0005)
    edge = t.maprange(t.math("ABSOLUTE", dist), 0.0012, 0.0)
    col = t.mix_col(pad, bj.hexcol(BOX_COL["plate"]), bj.hexcol(BOX_COL["pad"]))
    col = t.mix_col(t.math("MULTIPLY", edge, 0.5), col, (0.35, 0.33, 0.30, 1.0))
    p = t.principled(Base_Color=col)
    t.put(p.inputs["Roughness"], bj.lerp(t, pad, 0.5, 0.32))
    t.out(p.outputs[0])
    return m


# =============================================================================
# Proofing box mesh
# =============================================================================
def add_cuboid(bm, lo, hi, mat_of, bevel=0.003, ang=0.0, pivot=None):
    """Axis-aligned cuboid in Godot coordinates, beveled, optionally turned about x at pivot.
    mat_of(normal_godot) -> material index, decided after the bevel."""
    tmp = bmesh.new()
    vs = {}
    for ix in (0, 1):
        for iy in (0, 1):
            for iz in (0, 1):
                p = np.array([(lo, hi)[ix][0], (lo, hi)[iy][1], (lo, hi)[iz][2]], float)
                vs[(ix, iy, iz)] = tmp.verts.new(g2b(*p))
    quads = [((0, 0, 0), (0, 1, 0), (0, 1, 1), (0, 0, 1)), ((1, 0, 0), (1, 0, 1), (1, 1, 1), (1, 1, 0)),
             ((0, 0, 0), (0, 0, 1), (1, 0, 1), (1, 0, 0)), ((0, 1, 0), (1, 1, 0), (1, 1, 1), (0, 1, 1)),
             ((0, 0, 0), (1, 0, 0), (1, 1, 0), (0, 1, 0)), ((0, 0, 1), (0, 1, 1), (1, 1, 1), (1, 0, 1))]
    for q in quads:
        tmp.faces.new([vs[k] for k in q])
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    if bevel > 0:
        bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=bevel, segments=2, profile=0.5,
                        affect="EDGES", clamp_overlap=True)
    if ang:
        # Godot: +ang about x turns +z toward +y (the lid's front edge goes up). Blender axes are
        # (x, -z, y): Godot +z is Blender -y and Godot +y is Blender +z, so the same turn is -ang.
        piv_b = g2b(*pivot)
        bmesh.ops.rotate(tmp, verts=list(tmp.verts), cent=piv_b,
                         matrix=__import__("mathutils").Matrix.Rotation(-ang, 3, "X"))
    tmp.normal_update()
    for f in tmp.faces:
        n_b = f.normal
        f.material_index = mat_of(np.array([n_b.x, n_b.z, -n_b.y]))
    me = bpy.data.meshes.new("tmp")
    tmp.to_mesh(me)
    tmp.free()
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)


EXT, INT, PLATE = 0, 1, 2


def build_box(coll, mats):
    bm = bmesh.new()
    x0 = BOX_HX - BOX_T
    # Side walls: the face toward the jar, the top rim and the front edge are interior cream.
    add_cuboid(bm, (-BOX_HX, 0.0, BOX_BACK), (-x0, BOX_H, BOX_FRONT),
               lambda n: INT if (n[0] > 0.5 or n[1] > 0.5 or n[2] > 0.5) else EXT)
    add_cuboid(bm, (x0, 0.0, BOX_BACK), (BOX_HX, BOX_H, BOX_FRONT),
               lambda n: INT if (n[0] < -0.5 or n[1] > 0.5 or n[2] > 0.5) else EXT)
    add_cuboid(bm, (-x0, 0.0, BOX_BACK), (x0, BOX_H, BOX_BACK + BOX_T),
               lambda n: INT if (n[2] > 0.5 or n[1] > 0.5) else EXT, bevel=0.002)
    add_cuboid(bm, (-x0, 0.0, BOX_BACK + BOX_T), (x0, PLATE_T, BOX_FRONT), lambda n: PLATE, bevel=0.0)
    add_cuboid(bm, (-BOX_HX, 0.0, BOX_FRONT), (BOX_HX, DOOR_T, BOX_FRONT + BOX_H),
               lambda n: EXT if n[1] < -0.5 else INT)
    lid_normal_in = np.array([0.0, -1.0, 0.0])          # closed: faces down into the box

    def lid_mat(n):
        # The normal passed in is after the turn; turn the closed inner normal the same way.
        a = math.radians(LID_OPEN_DEG)
        inner = np.array([0.0, lid_normal_in[1] * math.cos(a), -lid_normal_in[1] * math.sin(a)])
        return EXT if float(np.dot(n, inner)) < -0.5 else INT
    add_cuboid(bm, (-BOX_HX, BOX_H, BOX_BACK), (BOX_HX, BOX_H + LID_T, BOX_FRONT), lid_mat,
               ang=math.radians(LID_OPEN_DEG), pivot=(0.0, BOX_H, BOX_BACK))
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-7)
    # No camera pose sees a face turned down onto the counter or back toward the wall (the camera
    # is always in front of z = -0.158 and above the counter): drop them, more texels for the rest.
    bm.normal_update()
    unseen = [f for f in bm.faces if f.normal.z < -0.9 or f.normal.y > 0.9]   # Blender: -y is Godot +z
    bmesh.ops.delete(bm, geom=unseen, context="FACES")
    ob = bj.make_object("Place_Proofing_Box", bm, coll, sharp_angle=30, mats=mats)
    return ob


def unwrap(ob):
    for o in bpy.context.scene.objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60.0), island_margin=0.012, area_weight=0.0,
                             scale_to_bounds=True)
    bpy.ops.object.mode_set(mode="OBJECT")


# =============================================================================
# Scenes
# =============================================================================
def preset_lights(coll, place, night=False):
    """The look-dev lights (bj.setup_lights_camera), re-tinted for the place, and for the night."""
    bj.setup_lights_camera(coll)
    # At night every place shares the signed-off night look (§18.6): the place multipliers fade
    # out by the night factor, so only the set (its textures) tells the places apart (§19.3).
    key_col, kx, rx, rim_col, tx, wx, wtop = PRESETS["counter" if night else place]
    sc = bpy.context.scene
    lights = {o.name: o for o in sc.objects if o.type == "LIGHT"}
    lights["Key"].data.color = lin(NIGHT["key_color"] if night else key_col)
    lights["Key"].data.energy = bj.KEY_W * kx * (NIGHT["key"] if night else 1.0)
    lights["Rim"].data.color = lin(rim_col)
    lights["Rim"].data.energy = bj.KEY_W * 0.85 * rx * (NIGHT["rim"] if night else 1.0)
    lights["Top"].data.energy = bj.KEY_W * 0.15 * tx * (NIGHT["key"] if night else 1.0)
    lights["Fill"].data.energy = bj.KEY_W * 0.16 * (NIGHT["key"] if night else 1.0)
    w = sc.world.node_tree.nodes
    w["Background"].inputs["Strength"].default_value = bj.WORLD_STRENGTH * wx * (NIGHT["world"] if night else 1.0)
    for nd in w:
        if nd.bl_idname == "ShaderNodeMix":
            [s for s in nd.inputs if s.type == "RGBA"][1].default_value = bj.hexcol(wtop)
    if night:
        lt = bpy.data.lights.new("NightLamp", "POINT")
        lt.energy = NIGHT["lamp_w"]
        lt.color = lin(NIGHT["lamp_color"])
        lt.shadow_soft_size = 0.04
        lamp = bpy.data.objects.new("NightLamp", lt)
        lamp.location = g2b(*NIGHT["lamp"])
        coll.objects.link(lamp)


def new_scene(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    coll = bpy.data.collections.new(name)
    sc.collection.children.link(coll)
    bj.setup_world()
    return sc, coll


def bake_window(samples):
    ww = int(round(bkw.ARC_LEN * bkw.BAKE_PX_PER_M))
    wh = int(round((bkw.WALL_TOP - bkw.WALL_BOT) * bkw.BAKE_PX_PER_M))
    cw = int(round(2 * bkw.HALF_W * bkw.BAKE_PX_PER_M))
    ch = int(round((bkw.CAB_TOP - bkw.CAB_BOT) * bkw.BAKE_PX_PER_M))
    out = {}
    for night in (False, True):
        t0 = time.time()
        sc, coll = new_scene("BakeWindow")
        wall = bkw.build_wall_mesh("Bake_Wall", coll, (mat_window_wall(night),), "bake_wall")
        cab = bkw.build_wall_mesh("Bake_Cabinet", coll, (mat_apron(),), "bake_cab")
        bj.build_counter(coll, (mat_sill(),))
        if night:
            sc.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.0
            lt = bpy.data.lights.new("NightLamp", "AREA")
            lt.shape = "RECTANGLE"
            lt.size, lt.size_y = bkw.NIGHT_LAMP_SIZE
            lt.energy = 2.0
            lt.color = bj.hexcol(bkw.NIGHT_COLOR)[:3]
            lamp = bpy.data.objects.new("NightLamp", lt)
            lamp.location = g2b(*bkw.NIGHT_LAMP)
            coll.objects.link(lamp)
            cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
            coll.objects.link(cam)
            sc.camera = cam
        else:
            preset_lights(coll, "window_sill")
        bj.setup_render(64, 100)
        wl = bkw.bake(wall, ww, wh, samples)
        for ob in sc.objects:
            if ob.type == "LIGHT":
                ob.hide_render = True
        cl = bkw.bake(cab, cw, ch, samples)
        wl, s0, s1 = bkw.blur_wall(wl, ww)
        cl = bks.gaussian_blur(cl, bkw.CAB_SIGMA_M * bkw.BAKE_PX_PER_M)
        out[night] = (bkw.resample(wl, bkw.WALL_ROWS, bkw.ATLAS_W), bkw.resample(cl, bkw.CAB_ROWS, bkw.ATLAS_W))
        print("BAKED window %s wall %dx%d, apron %dx%d, %d samples, blur %.1f..%.1f mm (%.1f s)"
              % ("night" if night else "day", ww, wh, cw, ch, samples, s0 * 1000, s1 * 1000, time.time() - t0))
    rgb = np.zeros((bkw.ATLAS_H, bkw.ATLAS_W, 3))
    lum = np.zeros((bkw.ATLAS_H, bkw.ATLAS_W))
    W, C0 = bkw.WALL_ROWS, bkw.CAB_ROW0
    luma = lambda a: a @ np.array([0.2126, 0.7152, 0.0722])
    w, c = out[False]
    rgb[:W], rgb[C0:] = w, c
    rgb[W:W + 2], rgb[W + 2:C0] = rgb[W - 1], rgb[C0]
    w, c = out[True]
    ref = float(luma(w).max())
    lum[:W], lum[C0:] = luma(w) / ref, luma(c) / ref
    lum[W:W + 2], lum[W + 2:C0] = lum[W - 1], lum[C0]
    clipped = float(np.mean(rgb.max(axis=2) > 1.0))
    bks.write_rgb(WIN_PNG, bks.srgb_encode(rgb))
    night = np.sqrt(np.clip(lum, 0, 1)).reshape(bkw.ATLAS_H // 2, 2, bkw.ATLAS_W // 2, 2).mean(axis=(1, 3))
    bks.write_gray(WIN_NIGHT_PNG, night)
    print("WROTE %s %d bytes: day linear max %.3f, clipped %.3f%%; %s %d bytes"
          % (os.path.relpath(WIN_PNG, REPO), os.path.getsize(WIN_PNG), rgb.max(), 100 * clipped,
             os.path.relpath(WIN_NIGHT_PNG, REPO), os.path.getsize(WIN_NIGHT_PNG)))


def jar_objects(coll, state="at_peak"):
    m_starter, sv = bj.mat_starter()
    m_liner, lv = bj.mat_liner()
    objs = {
        "Jar_Glass": bj.build_glass(coll, (bj.mat_glass("M_Glass"), bj.mat_glass("M_Glass_Inner"))),
        "Starter_Body": bj.build_starter(coll, (m_starter,)),
        "Starter_Liner": bj.build_liner(coll, (m_liner,)),
        "Jar_Lid_Loose": bj.build_lid_loose(coll, (mat_lid(),)),
        "Rubber_Band": bj.build_band(coll, (bj.mat_simple("M_Rubber_Band", bj.C["band"], 0.55, subsurf=0.1),)),
    }
    bj.add_starter_shape_modifier(objs["Starter_Body"], bj.mat_mold_fuzz())
    bj.apply_state(state, objs, sv, lv)
    return objs


def mat_lid():
    m, t = bj.new_mat("M_Lid_Wood")
    tc = t.n("ShaderNodeTexCoord")
    d = bks.detail_node(t, "lid_oak_detail.png", tc.outputs["Object"], bks.LID_TILE_M, box=True)
    col = t.mix_col(d, bj.hexcol(bj.C["lid_wood_dk"]), bj.hexcol(bj.C["lid_wood_lt"]))
    p = t.principled(Base_Color=col, Coat_Weight=0.15)
    t.put(p.inputs["Roughness"], t.maprange(d, 0.0, 1.0, 0.6, 0.4, smooth_step=False))
    t.out(p.outputs[0])
    return m


def bake_box(samples):
    t0 = time.time()
    sc, coll = new_scene("BakeBox")
    box = build_box(coll, (mat_box("exterior"), mat_box("interior"), mat_box("plate")))
    unwrap(box)
    jar = jar_objects(coll, "active")                 # the glass and lid shade the pad softly
    jar["Starter_Body"].visible_shadow = False        # an opaque starter baked a hard dark disk
    bj.build_counter(coll, (mat_oak_counter(),))
    bkw.build_wall_mesh("Bake_Wall", coll, (bkw.mat_wall_tiles(),), "bake_wall")
    preset_lights(coll, "proofing_box")
    bj.setup_render(64, 100)
    px = bkw.bake(box, BOX_PX, BOX_PX, samples)
    # Fill the gutters between UV islands with their neighbours so mipmaps never pull in black.
    filled = dilate(px, box)
    bks.write_rgb(BOX_PNG, bks.srgb_encode(filled))
    tris = sum(len(p.vertices) - 2 for p in box.data.polygons)
    print("BAKED %s %dx%d, %d samples, linear max %.3f, %d bytes (%.1f s). Box %d tris"
          % (os.path.relpath(BOX_PNG, REPO), BOX_PX, BOX_PX, samples, filled.max(), os.path.getsize(BOX_PNG),
             time.time() - t0, tris))
    return box


def dilate(px, ob, steps=8):
    """Grow baked texels into empty texels (top row first). Covered = any non-zero baked value."""
    img = px.copy()
    mask = img.max(axis=2) > 1e-6
    for _ in range(steps):
        if mask.all():
            break
        acc = np.zeros_like(img)
        cnt = np.zeros(mask.shape)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                m2 = np.roll(np.roll(mask, dy, 0), dx, 1)
                acc += np.roll(np.roll(img, dy, 0), dx, 1) * m2[..., None]
                cnt += m2
        grow = (~mask) & (cnt > 0)
        img[grow] = acc[grow] / cnt[grow][:, None]
        mask = mask | grow
    return img


def export_glb(box):
    box.data.materials.clear()
    m, t = bj.new_mat("M_Proofing_Box")
    t.out(t.principled(Base_Color=bj.hexcol(BOX_COL["interior"]), Roughness=0.5).outputs[0])
    box.data.materials.append(m)
    for p in box.data.polygons:
        p.material_index = 0
    box["texture"] = os.path.basename(BOX_PNG)
    box["inner_half_width_m"] = round(BOX_HX - BOX_T, 4)
    box["inner_back_z_m"] = round(BOX_BACK + BOX_T, 4)
    box["front_z_m"] = BOX_FRONT
    box["wall_top_m"] = BOX_H
    box["floor_top_m"] = PLATE_T
    box["footprint_m"] = [-BOX_HX, BOX_BACK, BOX_HX, round(BOX_FRONT + BOX_H, 4)]   # x0, z0, x1, z1 incl. door
    box["night_mult"] = list(BOX_NIGHT_MULT)
    for o in bpy.context.scene.objects:
        o.select_set(False)
    box.select_set(True)
    bpy.context.view_layer.objects.active = box
    bpy.ops.export_scene.gltf(
        filepath=GLB_OUT, export_format="GLB", use_selection=True, export_apply=False, export_yup=True,
        export_extras=True, export_cameras=False, export_lights=False, export_animations=False,
        export_texcoords=True, export_normals=True, export_tangents=False, export_materials="EXPORT")
    tris = sum(len(p.vertices) - 2 for p in box.data.polygons)
    print("EXPORTED %s %d bytes, Place_Proofing_Box %d verts, %d tris"
          % (os.path.relpath(GLB_OUT, REPO), os.path.getsize(GLB_OUT), len(box.data.vertices), tris))


# =============================================================================
# Previews: each place as Godot draws it (unshaded baked set, no depth of field)
# =============================================================================
def emission_mat(name, image, extension="EXTEND"):
    m, t = bj.new_mat(name)
    uvn = t.n("ShaderNodeUVMap")
    uvn.uv_map = "UVMap"
    tex = t.n("ShaderNodeTexImage")
    tex.image = image
    tex.extension = extension
    t.put(tex.inputs["Vector"], uvn.outputs["UV"])
    em = t.n("ShaderNodeEmission")
    t.put(em.inputs["Color"], tex.outputs["Color"])
    t.out(em.outputs[0])
    return m


def float_image(name, rgb_lin):
    """A linear float image from a top-row-first array."""
    h, w = rgb_lin.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=True, float_buffer=True)
    img.colorspace_settings.name = "Linear Rec.709"
    px = np.ones((h, w, 4), np.float32)
    px[..., :3] = rgb_lin[::-1]
    img.pixels.foreach_set(px.ravel())
    return img


def load_png_linear(path):
    img = bpy.data.images.load(path)
    img.colorspace_settings.name = "sRGB"
    w, h = img.size
    px = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(px)        # byte images: the stored sRGB values, not color managed
    v = px.reshape(h, w, 4)[::-1, :, :3].astype(np.float64)
    return np.where(v <= 0.04045, v / 12.92, ((v + 0.055) / 1.055) ** 2.4)


# T2's tuned night path (ViewLook: wall_lamp_color, wall_night_gain, wall_keep_hue), and the floor:
# the kitchen's warm #1A1310, or for the window a cool night sky, so dark panes never drift toward
# the reserved hues under the tonemapper (§19.2).
NIGHT_PATH = {"lamp": "#FFE2C0", "gain": 0.3, "keep": 0.4}
NIGHT_FLOOR = {"kitchen": "#1A1310", "window": "#15181C"}


def night_wall(day_png, night_png, floor="kitchen"):
    """§18.3's night path at n = 1, evaluated in numpy, for the Blender preview."""
    day = load_png_linear(day_png)
    img = bpy.data.images.load(night_png)
    img.colorspace_settings.name = "Non-Color"
    w, h = img.size
    px = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(px)
    m = px.reshape(h, w, 4)[::-1, :, 0]
    m = np.repeat(np.repeat(m, 2, 0), 2, 1)[:day.shape[0], :day.shape[1]]
    l = np.maximum(day @ np.array([0.2126, 0.7152, 0.0722]), 1e-4)
    k = NIGHT_PATH["keep"]
    hue = (1.0 - k) + k * day / l[..., None]
    return hue * lin(NIGHT_PATH["lamp"]) * (m * m)[..., None] * NIGHT_PATH["gain"] + lin(NIGHT_FLOOR[floor])


def preview_scene(place, night):
    sc, coll = new_scene("Check_%s" % place)
    jar_objects(coll, "at_peak")
    if place == "window_sill":
        bj.build_counter(coll, (mat_sill(),))
        wall_img = (float_image("wall_night", night_wall(WIN_PNG, WIN_NIGHT_PNG, "window")) if night
                    else bpy.data.images.load(WIN_PNG))
    else:
        bj.build_counter(coll, (mat_oak_counter(box_shadow=True),))
        k_png = bkw.WALL_PNG
        wall_img = (float_image("wall_night", night_wall(k_png, bkw.NIGHT_PNG)) if night
                    else bpy.data.images.load(k_png))
        box = build_box(coll, (mat_box("exterior"), mat_box("interior"), mat_box("plate")))
        unwrap(box)
        box_lin = load_png_linear(BOX_PNG)
        if night:
            box_lin = box_lin * np.array(BOX_NIGHT_MULT)
        bimg = float_image("box_lin", box_lin)
        box.data.materials.clear()
        box.data.materials.append(emission_mat("M_Proofing_Box", bimg))
        box.visible_shadow = False          # Godot draws no shadow maps (T2); the counter shades instead
    if not night and place == "window_sill":
        wall_img.colorspace_settings.name = "sRGB"
    if not night and place == "proofing_box":
        wall_img.colorspace_settings.name = "sRGB"
    wall = bkw.build_wall_mesh("Kitchen_Wall", coll, (emission_mat("M_Kitchen_Wall", wall_img),), "atlas")
    wall.visible_shadow = False
    preset_lights(coll, place, night)
    bj.setup_render(48, 100)
    sc.camera.data.dof.use_dof = False
    return sc


def previews(samples):
    t0 = time.time()
    pw, ph = 180, 390
    cols = [("day", -70.0), ("day", HOME_YAW), ("day", 70.0), ("night", HOME_YAW)]
    sheet = np.ones((ph * 2 + 6, pw * 4 + 6, 3))
    target = (0.0, 0.1018, 0.0)
    for r, place in enumerate(("window_sill", "proofing_box")):
        for night in (False, True):
            sc = preview_scene(place, night)
            cam = sc.camera
            # The §7 pose at full size, measured (not committed, D-045).
            if HOME_YAW in [c[1] for c in cols if (c[0] == "night") == night]:
                bkw.place_camera(cam, 0.0, 15.0, bj.CAM_DIST, (0.0, bj.CAM_TARGET_Z, 0.0))
                a = bkw.render_to_array(sc, bj.RENDER_RES[0], bj.RENDER_RES[1], max(samples, 48))
                tag = "%s %s" % (place, "night" if night else "day")
                print("POSE %s paste lit (290, 850) %s" % (tag, bkw.patch_hsv(a, 290, 850)))
                print("POSE %s paste shadow (450, 830) %s" % (tag, bkw.patch_hsv(a, 450, 830)))
                print("POSE %s backdrop behind the jar (360, 150) %s" % (tag, bkw.patch_hsv(a, 360, 150)))
                print("POSE %s backdrop low left (120, 520) %s" % (tag, bkw.patch_hsv(a, 120, 520)))
                print("POSE %s floor (600, 1150) %s" % (tag, bkw.patch_hsv(a, 600, 1150)))
                print("POSE %s floor under the jar (360, 1080) %s" % (tag, bkw.patch_hsv(a, 360, 1080)))
                hsv_max = a.max(axis=2)
                print("POSE %s clipped (max channel >= 0.99): %.3f%%; reserved hues (H < 25 and S > 50%%): %.3f%%"
                      % (tag, 100 * np.mean(hsv_max >= 0.99), 100 * reserved_share(a)))
            for c, (kind, yaw) in enumerate(cols):
                if (kind == "night") != night:
                    continue
                bkw.place_camera(cam, yaw, HOME_PITCH, bkw.HOME_DIST, target)
                a = bkw.render_to_array(sc, pw, ph, samples)
                sheet[r * (ph + 6):r * (ph + 6) + ph, c * (pw + 2):c * (pw + 2) + pw] = a
                print("SHEET %s %s yaw %+.0f: reserved hues %.3f%%" % (place, kind, yaw, 100 * reserved_share(a)))
    bks._png(SHEET_OUT, np.clip(np.round(sheet * 255.0), 0, 255).astype(np.uint8), 2)
    print("WROTE %s %dx%d, %d bytes (%.1f s)" % (os.path.relpath(SHEET_OUT, REPO), sheet.shape[1], sheet.shape[0],
                                                 os.path.getsize(SHEET_OUT), time.time() - t0))


def reserved_share(a):
    """Share of pixels in §2.3's reserved range: hue under 25 degrees at saturation over 50%."""
    mx, mn = a.max(axis=2), a.min(axis=2)
    sat = (mx - mn) / np.maximum(mx, 1e-6)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    with np.errstate(divide="ignore", invalid="ignore"):
        hue = np.where(mx == r, (60 * (g - b) / (mx - mn)) % 360, 0.0)
    return float(np.mean((mx == r) & (sat > 0.5) & ((hue < 25) | (hue > 330)) & (mx > 0.08)))


def main():
    t0 = time.time()
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    samples = int(argv[argv.index("--samples") + 1]) if "--samples" in argv else 256
    psamples = int(argv[argv.index("--preview-samples") + 1]) if "--preview-samples" in argv else 40
    print("BOX outer %.3f x %.3f x %.3f m (w x d x h), inner back %.3f m behind the jar axis, front at z %.3f"
          % (2 * BOX_HX, BOX_FRONT - BOX_BACK, BOX_H, -(BOX_BACK + BOX_T), BOX_FRONT))
    bad = occlusion_check()
    wall_miss = bkw.coverage_check(bj.COUNTER_X / 2)     # window_sill reuses the wall mesh as is
    if "--check-only" in argv:
        sys.exit(1 if (bad or wall_miss) else 0)
    if "--preview-only" not in argv:
        bake_window(samples)
        box = bake_box(samples)
        export_glb(box)
    if "--no-preview" not in argv:
        previews(psamples)
    print("DONE in %.1fs" % (time.time() - t0))
    if bad or wall_miss:
        sys.exit(1)


if __name__ == "__main__":
    main()
