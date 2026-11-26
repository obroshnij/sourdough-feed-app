"""Check assets/3d/jar_v0.glb against the mesh contract in docs/art-direction.md.

Plain Python 3, no dependencies:
    python3 art/blender/scripts/verify_glb.py [path/to/file.glb]
Exits 1 if any contract check fails.
"""

import json
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
    "Backdrop_placeholder": (1, False),
}
EMPTY_NODES = ("StarterFloor", "StarterRim")
TRI_BUDGET = {"Jar_Glass": 5000, "Starter_Body": 4000, "_total": 30000}
# architecture.md section 11: the rendered scene is 16k tris or fewer. Only one cover
# shows at a time, so check the base set plus the heaviest cover.
VISIBLE_BASE = ("Jar_Glass", "Starter_Body", "Starter_Liner", "Rubber_Band", "Counter",
                "Backdrop_placeholder")
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


def main():
    path = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else DEFAULT)
    g, binary = load(path)
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
