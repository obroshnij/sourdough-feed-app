"""Sourdough look-dev jar v0. Procedural, headless, re-runnable.

Run from the repo root:
    /Applications/Blender.app/Contents/MacOS/Blender -b -P art/blender/scripts/build_jar.py
Options (after a bare "--"):
    --no-render          build, export and save only
    --states a,b         render only these preview states
    --samples N          Cycles samples per preview (default RENDER_SAMPLES)
    --scale P            resolution percentage (default 100)
    --cover NAME         Jar_Lid_Loose (default), Jar_Lid_Tight or Cloth_Cover
    --out DIR            write renders to DIR instead of art/previews

Writes:
    art/blender/jar_v0.blend
    assets/3d/jar_v0.glb
    art/previews/jar_v0_<state>.png

Everything is built from the parameters below. The script, not the .blend, is
the source of truth: change a number, re-run, done.

Conventions (see docs/art-direction.md, "Mesh contract"):
    meters, real scale. Blender +Z up, exported as glTF +Y up.
    Jar front faces Blender -Y, which is Godot +Z.
    Rotation and scale are identity on every exported object.
    Materials in the GLB are placeholders. Godot replaces them by name.
"""

import math
import os
import sys
import time

import bmesh
import bpy
from mathutils import Vector, noise

# =============================================================================
# PARAMETERS
# =============================================================================

# --- Jar glass (container id: classic_jar) -----------------------------------
# Sized for a fixed 150 g after each feed (fill line ~30 mm) and a 3x rise
# (90 mm) with headroom below the shoulder. Tall and slim reads well in portrait.
SEGMENTS = 48             # around the axis, shared by every lathed part
JAR_OUTER_R = 0.042       # outer radius of the straight body (D 84 mm)
JAR_H = 0.170             # total glass height, base to lip top
WALL = 0.0035             # wall thickness
BASE_T = 0.008            # base thickness (inner floor height)
BASE_CORNER_R = 0.007     # outer bottom fillet
INNER_CORNER_R = 0.004    # inner floor fillet (the starter foot matches it)
PUNT_H = 0.0012           # the base is slightly recessed in the middle
CONTACT_R = 0.033         # radius of the ring that touches the counter
SHOULDER_Z0 = 0.138       # straight body ends here (outer)
SHOULDER_Z1 = 0.150       # neck begins here (outer)
NECK_R = 0.0375           # outer neck radius (mouth inner D 68 mm)
BEAD_Z = 0.1565           # the rolled bead the cloth tie and cap sit against
BEAD_HALF_W = 0.0022
BEAD_OUT = 0.0016

INNER_R = JAR_OUTER_R - WALL
NECK_IN_R = NECK_R - WALL

# --- Starter ------------------------------------------------------------------
FED_LEVEL = 0.030             # starter height right after a feed (150 g, approx.)
STARTER_GAP = 0.0005          # air gap to the glass, avoids z-fighting
STARTER_H = FED_LEVEL         # authored height = fed level, so rise 1.0 = as built
STARTER_FOOT = INNER_CORNER_R # foot top: nothing at or below it ever moves
STARTER_RIM_R = 0.002         # soft meniscus edge where top meets glass
STARTER_SIDE_RINGS = 10
STARTER_CAP_RINGS = 16
STARTER_BOTTOM_RINGS = 2
STARTER_R = INNER_R - STARTER_GAP

# --- Liner (streaks left on the glass) -----------------------------------------
LINER_GAP = 0.00015
LINER_H = 0.125               # top of the liner above the inner floor, below the shoulder
LINER_RINGS = 24
LINER_R = INNER_R - LINER_GAP

# --- Covers (cover ids: loose_lid, tight_lid, cloth) ----------------------------
LID_PLUG_DEPTH = 0.007
LID_R = NECK_R + 0.0035
LID_T = 0.014
LID_KNOB_R = 0.0105
LID_KNOB_H = 0.012
CAP_IN_R = NECK_R + 0.0010
CAP_OUT_R = NECK_R + 0.0030
CAP_SKIRT = 0.011
CLOTH_SIZE = 0.15             # square linen cover; short skirt so the starter stays visible
CLOTH_ROT = math.radians(18)  # turn the square so corners don't face camera
CLOTH_SKIRT_RINGS = 10       # rings from the tie to the hem (top, roll and neck rings are fixed)
CLOTH_SEGS = 72          # 11 folds over 72 segments keeps ~6.5 segments per fold
CLOTH_GAP = 0.0008
CLOTH_SAG = 0.0025            # dips into the mouth
CLOTH_ROLL_R = 0.0025         # rolls over the lip
CLOTH_BAND_Z = BEAD_Z - BEAD_HALF_W - 0.0016   # tied just under the bead
CLOTH_FOLDS = 11
CLOTH_FOLD_AMP = 0.0055
CLOTH_THICKNESS = 0.0007      # render-only solidify; the GLB is single sided
TWINE_R = 0.0011

# --- Rubber band: the baker's "level at last feed" marker -----------------------
BAND_T = 0.0016
BAND_H = 0.0045

# --- Environment ----------------------------------------------------------------
COUNTER_X = 2.20              # full width. Reaches under the curved kitchen wall's ends (x +-1.01 m,
                              # bake_kitchen_wall.py) so no orbit pose sees past the counter (§18)
COUNTER_FRONT_Y = -0.24
COUNTER_BACK_Y = 0.45
COUNTER_T = 0.035
BACKDROP_W = 1.0
BACKDROP_H = 0.70

# --- Colors (sRGB hex, see docs/art-direction.md palette) ------------------------
C = {
    "glass_tint":   "#FAFDFB",   # faint soda-lime green; compounds over 4 crossings
    "starter":      {"white_bread": "#F0E3C9", "whole_wheat": "#DCC29C",
                     "rye": "#BE9F7E", "spelt": "#E3CCA6"},
    "pocket":       "#D3BF9E",   # inside a bubble, seen through the glass
    "hooch":        "#8A7860",   # gray-brown, translucent-looking liquid
    "hooch_dark":   "#5A5045",   # long-sitting, thick hooch (unhealthy)
    "crust":        "#CDBB98",   # dull dry skin
    "bran":         "#8A6A48",   # whole wheat flecks
    "mold_halo":    "#F4F4EE",   # fuzzy white rim of a colony
    "mold_core":    "#2F7465",   # blue-green center
    "mold_mid":     "#8FB0A2",   # gray-green ring between core and halo
    "mold_spore":   "#1F2A27",   # dark spore dots
    "lid_wood_lt":  "#AD9670",   # oiled oak, kept low-chroma: no orange near the jar
    "lid_wood_dk":  "#6E5B3F",
    "enamel":       "#EFE7D8",
    "linen":        "#E6DCCA",
    "linen_stripe": "#8E9F86",
    "twine":        "#B79C74",
    "band":         "#5F7458",
    "counter_lt":   "#D2C09E",   # pale oak butcher block
    "counter_dk":   "#B19B76",
    "tile_a":       "#A3B69F",   # authored greener: warm key light pulls it toward khaki
    "tile_b":       "#97AB91",
    "grout":        "#DCD4C4",
    "world_top":    "#F3E8D8",
    "world_bottom": "#5A554E",   # near-neutral: a brown floor bounce turned the shadow side caramel
}

# --- Preview states (look-dev values; the sim spec drives the real ones) ----------
# rise = level / FED_LEVEL. hooch is liquid depth in meters (sim hooch 1.0 = 1 cm).
# Tells per state come from sourdough-scientist's draft (docs/starter-simulation-spec.md).
_BASE = dict(rise=1.0, dome=0.0, lumps=0.0008, bubble_big=0.1, bubble_small=0.1,
             stretch=0.0, rough=0.36, coat=0.25, streak_top=0.0, streak_age=0.0,
             hooch=0.0, hooch_col="hooch", dryness=0.0, flecks=0.0, mold=0.0,
             flour="white_bread")


def _state(**kw):
    s = dict(_BASE)
    s.update(kw)
    return s


STATES = {
    # Flat, smooth, thick paste, few tiny bubbles.
    "freshly_fed": _state(rise=1.0, dome=0.0010, lumps=0.0026, bubble_big=0.02,
                          bubble_small=0.12, rough=0.48, coat=0.10),
    # Many small and medium bubbles, steady rise, convex top.
    "active":      _state(rise=1.7, dome=0.0045, lumps=0.0014, bubble_big=0.28,
                          bubble_small=0.70, stretch=0.3, rough=0.36, coat=0.25),
    # Tallest, domed, big bubbles at the top, web-like strands through the glass.
    "at_peak":     _state(rise=2.3, dome=0.0080, lumps=0.0016, bubble_big=0.60,
                          bubble_small=0.60, stretch=0.6, rough=0.30, coat=0.35),
    # Top sinks, cream residue ring and streaks above the surface.
    "collapsing":  _state(rise=1.9, dome=-0.0040, lumps=0.0014, bubble_big=0.40,
                          bubble_small=0.35, stretch=0.3, rough=0.27, coat=0.40,
                          streak_top=0.0695),
    # Lower, loose, fewer and bigger holes, thin gray-brown hooch. Old streaks dried.
    "hungry":      _state(rise=1.25, dome=-0.0010, lumps=0.0004, bubble_big=0.18,
                          bubble_small=0.12, rough=0.30, coat=0.45, streak_top=0.0695,
                          streak_age=0.6, hooch=0.0035),
    # Flat and still, few bubbles, hooch common (fridge).
    "dormant":     _state(rise=1.0, dome=0.0, lumps=0.0006, bubble_big=0.04,
                          bubble_small=0.06, rough=0.40, coat=0.20, hooch=0.0050),
    # Warning, recoverable: dull dry skin, thick darker hooch, flat, almost no bubbles.
    # Never fuzz, never pink, orange or red.
    "unhealthy":   _state(rise=0.95, dome=-0.0005, lumps=0.0010, bubble_big=0.02,
                          bubble_small=0.03, rough=0.62, coat=0.0, streak_top=0.060,
                          streak_age=1.0, hooch=0.0040, hooch_col="hooch_dark",
                          dryness=0.85),
    # End state: fuzzy colonies (white halo, blue-green core, dark spores). Discard.
    "moldy":       _state(rise=0.95, dome=-0.0005, lumps=0.0012, bubble_big=0.02,
                          bubble_small=0.02, rough=0.65, coat=0.0, streak_top=0.060,
                          streak_age=1.0, dryness=0.7, mold=0.75),
}
PREVIEW_COVER = "Jar_Lid_Loose"    # which cover is visible in the previews

# --- Render ("preview pose", also the QA reference pose) -----------------------------
RENDER_RES = (720, 1280)   # portrait 9:16
RENDER_SAMPLES = 64
CAM_LENS = 60.0            # 36 mm sensor fit to height: vertical FOV 33.4 degrees
CAM_DIST = 0.58            # meters from target
CAM_ELEV_DEG = 15.0        # pitch down
CAM_TARGET_Z = 0.105       # keeps jar + lid between 24% and 80% of frame height
CAM_FSTOP = 2.4
KEY_W = 3.8               # area light watts; fill, rim and top are ratios of it
WORLD_STRENGTH = 0.30

# --- Mold colonies (render-only geometry fuzz; Godot uses shells, see doc) -----------
MOLD_CELL_SCALE = 30.0     # Voronoi scale on object coords, shared by GN and shader
MOLD_RADIUS = 0.22         # colony radius in Voronoi cell units
MOLD_HAIR_DENSITY = 9.0e6  # hairs per m2 inside colonies
MOLD_HAIR_LEN = 0.0024
MOLD_CUSHION = 0.0035      # colonies swell this much above the surface at mold = 1
MOLD_GLASS_SCALE = 48.0    # colonies on the glass above the surface (liner)
MOLD_GLASS_RADIUS = 0.38

# =============================================================================
# PATHS
# =============================================================================
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
BLEND_OUT = os.path.join(REPO, "art", "blender", "jar_v0.blend")
GLB_OUT = os.path.join(REPO, "assets", "3d", "jar_v0.glb")
PREVIEW_DIR = os.path.join(REPO, "art", "previews")

EXPORT_NAMES = ["Jar_Glass", "Starter_Body", "Starter_Liner", "Jar_Lid_Loose",
                "Jar_Lid_Tight", "Cloth_Cover", "Rubber_Band", "Counter",
                "Backdrop_placeholder", "StarterFloor", "StarterRim"]

EPS = 1e-7
GN_IDS = {}   # GN input name -> socket identifier (kept out of the GLB extras)


# =============================================================================
# SMALL HELPERS
# =============================================================================
def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexcol(h, a=1.0):
    h = h.lstrip("#")
    rgb = [srgb_to_linear(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4)]
    return (rgb[0], rgb[1], rgb[2], a)


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def arc(cx, cz, rad, a0, a1, n):
    pts = []
    for k in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * k / n)
        pts.append((cx + rad * math.cos(a), cz + rad * math.sin(a)))
    return pts


def lerp_pts(a, b, n):
    return [(a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n) for k in range(n + 1)]


def ease_pts(a, b, n):
    """S-curve from a to b with vertical tangents at both ends (shoulders)."""
    return [(a[0] + (b[0] - a[0]) * smooth(k / n), a[1] + (b[1] - a[1]) * k / n)
            for k in range(n + 1)]


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opts = {"render": True, "states": list(STATES), "samples": RENDER_SAMPLES, "scale": 100,
            "cover": PREVIEW_COVER, "out": PREVIEW_DIR}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--no-render":
            opts["render"] = False
        elif a == "--states":
            i += 1
            opts["states"] = [s for s in argv[i].split(",") if s]
        elif a == "--samples":
            i += 1
            opts["samples"] = int(argv[i])
        elif a == "--scale":
            i += 1
            opts["scale"] = int(argv[i])
        elif a == "--cover":          # Jar_Lid_Loose, Jar_Lid_Tight or Cloth_Cover
            i += 1
            opts["cover"] = argv[i]
        elif a == "--out":            # check renders elsewhere, keep the previews intact
            i += 1
            opts["out"] = os.path.abspath(argv[i])
        i += 1
    return opts


# =============================================================================
# MESH BUILDING
# =============================================================================
def lathe(profile, segments=SEGMENTS, closed=False, slot_from=None, phase=math.pi / 2):
    """Revolve a (r, z) profile around +Z.

    r <= EPS makes a pole (triangle fan). UV0: u = angle / 2pi with the seam at
    the back (+Y in Blender, -Z in Godot), v = arc length along the profile, 0..1.
    Faces from profile segment index >= slot_from get material slot 1.
    Returns (bm, seg_layer) where seg_layer stores each face's profile segment.
    """
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    seg_layer = bm.faces.layers.int.new("seg")
    prof = list(profile)
    if closed:
        prof = prof + [prof[0]]
    lengths = [0.0]
    for a, b in zip(prof, prof[1:]):
        lengths.append(lengths[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
    total = lengths[-1] or 1.0

    rings = []
    for idx, (r, z) in enumerate(profile):
        if r <= EPS:
            rings.append([bm.verts.new((0.0, 0.0, z))])
        else:
            ring = []
            for i in range(segments):
                ang = phase + 2.0 * math.pi * i / segments
                ring.append(bm.verts.new((r * math.cos(ang), r * math.sin(ang), z)))
            rings.append(ring)
    if closed:
        rings.append(rings[0])

    for k in range(len(rings) - 1):
        A, B = rings[k], rings[k + 1]
        va, vb = lengths[k] / total, lengths[k + 1] / total
        slot = 1 if (slot_from is not None and k >= slot_from) else 0
        for i in range(segments):
            i2 = (i + 1) % segments
            u0, u1 = i / segments, (i + 1) / segments
            if len(A) == 1 and len(B) == 1:
                continue
            if len(A) == 1:
                verts = [A[0], B[i], B[i2]]
                uvs = [((u0 + u1) * 0.5, va), (u0, vb), (u1, vb)]
            elif len(B) == 1:
                verts = [A[i], A[i2], B[0]]
                uvs = [(u0, va), (u1, va), ((u0 + u1) * 0.5, vb)]
            else:
                verts = [A[i], A[i2], B[i2], B[i]]
                uvs = [(u0, va), (u1, va), (u1, vb), (u0, vb)]
            f = bm.faces.new(verts)
            f.material_index = slot
            f[seg_layer] = k
            for loop, t in zip(f.loops, uvs):
                loop[uv].uv = t
    return bm, seg_layer


def orient_normals(bm, outward_test):
    """outward_test(face) -> True if the face already points the right way."""
    bm.normal_update()
    good = sum(1 for f in bm.faces if outward_test(f))
    if good < len(bm.faces) / 2:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    bm.normal_update()


def make_object(name, bm, coll, location=(0, 0, 0), sharp_angle=None, mats=()):
    for layer in list(bm.faces.layers.int):
        bm.faces.layers.int.remove(layer)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.shade_smooth()
    if sharp_angle is not None:
        me.set_sharp_from_angle(angle=math.radians(sharp_angle))
    for m in mats:
        me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    ob.location = location
    coll.objects.link(ob)
    return ob


# --- Jar_Glass ------------------------------------------------------------------
def glass_profile():
    """Closed cross-section of the glass: outer base -> lip -> inner floor.

    Returns (points, lip_top_index). Faces before lip_top are surface 0 (M_Glass),
    after it surface 1 (M_Glass_Inner). Straight runs get one extra ring only.
    """
    P = [(0.0, PUNT_H)]
    for k in range(1, 3):
        t = k / 2.0
        P.append((CONTACT_R * t, PUNT_H * (1.0 - smooth(t))))
    cx = JAR_OUTER_R - BASE_CORNER_R
    if cx > CONTACT_R + 1e-4:
        P.append((cx, 0.0))
    P += arc(cx, BASE_CORNER_R, BASE_CORNER_R, -90, 0, 4)[1:]
    P += lerp_pts((JAR_OUTER_R, BASE_CORNER_R), (JAR_OUTER_R, SHOULDER_Z0), 2)[1:]
    P += ease_pts((JAR_OUTER_R, SHOULDER_Z0), (NECK_R, SHOULDER_Z1), 6)[1:]
    P.append((NECK_R, BEAD_Z - BEAD_HALF_W))
    for k in range(1, 5):
        t = k / 5.0
        P.append((NECK_R + BEAD_OUT * math.sin(math.pi * t),
                  BEAD_Z - BEAD_HALF_W + 2.0 * BEAD_HALF_W * t))
    P.append((NECK_R, BEAD_Z + BEAD_HALF_W))
    P.append((NECK_R, JAR_H - WALL / 2.0))
    lip = arc(NECK_R - WALL / 2.0, JAR_H - WALL / 2.0, WALL / 2.0, 0, 180, 6)[1:]
    lip_top = len(P) + 2           # the 90 degree point of the lip
    P += lip
    P.append((NECK_IN_R, SHOULDER_Z1 - 0.0008))
    P += ease_pts((NECK_IN_R, SHOULDER_Z1 - 0.0008), (INNER_R, SHOULDER_Z0 - 0.0010), 6)[1:]
    P += lerp_pts((INNER_R, SHOULDER_Z0 - 0.0010), (INNER_R, BASE_T + INNER_CORNER_R), 2)[1:]
    icx = INNER_R - INNER_CORNER_R
    P += arc(icx, BASE_T + INNER_CORNER_R, INNER_CORNER_R, 0, -90, 4)[1:]
    P += [(icx * 0.5, BASE_T), (0.0, BASE_T)]
    return P, lip_top


def jar_outer_r(z):
    """Outer glass radius at height z (used to keep the cloth off the glass)."""
    prof, lip_top = glass_profile()
    outer = [p for p in prof[3:lip_top + 1]]
    best = JAR_OUTER_R
    for (r0, z0), (r1, z1) in zip(outer, outer[1:]):
        if min(z0, z1) <= z <= max(z0, z1) and abs(z1 - z0) > EPS:
            t = (z - z0) / (z1 - z0)
            return r0 + (r1 - r0) * t
    if z > JAR_H:
        return 0.0
    return best


def build_glass(coll, mats):
    prof, lip_top = glass_profile()
    bm, _ = lathe(prof, slot_from=lip_top)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    ob = make_object("Jar_Glass", bm, coll, sharp_angle=None, mats=mats)
    ob["inner_radius_m"] = INNER_R
    ob["outer_radius_m"] = JAR_OUTER_R
    ob["height_m"] = JAR_H
    ob["wall_m"] = WALL
    ob["floor_y_m"] = BASE_T
    return ob


# --- Starter_Body ----------------------------------------------------------------
def starter_stretch(z):
    """UV2.y: 0 at and below the foot top, 1 from the rim arc up, linear between."""
    lo, hi = STARTER_FOOT, STARTER_H - STARTER_RIM_R
    return max(0.0, min(1.0, (z - lo) / (hi - lo)))


def build_starter(coll, mats):
    """Closed starter body. Origin = inner floor center.

    The foot is concentric with the glass inner corner, offset by STARTER_GAP,
    so it never pokes through rounded glass. Only vertices above the foot move.
    """
    R, H, rr, g = STARTER_R, STARTER_H, STARTER_RIM_R, STARTER_GAP
    icx = INNER_R - INNER_CORNER_R          # foot arc center (same as the glass)
    P = [(0.0, g)]
    for k in range(1, STARTER_BOTTOM_RINGS + 1):
        P.append((icx * k / STARTER_BOTTOM_RINGS, g))
    P += arc(icx, INNER_CORNER_R, INNER_CORNER_R - g, -90, 0, 4)[1:]   # ends (R, foot)
    n_bottom = len(P) - 1                    # segments before this are floor + foot
    for j in range(1, STARTER_SIDE_RINGS + 1):
        P.append((R, STARTER_FOOT + (H - rr - STARTER_FOOT) * j / STARTER_SIDE_RINGS))
    P += arc(R - rr, H - rr, rr, 0, 90, 4)[1:]
    n_strip_end = len(P) - 1                 # segments up to here are side + rim
    for k in range(1, STARTER_CAP_RINGS + 1):
        P.append(((R - rr) * (1.0 - k / STARTER_CAP_RINGS), H))

    bm, seg = lathe(P)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    uv0 = bm.loops.layers.uv["UVMap"]
    uv2 = bm.loops.layers.uv.new("UV2_Shape")
    lengths = [0.0]
    for a, b in zip(P, P[1:]):
        lengths.append(lengths[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
    total = lengths[-1]
    s0, s1 = lengths[n_bottom] / total, lengths[n_strip_end] / total
    for f in bm.faces:
        k = f[seg]
        for loop in f.loops:
            co = loop.vert.co
            rad = min(1.0, math.hypot(co.x, co.y) / R)
            # glTF flips V on export; store 1 - value so Godot reads the contract value.
            loop[uv2].uv = (rad, 1.0 - starter_stretch(co.z))
            if k < n_bottom:        # floor + foot: disc at lower right of the atlas
                loop[uv0].uv = (0.75 + 0.24 * co.x / R, 0.75 + 0.24 * co.y / R)
            elif k >= n_strip_end:  # top cap: disc at upper left
                loop[uv0].uv = (0.25 + 0.24 * co.x / R, 0.75 + 0.24 * co.y / R)
            else:                   # side + rim: strip across the bottom half
                u, v = loop[uv0].uv
                loop[uv0].uv = (u, 0.5 * (v - s0) / (s1 - s0))
    ob = make_object("Starter_Body", bm, coll, location=(0, 0, BASE_T),
                     sharp_angle=None, mats=mats)
    ob["inner_radius_m"] = INNER_R
    ob["starter_radius_m"] = R
    ob["starter_authored_height_m"] = H
    ob["starter_foot_top_m"] = STARTER_FOOT
    ob["floor_y_m"] = BASE_T
    ob["uv2"] = ("x = radial 0 center..1 wall; y = stretch weight, 0 at/below the "
                 "foot top, 1 on rim and cap")
    return ob


def _sock(sockets, name, kind=None):
    """Pick a socket by name and, for multi-type nodes, by type (VALUE, VECTOR...)."""
    for s in sockets:
        if s.name == name and (kind is None or s.type == kind):
            return s
    raise KeyError("%s/%s" % (name, kind))


def add_starter_shape_modifier(ob, mold_mat):
    """Geometry Nodes twin of the Godot starter vertex shader. Same math, same names.

        w   = UV2.y * (1 - UV2.x^2)                      # 0 on side, floor, foot
        y'  = y + UV2.y * (level - authored_h) + w * (dome + lumps * (noise - 0.5))

    Plus render-only mold fuzz (curves) when Mold > 0. The GLB is exported from the
    raw mesh, so none of this reaches Godot.
    """
    ng = bpy.data.node_groups.new("GN_StarterShape", "GeometryNodeTree")
    if hasattr(ng, "is_modifier"):
        ng.is_modifier = True
    it = ng.interface
    it.new_socket("Geometry", in_out="INPUT", socket_type="NodeSocketGeometry")
    sockets = {}
    for nm, default in (("Level", STARTER_H), ("Dome", 0.0), ("Lumps", 0.0), ("Mold", 0.0)):
        s = it.new_socket(nm, in_out="INPUT", socket_type="NodeSocketFloat")
        s.default_value = default
        sockets[nm] = s
    it.new_socket("Geometry", in_out="OUTPUT", socket_type="NodeSocketGeometry")
    N, L = ng.nodes, ng.links

    def put(sock, val):
        if isinstance(val, bpy.types.NodeSocket):
            L.new(val, sock)
        elif val is not None:
            sock.default_value = val

    def m(op, a, b=None):
        n = N.new("ShaderNodeMath")
        n.operation = op
        put(n.inputs[0], a)
        if b is not None:
            put(n.inputs[1], b)
        return n.outputs[0]

    gin = N.new("NodeGroupInput")
    gout = N.new("NodeGroupOutput")
    attr = N.new("GeometryNodeInputNamedAttribute")
    attr.data_type = "FLOAT_VECTOR"
    attr.inputs["Name"].default_value = "UV2_Shape"
    sep = N.new("ShaderNodeSeparateXYZ")
    L.new(_sock(attr.outputs, "Attribute"), sep.inputs[0])
    pos = N.new("GeometryNodeInputPosition")
    psep = N.new("ShaderNodeSeparateXYZ")
    L.new(pos.outputs[0], psep.inputs[0])
    nz = N.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 70.0
    nz.inputs["Detail"].default_value = 2.0

    rad, stretch = sep.outputs[0], m("SUBTRACT", 1.0, sep.outputs[1])   # undo the V pre-flip
    w_cap = m("MULTIPLY", stretch, m("SUBTRACT", 1.0, m("MULTIPLY", rad, rad)))
    lump = m("MULTIPLY", m("SUBTRACT", nz.outputs["Fac"], 0.5), gin.outputs["Lumps"])
    top = m("MULTIPLY", w_cap, m("ADD", gin.outputs["Dome"], lump))
    grow = m("MULTIPLY", stretch, m("SUBTRACT", gin.outputs["Level"], STARTER_H))
    z = m("ADD", m("ADD", psep.outputs[2], grow), top)
    # Mold cushions: colonies swell above the surface (cells on flattened XY).
    flat = N.new("ShaderNodeCombineXYZ")
    L.new(psep.outputs[0], flat.inputs[0])
    L.new(psep.outputs[1], flat.inputs[1])
    cv = N.new("ShaderNodeTexVoronoi")
    cv.voronoi_dimensions = "3D"
    L.new(flat.outputs[0], cv.inputs["Vector"])
    cv.inputs["Scale"].default_value = MOLD_CELL_SCALE
    crgb = N.new("FunctionNodeSeparateColor")
    L.new(cv.outputs["Color"], crgb.inputs[0])
    swell = N.new("ShaderNodeMath")
    swell.operation = "DIVIDE"
    swell.use_clamp = True
    L.new(m("SUBTRACT", MOLD_RADIUS, cv.outputs["Distance"]), swell.inputs[0])
    swell.inputs[1].default_value = MOLD_RADIUS * 0.45
    cushion = m("MULTIPLY", m("MULTIPLY", swell.outputs[0], m("LESS_THAN", crgb.outputs[0], gin.outputs["Mold"])),
                m("MULTIPLY", w_cap, m("MULTIPLY", gin.outputs["Mold"], MOLD_CUSHION / 0.75)))
    z = m("ADD", z, cushion)
    comb = N.new("ShaderNodeCombineXYZ")
    L.new(psep.outputs[0], comb.inputs[0])
    L.new(psep.outputs[1], comb.inputs[1])
    L.new(z, comb.inputs[2])
    setp = N.new("GeometryNodeSetPosition")
    L.new(gin.outputs["Geometry"], setp.inputs["Geometry"])
    L.new(comb.outputs[0], setp.inputs["Position"])
    shaped = setp.outputs[0]

    try:
        fuzz = _mold_fuzz(N, L, m, put, shaped, gin.outputs["Mold"], mold_mat)
        join = N.new("GeometryNodeJoinGeometry")
        L.new(shaped, join.inputs[0])
        L.new(fuzz, join.inputs[0])
        L.new(join.outputs[0], gout.inputs["Geometry"])
    except Exception as exc:   # keep the build alive; mold then is shader-only
        print("MOLD FUZZ DISABLED:", exc)
        L.new(shaped, gout.inputs["Geometry"])

    mod = ob.modifiers.new("StarterShape", "NODES")
    mod.node_group = ng
    GN_IDS.update({k: s.identifier for k, s in sockets.items()})
    return mod


def _mold_fuzz(N, L, m, put, geo, mold, mold_mat):
    """Hairs on the top cap inside Voronoi colonies (same cells as the shader)."""
    attr = N.new("GeometryNodeInputNamedAttribute")
    attr.data_type = "FLOAT_VECTOR"
    attr.inputs["Name"].default_value = "UV2_Shape"
    sep = N.new("ShaderNodeSeparateXYZ")
    L.new(_sock(attr.outputs, "Attribute"), sep.inputs[0])
    on_cap = m("MULTIPLY", m("LESS_THAN", sep.outputs[1], 0.005),     # stretch > 0.995
               m("LESS_THAN", sep.outputs[0], 0.90))
    dist = N.new("GeometryNodeDistributePointsOnFaces")
    dist.distribute_method = "RANDOM"
    L.new(geo, dist.inputs["Mesh"])
    put(dist.inputs["Selection"], on_cap)
    dist.inputs["Density"].default_value = MOLD_HAIR_DENSITY
    dist.inputs["Seed"].default_value = 7

    pos = N.new("GeometryNodeInputPosition")
    pxyz = N.new("ShaderNodeSeparateXYZ")
    L.new(pos.outputs[0], pxyz.inputs[0])
    flat = N.new("ShaderNodeCombineXYZ")
    L.new(pxyz.outputs[0], flat.inputs[0])
    L.new(pxyz.outputs[1], flat.inputs[1])
    vor = N.new("ShaderNodeTexVoronoi")
    vor.voronoi_dimensions = "3D"
    vor.feature = "F1"
    L.new(flat.outputs[0], vor.inputs["Vector"])
    vor.inputs["Scale"].default_value = MOLD_CELL_SCALE
    rgb = N.new("FunctionNodeSeparateColor")
    L.new(vor.outputs["Color"], rgb.inputs[0])
    jitter = N.new("FunctionNodeRandomValue")
    jitter.data_type = "FLOAT"
    _sock(jitter.inputs, "Min", "VALUE").default_value = -0.05
    _sock(jitter.inputs, "Max", "VALUE").default_value = 0.05
    inside = m("LESS_THAN", vor.outputs["Distance"],
               m("ADD", MOLD_RADIUS, _sock(jitter.outputs, "Value", "VALUE")))
    alive = m("LESS_THAN", rgb.outputs[0], mold)
    keep = m("MULTIPLY", inside, alive)
    dele = N.new("GeometryNodeDeleteGeometry")
    dele.domain = "POINT"
    L.new(dist.outputs["Points"], dele.inputs["Geometry"])
    L.new(m("LESS_THAN", keep, 0.5), dele.inputs["Selection"])

    line = N.new("GeometryNodeCurvePrimitiveLine")
    line.inputs["Start"].default_value = (0.0, 0.0, 0.0)
    line.inputs["End"].default_value = (0.0, 0.0, MOLD_HAIR_LEN)
    inst = N.new("GeometryNodeInstanceOnPoints")
    L.new(dele.outputs[0], inst.inputs["Points"])
    L.new(line.outputs[0], inst.inputs["Instance"])
    L.new(dist.outputs["Rotation"], inst.inputs["Rotation"])
    scl = N.new("FunctionNodeRandomValue")
    scl.data_type = "FLOAT"
    _sock(scl.inputs, "Min", "VALUE").default_value = 0.35
    _sock(scl.inputs, "Max", "VALUE").default_value = 1.25
    L.new(_sock(scl.outputs, "Value", "VALUE"), inst.inputs["Scale"])
    tilt = N.new("FunctionNodeRandomValue")
    tilt.data_type = "FLOAT_VECTOR"
    _sock(tilt.inputs, "Min", "VECTOR").default_value = (-0.8, -0.8, -3.1)
    _sock(tilt.inputs, "Max", "VECTOR").default_value = (0.8, 0.8, 3.1)
    rot = N.new("GeometryNodeRotateInstances")
    L.new(inst.outputs[0], rot.inputs["Instances"])
    L.new(_sock(tilt.outputs, "Value", "VECTOR"), rot.inputs["Rotation"])
    real = N.new("GeometryNodeRealizeInstances")
    L.new(rot.outputs[0], real.inputs[0])
    rad = N.new("GeometryNodeSetCurveRadius")
    L.new(real.outputs[0], rad.inputs["Curve"])
    rad.inputs["Radius"].default_value = 0.00004
    mat = N.new("GeometryNodeSetMaterial")
    L.new(rad.outputs[0], mat.inputs["Geometry"])
    mat.inputs["Material"].default_value = mold_mat
    return mat.outputs[0]


def set_starter_shape(ob, level, dome, lumps, mold):
    mod = ob.modifiers["StarterShape"]
    ids = GN_IDS
    values = {"Level": level, "Dome": dome, "Lumps": lumps, "Mold": mold}
    for key, val in values.items():
        if hasattr(mod, "properties"):          # Blender 5.x interface
            getattr(mod.properties.inputs, ids[key]).value = val
        else:                                   # Blender 4.x id-properties
            mod[ids[key]] = val
    ob.update_tag()


# --- Starter_Liner --------------------------------------------------------------
def build_liner(coll, mats):
    """Open cylinder from the foot top to LINER_H. UV v = height above floor / LINER_H."""
    z0 = STARTER_FOOT
    P = [(LINER_R, z0 + (LINER_H - z0) * j / LINER_RINGS) for j in range(LINER_RINGS + 1)]
    bm, _ = lathe(P)
    uv = bm.loops.layers.uv["UVMap"]
    for f in bm.faces:
        for loop in f.loops:
            loop[uv].uv = (loop[uv].uv[0], 1.0 - loop.vert.co.z / LINER_H)   # Godot: v = height

    def outward(f):
        c = f.calc_center_median()
        return f.normal.dot(Vector((c.x, c.y, 0.0))) > 0

    orient_normals(bm, outward)
    ob = make_object("Starter_Liner", bm, coll, location=(0, 0, BASE_T), mats=mats)
    ob["liner_height_m"] = LINER_H
    ob["floor_y_m"] = BASE_T
    ob["double_sided"] = True
    ob["uv"] = "u = angle, v = height above inner floor / liner_height_m"
    return ob


def build_empties(coll):
    """Fallback anchors in case extras are lost: floor center and liner top at the wall."""
    out = {}
    for name, loc in (("StarterFloor", (0.0, 0.0, BASE_T)),
                      ("StarterRim", (INNER_R, 0.0, BASE_T + LINER_H))):
        e = bpy.data.objects.new(name, None)
        e.empty_display_type = "PLAIN_AXES"
        e.empty_display_size = 0.01
        e.location = loc
        coll.objects.link(e)
        out[name] = e
    return out


# --- Covers -----------------------------------------------------------------------
def build_lid_loose(coll, mats):
    """Turned acacia lid with a plug that sits inside the mouth. Origin = rim top."""
    rp = NECK_IN_R - 0.0008
    P = [(0.0, -LID_PLUG_DEPTH), (rp * 0.5, -LID_PLUG_DEPTH)]
    P += arc(rp - 0.0012, -LID_PLUG_DEPTH + 0.0012, 0.0012, -90, 0, 3)[1:]
    P += [(rp, -0.0008)]
    P += arc(rp + 0.0008, -0.0008, 0.0008, 180, 90, 2)[1:]
    P += [(LID_R - 0.002, 0.0)]
    P += arc(LID_R - 0.002, 0.002, 0.002, -90, 0, 3)[1:]
    P += [(LID_R, LID_T - 0.004)]
    P += arc(LID_R - 0.004, LID_T - 0.004, 0.004, 0, 90, 5)[1:]
    P += [(LID_KNOB_R + 0.004, LID_T + 0.0006)]
    P += arc(LID_KNOB_R + 0.0015, LID_T + 0.0021, 0.0015, -90, -180, 3)[1:]
    P += [(LID_KNOB_R, LID_T + LID_KNOB_H - 0.004)]
    P += arc(LID_KNOB_R - 0.004, LID_T + LID_KNOB_H - 0.004, 0.004, 0, 90, 4)[1:]
    P += [(LID_KNOB_R * 0.45, LID_T + LID_KNOB_H + 0.0003), (0.0, LID_T + LID_KNOB_H + 0.0005)]
    bm, _ = lathe(P)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return make_object("Jar_Lid_Loose", bm, coll, location=(0, 0, JAR_H),
                       sharp_angle=50, mats=mats)


def build_lid_tight(coll, mats):
    """Cream enamel screw cap. Origin = rim top."""
    top_in, top_out = 0.0003, 0.0012
    P = [(0.0, top_out + 0.0006), (0.036, top_out + 0.0006)]
    P += arc(0.036, top_out + 0.0002, 0.0004, 90, 0, 2)[1:]
    P += [(0.0372, top_out)]
    P += [(CAP_OUT_R - 0.0015, top_out)]
    P += arc(CAP_OUT_R - 0.0015, top_out - 0.0015, 0.0015, 90, 0, 4)[1:]
    P += [(CAP_OUT_R, -CAP_SKIRT + 0.0005)]
    P += arc((CAP_OUT_R + CAP_IN_R) / 2, -CAP_SKIRT + 0.0005, (CAP_OUT_R - CAP_IN_R) / 2,
             0, -180, 5)[1:]
    P += [(CAP_IN_R, top_in), (0.0, top_in)]
    bm, _ = lathe(P)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return make_object("Jar_Lid_Tight", bm, coll, location=(0, 0, JAR_H),
                       sharp_angle=55, mats=mats)


def cloth_point(d, theta, k_noise):
    """Drape a flat cloth point (distance d from center, angle theta)."""
    r_top = NECK_R + CLOTH_GAP + 0.0005
    rr = CLOTH_ROLL_R
    z_top = JAR_H + CLOTH_GAP
    flat_r = r_top - rr
    roll_len = 0.5 * math.pi * rr
    if d <= flat_r:
        z = z_top - CLOTH_SAG * (1.0 - (d / flat_r) ** 2)
        r = d
        fold = 0.0
    elif d <= flat_r + roll_len:
        a = (d - flat_r) / rr
        r = flat_r + rr * math.sin(a)
        z = z_top - rr + rr * math.cos(a)
        fold = 0.0
    else:
        s = d - flat_r - roll_len
        s_band = (z_top - rr) - CLOTH_BAND_Z
        if s <= s_band:
            z = z_top - rr - s
            r = r_top
            fold = 0.0006 * (s / s_band)
        else:
            s2 = s - s_band
            # Flares out under the band, then hangs nearly straight.
            r = r_top + 0.16 * s2 + 0.42 * 0.018 * (1.0 - math.exp(-s2 / 0.018))
            steps = 12
            z = CLOTH_BAND_Z
            for i in range(steps):
                si = s2 * (i + 0.5) / steps
                drds = 0.16 + 0.42 * math.exp(-si / 0.018)
                z -= math.sqrt(max(0.0, 1.0 - drds * drds)) * s2 / steps
            fold = CLOTH_FOLD_AMP * (1.0 - math.exp(-s2 / 0.012))
            z += 0.0025 * k_noise * min(1.0, s2 / 0.04)    # uneven hem
    phase = 1.7 * noise.noise(Vector((math.cos(theta) * 1.3, math.sin(theta) * 1.3, 0.37)))
    amp_var = 0.75 + 0.5 * (0.5 + 0.5 * noise.noise(
        Vector((math.cos(theta) * 2.1 + 5.0, math.sin(theta) * 2.1, 1.1))))
    wave = 0.5 + 0.5 * math.sin(CLOTH_FOLDS * theta + phase)
    r += fold * amp_var * wave
    r = max(r, jar_outer_r(z) + CLOTH_GAP)
    return Vector((r * math.cos(theta), r * math.sin(theta), z))


def build_cloth(coll, mats):
    """Square linen cover with polar topology, plus a twine tie (slot 1). Origin = rim top."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    half = CLOTH_SIZE / 2.0
    # Flat distance of each ring from the center. Fixed rings land exactly on the
    # top, the lip roll and the tie; skirt rings stretch to the square edge.
    r_top = NECK_R + CLOTH_GAP + 0.0005
    flat_r = r_top - CLOTH_ROLL_R
    roll_end = flat_r + 0.5 * math.pi * CLOTH_ROLL_R
    band_d = roll_end + (JAR_H + CLOTH_GAP - CLOTH_ROLL_R) - CLOTH_BAND_Z
    fixed = [flat_r * i / 4.0 for i in range(1, 5)]
    fixed += [flat_r + (roll_end - flat_r) * i / 3.0 for i in range(1, 4)]
    fixed += [roll_end + (band_d - roll_end) * i / 3.0 for i in range(1, 4)]

    def ring_d(k, reach):
        if k <= len(fixed):
            return fixed[k - 1]
        j = k - len(fixed)
        return band_d + (reach - band_d) * j / CLOTH_SKIRT_RINGS

    n_rings = len(fixed) + CLOTH_SKIRT_RINGS
    rings = []
    for k in range(n_rings + 1):
        if k == 0:
            rings.append([(bm.verts.new(cloth_point(0.0, 0.0, 0.0) - Vector((0, 0, JAR_H))),
                           (0.5, 0.5))])
            continue
        ring = []
        for i in range(CLOTH_SEGS):
            th = 2.0 * math.pi * i / CLOTH_SEGS
            lt = th - CLOTH_ROT
            reach = half / max(abs(math.cos(lt)), abs(math.sin(lt)))
            d = ring_d(k, reach)
            kn = noise.noise(Vector((math.cos(th) * 3.0, math.sin(th) * 3.0, 7.7)))
            p = cloth_point(d, th, kn) - Vector((0, 0, JAR_H))
            u = 0.5 + d * math.cos(lt) / CLOTH_SIZE
            v = 0.5 + d * math.sin(lt) / CLOTH_SIZE
            ring.append((bm.verts.new(p), (u, v)))
        rings.append(ring)
    for k in range(n_rings):
        A, B = rings[k], rings[k + 1]
        for i in range(CLOTH_SEGS):
            i2 = (i + 1) % CLOTH_SEGS
            if len(A) == 1:
                items = [A[0], B[i], B[i2]]
            else:
                items = [A[i], A[i2], B[i2], B[i]]
            f = bm.faces.new([it[0] for it in items])
            f.material_index = 0
            for loop, it in zip(f.loops, items):
                loop[uv].uv = it[1]

    def up_out(f):
        c = f.calc_center_median()
        return f.normal.dot(Vector((c.x, c.y, max(c.z + 0.01, 0.0) * 4.0))) > 0

    orient_normals(bm, up_out)
    # Twine: two wraps just under the bead.
    r_tw = NECK_R + CLOTH_GAP + 0.0005 + TWINE_R + 0.0002
    for dz in (0.0, -2.1 * TWINE_R):
        circle = arc(r_tw, CLOTH_BAND_Z + dz - JAR_H, TWINE_R, 0, 360, 6)[:-1]
        tb, _ = lathe(circle, segments=32, closed=True)
        bmesh.ops.recalc_face_normals(tb, faces=tb.faces[:])
        for f in tb.faces:
            f.material_index = 1
        tmp = bpy.data.meshes.new("_tmp")
        tb.to_mesh(tmp)
        tb.free()
        bm.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
    ob = make_object("Cloth_Cover", bm, coll, location=(0, 0, JAR_H), mats=mats)
    sol = ob.modifiers.new("RenderThickness", "SOLIDIFY")
    sol.thickness = CLOTH_THICKNESS
    sol.offset = -1.0
    sol.use_even_offset = False   # even offset spikes at the lip crease
    ob["double_sided"] = True
    return ob


def build_band(coll, mats):
    """Rounded flat band around the body. Origin = its own center."""
    r0, r1 = JAR_OUTER_R + 0.00005, JAR_OUTER_R + BAND_T
    h, cr = BAND_H / 2.0, 0.0005
    prof = []
    prof += arc(r1 - cr, -h + cr, cr, -90, 0, 2)
    prof += arc(r1 - cr, h - cr, cr, 0, 90, 2)
    prof += arc(r0 + cr, h - cr, cr, 90, 180, 2)
    prof += arc(r0 + cr, -h + cr, cr, 180, 270, 2)
    bm, _ = lathe(prof, closed=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    ob = make_object("Rubber_Band", bm, coll, location=(0, 0, BASE_T + FED_LEVEL),
                     sharp_angle=None, mats=mats)
    ob["meaning"] = "starter level right after the last feed"
    return ob


# --- Environment ------------------------------------------------------------------
def build_counter(coll, mats):
    """Oak slab. Top at z=0, origin under the jar. Rounded front edge."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= COUNTER_X
        v.co.y = COUNTER_BACK_Y if v.co.y > 0 else COUNTER_FRONT_Y
        v.co.z = 0.0 if v.co.z > 0 else -COUNTER_T
    front_top = [e for e in bm.edges
                 if all(abs(v.co.y - COUNTER_FRONT_Y) < EPS for v in e.verts)
                 and all(abs(v.co.z) < EPS for v in e.verts)]
    bmesh.ops.bevel(bm, geom=front_top, offset=0.006, segments=5, profile=0.5,
                    affect="EDGES", clamp_overlap=True)
    uv = bm.loops.layers.uv.new("UVMap")
    bm.normal_update()
    for f in bm.faces:
        n = f.normal
        for loop in f.loops:
            co = loop.vert.co
            if abs(n.z) >= max(abs(n.x), abs(n.y)):
                loop[uv].uv = (co.x, co.y)
            elif abs(n.y) >= abs(n.x):
                loop[uv].uv = (co.x, co.z)
            else:
                loop[uv].uv = (co.y, co.z)
    return make_object("Counter", bm, coll, sharp_angle=40, mats=mats)


def build_backdrop(coll, mats):
    """Placeholder wall card. UV 0..1 for a painted, pre-blurred backdrop."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    nx, nz = 8, 6
    grid = []
    for j in range(nz + 1):
        row = []
        for i in range(nx + 1):
            x = -BACKDROP_W / 2 + BACKDROP_W * i / nx
            z = BACKDROP_H * j / nz
            row.append((bm.verts.new((x, COUNTER_BACK_Y, z)), (i / nx, j / nz)))
        grid.append(row)
    for j in range(nz):
        for i in range(nx):
            items = [grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]]
            f = bm.faces.new([it[0] for it in items])
            for loop, it in zip(f.loops, items):
                loop[uv].uv = it[1]
    orient_normals(bm, lambda f: f.normal.y < 0)
    ob = make_object("Backdrop_placeholder", bm, coll, mats=mats)
    ob["placeholder"] = "wall card; final soft-focus kitchen corner comes later"
    return ob


# =============================================================================
# MATERIALS (Blender look-dev; Godot rebuilds them as shaders by name)
# =============================================================================
class NT:
    """Tiny node-tree builder to keep material code readable."""

    def __init__(self, mat):
        try:
            mat.use_nodes = True
        except Exception:
            pass
        self.nt = mat.node_tree
        self.nt.nodes.clear()
        self.vals = {}

    def n(self, kind, **props):
        node = self.nt.nodes.new(kind)
        for k, v in props.items():
            setattr(node, k, v)
        return node

    def put(self, sock, val):
        if isinstance(val, bpy.types.NodeSocket):
            self.nt.links.new(val, sock)
        elif val is not None:
            sock.default_value = val

    def math(self, op, a, b=None, clamp=False):
        node = self.n("ShaderNodeMath", operation=op, use_clamp=clamp)
        self.put(node.inputs[0], a)
        if b is not None:
            self.put(node.inputs[1], b)
        return node.outputs[0]

    def value(self, name, v):
        node = self.n("ShaderNodeValue")
        node.name = node.label = name
        node.outputs[0].default_value = v
        self.vals[name] = node
        return node.outputs[0]

    def rgb(self, name, col):
        node = self.n("ShaderNodeRGB")
        node.name = node.label = name
        node.outputs[0].default_value = col
        self.vals[name] = node
        return node.outputs[0]

    def maprange(self, val, fmin, fmax, tmin=0.0, tmax=1.0, smooth_step=True):
        node = self.n("ShaderNodeMapRange", clamp=True,
                      interpolation_type="SMOOTHSTEP" if smooth_step else "LINEAR")
        self.put(node.inputs["Value"], val)
        self.put(node.inputs["From Min"], fmin)
        self.put(node.inputs["From Max"], fmax)
        self.put(node.inputs["To Min"], tmin)
        self.put(node.inputs["To Max"], tmax)
        return node.outputs["Result"]

    def mix_col(self, fac, a, b):
        node = self.n("ShaderNodeMix", data_type="RGBA", clamp_factor=True)
        self.put(node.inputs["Factor"], fac)
        ins = [s for s in node.inputs if s.type == "RGBA"]
        self.put(ins[0], a)
        self.put(ins[1], b)
        return [s for s in node.outputs if s.type == "RGBA"][0]

    def sep(self, vec):
        node = self.n("ShaderNodeSeparateXYZ")
        self.put(node.inputs[0], vec)
        return node.outputs

    def combine(self, x, y, z):
        node = self.n("ShaderNodeCombineXYZ")
        for i, v in enumerate((x, y, z)):
            self.put(node.inputs[i], v)
        return node.outputs[0]

    def principled(self, **inputs):
        p = self.n("ShaderNodeBsdfPrincipled")
        for k, v in inputs.items():
            self.put(p.inputs[k.replace("_", " ")], v)
        return p

    def out(self, shader):
        o = self.n("ShaderNodeOutputMaterial")
        self.put(o.inputs["Surface"], shader)
        return o


def new_mat(name):
    m = bpy.data.materials.new(name)
    return m, NT(m)


def mat_glass(name):
    m, t = new_mat(name)
    tint = hexcol(C["glass_tint"])
    tc = t.n("ShaderNodeTexCoord")
    smudge = t.n("ShaderNodeTexNoise")
    t.put(smudge.inputs["Vector"], tc.outputs["Object"])
    smudge.inputs["Scale"].default_value = 35.0
    smudge.inputs["Detail"].default_value = 3.0
    rough = t.maprange(smudge.outputs["Fac"], 0.55, 0.8, 0.008, 0.045)
    # No volume absorption: the glass has two materials (outer/inner) and Cycles
    # pairs volume entry/exit by shader, which floods the cavity. A per-surface
    # tint of ~1% compounds over the four crossings to a faint, clean green.
    p = t.principled(Base_Color=tint, Roughness=rough, IOR=1.5,
                     Transmission_Weight=1.0)
    tr = t.n("ShaderNodeBsdfTransparent")
    tr.inputs["Color"].default_value = tint
    lp = t.n("ShaderNodeLightPath")
    mix = t.n("ShaderNodeMixShader")
    t.put(mix.inputs["Fac"], t.math("MULTIPLY", lp.outputs["Is Shadow Ray"], 0.88))
    t.put(mix.inputs[1], p.outputs[0])
    t.put(mix.inputs[2], tr.outputs[0])
    t.out(mix.outputs[0])
    return m


def bubble_mask(t, coord, scale, radius, density, distort=0.35):
    """Irregular bubbles: domain-warped Voronoi cells, size varies per cell.

    Returns 1 inside a bubble, 0 outside. density 0..1 = share of cells with a bubble.
    """
    warp = t.n("ShaderNodeTexNoise")
    t.put(warp.inputs["Vector"], coord)
    warp.inputs["Scale"].default_value = scale * 0.6
    warp.inputs["Detail"].default_value = 2.0
    off = t.n("ShaderNodeVectorMath", operation="SUBTRACT")
    t.put(off.inputs[0], warp.outputs["Color"])
    off.inputs[1].default_value = (0.5, 0.5, 0.5)
    amt = t.n("ShaderNodeVectorMath", operation="SCALE")
    t.put(amt.inputs[0], off.outputs[0])
    amt.inputs["Scale"].default_value = distort / scale
    warped = t.n("ShaderNodeVectorMath", operation="ADD")
    t.put(warped.inputs[0], coord)
    t.put(warped.inputs[1], amt.outputs[0])
    mp = t.n("ShaderNodeMapping")
    t.put(mp.inputs["Vector"], warped.outputs[0])
    vor = t.n("ShaderNodeTexVoronoi", voronoi_dimensions="3D", feature="F1")
    t.put(vor.inputs["Vector"], mp.outputs[0])
    vor.inputs["Scale"].default_value = scale
    rnd = t.n("ShaderNodeSeparateColor")
    t.put(rnd.inputs[0], vor.outputs["Color"])
    size = t.math("ADD", 0.45, t.math("MULTIPLY", rnd.outputs[1], 0.8))
    r_out = t.math("MULTIPLY", size, radius)
    inside = t.maprange(vor.outputs["Distance"], t.math("MULTIPLY", r_out, 0.6), r_out, 1.0, 0.0)
    on = t.math("LESS_THAN", rnd.outputs[0], density)
    return t.math("MULTIPLY", inside, on)


def lerp(t, f, a, b):
    """a + (b - a) * f for float sockets or numbers."""
    return t.math("ADD", a, t.math("MULTIPLY", f, t.math("SUBTRACT", b, a)))


def mold_layers(t, coord, scale, radius, density):
    """Colony masks shared by the cap and the liner: (colony, core, spores)."""
    vor = t.n("ShaderNodeTexVoronoi", voronoi_dimensions="3D", feature="F1")
    t.put(vor.inputs["Vector"], coord)
    vor.inputs["Scale"].default_value = scale
    rnd = t.n("ShaderNodeSeparateColor")
    t.put(rnd.inputs[0], vor.outputs["Color"])
    alive = t.math("LESS_THAN", rnd.outputs[0], density)
    d = vor.outputs["Distance"]
    fuzz = t.n("ShaderNodeTexNoise")
    t.put(fuzz.inputs["Vector"], coord)
    fuzz.inputs["Scale"].default_value = scale * 16.0
    fuzz.inputs["Detail"].default_value = 8.0
    fuzz.inputs["Roughness"].default_value = 0.65
    ragged = t.math("ADD", radius * 1.15, t.math("MULTIPLY", t.math("SUBTRACT", fuzz.outputs["Fac"], 0.5), radius * 1.1))
    colony = t.math("MULTIPLY", t.maprange(d, ragged, t.math("SUBTRACT", ragged, radius * 0.4), 0.0, 1.0), alive)
    core = t.math("MULTIPLY", t.maprange(d, radius * 0.80, radius * 0.62, 0.0, 1.0), alive)
    mid = t.math("MULTIPLY", t.maprange(d, radius * 1.0, radius * 0.86, 0.0, 1.0), alive)
    sp = t.n("ShaderNodeTexVoronoi", voronoi_dimensions="3D", feature="F1")
    t.put(sp.inputs["Vector"], coord)
    sp.inputs["Scale"].default_value = scale * 9.0
    spores = t.math("MULTIPLY", t.maprange(sp.outputs["Distance"], 0.30, 0.16, 0.0, 1.0), core)
    return colony, t.math("MAXIMUM", core, t.math("MULTIPLY", mid, 0.55)), spores


def mat_starter():
    m, t = new_mat("M_Starter")
    tc = t.n("ShaderNodeTexCoord")
    obj = tc.outputs["Object"]
    oz = t.sep(obj)[2]
    base = t.rgb("base_color", hexcol(C["starter"]["white_bread"]))
    hooch_rgb = t.rgb("hooch_color", hexcol(C["hooch"]))
    stretch = t.value("stretch", 0.0)
    sz = t.combine(1.0, 1.0, t.math("SUBTRACT", 1.0, t.math("MULTIPLY", stretch, 0.7)))
    big = bubble_mask(t, obj, 105.0, 0.32, t.value("bubble_big", 0.5))
    small = bubble_mask(t, obj, 430.0, 0.27, t.value("bubble_small", 0.5))
    # Gluten web: stretched bubbles get their mapping squashed in z.
    for node in [n for n in t.nt.nodes if n.bl_idname == "ShaderNodeMapping"]:
        t.put(node.inputs["Scale"], sz)
    bub = t.math("MAXIMUM", big, small)

    # Regions from UV2: cap = top surface (stretch weight 1, inside the rim).
    uvm = t.n("ShaderNodeUVMap", uv_map="UV2_Shape")
    shape = t.sep(uvm.outputs["UV"])
    stretch_w = t.math("SUBTRACT", 1.0, shape[1])                     # undo the V pre-flip
    cap = t.math("MULTIPLY", t.maprange(stretch_w, 0.985, 0.999),
                 t.maprange(shape[0], 0.99, 0.95))

    # Hooch: everything within hooch_m of the surface reads as liquid.
    level = t.value("level", STARTER_H)
    hooch_m = t.value("hooch_m", 0.0)
    has_hooch = t.math("GREATER_THAN", hooch_m, 0.0)
    hooch_lo = t.math("SUBTRACT", level, hooch_m)
    hooch = t.math("MULTIPLY", has_hooch,
                   t.maprange(oz, t.math("SUBTRACT", hooch_lo, 0.0006),
                              t.math("ADD", hooch_lo, 0.0004)))
    hooch_depth = t.maprange(oz, hooch_lo, level)   # 0 at the starter, 1 at the top

    # Dry skin and crackle on the cap.
    dry = t.math("MULTIPLY", cap, t.value("dryness", 0.0))
    crack_v = t.n("ShaderNodeTexVoronoi", voronoi_dimensions="3D", feature="DISTANCE_TO_EDGE")
    t.put(crack_v.inputs["Vector"], obj)
    crack_v.inputs["Scale"].default_value = 75.0
    crack = t.math("MULTIPLY", t.maprange(crack_v.outputs["Distance"], 0.05, 0.0), dry)

    # Bran flecks (whole wheat, rye).
    fl_v = t.n("ShaderNodeTexVoronoi", voronoi_dimensions="3D", feature="F1")
    t.put(fl_v.inputs["Vector"], obj)
    fl_v.inputs["Scale"].default_value = 900.0
    fl_r = t.n("ShaderNodeSeparateColor")
    t.put(fl_r.inputs[0], fl_v.outputs["Color"])
    fleck = t.math("MULTIPLY", t.maprange(fl_v.outputs["Distance"], 0.2, 0.12),
                   t.math("LESS_THAN", fl_r.outputs[0], t.value("flecks", 0.0)))

    # Mold colonies on the cap (same Voronoi cells as the GN fuzz).
    flat = t.n("ShaderNodeMapping")
    t.put(flat.inputs["Vector"], obj)
    flat.inputs["Scale"].default_value = (1.0, 1.0, 0.0)
    colony, core, spores = mold_layers(t, flat.outputs[0], MOLD_CELL_SCALE, MOLD_RADIUS,
                                       t.value("mold", 0.0))
    colony = t.math("MULTIPLY", colony, cap)
    core = t.math("MULTIPLY", core, cap)
    spores = t.math("MULTIPLY", spores, cap)

    nz = t.n("ShaderNodeTexNoise")
    t.put(nz.inputs["Vector"], obj)
    nz.inputs["Scale"].default_value = 160.0
    nz.inputs["Detail"].default_value = 4.0
    still = t.math("SUBTRACT", 1.0, hooch)
    height = t.math("MULTIPLY", still, t.math("SUBTRACT",
                    t.math("MULTIPLY", nz.outputs["Fac"], 0.35), bub))
    height = t.math("SUBTRACT", height, t.math("MULTIPLY", crack, 0.6))
    height = t.math("ADD", height, t.math("MULTIPLY", colony, 0.9))
    bump = t.n("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.55
    bump.inputs["Distance"].default_value = 0.0006
    t.put(bump.inputs["Height"], height)
    soft = t.n("ShaderNodeBump")
    soft.inputs["Strength"].default_value = 0.15
    soft.inputs["Distance"].default_value = 0.0006
    t.put(soft.inputs["Height"], t.math("MULTIPLY", height, still))

    tone = t.maprange(nz.outputs["Fac"], 0.3, 0.7, 0.96, 1.03, smooth_step=False)
    col = t.n("ShaderNodeMix", data_type="RGBA", blend_type="MULTIPLY", clamp_factor=True)
    col.inputs["Factor"].default_value = 1.0
    rgba_in = [s for s in col.inputs if s.type == "RGBA"]
    t.put(rgba_in[0], base)
    t.put(rgba_in[1], t.combine(tone, tone, tone))
    c = [s for s in col.outputs if s.type == "RGBA"][0]
    c = t.mix_col(t.math("MULTIPLY", bub, 0.6), c, hexcol(C["pocket"]))
    c = t.mix_col(t.math("MULTIPLY", fleck, 0.8), c, hexcol(C["bran"]))
    c = t.mix_col(t.math("MULTIPLY", dry, 0.85), c, hexcol(C["crust"]))
    c = t.mix_col(t.math("MULTIPLY", crack, 0.5), c, hexcol(C["pocket"]))
    hooch_tint = t.mix_col(t.maprange(hooch_depth, 0.0, 0.5, 0.45, 1.0), c, hooch_rgb)
    c = t.mix_col(hooch, c, hooch_tint)
    c = t.mix_col(colony, c, hexcol(C["mold_halo"]))
    c = t.mix_col(t.math("MINIMUM", t.math("MULTIPLY", core, 1.82), 1.0), c, hexcol(C["mold_mid"]))
    c = t.mix_col(t.maprange(core, 0.6, 0.9), c, hexcol(C["mold_core"]))
    c = t.mix_col(spores, c, hexcol(C["mold_spore"]))

    rough = lerp(t, bub, t.value("rough", 0.35), 0.14)
    rough = lerp(t, dry, rough, 0.8)
    rough = lerp(t, hooch, rough, 0.04)
    rough = lerp(t, colony, rough, 0.95)
    coat = t.math("MULTIPLY", t.value("coat", 0.3), t.math("SUBTRACT", 1.0, t.math("MAXIMUM", dry, colony)))
    coat = t.math("MAXIMUM", coat, hooch)
    p = t.principled(Base_Color=c, Roughness=rough,
                     Subsurface_Scale=0.0018, Coat_Roughness=0.06, Specular_IOR_Level=0.6,
                     Sheen_Roughness=0.35)
    # Near-neutral radius: a red-heavy radius turned shadowed bubble pockets caramel.
    p.inputs["Subsurface Radius"].default_value = (1.0, 0.9, 0.78)
    sss = lerp(t, t.math("MAXIMUM", hooch, dry), 0.22, 0.02)
    t.put(p.inputs["Subsurface Weight"], lerp(t, bub, sss, 0.08))
    t.put(p.inputs["Sheen Weight"], colony)
    t.put(p.inputs["Coat Weight"], coat)
    t.put(p.inputs["Normal"], bump.outputs[0])
    t.put(p.inputs["Coat Normal"], soft.outputs[0])
    t.out(p.outputs[0])
    return m, t.vals


def mat_mold_fuzz():
    m, t = new_mat("M_Mold_Fuzz_preview")
    p = t.principled(Base_Color=hexcol("#E9EEE6"), Roughness=0.7,
                     Subsurface_Weight=0.3, Subsurface_Scale=0.0005)
    t.out(p.outputs[0])
    return m


def mat_liner():
    m, t = new_mat("M_Starter_Liner")
    tc = t.n("ShaderNodeTexCoord")
    v = t.math("SUBTRACT", 1.0, t.sep(tc.outputs["UV"])[1])          # undo the V pre-flip
    level = t.value("level_frac", 0.3)
    top = t.value("top_frac", 0.0)
    age = t.value("streak_age", 0.0)
    mold = t.value("mold", 0.0)
    # Wavy peak line around the jar.
    mp = t.n("ShaderNodeMapping")
    t.put(mp.inputs["Vector"], tc.outputs["Object"])
    mp.inputs["Scale"].default_value = (1.0, 1.0, 0.0)
    edge_n = t.n("ShaderNodeTexNoise")
    t.put(edge_n.inputs["Vector"], mp.outputs[0])
    edge_n.inputs["Scale"].default_value = 40.0
    edge_n.inputs["Detail"].default_value = 3.0
    edge = t.math("ADD", top, t.math("MULTIPLY", t.math("SUBTRACT", edge_n.outputs["Fac"], 0.5), 0.045))
    # Vertical streaks.
    mp2 = t.n("ShaderNodeMapping")
    t.put(mp2.inputs["Vector"], tc.outputs["Object"])
    mp2.inputs["Scale"].default_value = (1.0, 1.0, 0.08)
    st = t.n("ShaderNodeTexNoise")
    t.put(st.inputs["Vector"], mp2.outputs[0])
    st.inputs["Scale"].default_value = 260.0
    st.inputs["Detail"].default_value = 2.0
    streaks = t.maprange(st.outputs["Fac"], 0.5, 0.72)
    below_edge = t.math("SUBTRACT", 1.0, t.maprange(v, t.math("SUBTRACT", edge, 0.004), edge))
    above_level = t.maprange(v, t.math("SUBTRACT", level, 0.004), t.math("ADD", level, 0.012))
    ring = t.maprange(v, t.math("SUBTRACT", edge, 0.022), t.math("SUBTRACT", edge, 0.004))
    band = t.math("MULTIPLY", below_edge, above_level)
    amount = t.math("ADD", t.math("MULTIPLY", ring, 0.6), t.math("MULTIPLY", streaks, 0.5))
    alpha = t.math("MULTIPLY", band, t.math("MINIMUM", t.math("ADD", amount, 0.04), 0.8))
    alpha = t.math("MULTIPLY", alpha, t.math("GREATER_THAN", top, 0.0))
    # Old residue dries and breaks up: lower coverage, matte, slightly darker.
    alpha = t.math("MULTIPLY", alpha, lerp(t, age, 1.0, t.maprange(streaks, 0.1, 0.6, 0.35, 1.0)))
    # Mold on the glass just above the surface (moldy only), seen face-on.
    colony, core, spores = mold_layers(t, tc.outputs["Object"], MOLD_GLASS_SCALE, MOLD_GLASS_RADIUS,
                                       t.math("MULTIPLY", mold, 0.9))
    sat_c, sat_k, sat_s = mold_layers(t, tc.outputs["Object"], MOLD_GLASS_SCALE * 2.4, 0.3,
                                      t.math("MULTIPLY", mold, 0.55))
    colony = t.math("MAXIMUM", colony, sat_c)
    core = t.math("MAXIMUM", core, sat_k)
    spores = t.math("MAXIMUM", spores, sat_s)
    near = t.math("MULTIPLY", t.maprange(v, t.math("SUBTRACT", level, 0.002), t.math("ADD", level, 0.01)),
                  t.maprange(v, t.math("ADD", level, 0.17), t.math("ADD", level, 0.09)))
    colony = t.math("MULTIPLY", colony, near)
    core = t.math("MULTIPLY", core, near)
    spores = t.math("MULTIPLY", spores, near)
    alpha = t.math("MAXIMUM", alpha, colony)
    c = lerp_col = t.mix_col(age, hexcol(C["starter"]["white_bread"]), hexcol(C["crust"]))
    c = t.mix_col(colony, lerp_col, hexcol(C["mold_halo"]))
    c = t.mix_col(t.math("MINIMUM", t.math("MULTIPLY", core, 1.82), 1.0), c, hexcol(C["mold_mid"]))
    c = t.mix_col(t.maprange(core, 0.6, 0.9), c, hexcol(C["mold_core"]))
    c = t.mix_col(spores, c, hexcol(C["mold_spore"]))
    p = t.principled(Base_Color=c, Subsurface_Weight=0.1, Subsurface_Scale=0.002)
    t.put(p.inputs["Roughness"], lerp(t, t.math("MAXIMUM", age, colony), 0.28, 0.85))
    t.put(p.inputs["Sheen Weight"], colony)
    tr = t.n("ShaderNodeBsdfTransparent")
    mix = t.n("ShaderNodeMixShader")
    t.put(mix.inputs["Fac"], alpha)
    t.put(mix.inputs[1], tr.outputs[0])
    t.put(mix.inputs[2], p.outputs[0])
    t.out(mix.outputs[0])
    return m, t.vals


def wood(t, coord, light, dark, ring_scale, stretch, direction="Y"):
    mp = t.n("ShaderNodeMapping")
    t.put(mp.inputs["Vector"], coord)
    mp.inputs["Scale"].default_value = stretch
    wv = t.n("ShaderNodeTexWave", wave_type="BANDS", bands_direction=direction)
    t.put(wv.inputs["Vector"], mp.outputs[0])
    wv.inputs["Scale"].default_value = ring_scale
    wv.inputs["Distortion"].default_value = 11.0
    wv.inputs["Detail"].default_value = 3.0
    wv.inputs["Detail Scale"].default_value = 1.5
    fine = t.n("ShaderNodeTexNoise")
    t.put(fine.inputs["Vector"], mp.outputs[0])
    fine.inputs["Scale"].default_value = ring_scale * 12.0
    fine.inputs["Detail"].default_value = 6.0
    g = t.math("ADD", t.math("MULTIPLY", wv.outputs["Fac"], 0.55),
               t.math("MULTIPLY", fine.outputs["Fac"], 0.45))
    col = t.mix_col(t.maprange(g, 0.1, 0.95), dark, light)
    return col, g


def mat_lid_wood():
    m, t = new_mat("M_Lid_Wood")
    tc = t.n("ShaderNodeTexCoord")
    # Flat-sawn board: ring layers stacked in z, so the sides show fine horizontal
    # lines and the slightly domed top shows a cathedral pattern.
    col, g = wood(t, tc.outputs["Object"], hexcol(C["lid_wood_lt"]), hexcol(C["lid_wood_dk"]),
                  150.0, (1.0, 0.6, 1.0), direction="Z")
    bump = t.n("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.08
    t.put(bump.inputs["Height"], g)
    p = t.principled(Base_Color=col, Roughness=0.42, Coat_Weight=0.25, Coat_Roughness=0.3)
    t.put(p.inputs["Normal"], bump.outputs[0])
    t.out(p.outputs[0])
    return m


def mat_enamel():
    m, t = new_mat("M_Lid_Enamel")
    tc = t.n("ShaderNodeTexCoord")
    grad = t.n("ShaderNodeTexGradient", gradient_type="RADIAL")
    t.put(grad.inputs["Vector"], tc.outputs["Object"])
    knurl = t.math("SINE", t.math("MULTIPLY", grad.outputs["Fac"], 2.0 * math.pi * 120.0))
    z = t.sep(tc.outputs["Object"])[2]
    skirt = t.maprange(z, -0.0005, -0.0015)
    bump = t.n("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.35
    bump.inputs["Distance"].default_value = 0.0003
    t.put(bump.inputs["Height"], t.math("MULTIPLY", knurl, skirt))
    p = t.principled(Base_Color=hexcol(C["enamel"]), Roughness=0.32,
                     Coat_Weight=0.6, Coat_Roughness=0.12)
    t.put(p.inputs["Normal"], bump.outputs[0])
    t.out(p.outputs[0])
    return m


def mat_linen():
    m, t = new_mat("M_Cloth_Linen")
    tc = t.n("ShaderNodeTexCoord")
    uv = t.sep(tc.outputs["UV"])
    # Two thin sage stripes near each edge (tea-towel style), along both axes.
    def stripes(c):
        dist = t.math("ABSOLUTE", t.math("SUBTRACT", c, 0.5))
        s1 = t.math("MULTIPLY", t.maprange(dist, 0.395, 0.40), t.math("SUBTRACT", 1.0, t.maprange(dist, 0.41, 0.415)))
        s2 = t.math("MULTIPLY", t.maprange(dist, 0.425, 0.43), t.math("SUBTRACT", 1.0, t.maprange(dist, 0.434, 0.439)))
        return t.math("MAXIMUM", s1, s2)
    stripe = t.math("MAXIMUM", stripes(uv[0]), stripes(uv[1]))
    col = t.mix_col(stripe, hexcol(C["linen"]), hexcol(C["linen_stripe"]))
    weave_u = t.n("ShaderNodeTexWave", wave_type="BANDS", bands_direction="X")
    t.put(weave_u.inputs["Vector"], tc.outputs["UV"])
    weave_u.inputs["Scale"].default_value = 900.0
    weave_v = t.n("ShaderNodeTexWave", wave_type="BANDS", bands_direction="Y")
    t.put(weave_v.inputs["Vector"], tc.outputs["UV"])
    weave_v.inputs["Scale"].default_value = 900.0
    slub = t.n("ShaderNodeTexNoise")
    t.put(slub.inputs["Vector"], t.combine(t.math("MULTIPLY", uv[0], 6.0), t.math("MULTIPLY", uv[1], 300.0), 0.0))
    slub.inputs["Scale"].default_value = 4.0
    h = t.math("ADD", t.math("MULTIPLY", weave_u.outputs["Fac"], weave_v.outputs["Fac"]),
               t.math("MULTIPLY", slub.outputs["Fac"], 0.4))
    bump = t.n("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.25
    t.put(bump.inputs["Height"], h)
    p = t.principled(Base_Color=col, Roughness=0.85, Sheen_Weight=0.6, Sheen_Roughness=0.5)
    t.put(p.inputs["Normal"], bump.outputs[0])
    t.out(p.outputs[0])
    return m


def mat_simple(name, hexc, rough, coat=0.0, subsurf=0.0, bump_scale=0.0, bump_strength=0.0):
    m, t = new_mat(name)
    p = t.principled(Base_Color=hexcol(hexc), Roughness=rough, Coat_Weight=coat,
                     Subsurface_Weight=subsurf, Subsurface_Scale=0.002)
    if bump_scale:
        tc = t.n("ShaderNodeTexCoord")
        nz = t.n("ShaderNodeTexNoise")
        t.put(nz.inputs["Vector"], tc.outputs["Object"])
        nz.inputs["Scale"].default_value = bump_scale
        nz.inputs["Detail"].default_value = 5.0
        b = t.n("ShaderNodeBump")
        b.inputs["Strength"].default_value = bump_strength
        t.put(b.inputs["Height"], nz.outputs["Fac"])
        t.put(p.inputs["Normal"], b.outputs[0])
    t.out(p.outputs[0])
    return m


def mat_counter():
    m, t = new_mat("M_Counter_Wood")
    tc = t.n("ShaderNodeTexCoord")
    obj = tc.outputs["Object"]
    # Butcher-block strips 4.5 cm wide running along X.
    brick = t.n("ShaderNodeTexBrick", offset=0.37, offset_frequency=1)
    t.put(brick.inputs["Vector"], obj)
    brick.inputs["Mortar Size"].default_value = 0.0004
    brick.inputs["Brick Width"].default_value = 0.62
    brick.inputs["Row Height"].default_value = 0.045
    brick.inputs["Color1"].default_value = (1, 1, 1, 1)
    brick.inputs["Color2"].default_value = (0.90, 0.90, 0.90, 1)
    brick.inputs["Mortar"].default_value = (0.78, 0.78, 0.78, 1)
    brick.inputs["Scale"].default_value = 1.0
    col, g = wood(t, obj, hexcol(C["counter_lt"]), hexcol(C["counter_dk"]), 70.0, (0.08, 1.0, 1.0))
    strip = t.n("ShaderNodeMix", data_type="RGBA", blend_type="MULTIPLY", clamp_factor=True)
    strip.inputs["Factor"].default_value = 1.0
    ins = [s for s in strip.inputs if s.type == "RGBA"]
    t.put(ins[0], col)
    t.put(ins[1], brick.outputs["Color"])
    out_col = [s for s in strip.outputs if s.type == "RGBA"][0]
    bump = t.n("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.06
    t.put(bump.inputs["Height"], t.math("ADD", g, t.math("MULTIPLY", brick.outputs["Fac"], -1.0)))
    p = t.principled(Base_Color=out_col, Roughness=0.5, Coat_Weight=0.15, Coat_Roughness=0.35)
    t.put(p.inputs["Normal"], bump.outputs[0])
    t.out(p.outputs[0])
    return m


def mat_backdrop():
    m, t = new_mat("M_Backdrop")
    tc = t.n("ShaderNodeTexCoord")
    mp = t.n("ShaderNodeMapping")
    t.put(mp.inputs["Vector"], tc.outputs["Object"])
    mp.inputs["Rotation"].default_value = (math.radians(90), 0, 0)
    brick = t.n("ShaderNodeTexBrick", offset=0.0, offset_frequency=1)
    t.put(brick.inputs["Vector"], mp.outputs[0])
    brick.inputs["Scale"].default_value = 1.0
    brick.inputs["Mortar Size"].default_value = 0.0015
    brick.inputs["Mortar Smooth"].default_value = 0.3
    brick.inputs["Brick Width"].default_value = 0.065
    brick.inputs["Row Height"].default_value = 0.065
    brick.inputs["Bias"].default_value = 0.0
    brick.inputs["Color1"].default_value = hexcol(C["tile_a"])
    brick.inputs["Color2"].default_value = hexcol(C["tile_b"])
    brick.inputs["Mortar"].default_value = hexcol(C["grout"])
    glaze = t.n("ShaderNodeTexNoise")
    t.put(glaze.inputs["Vector"], tc.outputs["Object"])
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


def setup_world():
    w = bpy.data.worlds.new("World")
    bpy.context.scene.world = w
    try:
        w.use_nodes = True
    except Exception:
        pass
    nt = w.node_tree
    nt.nodes.clear()
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.interpolation_type = "SMOOTHSTEP"
    mr.inputs["From Min"].default_value = -0.3
    mr.inputs["From Max"].default_value = 0.7
    nt.links.new(sep.outputs[2], mr.inputs["Value"])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    nt.links.new(mr.outputs["Result"], mix.inputs["Factor"])
    ins = [s for s in mix.inputs if s.type == "RGBA"]
    ins[0].default_value = hexcol(C["world_bottom"])
    ins[1].default_value = hexcol(C["world_top"])
    bg = nt.nodes.new("ShaderNodeBackground")
    bg.inputs["Strength"].default_value = WORLD_STRENGTH
    nt.links.new([s for s in mix.outputs if s.type == "RGBA"][0], bg.inputs["Color"])
    out = nt.nodes.new("ShaderNodeOutputWorld")
    nt.links.new(bg.outputs[0], out.inputs["Surface"])


# =============================================================================
# LIGHTS, CAMERA, RENDER
# =============================================================================
def aim(ob, target):
    d = Vector(target) - ob.location
    ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def add_area(coll, name, loc, target, size, size_y, energy, hexc, spread_deg=180):
    lt = bpy.data.lights.new(name, "AREA")
    lt.shape = "RECTANGLE"
    lt.size, lt.size_y = size, size_y
    lt.energy = energy
    lt.color = hexcol(hexc)[:3]
    if hasattr(lt, "spread"):
        lt.spread = math.radians(spread_deg)
    ob = bpy.data.objects.new(name, lt)
    ob.location = loc
    coll.objects.link(ob)
    aim(ob, target)
    return ob


def setup_lights_camera(coll):
    tgt = (0.0, 0.0, 0.07)
    # Key: tall window softbox, front left, warm.
    add_area(coll, "Key", (-0.50, -0.34, 0.36), tgt, 0.30, 0.80, KEY_W, "#FFEAD6", 75)
    # Fill: broad, front right, slightly cooler and weak.
    add_area(coll, "Fill", (0.55, -0.45, 0.22), tgt, 0.9, 0.9, KEY_W * 0.16, "#F2F2F2")
    # Rim: narrow strip behind right, warm, outlines the glass.
    add_area(coll, "Rim", (0.30, 0.38, 0.30), (0.0, 0.0, 0.08), 0.10, 0.55, KEY_W * 0.85, "#FFEEDD", 60)
    # Top: soft overhead kiss for the starter's top surface and lid.
    add_area(coll, "Top", (-0.05, -0.10, 0.55), tgt, 0.4, 0.4, KEY_W * 0.15, "#FFF1DE")

    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.lens = CAM_LENS
    cam_data.sensor_fit = "AUTO"
    cam_data.clip_start = 0.01
    cam_data.dof.use_dof = True
    cam_data.dof.aperture_fstop = CAM_FSTOP
    cam_data.dof.aperture_blades = 7
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    el = math.radians(CAM_ELEV_DEG)
    cam.location = (0.0, -CAM_DIST * math.cos(el), CAM_TARGET_Z + CAM_DIST * math.sin(el))
    coll.objects.link(cam)
    aim(cam, (0.0, 0.0, CAM_TARGET_Z))
    focus = bpy.data.objects.new("FocusTarget", None)
    focus.location = (0.0, -JAR_OUTER_R * 0.6, CAM_TARGET_Z)
    coll.objects.link(focus)
    cam_data.dof.focus_object = focus
    bpy.context.scene.camera = cam


def setup_render(samples, scale):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "METAL"
        prefs.get_devices()
        for d in prefs.devices:
            d.use = d.type == "METAL"
        sc.cycles.device = "GPU"
    except Exception as exc:  # CPU fallback keeps the script portable
        print("GPU setup failed, using CPU:", exc)
    cy = sc.cycles
    cy.samples = samples
    cy.use_adaptive_sampling = True
    cy.adaptive_threshold = 0.02
    cy.use_denoising = True
    try:
        cy.denoiser = "OPENIMAGEDENOISE"
    except Exception:
        pass
    cy.max_bounces = 16
    cy.diffuse_bounces = 3
    cy.glossy_bounces = 6
    cy.transmission_bounces = 14
    cy.transparent_max_bounces = 16
    cy.caustics_reflective = False
    cy.caustics_refractive = False
    cy.blur_glossy = 1.0
    sc.render.resolution_x, sc.render.resolution_y = RENDER_RES
    sc.render.resolution_percentage = scale
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGB"
    sc.render.film_transparent = False
    vs = sc.view_settings
    try:
        vs.view_transform = "AgX"
        for look in ("AgX - Medium High Contrast", "Medium High Contrast"):
            try:
                vs.look = look
                break
            except TypeError:
                continue
    except TypeError:
        pass
    vs.exposure = 0.0


# =============================================================================
# STATES
# =============================================================================
def apply_state(name, objs, starter_vals, liner_vals):
    s = STATES[name]
    level = s["rise"] * FED_LEVEL
    set_starter_shape(objs["Starter_Body"], level, s["dome"], s["lumps"], s["mold"])
    for key in ("bubble_big", "bubble_small", "rough", "coat", "stretch", "dryness",
                "flecks", "mold"):
        starter_vals[key].outputs[0].default_value = s[key]
    starter_vals["level"].outputs[0].default_value = level
    starter_vals["hooch_m"].outputs[0].default_value = s["hooch"]
    starter_vals["hooch_color"].outputs[0].default_value = hexcol(C[s["hooch_col"]])
    starter_vals["base_color"].outputs[0].default_value = hexcol(C["starter"][s["flour"]])
    liner_vals["level_frac"].outputs[0].default_value = level / LINER_H
    liner_vals["top_frac"].outputs[0].default_value = s["streak_top"] / LINER_H
    liner_vals["streak_age"].outputs[0].default_value = s["streak_age"]
    liner_vals["mold"].outputs[0].default_value = s["mold"]
    objs["Rubber_Band"].location.z = BASE_T + FED_LEVEL


def show_cover(objs, cover):
    for n in ("Jar_Lid_Loose", "Jar_Lid_Tight", "Cloth_Cover"):
        objs[n].hide_render = n != cover


# =============================================================================
# MAIN
# =============================================================================
def main():
    t0 = time.time()
    opts = parse_args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"
    sc.unit_settings.scale_length = 1.0

    export_coll = bpy.data.collections.new("GLB_Export")
    render_coll = bpy.data.collections.new("Render_Only")
    sc.collection.children.link(export_coll)
    sc.collection.children.link(render_coll)

    m_glass = mat_glass("M_Glass")
    m_glass_in = mat_glass("M_Glass_Inner")
    m_starter, starter_vals = mat_starter()
    m_liner, liner_vals = mat_liner()
    m_wood = mat_lid_wood()
    m_enamel = mat_enamel()
    m_linen = mat_linen()
    m_twine = mat_simple("M_Twine", C["twine"], 0.8, bump_scale=900.0, bump_strength=0.4)
    m_band = mat_simple("M_Rubber_Band", C["band"], 0.55, subsurf=0.1)
    m_counter = mat_counter()
    m_backdrop = mat_backdrop()
    setup_world()

    objs = {}
    objs["Jar_Glass"] = build_glass(export_coll, (m_glass, m_glass_in))
    objs["Starter_Body"] = build_starter(export_coll, (m_starter,))
    objs["Starter_Liner"] = build_liner(export_coll, (m_liner,))
    objs["Jar_Lid_Loose"] = build_lid_loose(export_coll, (m_wood,))
    objs["Jar_Lid_Tight"] = build_lid_tight(export_coll, (m_enamel,))
    objs["Cloth_Cover"] = build_cloth(export_coll, (m_linen, m_twine))
    objs["Rubber_Band"] = build_band(export_coll, (m_band,))
    objs["Counter"] = build_counter(export_coll, (m_counter,))
    objs["Backdrop_placeholder"] = build_backdrop(export_coll, (m_backdrop,))
    objs.update(build_empties(export_coll))
    add_starter_shape_modifier(objs["Starter_Body"], mat_mold_fuzz())
    setup_lights_camera(render_coll)

    # --- Export the GLB (raw meshes, modifiers NOT applied) -------------------
    os.makedirs(os.path.dirname(GLB_OUT), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for n in EXPORT_NAMES:
        objs[n].select_set(True)
    bpy.context.view_layer.objects.active = objs["Jar_Glass"]
    bpy.ops.export_scene.gltf(
        filepath=GLB_OUT, export_format="GLB", use_selection=True,
        export_apply=False, export_yup=True, export_extras=True,
        export_cameras=False, export_lights=False, export_animations=False,
        export_texcoords=True, export_normals=True, export_tangents=False,
        export_materials="EXPORT")
    print("EXPORTED", GLB_OUT, os.path.getsize(GLB_OUT), "bytes")

    # --- Save the .blend at a nice-looking default state -----------------------
    setup_render(opts["samples"], opts["scale"])
    show_cover(objs, PREVIEW_COVER)
    apply_state("at_peak", objs, starter_vals, liner_vals)
    os.makedirs(os.path.dirname(BLEND_OUT), exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0    # no jar_v0.blend1 backups
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUT, compress=True)
    print("SAVED", BLEND_OUT)

    # --- Previews -------------------------------------------------------------
    if opts["render"]:
        show_cover(objs, opts["cover"])
        os.makedirs(opts["out"], exist_ok=True)
        for name in opts["states"]:
            t1 = time.time()
            apply_state(name, objs, starter_vals, liner_vals)
            sc.render.filepath = os.path.join(opts["out"], "jar_v0_%s.png" % name)
            bpy.ops.render.render(write_still=True)
            print("RENDERED %s in %.1fs" % (sc.render.filepath, time.time() - t1))
    print("DONE in %.1fs" % (time.time() - t0))


if __name__ == "__main__":
    main()
