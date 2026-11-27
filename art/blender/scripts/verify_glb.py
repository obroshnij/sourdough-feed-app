"""Check a GLB against its mesh contract in docs/art-direction.md: the jar (§12), or, when the file
holds a Kitchen_Wall node, the kitchen wall (§18), or, with a Place_Proofing_Box node, the places (§19).

Plain Python 3, no dependencies:
    python3 art/blender/scripts/verify_glb.py [path/to/file.glb]
Exits 1 if any contract check fails.
"""

import json
import math
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT = os.path.join(HERE, "..", "..", "..", "assets", "3d", "jar_v0.glb")

MESH_NODES = {
    # name: (expected surfaces, needs TEXCOORD_1)
    "Jar_Glass": (2, False),
    "Starter_Body": (1, True),
    "Starter_Liner": (1, False),
    "Jar_Lid_Loose": (1, False),
    "Jar_Lid_Tight": (1, False),
    "Cloth_Cover": (2, False),
    "Rubber_Band": (1, False),
    "Counter": (1, False),
}
EMPTY_NODES = ("StarterFloor", "StarterRim")
TRI_BUDGET = {"Jar_Glass": 5000, "Starter_Body": 4000, "_total": 30000}
# architecture.md section 11: the rendered scene is 16k tris or fewer. Only one cover
# shows at a time, so check the base set plus the heaviest cover. The kitchen wall lives in
# kitchen_wall.glb; its check adds the wall to this set.
VISIBLE_BASE = ("Jar_Glass", "Starter_Body", "Starter_Liner", "Rubber_Band", "Counter")
COVERS = ("Jar_Lid_Loose", "Jar_Lid_Tight", "Cloth_Cover")
VISIBLE_BUDGET = 16000


def load(path):
    """Return (json, binary chunk)."""
    with open(path, "rb") as f:
        data = f.read()
    magic, version, _length = struct.unpack_from("<4sII", data, 0)
    assert magic == b"glTF" and version == 2, "not a glTF 2 binary"
    clen, ctype = struct.unpack_from("<I4s", data, 12)
    assert ctype == b"JSON"
    g = json.loads(data[20:20 + clen])
    boff = 20 + clen
    blen, _ = struct.unpack_from("<I4s", data, boff)
    return g, data[boff + 8:boff + 8 + blen]


def read_floats(g, binary, index):
    a = g["accessors"][index]
    bv = g["bufferViews"][a["bufferView"]]
    n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
    assert a["componentType"] == 5126, "expected float accessor"
    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = bv.get("byteStride", 4 * n)
    return [struct.unpack_from("<%df" % n, binary, off + i * stride) for i in range(a["count"])]


# Kitchen wall (§18): one node, one surface, UV0 = the kitchen_wall.png atlas.
WALL_TRI_BUDGET = 500
WALL_ATLAS_V = {"wall_top": 0.0, "wall_bottom": 448 / 512, "cabinet_top": 452 / 512, "cabinet_bottom": 1.0}
WALL_EXTRAS = ("wall_center_z_m", "wall_radius_m", "wall_end_deg", "wall_top_m", "cabinet_z_m", "texture")


def verify_wall(path, g, binary):
    errors = []
    by_name = {n.get("name"): n for n in g["nodes"]}
    extra = sorted(set(by_name) - {"Kitchen_Wall"})
    if extra:
        errors.append("unexpected nodes: " + ", ".join(extra))
    n = by_name["Kitchen_Wall"]
    if any(k in n for k in ("rotation", "scale", "matrix")):
        errors.append("Kitchen_Wall has rotation/scale/matrix (must be identity)")
    if any(abs(c) > 1e-9 for c in n.get("translation", [0.0, 0.0, 0.0])):
        errors.append("Kitchen_Wall origin must be (0, 0, 0), the jar axis on the counter top")
    ex = n.get("extras", {})
    for k in WALL_EXTRAS:
        if k not in ex:
            errors.append("Kitchen_Wall extras has no " + k)
    prims = g["meshes"][n["mesh"]]["primitives"]
    if len(prims) != 1:
        errors.append("Kitchen_Wall has %d surfaces, expected 1 (one draw call)" % len(prims))
    p = prims[0]
    a = p["attributes"]
    mat = g["materials"][p["material"]]["name"] if "material" in p else None
    if mat != "M_Kitchen_Wall":
        errors.append("Kitchen_Wall material is %s, expected M_Kitchen_Wall" % mat)
    if g.get("images") or g.get("textures"):
        errors.append("the GLB embeds images; the wall texture ships as a separate PNG")
    for attr in ("NORMAL", "TEXCOORD_0"):
        if attr not in a:
            errors.append("Kitchen_Wall has no " + attr)
    tris = g["accessors"][p["indices"]]["count"] // 3
    if tris > WALL_TRI_BUDGET:
        errors.append("Kitchen_Wall has %d tris, budget %d" % (tris, WALL_TRI_BUDGET))
    pos = read_floats(g, binary, a["POSITION"])
    nrm = read_floats(g, binary, a["NORMAL"])
    uv = read_floats(g, binary, a["TEXCOORD_0"])
    cz, r = float(ex.get("wall_center_z_m", 0.65)), float(ex.get("wall_radius_m", 1.10))
    cab_z = float(ex.get("cabinet_z_m", 0.22))
    if min(c for t in uv for c in t) < -1e-6 or max(c for t in uv for c in t) > 1 + 1e-6:
        errors.append("UV0 outside 0..1")
    bad_n = 0
    wall_v, cab_v = [], []
    for (x, y, z), (nx, _ny, nz), (u, v) in zip(pos, nrm, uv):
        if abs(z - cab_z) < 1e-4 and y < -0.025:            # cabinet front: faces the camera (+z)
            bad_n += nz <= 0.5
            cab_v.append((y, v))
        else:                                               # wall: faces the circle center
            bad_n += (nx * -x + nz * (cz - z)) <= 0.0
            if abs((x * x + (z - cz) ** 2) ** 0.5 - r) > 1e-3:
                errors.append("wall vertex off the circle at (%.3f, %.3f, %.3f)" % (x, y, z))
                break
            wall_v.append((y, v, x, u, z))
    if bad_n:
        errors.append("%d vertex normals face away from the camera side" % bad_n)
    top = min(wall_v, key=lambda t: -t[0])
    bot = min(wall_v, key=lambda t: t[0])
    ctop = max(cab_v, key=lambda t: t[0])
    cbot = min(cab_v, key=lambda t: t[0])
    left = min(wall_v, key=lambda t: t[2])
    right = max(wall_v, key=lambda t: t[2])
    checks = [("wall top v", top[1], WALL_ATLAS_V["wall_top"]), ("wall bottom v", bot[1], WALL_ATLAS_V["wall_bottom"]),
              ("cabinet top v", ctop[1], WALL_ATLAS_V["cabinet_top"]), ("cabinet bottom v", cbot[1], WALL_ATLAS_V["cabinet_bottom"]),
              ("left end u", left[3], 0.0), ("right end u", right[3], 1.0)]
    for label, got, want in checks:
        if abs(got - want) > 1e-4:
            errors.append("%s is %.4f, expected %.4f" % (label, got, want))
    # Every vertex: u follows the angle around the arc (x across the cabinet), v follows the height.
    end = math.radians(float(ex.get("wall_end_deg", 67.0)))
    y_top, y_bot = top[0], bot[0]
    worst_uv = 0.0
    for y, v, x, u, z in wall_v:
        want_u = (math.atan2(x, cz - z) + end) / (2 * end)
        want_v = (y_top - y) / (y_top - y_bot) * WALL_ATLAS_V["wall_bottom"]
        worst_uv = max(worst_uv, abs(u - want_u), abs(v - want_v))
    half_w = (r * r - (cz - cab_z) ** 2) ** 0.5
    for (x, y, z), (u, v) in zip(pos, uv):
        if abs(z - cab_z) < 1e-4 and y < -0.025:
            want_u = (x + half_w) / (2 * half_w)
            want_v = WALL_ATLAS_V["cabinet_top"] + (ctop[0] - y) / (ctop[0] - cbot[0]) * (1.0 - WALL_ATLAS_V["cabinet_top"])
            worst_uv = max(worst_uv, abs(u - want_u), abs(v - want_v))
    if worst_uv > 1e-4:
        errors.append("UV0 does not follow the atlas layout (worst error %.5f)" % worst_uv)
    checks.append(("worst per-vertex UV error", worst_uv, 0.0))
    print("file:", path, os.path.getsize(path), "bytes")
    print("Kitchen_Wall: %d verts, %d tris, material %s, wall y %.3f..%.3f, x %.3f..%.3f, cabinet y %.3f..%.3f at z %.2f"
          % (len(pos), tris, mat, bot[0], top[0], left[2], right[2], cbot[0], ctop[0], cab_z))
    print("UV0: " + ", ".join("%s %.4f" % (lbl, got) for lbl, got, _ in checks))
    print("extras: " + ", ".join("%s=%s" % (k, ex[k]) for k in WALL_EXTRAS if k in ex))
    jar = os.path.abspath(DEFAULT)
    if os.path.exists(jar):
        jg, _ = load(jar)
        jn = {nd.get("name"): nd for nd in jg["nodes"]}

        def node_tris(name):
            if name not in jn:
                return 0
            return sum(jg["accessors"][pr["indices"]]["count"] // 3 for pr in jg["meshes"][jn[name]["mesh"]]["primitives"])
        base = sum(node_tris(nm) for nm in VISIBLE_BASE)
        worst = base + max(node_tris(c) for c in COVERS) + tris
        print("visible scene with this wall, heaviest cover: %d tris (budget %d)"
              % (worst, VISIBLE_BUDGET))
        if worst > VISIBLE_BUDGET:
            errors.append("visible scene with the wall is %d tris, over %d" % (worst, VISIBLE_BUDGET))
    if errors:
        print("FAIL")
        for e in errors:
            print("  -", e)
        sys.exit(1)
    print("PASS: kitchen wall node, identity transform, one surface, inward normals, atlas UVs, extras, budgets")


# Places (§19): places.glb holds the proofing box. The jar root never moves, so the box must stand
# on the counter around the jar without touching it, under the visible budget with the jar and wall.
BOX_TRI_BUDGET = 1500
BOX_EXTRAS = ("texture", "inner_half_width_m", "inner_back_z_m", "front_z_m", "wall_top_m", "floor_top_m",
              "footprint_m", "night_mult")
JAR_CLEAR_R = 0.055        # nothing of the box above its heat plate comes closer to the jar axis
PLATE_TOP_MAX = 0.002      # the jar root stays at y = 0: the plate under it is at most 2 mm


def verify_places(path, g, binary):
    errors = []
    by_name = {n.get("name"): n for n in g["nodes"]}
    extra = sorted(set(by_name) - {"Place_Proofing_Box"})
    if extra:
        errors.append("unexpected nodes: " + ", ".join(extra))
    n = by_name["Place_Proofing_Box"]
    if any(k in n for k in ("rotation", "scale", "matrix")):
        errors.append("Place_Proofing_Box has rotation/scale/matrix (must be identity)")
    if any(abs(c) > 1e-9 for c in n.get("translation", [0.0, 0.0, 0.0])):
        errors.append("Place_Proofing_Box origin must be (0, 0, 0), the jar axis on the counter top")
    ex = n.get("extras", {})
    for k in BOX_EXTRAS:
        if k not in ex:
            errors.append("Place_Proofing_Box extras has no " + k)
    prims = g["meshes"][n["mesh"]]["primitives"]
    if len(prims) != 1:
        errors.append("Place_Proofing_Box has %d surfaces, expected 1 (one draw call)" % len(prims))
    p = prims[0]
    a = p["attributes"]
    mat = g["materials"][p["material"]]["name"] if "material" in p else None
    if mat != "M_Proofing_Box":
        errors.append("material is %s, expected M_Proofing_Box" % mat)
    if g.get("images") or g.get("textures"):
        errors.append("the GLB embeds images; the box texture ships as a separate PNG")
    for attr in ("NORMAL", "TEXCOORD_0"):
        if attr not in a:
            errors.append("Place_Proofing_Box has no " + attr)
    tris = g["accessors"][p["indices"]]["count"] // 3
    if tris > BOX_TRI_BUDGET:
        errors.append("Place_Proofing_Box has %d tris, budget %d" % (tris, BOX_TRI_BUDGET))
    pos = read_floats(g, binary, a["POSITION"])
    uv = read_floats(g, binary, a["TEXCOORD_0"])
    if min(c for t in uv for c in t) < -1e-6 or max(c for t in uv for c in t) > 1 + 1e-6:
        errors.append("UV0 outside 0..1")
    ymin = min(q[1] for q in pos)
    if ymin < -1e-6:
        errors.append("the box reaches below the counter top (y %.4f)" % ymin)
    plate_top = float(ex.get("floor_top_m", 1.0))
    near = [q for q in pos if q[1] > plate_top + 1e-4 and (q[0] ** 2 + q[2] ** 2) ** 0.5 < JAR_CLEAR_R]
    if near:
        errors.append("%d vertices above the floor within %.3f m of the jar axis" % (len(near), JAR_CLEAR_R))
    # The floor the jar stands on is the heat plate: every vertex near the axis at floor height.
    under = [q[1] for q in pos if (q[0] ** 2 + q[2] ** 2) ** 0.5 < 0.30 and q[1] < 0.005 and q[2] < 0.06]
    if under and max(under) > plate_top + 1e-4 and max(under) > PLATE_TOP_MAX:
        errors.append("geometry under the jar reaches %.4f m" % max(under))
    if plate_top > PLATE_TOP_MAX:
        errors.append("the floor under the jar is %.4f m high; the jar root stays at 0" % plate_top)
    lo = [min(q[i] for q in pos) for i in range(3)]
    hi = [max(q[i] for q in pos) for i in range(3)]
    print("file:", path, os.path.getsize(path), "bytes")
    print("Place_Proofing_Box: %d verts, %d tris, material %s, bounds x %.3f..%.3f, y %.4f..%.3f, z %.3f..%.3f, "
          "floor under the jar %.4f m" % (len(pos), tris, mat, lo[0], hi[0], lo[1], hi[1], lo[2], hi[2], plate_top))
    print("extras: " + ", ".join("%s=%s" % (k, ex[k]) for k in BOX_EXTRAS if k in ex))
    jar = os.path.abspath(DEFAULT)
    wall = os.path.join(os.path.dirname(jar), "kitchen_wall.glb")
    if os.path.exists(jar) and os.path.exists(wall):
        jg, _ = load(jar)
        jn = {nd.get("name"): nd for nd in jg["nodes"]}
        wg, _ = load(wall)

        def node_tris(gg, nodes, name):
            if name not in nodes:
                return 0
            return sum(gg["accessors"][pr["indices"]]["count"] // 3 for pr in gg["meshes"][nodes[name]["mesh"]]["primitives"])
        base = sum(node_tris(jg, jn, nm) for nm in VISIBLE_BASE)
        wall_tris = node_tris(wg, {nd.get("name"): nd for nd in wg["nodes"]}, "Kitchen_Wall")
        worst = base + max(node_tris(jg, jn, c) for c in COVERS) + wall_tris + tris
        print("visible scene in the proofing box (jar, heaviest cover, wall, box): %d tris (budget %d)"
              % (worst, VISIBLE_BUDGET))
        if worst > VISIBLE_BUDGET:
            errors.append("visible scene with the box is %d tris, over %d" % (worst, VISIBLE_BUDGET))
    if errors:
        print("FAIL")
        for e in errors:
            print("  -", e)
        sys.exit(1)
    print("PASS: places node, identity transform, one surface, UVs, extras, clear of the jar, budgets")


def main():
    path = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else DEFAULT)
    g, binary = load(path)
    if any(n.get("name") == "Kitchen_Wall" for n in g["nodes"]):
        verify_wall(path, g, binary)
        return
    if any(n.get("name") == "Place_Proofing_Box" for n in g["nodes"]):
        verify_places(path, g, binary)
        return
    acc = g["accessors"]
    errors = []
    total_tris = 0
    tris_by_node = {}
    print("file:", path, os.path.getsize(path), "bytes")
    print("%-22s %-28s %6s %6s %s" % ("node", "translation (m, +Y up)", "verts", "tris", "notes"))
    by_name = {n.get("name"): n for n in g["nodes"]}
    for name in list(MESH_NODES) + list(EMPTY_NODES):
        n = by_name.get(name)
        if n is None:
            errors.append("missing node " + name)
            continue
        if any(k in n for k in ("rotation", "scale", "matrix")):
            errors.append("%s has rotation/scale/matrix (must be identity)" % name)
        t = n.get("translation", [0.0, 0.0, 0.0])
        notes = []
        verts = tris = 0
        if name in MESH_NODES:
            want_surf, want_uv2 = MESH_NODES[name]
            mesh = g["meshes"][n["mesh"]]
            prims = mesh["primitives"]
            if len(prims) != want_surf:
                errors.append("%s has %d surfaces, expected %d" % (name, len(prims), want_surf))
            mats = [g["materials"][p["material"]]["name"] for p in prims if "material" in p]
            notes.append("mats=" + ",".join(mats))
            lo = [1e9] * 3
            hi = [-1e9] * 3
            for p in prims:
                a = p["attributes"]
                verts += acc[a["POSITION"]]["count"]
                tris += acc[p["indices"]]["count"] // 3
                for i in range(3):
                    lo[i] = min(lo[i], acc[a["POSITION"]]["min"][i])
                    hi[i] = max(hi[i], acc[a["POSITION"]]["max"][i])
                if "NORMAL" not in a:
                    errors.append(name + " has no normals")
                if want_uv2:
                    if "TEXCOORD_1" not in a:
                        errors.append(name + " is missing TEXCOORD_1 (UV2)")
                    else:
                        uv2 = read_floats(g, binary, a["TEXCOORD_1"])
                        pos = read_floats(g, binary, a["POSITION"])
                        flat = [c for uv in uv2 for c in uv]
                        if min(flat) < -1e-6 or max(flat) > 1 + 1e-6:
                            errors.append(name + " UV2 outside 0..1")
                        top = max(range(len(pos)), key=lambda i: pos[i][1])
                        low = min(range(len(pos)), key=lambda i: pos[i][1])
                        # Contract, as Godot reads it: UV2.y = 1 on the top cap, 0 at the floor.
                        if uv2[top][1] < 0.999 or uv2[low][1] > 1e-6:
                            errors.append("%s UV2.y orientation wrong (top %.3f, floor %.3f)"
                                          % (name, uv2[top][1], uv2[low][1]))
                        notes.append("uv2.y top=%.2f floor=%.2f" % (uv2[top][1], uv2[low][1]))
                if name == "Starter_Liner":
                    uv0 = read_floats(g, binary, a["TEXCOORD_0"])
                    pos = read_floats(g, binary, a["POSITION"])
                    top = max(range(len(pos)), key=lambda i: pos[i][1])
                    if abs(uv0[top][1] - 1.0) > 1e-4:
                        errors.append("Starter_Liner v at the top is %.3f, expected 1" % uv0[top][1])
                    notes.append("v top=%.3f" % uv0[top][1])
            notes.append("bounds y %.4f..%.4f, r %.4f" % (lo[1], hi[1], max(abs(lo[0]), hi[0])))
            total_tris += tris
            tris_by_node[name] = tris
            budget = TRI_BUDGET.get(name)
            if budget and tris > budget:
                errors.append("%s has %d tris, budget %d" % (name, tris, budget))
        if n.get("extras"):
            notes.append("extras=" + ",".join(sorted(n["extras"])))
        print("%-22s %-28s %6s %6s %s" % (
            name, "(%.4f, %.4f, %.4f)" % tuple(t), verts or "-", tris or "-", "; ".join(notes)))
    extra = sorted(set(by_name) - set(MESH_NODES) - set(EMPTY_NODES))
    if extra:
        errors.append("unexpected nodes: " + ", ".join(extra))
    print("total tris:", total_tris, "(budget %d)" % TRI_BUDGET["_total"])
    base = sum(tris_by_node.get(n, 0) for n in VISIBLE_BASE)
    for cover in COVERS:
        vis = base + tris_by_node.get(cover, 0)
        print("visible with %-14s %6d tris (budget %d)" % (cover + ":", vis, VISIBLE_BUDGET))
        if vis > VISIBLE_BUDGET:
            errors.append("visible set with %s is %d tris, over %d" % (cover, vis, VISIBLE_BUDGET))
    if total_tris > TRI_BUDGET["_total"]:
        errors.append("total tris over budget")
    if errors:
        print("FAIL")
        for e in errors:
            print("  -", e)
        sys.exit(1)
    print("PASS: contract nodes, identity rotation/scale, surfaces, UV2, budgets (all-variants and visible 16k)")


if __name__ == "__main__":
    main()
