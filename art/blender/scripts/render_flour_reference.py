"""Flour looks (Phase 4, art-direction.md §20): the four canonical flours at their own peak.

    /Applications/Blender.app/Contents/MacOS/Blender -b -P art/blender/scripts/render_flour_reference.py
Options (after a bare "--"): --samples N (default 48)

Reuses render_starter_reference.py's masked starter (the same masks and math as T2's shader,
§16.3 and §16.4) and adds only what §20 adds: the flour tint, bran flecks, the pocket color
scaled by the tint, and rye's cracks. VisualParams per flour follow §20's mapper terms: dome_k,
the firmness from h_eff = hydration / absorb, and crack.

Writes art/previews/flours_check.png: one column per flour (white_bread, whole_wheat, rye, spelt),
side close-up on top, surface close-up below. Prints the measured rows for §20.
Never touches the GLB, the .blend or any other preview.
"""

import math
import os
import sys
import time

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_jar as bj  # noqa: E402
import bake_kitchen_set as bks  # noqa: E402
import render_starter_reference as rs  # noqa: E402

OUT = os.path.join(bj.REPO, "art", "previews", "flours_check.png")

# §20, the values T1 puts in SimCatalog (TINTS, FLECKS) and VisualMapper (dome_k, size_k, absorb).
# One bran color for every flour: the shader has one FLECK_COLOR constant and VisualParams no field.
FLOURS = {
    #               tint       fleck  fleck color  dome_k size_k absorb (spec §4)  peak rise (spec V5)
    "white_bread": ("#F5EBD6", 0.00, "#7E5E3E", 1.0, 1.00, 1.00, 2.20),
    "whole_wheat": ("#D8BD98", 0.60, "#7E5E3E", 0.7, 0.90, 1.12, 1.91),
    "rye":         ("#AA9379", 0.30, "#7E5E3E", 0.3, 0.75, 1.25, 1.66),
    "spelt":       ("#EFDCAC", 0.15, "#7E5E3E", 0.7, 1.00, 0.95, 1.91),
}
WHITE = "#F5EBD6"
CRACK_FLOOR = 0.35
AT_PEAK = rs.STATES["at_peak"]


def smoothstep(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def visual_params(flour, rye_share=None, hydration=100.0):
    """§20's mapper terms applied to the §6 at_peak values, at the flour's own peak rise."""
    tint, fleck, _fc, dome_k, size_k, absorb, peak = FLOURS[flour]
    rye = (1.0 if flour == "rye" else 0.0) if rye_share is None else rye_share
    h_eff = hydration / absorb
    firm = min(max((100.0 - h_eff) / 40.0, -0.6), 1.0)
    p = dict(AT_PEAK)
    p["rise"] = peak
    p["dome"] = AT_PEAK["dome"] * dome_k * (1 - 0.4 * max(-firm, 0))
    p["sheen"] = min(1.0, AT_PEAK["sheen"] * (1 - 0.35 * max(firm, 0) + 0.25 * max(-firm, 0)))
    p["lumps"] = min(1.0, (AT_PEAK["lumps"] + 0.25 * max(firm, 0)) * (1 - 0.5 * max(-firm, 0)))
    p["bubble_size"] = AT_PEAK["bubble_size"] * size_k
    on = rye >= 0.5 and peak >= 1.3
    p["crack"] = (CRACK_FLOOR + (1 - CRACK_FLOOR) * smoothstep(0.5, 0.8, rye) * smoothstep(1.3, 1.5, peak)) if on else 0.0
    p["firm"] = firm
    return p


def ratio(hexc):
    return np.array(bj.hexcol(hexc)[:3]) / np.array(bj.hexcol(WHITE)[:3])


def extend_material(m, vals):
    """Insert flecks and cracks into the masked starter. Returns the new value nodes."""
    nt = m.node_tree
    t = bj.NT.__new__(bj.NT)
    t.nt, t.vals = nt, {}
    base_node = vals["base_color"]
    targets = [l.to_socket for l in nt.links if l.from_node == base_node]
    base = base_node.outputs[0]
    tc = t.n("ShaderNodeTexCoord")
    obj = tc.outputs["Object"]
    geo = t.n("ShaderNodeNewGeometry")
    top_w = t.maprange(t.sep(geo.outputs["Normal"])[2], 0.55, 0.85)

    # Bran flecks: small flakes on random Voronoi cells (about 1.8% of the paste at fleck 0.6).
    fl_v = t.n("ShaderNodeTexVoronoi", voronoi_dimensions="3D", feature="F1")
    t.put(fl_v.inputs["Vector"], obj)
    fl_v.inputs["Scale"].default_value = 420.0
    rnd = t.n("ShaderNodeSeparateColor")
    t.put(rnd.inputs[0], fl_v.outputs["Color"])
    fleck_amt = t.value("fleck", 0.0)
    fleck = t.math("MULTIPLY", t.maprange(fl_v.outputs["Distance"], 0.25, 0.16),
                   t.math("LESS_THAN", rnd.outputs[0], t.math("MULTIPLY", fleck_amt, 0.45)))
    fleck_col = t.rgb("fleck_color", bj.hexcol("#8A6A48"))
    col = t.mix_col(t.math("MULTIPLY", fleck, 0.85), base, fleck_col)

    # Rye cracks on the cap: an irregular Voronoi edge network, about 7 mm cells. Fissures read
    # as shallow pockets (pocket tone, cavity shade), never as dark lines or a dry crust (§20).
    warp = t.n("ShaderNodeTexNoise")
    t.put(warp.inputs["Vector"], obj)
    warp.inputs["Scale"].default_value = 90.0
    wv = t.n("ShaderNodeVectorMath", operation="MULTIPLY_ADD")
    t.put(wv.inputs[0], warp.outputs["Color"])
    wv.inputs[1].default_value = (0.006, 0.006, 0.0)
    t.put(wv.inputs[2], obj)
    cr_v = t.n("ShaderNodeTexVoronoi", voronoi_dimensions="2D", feature="DISTANCE_TO_EDGE")
    t.put(cr_v.inputs["Vector"], wv.outputs[0])
    cr_v.inputs["Scale"].default_value = 1.0 / 0.016
    crack_amt = t.value("crack", 0.0)
    vary = t.n("ShaderNodeTexNoise")
    t.put(vary.inputs["Vector"], obj)
    vary.inputs["Scale"].default_value = 70.0
    open_k = t.maprange(vary.outputs["Fac"], 0.38, 0.62, 0.12, 1.0)         # some segments nearly shut
    width = t.math("MULTIPLY", t.math("MULTIPLY", crack_amt, 0.075), open_k)
    fissure = t.math("MULTIPLY", t.maprange(cr_v.outputs["Distance"], width, t.math("MULTIPLY", width, 0.35)),
                     t.math("MULTIPLY", top_w, t.math("GREATER_THAN", crack_amt, 0.0)))
    shoulder = t.math("MULTIPLY", t.maprange(cr_v.outputs["Distance"], t.math("MULTIPLY", width, 2.2), width),
                      t.math("MULTIPLY", top_w, t.math("GREATER_THAN", crack_amt, 0.0)))
    pocket = t.rgb("crack_color", bj.hexcol(rs.POCKET))
    col = t.mix_col(t.math("MULTIPLY", fissure, 0.85), col, pocket)
    col = t.mix_col(t.math("MULTIPLY", shoulder, 0.25), col, pocket)
    for s in targets:
        nt.links.new(col, s)
    bump = [n for n in nt.nodes if n.bl_idname == "ShaderNodeBump"][0]
    h_link = [l for l in nt.links if l.to_socket == bump.inputs["Height"]][0]
    h = t.math("SUBTRACT", h_link.from_socket, t.math("ADD", t.math("MULTIPLY", fissure, 0.9),
                                                       t.math("MULTIPLY", shoulder, 0.25)))
    nt.links.new(h, bump.inputs["Height"])
    # Pockets take the flour's tint ratio (§16.4 cue 1).
    pocket_mix = [n for n in nt.nodes if n.bl_idname == "ShaderNodeMix" and n.data_type == "RGBA"
                  and any(s.type == "RGBA" and not s.is_linked and np.allclose(tuple(s.default_value)[:3],
                          tuple(bj.hexcol(rs.POCKET))[:3], atol=1e-5) for s in n.inputs)]
    print("POCKET mix nodes found: %d" % len(pocket_mix))
    return t.vals, pocket_mix


def apply_flour(flour, objs, sv, lv, ext, pocket_mix):
    tint, fleck, fleck_col, *_ = FLOURS[flour]
    p = visual_params(flour)
    name = "flour_" + flour
    rs.STATES[name] = p
    level = rs.apply_state(name, objs, sv, lv)
    sv["base_color"].outputs[0].default_value = bj.hexcol(tint)
    ext["fleck"].outputs[0].default_value = fleck
    ext["fleck_color"].outputs[0].default_value = bj.hexcol(fleck_col)
    ext["crack"].outputs[0].default_value = p["crack"]
    r = ratio(tint)
    pk = np.array(bj.hexcol(rs.POCKET)[:3]) * r
    ext["crack_color"].outputs[0].default_value = tuple(pk * 0.95) + (1.0,)
    for n in pocket_mix:
        for s in n.inputs:
            if s.type == "RGBA" and not s.is_linked:
                s.default_value = tuple(pk) + (1.0,)
    return level, p


def to_array(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    px = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    return px.reshape(h, w, 4)[::-1, :, :3].astype(np.float64)   # byte PNG: stored display values


def paste_stats(a):
    """Paste (pixels within 10 value points of the 80th percentile) and pockets, as §16.1."""
    v = a.max(axis=2)
    p80 = np.percentile(v, 80)
    paste = a[(v > p80 - 0.10) & (v < 0.97)]
    m = paste.mean(0)
    mx, mn = m.max(), m.min()
    hue = (60 * ((m[1] - m[2]) / (mx - mn))) % 360 if mx == m[0] and mx > mn else 0.0
    return "#%02X%02X%02X (H %.0f, S %.0f%%, V %.0f%%)" % (tuple(int(round(c * 255)) for c in m) + (hue, 100 * (mx - mn) / mx, 100 * mx))


def main():
    t0 = time.time()
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    samples = int(argv[argv.index("--samples") + 1]) if "--samples" in argv else 48
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    coll = bpy.data.collections.new("Scene_Flour")
    sc.collection.children.link(coll)
    m_starter, sv = rs.mat_starter_masked(rs.load_mask("starter_side_bubbles.png"), rs.load_mask("starter_top_pits.png"))
    ext, pocket_mix = extend_material(m_starter, sv)
    m_liner, lv = rs.mat_liner_masked(rs.load_mask("starter_liner_streaks.png"))
    objs = {
        "Jar_Glass": bj.build_glass(coll, (bj.mat_glass("M_Glass"), bj.mat_glass("M_Glass_Inner"))),
        "Starter_Body": bj.build_starter(coll, (m_starter,)),
        "Starter_Liner": bj.build_liner(coll, (m_liner,)),
        "Jar_Lid_Loose": bj.build_lid_loose(coll, (bj.mat_lid_wood(),)),
        "Rubber_Band": bj.build_band(coll, (bj.mat_simple("M_Rubber_Band", bj.C["band"], 0.55, subsurf=0.1),)),
        "Counter": bj.build_counter(coll, (bj.mat_counter(),)),
    }
    bj.add_starter_shape_modifier(objs["Starter_Body"], bj.mat_mold_fuzz())
    objs.update(bj.build_wall_preview(coll))
    bj.setup_world()
    bj.setup_lights_camera(coll)
    bj.setup_render(samples, 100)
    cam, fo = rs.make_camera("RefCam", (0, -0.2, 0.1), (0, 0, 0.05), 60.0, 5.6, (0, 0, 0.05))
    sc.camera = cam
    pw, ph = 256, 320
    gap = 6
    names = list(FLOURS)
    sheet = np.ones((2 * ph + 3 * gap, len(names) * pw + (len(names) + 1) * gap, 3))
    sheet[...] = (0.984, 0.965, 0.925)
    tmp = os.path.join(bpy.app.tempdir or "/tmp", "flour_tmp.png")
    for ci, flour in enumerate(names):
        level, p = apply_flour(flour, objs, sv, lv, ext, pocket_mix)
        print("FLOUR %s: rise %.2f dome %.2f lumps %.2f sheen %.2f bubble_size %.2f crack %.2f firm %+.2f"
              % (flour, p["rise"], p["dome"], p["lumps"], p["sheen"], p["bubble_size"], p["crack"], p["firm"]))
        for ri, view in enumerate(("side", "top")):
            if view == "side":
                rs.frame_side(cam, fo, level)
                cam.data.dof.aperture_fstop = 5.6
                objs["Jar_Lid_Loose"].hide_render = False
            else:
                rs.frame_top(cam, fo, level, p["dome"] * rs.DOME_MAX_M)
                cam.data.dof.aperture_fstop = 8.0
                objs["Jar_Lid_Loose"].hide_render = True
            sc.render.resolution_x, sc.render.resolution_y = pw, ph
            sc.render.filepath = tmp
            bpy.ops.render.render(write_still=True)
            a = to_array(tmp)
            y0, x0 = gap + ri * (ph + gap), gap + ci * (pw + gap)
            sheet[y0:y0 + ph, x0:x0 + pw] = a
            print("ROW %s %s paste %s" % (flour, view, paste_stats(a)))
    bks._png(OUT, np.clip(np.round(sheet * 255.0), 0, 255).astype(np.uint8), 2)
    print("WROTE %s %dx%d, %d bytes (%.1f s)" % (os.path.relpath(OUT, bj.REPO), sheet.shape[1], sheet.shape[0],
                                                 os.path.getsize(OUT), time.time() - t0))


if __name__ == "__main__":
    main()
