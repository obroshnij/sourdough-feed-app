"""Starter reference board (D-037). Close-ups rendered with the runtime masks.

Run from the repo root:
    /Applications/Blender.app/Contents/MacOS/Blender -b -P art/blender/scripts/render_starter_reference.py
Options (after a bare "--"):
    --states a,b      only these states (default: the five rise-cycle key states)
    --views a,b       side, top, pose (default: all three)
    --samples N       Cycles samples (default 48)
    --no-board        skip the contact sheet

Writes only art/previews/reference/:
    ref_<state>_side.png    bubbles through the glass, the inspect "bubbles" framing
    ref_<state>_top.png     into the mouth at 60 degrees, the inspect "surface" framing
    ref_<state>_pose.png    the QA preview pose (art-direction §7), for at_peak and collapsing
    board_starter.png       contact sheet: one row per state, side | top

It reuses build_jar.py for geometry, glass, lights and render settings, then swaps
the starter and liner materials for versions that read the three masks in
assets/textures/ with the same math as the Godot spec (art-direction §16.3 and §16.4). So what
you see here is what the masks can do, not a separate procedural look.
Never touches jar_v0.blend, the GLB or art/previews/jar_v0_*.png.
"""

import math
import os
import sys
import time

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_jar as bj  # noqa: E402

REPO = bj.REPO
TEX = os.path.join(REPO, "assets", "textures")
OUT = os.path.join(REPO, "art", "previews", "reference")

# Mirror of art-direction §16.3 (and art/textures/make_starter_masks.py).
SIDE_REPEATS = 4
SIDE_TILE_M = 2.0 * math.pi * 0.0380 / SIDE_REPEATS
TOP_TILE_M = 0.048
TOP_ROT = 0.6                     # radians, breaks the axis-aligned repeat on the cap
LINER_REPEATS = 2
LINER_SPAN_M = 2.0 * math.pi * 0.03835 / LINER_REPEATS * 0.5
LINER_EDGE_V = 0.10
GROW_RAMP = 0.08                  # a feature grows in over this much density
SIZE_MIN = 0.12                   # bubble_size 0 still shows features at 12% scale
STRETCH_K = 0.35                  # v squash at full stretch (web strands at peak)
TAP = 1.5 / 512.0                 # gradient tap offset, 1.5 texels
LIGHT_UV = (-0.35, 0.94)          # key light direction in mask space (u, image-up)

DOME_MAX_M = 0.010
LUMPS_MAX_M = 0.003
HOOCH_MAX_M = 0.010
FED = bj.FED_LEVEL

# VisualParams per state, straight from art-direction §6 (the VisualMapper targets).
STATES = {
    "freshly_fed": dict(rise=1.0, dome=0.1, lumps=0.85, bubble_density=0.1, bubble_size=0.1,
                        peak_line=0.0, streak_amount=0.0, hooch_depth=0.0, surface_dryness=0.0,
                        sheen=0.35, age=0.0),
    "active":      dict(rise=1.7, dome=0.45, lumps=0.45, bubble_density=0.7, bubble_size=0.35,
                        peak_line=0.0, streak_amount=0.0, hooch_depth=0.0, surface_dryness=0.0,
                        sheen=0.55, age=0.0),
    "at_peak":     dict(rise=2.3, dome=0.8, lumps=0.5, bubble_density=0.65, bubble_size=0.8,
                        peak_line=0.0, streak_amount=0.0, hooch_depth=0.0, surface_dryness=0.0,
                        sheen=0.65, age=0.0),
    "collapsing":  dict(rise=1.9, dome=-0.4, lumps=0.45, bubble_density=0.4, bubble_size=0.75,
                        peak_line=2.3, streak_amount=0.8, hooch_depth=0.0, surface_dryness=0.0,
                        sheen=0.7, age=0.0),
    "hungry":      dict(rise=1.25, dome=-0.1, lumps=0.15, bubble_density=0.2, bubble_size=0.85,
                        peak_line=2.3, streak_amount=0.5, hooch_depth=0.35, surface_dryness=0.1,
                        sheen=0.7, age=0.6),
    # Warning, recoverable: dull dry cap, thick dark hooch, almost no bubbles, old pale residue.
    # Never fuzz, never green, pink, orange or red specks.
    "unhealthy":   dict(rise=0.95, dome=-0.05, lumps=0.35, bubble_density=0.03, bubble_size=0.2,
                        peak_line=2.3, streak_amount=0.6, hooch_depth=0.4, surface_dryness=0.85,
                        sheen=0.1, age=1.0, hooch_col="hooch_dark"),
}
POSE_STATES = ("at_peak", "collapsing", "hungry", "unhealthy")
POCKET = "#D3BF9E"
DRIED = "#E2D9C8"                 # dried residue: paler than wet paste, never darker


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opts = {"states": list(STATES), "views": ["side", "top", "pose"], "samples": 48,
            "board": True}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--states":
            i += 1
            opts["states"] = [s for s in argv[i].split(",") if s]
        elif a == "--views":
            i += 1
            opts["views"] = [s for s in argv[i].split(",") if s]
        elif a == "--samples":
            i += 1
            opts["samples"] = int(argv[i])
        elif a == "--no-board":
            opts["board"] = False
        i += 1
    return opts


def load_mask(name):
    img = bpy.data.images.load(os.path.join(TEX, name), check_existing=True)
    img.colorspace_settings.name = "Non-Color"
    img.alpha_mode = "CHANNEL_PACKED"      # gray and alpha are separate data channels
    return img


def sample(t, img, u, v, extension="REPEAT"):
    """Returns (L, A) sockets. Blender v grows up the image, Godot v grows down;
    the callers pass Blender v (= -Godot v), so image-up is world-up in both."""
    tex = t.n("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Linear"
    tex.extension = extension
    t.put(tex.inputs["Vector"], t.combine(u, v, 0.0))
    sep = t.n("ShaderNodeSeparateColor")
    t.put(sep.inputs[0], tex.outputs["Color"])
    return sep.outputs[0], tex.outputs["Alpha"]


def feature(t, F, P, density, size):
    """The §16.4 feature function. Returns (air, depth01, lip)."""
    grow = t.maprange(density, P, t.math("ADD", P, GROW_RAMP))          # smoothstep
    frac = t.math("MULTIPLY", t.math("ADD", SIZE_MIN, t.math("MULTIPLY", size, 1.0 - SIZE_MIN)), grow)
    thr = t.math("SUBTRACT", 1.0, frac)
    aa = t.math("MINIMUM", 0.03, t.math("MULTIPLY", frac, 0.5))
    air = t.maprange(F, t.math("SUBTRACT", thr, aa), t.math("ADD", thr, aa))
    depth = t.math("DIVIDE", t.math("SUBTRACT", F, thr), t.math("MAXIMUM", frac, 0.001), clamp=True)
    lip_lo = t.math("SUBTRACT", thr, t.math("MULTIPLY", frac, 0.35))
    lip = t.math("MULTIPLY", t.maprange(F, lip_lo, thr), t.math("SUBTRACT", 1.0, air))
    return air, depth, lip


def mat_starter_masked(side_img, top_img):
    m, t = bj.new_mat("M_Starter")
    tc = t.n("ShaderNodeTexCoord")
    ox, oy, oz = t.sep(tc.outputs["Object"])
    geo = t.n("ShaderNodeNewGeometry")
    nz = t.sep(geo.outputs["Normal"])[2]                       # identity rotation: world = object
    top_w = t.maprange(nz, 0.55, 0.85)

    base = t.rgb("base_color", bj.hexcol(bj.C["starter"]["white_bread"]))
    density = t.value("bubble_density", 0.5)
    size = t.value("bubble_size", 0.5)
    stretch = t.value("stretch", 0.0)
    sheen = t.value("sheen", 0.5)
    level = t.value("level", FED)
    hooch_m = t.value("hooch_m", 0.0)
    dryness = t.value("dryness", 0.0)
    hooch_rgb = t.rgb("hooch_color", bj.hexcol(bj.C["hooch"]))

    # Side: cylindrical, 4 tiles around, square texels, v squashed by stretch.
    ang = t.math("ARCTAN2", oy, ox)
    u_s = t.math("MULTIPLY", ang, SIDE_REPEATS / (2.0 * math.pi))
    v_s = t.math("DIVIDE", oz, t.math("MULTIPLY", SIDE_TILE_M, t.math("ADD", 1.0, t.math("MULTIPLY", stretch, STRETCH_K))))
    F_s, P_s = sample(t, side_img, u_s, v_s)
    # Two extra taps of the same mask give the bubble's inward direction, so the
    # pocket can be shaded as a cavity lit from above-left (§16.4, "depth").
    F_su, _ = sample(t, side_img, t.math("ADD", u_s, TAP), v_s)
    F_sv, _ = sample(t, side_img, u_s, t.math("ADD", v_s, TAP))
    gx = t.math("SUBTRACT", F_su, F_s)
    gy = t.math("SUBTRACT", F_sv, F_s)
    glen = t.math("MAXIMUM", t.math("SQRT", t.math("ADD", t.math("MULTIPLY", gx, gx), t.math("MULTIPLY", gy, gy))), 1e-4)
    facing = t.math("DIVIDE", t.math("ADD", t.math("MULTIPLY", gx, LIGHT_UV[0]), t.math("MULTIPLY", gy, LIGHT_UV[1])), glen)
    # Bigger bubbles near the top: size grows 0.85x to 1.15x with height.
    hfrac = t.math("DIVIDE", oz, t.math("MAXIMUM", level, 0.001), clamp=True)
    size_s = t.math("MULTIPLY", size, t.math("ADD", 0.85, t.math("MULTIPLY", hfrac, 0.3)), clamp=True)
    air_s, dep_s, _ = feature(t, F_s, P_s, density, size_s)

    # Top: planar on object XY (Godot XZ), rotated, 48 mm tile.
    c, s = math.cos(TOP_ROT), math.sin(TOP_ROT)
    u_t = t.math("DIVIDE", t.math("SUBTRACT", t.math("MULTIPLY", ox, c), t.math("MULTIPLY", oy, s)), TOP_TILE_M)
    v_t = t.math("DIVIDE", t.math("ADD", t.math("MULTIPLY", ox, s), t.math("MULTIPLY", oy, c)), TOP_TILE_M)
    F_t, P_t = sample(t, top_img, u_t, v_t)
    # Fewer, smaller open pits on top than bubbles at the glass; collapse opens more.
    air_t, dep_t, lip_t = feature(t, F_t, P_t, t.math("MULTIPLY", density, 0.9),
                                  t.math("MULTIPLY", size, 0.8))

    # Cavity light: dark under the top lip, lit on the lower wall, plain at the center.
    wall = t.math("SUBTRACT", 1.0, t.math("MULTIPLY", dep_s, dep_s))
    cav_s = t.math("ADD", 0.82, t.math("MULTIPLY", t.math("MULTIPLY", facing, 0.22), wall))
    contact = t.math("MULTIPLY", t.math("MULTIPLY", air_s, t.math("SUBTRACT", 1.0, air_s)), 4.0)
    cav_s = t.math("MULTIPLY", cav_s, t.math("SUBTRACT", 1.0, t.math("MULTIPLY", contact, 0.18)))
    cav = bj.lerp(t, top_w, cav_s, t.math("SUBTRACT", 0.86, t.math("MULTIPLY", dep_t, 0.28)))
    air = bj.lerp(t, top_w, air_s, air_t)
    dep = bj.lerp(t, top_w, dep_s, dep_t)
    lip = t.math("MULTIPLY", lip_t, top_w)

    # Hooch band from the surface down.
    has_hooch = t.math("GREATER_THAN", hooch_m, 0.0)
    hooch_lo = t.math("SUBTRACT", level, hooch_m)
    hooch = t.math("MULTIPLY", has_hooch, t.maprange(oz, t.math("SUBTRACT", hooch_lo, 0.0006),
                                                     t.math("ADD", hooch_lo, 0.0004)))
    still = t.math("SUBTRACT", 1.0, hooch)
    air = t.math("MULTIPLY", air, still)

    # Pocket height: concave, rounded wall (sqrt profile), deeper for bigger features.
    prof = t.math("SQRT", t.math("SUBTRACT", 1.0, t.math("POWER", t.math("SUBTRACT", 1.0, dep), 2.0)))
    height = t.math("SUBTRACT", t.math("MULTIPLY", lip, 0.25), t.math("MULTIPLY", prof, air))
    grain = t.n("ShaderNodeTexNoise")
    t.put(grain.inputs["Vector"], tc.outputs["Object"])
    grain.inputs["Scale"].default_value = 180.0
    grain.inputs["Detail"].default_value = 3.0
    height = t.math("ADD", height, t.math("MULTIPLY", t.math("MULTIPLY", grain.outputs["Fac"], 0.12), still))
    bump = t.n("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.7
    bump.inputs["Distance"].default_value = 0.0005
    t.put(bump.inputs["Height"], height)

    # Albedo: cream, a touch darker and warmer in pockets, never brown.
    mottle = t.n("ShaderNodeTexNoise")
    t.put(mottle.inputs["Vector"], tc.outputs["Object"])
    mottle.inputs["Scale"].default_value = 28.0
    mottle.inputs["Detail"].default_value = 2.0
    tone = t.math("MULTIPLY", t.maprange(grain.outputs["Fac"], 0.3, 0.7, 0.975, 1.015, smooth_step=False),
                  t.maprange(mottle.outputs["Fac"], 0.35, 0.65, 0.96, 1.02))
    mul = t.n("ShaderNodeMix", data_type="RGBA", blend_type="MULTIPLY", clamp_factor=True)
    mul.inputs["Factor"].default_value = 1.0
    ins = [x for x in mul.inputs if x.type == "RGBA"]
    t.put(ins[0], base)
    t.put(ins[1], t.combine(tone, tone, tone))
    col = [x for x in mul.outputs if x.type == "RGBA"][0]
    pocket_amt = t.math("MULTIPLY", air, t.math("ADD", 0.55, t.math("MULTIPLY", dep, 0.35)))
    col = t.mix_col(pocket_amt, col, bj.hexcol(POCKET))
    shade = bj.lerp(t, air, 1.0, cav)
    dim = t.n("ShaderNodeMix", data_type="RGBA", blend_type="MULTIPLY", clamp_factor=True)
    dim.inputs["Factor"].default_value = 1.0
    dins = [x for x in dim.inputs if x.type == "RGBA"]
    t.put(dins[0], col)
    t.put(dins[1], t.combine(shade, shade, shade))
    col = [x for x in dim.outputs if x.type == "RGBA"][0]
    dry = t.math("MULTIPLY", top_w, dryness)
    col = t.mix_col(t.math("MULTIPLY", dry, 0.85), col, bj.hexcol(bj.C["crust"]))
    hooch_col = t.mix_col(t.maprange(oz, hooch_lo, level, 0.45, 1.0), col, hooch_rgb)
    col = t.mix_col(hooch, col, hooch_col)

    # Glossy skin: sheen drives roughness down and a clear coat up, most on the dome.
    rough = t.maprange(sheen, 0.0, 1.0, 0.55, 0.24, smooth_step=False)
    rough = bj.lerp(t, air, rough, 0.18)
    rough = bj.lerp(t, dry, rough, 0.8)
    rough = bj.lerp(t, hooch, rough, 0.04)
    coat = t.math("MULTIPLY", t.math("MULTIPLY", sheen, bj.lerp(t, top_w, 0.25, 0.6)),
                  t.math("SUBTRACT", 1.0, dry))
    coat = t.math("MAXIMUM", coat, hooch)
    p = t.principled(Base_Color=col, Subsurface_Scale=0.0018, Coat_Roughness=0.08,
                     Specular_IOR_Level=0.55)
    p.inputs["Subsurface Radius"].default_value = (1.0, 0.9, 0.78)
    sss = bj.lerp(t, t.math("MAXIMUM", hooch, dry), 0.24, 0.02)
    t.put(p.inputs["Subsurface Weight"], bj.lerp(t, air, sss, 0.06))
    t.put(p.inputs["Roughness"], rough)
    t.put(p.inputs["Coat Weight"], coat)
    t.put(p.inputs["Normal"], bump.outputs[0])
    t.out(p.outputs[0])
    return m, t.vals


def mat_liner_masked(liner_img):
    m, t = bj.new_mat("M_Starter_Liner")
    tc = t.n("ShaderNodeTexCoord")
    ox, oy, oz = t.sep(tc.outputs["Object"])
    peak = t.value("peak_m", 0.0)
    level = t.value("level", FED)
    amount = t.value("streak_amount", 0.0)
    age = t.value("age", 0.0)

    ang = t.math("ARCTAN2", oy, ox)
    u = t.math("FRACT", t.math("MULTIPLY", ang, LINER_REPEATS / (2.0 * math.pi)))
    v_godot = t.math("ADD", LINER_EDGE_V, t.math("DIVIDE", t.math("SUBTRACT", peak, oz), LINER_SPAN_M))
    E, D = sample(t, liner_img, u, t.math("SUBTRACT", 1.0, v_godot), extension="EXTEND")

    thr = t.math("SUBTRACT", 1.0, amount)
    vis = t.maprange(E, t.math("SUBTRACT", thr, 0.02), t.math("ADD", thr, 0.02))
    keep = t.maprange(D, t.math("MULTIPLY", age, 0.35), t.math("ADD", t.math("MULTIPLY", age, 0.35), 0.04))
    vis = t.math("MULTIPLY", vis, keep)
    above = t.maprange(oz, t.math("ADD", level, 0.0003), t.math("ADD", level, 0.0018))
    thick = t.math("DIVIDE", t.math("SUBTRACT", E, thr), 0.5, clamp=True)
    alpha = t.math("MULTIPLY", t.math("MULTIPLY", vis, above),
                   t.math("ADD", 0.30, t.math("MULTIPLY", thick, 0.62)))
    alpha = t.math("MULTIPLY", alpha, t.math("SUBTRACT", 1.0, t.math("MULTIPLY", age, 0.25)))
    alpha = t.math("MULTIPLY", alpha, t.math("GREATER_THAN", amount, 0.0))
    col = t.mix_col(age, bj.hexcol(bj.C["starter"]["white_bread"]), bj.hexcol(DRIED))
    p = t.principled(Base_Color=col, Subsurface_Weight=0.15, Subsurface_Scale=0.002)
    t.put(p.inputs["Roughness"], bj.lerp(t, age, 0.22, 0.8))
    tr = t.n("ShaderNodeBsdfTransparent")
    mix = t.n("ShaderNodeMixShader")
    t.put(mix.inputs["Fac"], alpha)
    t.put(mix.inputs[1], tr.outputs[0])
    t.put(mix.inputs[2], p.outputs[0])
    t.out(mix.outputs[0])
    return m, t.vals


def apply_state(name, objs, sv, lv):
    s = STATES[name]
    level = s["rise"] * FED
    bj.set_starter_shape(objs["Starter_Body"], level, s["dome"] * DOME_MAX_M,
                         s["lumps"] * LUMPS_MAX_M, 0.0)
    sv["bubble_density"].outputs[0].default_value = s["bubble_density"]
    sv["bubble_size"].outputs[0].default_value = s["bubble_size"]
    sv["stretch"].outputs[0].default_value = s["bubble_size"] * max(0.0, min(1.0, (s["rise"] - 1.5) / 0.8))
    sv["sheen"].outputs[0].default_value = s["sheen"]
    sv["level"].outputs[0].default_value = level
    sv["hooch_m"].outputs[0].default_value = s["hooch_depth"] * HOOCH_MAX_M
    sv["dryness"].outputs[0].default_value = s["surface_dryness"]
    sv["hooch_color"].outputs[0].default_value = bj.hexcol(bj.C[s.get("hooch_col", "hooch")])
    lv["peak_m"].outputs[0].default_value = s["peak_line"] * FED
    lv["level"].outputs[0].default_value = level
    lv["streak_amount"].outputs[0].default_value = s["streak_amount"]
    lv["age"].outputs[0].default_value = s["age"]
    objs["Rubber_Band"].location.z = bj.BASE_T + FED
    return level


def make_camera(name, loc, target, lens, fstop, focus_pt):
    cd = bpy.data.cameras.new(name)
    cd.lens = lens
    cd.sensor_fit = "AUTO"
    cd.clip_start = 0.005
    cd.dof.use_dof = True
    cd.dof.aperture_fstop = fstop
    cd.dof.aperture_blades = 7
    cam = bpy.data.objects.new(name, cd)
    cam.location = loc
    bpy.context.scene.collection.objects.link(cam)
    bj.aim(cam, target)
    fo = bpy.data.objects.new(name + "_focus", None)
    fo.location = focus_pt
    bpy.context.scene.collection.objects.link(fo)
    cd.dof.focus_object = fo
    return cam, fo


def frame_side(cam, fo, level):
    """Inspect 'bubbles': glass wall at the starter's mid-height, the side facing the key."""
    az = math.radians(-28.0)                   # from -Y toward -X (the key light side)
    zt = bj.BASE_T + level * 0.55
    r_cam = bj.JAR_OUTER_R + 0.115
    cam.location = (r_cam * math.sin(az), -r_cam * math.cos(az), zt + 0.012)
    bj.aim(cam, (0.0, 0.0, zt))
    fo.location = (bj.STARTER_R * math.sin(az), -bj.STARTER_R * math.cos(az), zt)


def frame_top(cam, fo, level, dome):
    """Inspect 'surface': into the mouth from about 60 degrees, lid lifted away."""
    zt = bj.BASE_T + level + max(dome, 0.0) * 0.6
    pitch = math.radians(76.0)
    d = 0.20
    cam.location = (0.0, -d * math.cos(pitch), zt + d * math.sin(pitch))
    bj.aim(cam, (0.0, 0.004, zt))
    fo.location = (0.0, 0.0, zt)


def build_board(paths_by_state, out_path, cell=(480, 600), gap=8):
    """Contact sheet in pure bpy: rows = states, columns = side | top."""
    import numpy as np
    rows = [r for r in paths_by_state if all(os.path.exists(p) for p in r[1])]
    if not rows:
        return None
    cw, ch = cell
    ncol = max(len(r[1]) for r in rows)
    W = ncol * cw + (ncol + 1) * gap
    H = len(rows) * ch + (len(rows) + 1) * gap
    board = np.ones((H, W, 4), dtype=np.float32)
    board[..., :3] = 0.984, 0.965, 0.925      # surface #FBF6EC
    for ri, (_state, paths) in enumerate(rows):
        for ci, p in enumerate(paths):
            img = bpy.data.images.load(p)
            img.scale(cw, ch)
            px = np.empty(cw * ch * 4, dtype=np.float32)
            img.pixels.foreach_get(px)
            px = px.reshape(ch, cw, 4)                      # bottom-up rows
            y0 = H - (gap + ri * (ch + gap)) - ch           # board is bottom-up too
            x0 = gap + ci * (cw + gap)
            board[y0:y0 + ch, x0:x0 + cw] = px
            bpy.data.images.remove(img)
    out = bpy.data.images.new("board", W, H, alpha=False, float_buffer=False)
    out.colorspace_settings.name = "sRGB"
    out.pixels.foreach_set(board.ravel())
    out.filepath_raw = out_path
    out.file_format = "PNG"
    out.save()
    return out_path


def main():
    t0 = time.time()
    opts = parse_args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"
    coll = bpy.data.collections.new("Scene_Ref")
    sc.collection.children.link(coll)

    side_img = load_mask("starter_side_bubbles.png")
    top_img = load_mask("starter_top_pits.png")
    liner_img = load_mask("starter_liner_streaks.png")

    m_glass = bj.mat_glass("M_Glass")
    m_glass_in = bj.mat_glass("M_Glass_Inner")
    m_starter, sv = mat_starter_masked(side_img, top_img)
    m_liner, lv = mat_liner_masked(liner_img)
    objs = {}
    objs["Jar_Glass"] = bj.build_glass(coll, (m_glass, m_glass_in))
    objs["Starter_Body"] = bj.build_starter(coll, (m_starter,))
    objs["Starter_Liner"] = bj.build_liner(coll, (m_liner,))
    objs["Jar_Lid_Loose"] = bj.build_lid_loose(coll, (bj.mat_lid_wood(),))
    objs["Rubber_Band"] = bj.build_band(coll, (bj.mat_simple("M_Rubber_Band", bj.C["band"], 0.55, subsurf=0.1),))
    objs["Counter"] = bj.build_counter(coll, (bj.mat_counter(),))
    objs["Backdrop_placeholder"] = bj.build_backdrop(coll, (bj.mat_backdrop(),))
    bj.add_starter_shape_modifier(objs["Starter_Body"], bj.mat_mold_fuzz())
    bj.setup_world()
    bj.setup_lights_camera(coll)
    pose_cam = sc.camera
    bj.setup_render(opts["samples"], 100)

    cam, fo = make_camera("RefCam", (0, -0.2, 0.1), (0, 0, 0.05), 60.0, 5.6, (0, 0, 0.05))
    os.makedirs(OUT, exist_ok=True)
    board_rows = []
    for name in opts["states"]:
        s = STATES[name]
        level = apply_state(name, objs, sv, lv)
        row = []
        for view in opts["views"]:
            if view == "pose" and name not in POSE_STATES:
                continue
            t1 = time.time()
            if view == "side":
                frame_side(cam, fo, level)
                sc.camera = cam
                cam.data.dof.aperture_fstop = 5.6
                sc.render.resolution_x, sc.render.resolution_y = 640, 800
                objs["Jar_Lid_Loose"].hide_render = False
            elif view == "top":
                frame_top(cam, fo, level, s["dome"] * DOME_MAX_M)
                sc.camera = cam
                cam.data.dof.aperture_fstop = 8.0
                sc.render.resolution_x, sc.render.resolution_y = 640, 800
                objs["Jar_Lid_Loose"].hide_render = True       # the lid lifts away
            else:
                sc.camera = pose_cam
                sc.render.resolution_x, sc.render.resolution_y = bj.RENDER_RES
                objs["Jar_Lid_Loose"].hide_render = False
            path = os.path.join(OUT, "ref_%s_%s.png" % (name, view))
            sc.render.filepath = path
            bpy.ops.render.render(write_still=True)
            print("RENDERED %s in %.1fs" % (path, time.time() - t1))
            if view in ("side", "top"):
                row.append(path)
        board_rows.append((name, row))
    if opts["board"]:
        all_rows = [(n, [os.path.join(OUT, "ref_%s_%s.png" % (n, v)) for v in ("side", "top")])
                    for n in STATES]
        print("BOARD", build_board(all_rows, os.path.join(OUT, "board_starter.png")))
    print("DONE in %.1fs" % (time.time() - t0))


if __name__ == "__main__":
    main()
