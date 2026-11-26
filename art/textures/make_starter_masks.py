"""Starter runtime masks for Godot (D-037). Pure numpy, deterministic, no Blender.

Run from the repo root:
    python3 -I art/textures/make_starter_masks.py

Writes 8-bit PNGs (gray + alpha, linear data, never color-managed):
    assets/textures/starter_side_bubbles.png   512 x 512, tiles in u and v
    assets/textures/starter_top_pits.png       512 x 512, tiles in u and v
    assets/textures/starter_liner_streaks.png  512 x 256, tiles in u; v is clamped

Channel meaning (docs/art-direction.md §16.3 and §16.4 have the UV mapping and shader math):
    side, top   L = feature field F: 1 - rho inside a bubble or pit (rho = 0 at its
                    center, 1 at its full-size edge), 0 outside. Thresholding F at
                    1 - s shows every feature scaled to s about its own center, so
                    irregular outlines stay irregular at every size.
                A = presence rank P of the nearest feature (Voronoi), 0.02..0.90.
                    A feature exists when bubble_density > P. Big and clustered
                    features get low ranks, so they appear first. 1.0 = far from
                    any feature.
    liner       L = residue onset E: residue shows where E > 1 - streak_amount.
                    Ring at the peak line first, then drips, then a faint haze.
                    E above the threshold also reads as film thickness.
                A = drying breakup D: dried residue is removed where D < 0.35 x age.
                    Soft patches go first, so old film thins out, never into grit.

Every random draw comes from one seeded generator, so re-running gives
byte-identical files.
"""

import math
import os
import struct
import zlib

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(REPO, "assets", "textures")
SEED = 20261126

# --- Physical scales. Mirror these in the shader (art-direction.md §16.3). -----
STARTER_R_M = 0.0380                      # Starter_Body radius (mesh contract)
SIDE_PX = 512
SIDE_REPEATS = 4                          # tiles around the circumference
SIDE_TILE_M = 2.0 * math.pi * STARTER_R_M / SIDE_REPEATS     # 0.05969 m, square texels
TOP_PX = 512
TOP_TILE_M = 0.048                        # planar tile on the cap (cap is 76 mm across)
LINER_R_M = 0.03835                       # Starter_Liner radius
LINER_W, LINER_H = 512, 256
LINER_REPEATS = 2
LINER_TILE_W_M = 2.0 * math.pi * LINER_R_M / LINER_REPEATS  # 0.12048 m
LINER_SPAN_M = LINER_TILE_W_M * LINER_H / LINER_W            # 0.06024 m, square texels
LINER_EDGE_V = 0.10                       # the peak line sits at v = 0.10

P_MIN, P_MAX = 0.02, 0.90                 # rank range; density 1.0 shows every feature
VORONOI_PAD_PX = 20                       # rank cells reach this far past each feature


# =============================================================================
# PNG (gray + alpha, 8 bit) without PIL
# =============================================================================
def write_png_la(path, lum, alpha):
    """lum, alpha: float arrays in 0..1, shape (h, w). Row 0 is the top of the image."""
    h, w = lum.shape
    la = np.empty((h, w, 2), dtype=np.uint8)
    la[..., 0] = np.clip(np.round(lum * 255.0), 0, 255)
    la[..., 1] = np.clip(np.round(alpha * 255.0), 0, 255)
    raw = b"".join(b"\x00" + la[y].tobytes() for y in range(h))

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 4, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)
    return la


# =============================================================================
# Periodic noise helpers (everything tiles because it is built on a torus)
# =============================================================================
def periodic_noise(rng, h, w, scale_px, aniso=(1.0, 1.0)):
    """Smooth Gaussian random field that wraps in both axes. Returns 0..1, mean 0.5.

    scale_px: feature size in pixels. aniso = (sx, sy) stretches features by sx along
    x and sy along y (frequencies are scaled by it, so a bigger value = longer).
    """
    white = rng.standard_normal((h, w))
    fy = np.fft.fftfreq(h)[:, None] * aniso[1]
    fx = np.fft.fftfreq(w)[None, :] * aniso[0]
    k2 = fx * fx + fy * fy
    spec = np.exp(-k2 * (math.pi * scale_px) ** 2)
    field = np.real(np.fft.ifft2(np.fft.fft2(white) * spec))
    field = (field - field.mean()) / (field.std() + 1e-9)
    return np.clip(0.5 + 0.18 * field, 0.0, 1.0)


def rank_normalize(a):
    """Map values to their rank: an even 0..1 histogram, same ordering."""
    flat = a.ravel()
    order = np.argsort(flat, kind="stable")
    out = np.empty_like(flat, dtype=np.float64)
    out[order] = np.linspace(0.0, 1.0, flat.size)
    return out.reshape(a.shape)


def wrap_delta(d, period):
    return (d + period / 2.0) % period - period / 2.0


# =============================================================================
# Feature masks (side bubbles, top pits)
# =============================================================================
class Feature:
    __slots__ = ("cx", "cy", "r", "aspect", "tilt", "tear", "harm", "rank_key",
                 "size_key", "cluster_key", "parent", "p")

    def boundary(self, theta):
        """Unit-shape radius at local angle theta (y up). Star-shaped by construction."""
        rr = np.ones_like(theta)
        for k, (amp, ph) in enumerate(self.harm, start=2):
            rr = rr + amp * np.cos(k * theta + ph)
        # Egg plus a pinched tip: tear > 0 points the tip up, < 0 points it down.
        s = np.sin(theta) * np.sign(self.tear) if self.tear else 0.0
        if self.tear:
            t = abs(self.tear)
            rr = rr * (1.0 - 0.35 * t * s)                 # rounder at the head
            tip = np.clip(s, 0.0, 1.0) ** 6
            rr = rr * (1.0 + 0.55 * t * tip)               # elongated toward the tip
            rr = rr * (1.0 - 0.45 * t * tip * (np.cos(theta) ** 2))
        return np.maximum(rr, 0.35)


def make_shape(rng, cls, mm_per_px):
    f = Feature()
    lo, hi = cls["r_mm"]
    # Log-uniform radius: many small, a few large within each class.
    f.r = math.exp(rng.uniform(math.log(lo), math.log(hi))) / mm_per_px
    a_lo, a_hi = cls["aspect"]
    f.aspect = rng.uniform(a_lo, a_hi)
    if rng.random() < cls.get("flat_share", 0.0):          # a few lie sideways
        f.aspect = 1.0 / f.aspect
    f.tilt = rng.normal(0.0, cls.get("tilt_sd", 0.25))
    t_lo, t_hi = cls["tear"]
    tear = rng.uniform(t_lo, t_hi) if rng.random() < cls.get("tear_share", 0.0) else 0.0
    f.tear = tear * (1.0 if rng.random() < 0.7 else -1.0)
    w_lo, w_hi = cls["wobble"]
    wob = rng.uniform(w_lo, w_hi)
    f.harm = [(wob * rng.uniform(0.3, 1.0) / (k ** 0.6), rng.uniform(0, 2 * math.pi))
              for k in range(2, 7)]
    f.parent = None
    return f


def place_features(rng, size_px, mm_per_px, classes, n_clusters, cluster_sd_mm):
    parents = rng.uniform(0, size_px, size=(n_clusters, 2))
    sds = rng.uniform(cluster_sd_mm[0], cluster_sd_mm[1], size=n_clusters) / mm_per_px
    placed = []
    pos = np.zeros((0, 2))
    rad = np.zeros(0)

    def cluster_density(x, y):
        dx = wrap_delta(parents[:, 0] - x, size_px)
        dy = wrap_delta(parents[:, 1] - y, size_px)
        return float(np.sum(np.exp(-(dx * dx + dy * dy) / (2.0 * sds * sds))))

    for cls in classes:
        for _ in range(cls["n"]):
            f = make_shape(rng, cls, mm_per_px)
            ext = f.r * math.sqrt(max(f.aspect, 1.0 / f.aspect))
            ok = False
            for _try in range(300):
                if rng.random() < cls["clustered"]:
                    j = rng.integers(n_clusters)
                    x, y = parents[j] + rng.normal(0, sds[j], size=2)
                else:
                    x, y = rng.uniform(0, size_px, size=2)
                x %= size_px
                y %= size_px
                if len(rad):
                    dx = wrap_delta(pos[:, 0] - x, size_px)
                    dy = wrap_delta(pos[:, 1] - y, size_px)
                    gap = np.hypot(dx, dy) - (rad + ext) * cls.get("spacing", 0.95)
                    if np.any(gap < 0):
                        continue
                ok = True
                break
            if not ok:
                continue
            f.cx, f.cy = x, y
            f.size_key = ext
            f.cluster_key = cluster_density(x, y)
            f.rank_key = rng.random()
            placed.append(f)
            pos = np.vstack([pos, [x, y]])
            rad = np.append(rad, ext)
            # Merged voids: a satellite overlapping the parent (peanut and lobed shapes).
            if rng.random() < cls.get("merge_share", 0.0):
                s = make_shape(rng, cls, mm_per_px)
                s.r = f.r * rng.uniform(0.45, 0.75)
                s.aspect = rng.uniform(1.0, 1.4)
                ang = rng.uniform(0, 2 * math.pi)
                d = (f.r + s.r) * rng.uniform(0.55, 0.85)
                s.cx = (x + d * math.cos(ang)) % size_px
                s.cy = (y + d * math.sin(ang)) % size_px
                s.parent = f
                s.size_key = ext
                s.cluster_key = f.cluster_key
                s.rank_key = f.rank_key
                placed.append(s)
    return placed


def assign_ranks(features, w_size, w_cluster, w_rand):
    roots = [f for f in features if f.parent is None]
    sizes = np.array([f.size_key for f in roots])
    clus = np.array([f.cluster_key for f in roots])
    rnd = np.array([f.rank_key for f in roots])
    size_pct = rank_normalize(sizes)
    clus_pct = rank_normalize(clus)
    score = w_size * (1.0 - size_pct) + w_cluster * (1.0 - clus_pct) + w_rand * rnd
    order = np.argsort(score, kind="stable")
    ranks = np.empty(len(roots))
    ranks[order] = np.linspace(P_MIN, P_MAX, len(roots))
    for f, p in zip(roots, ranks):
        f.p = float(p)
    for f in features:
        if f.parent is not None:
            f.p = f.parent.p


def rasterize(features, size_px):
    F = np.zeros((size_px, size_px))
    P = np.ones((size_px, size_px))
    best = np.full((size_px, size_px), float(VORONOI_PAD_PX))
    for f in features:
        ext = f.r * math.sqrt(max(f.aspect, 1.0 / f.aspect)) * 1.6
        h = int(math.ceil(ext + VORONOI_PAD_PX))
        ix0, iy0 = int(math.floor(f.cx)), int(math.floor(f.cy))
        offs = np.arange(-h, h + 1)
        xs = ix0 + offs
        ys = iy0 + offs
        dx = (xs + 0.5 - f.cx)[None, :]
        dy_up = -(ys + 0.5 - f.cy)[:, None]            # image rows grow down; shapes use y up
        c, s = math.cos(f.tilt), math.sin(f.tilt)
        lx = c * dx + s * dy_up
        ly = -s * dx + c * dy_up
        sa = math.sqrt(f.aspect)
        qx = lx / (f.r / sa)
        qy = ly / (f.r * sa)
        qd = np.hypot(qx, qy)
        theta = np.arctan2(qy, qx)
        rho = qd / f.boundary(theta)
        dist = np.hypot(dx, dy_up)
        rw = np.where(rho > 1e-6, dist / np.maximum(rho, 1e-6), f.r)
        edge = dist - rw                                # px to the outline along the ray
        iy = ys % size_px
        ix = xs % size_px
        sub = np.ix_(iy, ix)
        F[sub] = np.maximum(F[sub], np.clip(1.0 - rho, 0.0, 1.0))
        cur = best[sub]
        win = edge < cur
        best[sub] = np.where(win, edge, cur)
        P[sub] = np.where(win, f.p, P[sub])
    return F, P


SIDE_CLASSES = [
    # Pressed against the glass: flattened, mostly taller than wide, some teardrops
    # and merged lobes. Big ones are rarer and more irregular.
    dict(n=30, r_mm=(1.5, 4.6), aspect=(1.15, 2.1), flat_share=0.12, tilt_sd=0.30,
         tear=(0.25, 0.75), tear_share=0.55, wobble=(0.08, 0.22), clustered=0.75,
         merge_share=0.40, spacing=0.90),
    dict(n=110, r_mm=(0.7, 1.5), aspect=(1.0, 1.7), flat_share=0.15, tilt_sd=0.30,
         tear=(0.2, 0.6), tear_share=0.35, wobble=(0.05, 0.15), clustered=0.75,
         merge_share=0.18, spacing=0.92),
    dict(n=260, r_mm=(0.32, 0.7), aspect=(1.0, 1.4), flat_share=0.2, tilt_sd=0.35,
         tear=(0.1, 0.4), tear_share=0.15, wobble=(0.03, 0.09), clustered=0.7,
         merge_share=0.05, spacing=0.95),
    dict(n=520, r_mm=(0.23, 0.34), aspect=(1.0, 1.25), tilt_sd=0.4,
         tear=(0.0, 0.0), wobble=(0.0, 0.05), clustered=0.6, spacing=1.0),
]

TOP_CLASSES = [
    # Seen from above: rounder. Craters are popped bubbles, pits are smaller,
    # pinholes are the many tiny dark dots.
    dict(n=14, r_mm=(1.3, 3.0), aspect=(1.0, 1.3), tilt_sd=1.5,
         tear=(0.1, 0.3), tear_share=0.25, wobble=(0.10, 0.24), clustered=0.6,
         merge_share=0.35, spacing=0.95),
    dict(n=70, r_mm=(0.5, 1.3), aspect=(1.0, 1.25), tilt_sd=1.5,
         tear=(0.0, 0.0), wobble=(0.05, 0.15), clustered=0.65, merge_share=0.12,
         spacing=0.95),
    dict(n=420, r_mm=(0.19, 0.45), aspect=(1.0, 1.15), tilt_sd=1.5,
         tear=(0.0, 0.0), wobble=(0.0, 0.06), clustered=0.6, spacing=1.05),
]


def feature_mask(rng, size_px, tile_m, classes, n_clusters, cluster_sd_mm):
    mm_per_px = tile_m * 1000.0 / size_px
    feats = place_features(rng, size_px, mm_per_px, classes, n_clusters, cluster_sd_mm)
    assign_ranks(feats, w_size=0.40, w_cluster=0.25, w_rand=0.35)
    F, P = rasterize(feats, size_px)
    return F, P, feats, mm_per_px


# =============================================================================
# Liner residue (ring at the peak line, lacy film, a few drips, haze)
# =============================================================================
LINER_IMPRINT_CLASSES = [
    # Where bubbles touched the glass, the film is missing: residue is a negative
    # print of the bubble pattern, a little stretched by the slide down.
    dict(n=46, r_mm=(1.4, 3.8), aspect=(1.2, 2.2), tilt_sd=0.25, tear=(0.2, 0.6),
         tear_share=0.4, wobble=(0.08, 0.2), clustered=0.5, merge_share=0.35, spacing=0.85),
    dict(n=300, r_mm=(0.6, 1.4), aspect=(1.0, 1.8), tilt_sd=0.3, tear=(0.1, 0.5),
         tear_share=0.25, wobble=(0.05, 0.14), clustered=0.5, merge_share=0.15, spacing=0.88),
    dict(n=600, r_mm=(0.4, 0.6), aspect=(1.0, 1.3), tilt_sd=0.4, tear=(0.0, 0.0),
         wobble=(0.0, 0.06), clustered=0.4, spacing=0.95),
]


def cell_crackle(rng, h, w, cell_w, cell_h):
    """Jittered-grid Voronoi on a torus: (d2 - d1) in px, small along cell edges."""
    gw, gh = w // cell_w, h // cell_h
    jit = rng.uniform(0.1, 0.9, size=(gh, gw, 2))
    yy, xx = np.mgrid[0:h, 0:w] + 0.5
    cx, cy = xx / cell_w, yy / cell_h
    ix, iy = np.floor(cx).astype(int), np.floor(cy).astype(int)
    d1 = np.full((h, w), 1e9)
    d2 = np.full((h, w), 1e9)
    for oy in (-1, 0, 1):
        for ox in (-1, 0, 1):
            nx, ny = ix + ox, iy + oy
            j = jit[ny % gh, nx % gw]
            px = (nx + j[..., 0]) * cell_w
            py = (ny + j[..., 1]) * cell_h
            d = np.hypot(xx - px, yy - py)
            d2 = np.where(d < d1, d1, np.minimum(d2, d))
            d1 = np.minimum(d1, d)
    return d2 - d1


def liner_mask(rng):
    W, H = LINER_W, LINER_H
    mm = LINER_TILE_W_M * 1000.0 / W                    # mm per px
    edge_row = LINER_EDGE_V * H                         # peak line, 25.6 px from the top
    x = np.arange(W) + 0.5
    rows = (np.arange(H) + 0.5)[:, None]

    # Peak line: a soft wave plus rounded scallops where dome bubbles touched the glass.
    wave = (periodic_noise(rng, 8, W, 22.0)[4] - 0.5) * 6.0
    edge = edge_row + wave
    for _ in range(30):
        xc = rng.uniform(0, W)
        half = rng.uniform(2.5, 9.0)
        lift = rng.uniform(0.5, 1.4) * half * 0.55
        d = wrap_delta(x - xc, W) / half
        bump = np.where(np.abs(d) < 1.0, lift * np.sqrt(np.clip(1.0 - d * d, 0, 1)), 0.0)
        edge = np.minimum(edge, edge_row + wave - bump)
    depth = rows - edge[None, :]                        # px below the peak line
    below = np.clip(depth + 0.5, 0.0, 1.0)              # 1 px anti-aliased top edge

    streaky = periodic_noise(rng, H, W, 2.2, aniso=(1.0, 14.0))    # vertical smear grain
    blotch = periodic_noise(rng, H, W, 9.0, aniso=(1.0, 2.2))      # patchy, a little taller

    # Ring: the high-water mark, 3 to 8 mm deep, thickest at the very top.
    ring_w = (5.5 + (periodic_noise(rng, 8, W, 26.0)[2] - 0.5) * 9.0) / mm
    ring_w = ring_w[None, :] * (0.8 + 0.4 * blotch)
    ridge = np.exp(-np.clip(depth, 0, None) / (0.9 / mm))
    ring = np.clip(1.0 - (depth - ring_w) / (2.5 / mm), 0.0, 1.0)
    E_ring = (0.82 + 0.18 * ridge) * ring

    # Lace film: thins with depth, streaked downward, holes where bubbles were.
    film = (0.66 - 0.56 * np.clip(depth / (40.0 / mm), 0, 1)) * (0.45 + 1.1 * streaky)
    film = film * (0.55 + 0.9 * blotch)
    feats = place_features(rng, W, mm, LINER_IMPRINT_CLASSES, n_clusters=18,
                           cluster_sd_mm=(3.0, 9.0))
    for f in feats:
        f.p = 0.5
    imp, _ = rasterize(feats, W)
    imp = imp[:H]
    holes = np.clip((imp - 0.08) / 0.10, 0, 1)
    film = film * (1.0 - holes)
    E_ring = E_ring * (1.0 - 0.85 * holes * np.clip(depth / (1.2 / mm), 0, 1))

    # Drips: a few soft runs from the ring, wavy, tapering, some ending in a bead.
    E_drip = np.zeros((H, W))
    for _ in range(24):
        x0 = rng.uniform(0, W)
        top = float(np.interp(x0, x, edge)) + rng.uniform(0.5, 1.0) * float(ring_w.mean())
        length = math.exp(rng.uniform(math.log(4.0 / mm), math.log(34.0 / mm)))
        w0 = rng.uniform(0.9, 3.0) / mm
        s0 = rng.uniform(0.7, 0.95)
        bead = rng.random() < 0.5
        t = (rows - top) / length
        tc = np.clip(t, 0, 1)
        cx = x0 + rng.uniform(0.5, 2.0) * np.sin(tc * rng.uniform(2.0, 4.0) + rng.uniform(0, 6.3))
        width = w0 * (1.0 - 0.6 * tc)
        if bead:
            width = width * (1.0 + 0.7 * np.exp(-((t - 0.95) / 0.05) ** 2))
        dx = wrap_delta(x[None, :] - cx, W)
        across = np.clip(1.0 - (2.0 * dx / np.maximum(width, 0.8)) ** 2, 0, 1)
        along = s0 * (1.0 - 0.35 * tc) * (0.85 + 0.3 * streaky)
        tip = np.clip((1.0 - t) * length / max(w0 * 0.5, 1.0), 0, 1)
        start = np.clip((rows - top + 6.0) / 6.0, 0, 1)
        E_drip = np.maximum(E_drip, along * np.sqrt(across) * tip * start)

    # Haze: a thin wet film that shows only at high streak_amount.
    haze = (0.08 + 0.2 * streaky) * np.clip(1.0 - depth / (50.0 / mm), 0, 1)

    E = np.maximum.reduce([E_ring, film, E_drip, haze]) * below
    fade_bottom = np.clip((H - 2.0 - rows) / 6.0, 0, 1)    # clamp-safe: last rows are zero
    E = np.clip(E * fade_bottom, 0, 1)

    # Drying breakup: soft patches about 5 to 8 mm across, with only a hint of
    # cracking at their edges. Fine cells read as grit at game distance, and the
    # gaps showed dark hooch and the sage wall as olive specks (Phase 2 review).
    crack = np.clip(cell_crackle(rng, H, W, 22, 30) / 8.0, 0, 1)
    fine = periodic_noise(rng, H, W, 4.0)
    coarse = periodic_noise(rng, H, W, 14.0, aniso=(1.0, 1.6))
    D = rank_normalize(0.15 * crack + 0.25 * fine + 0.60 * coarse)
    return E, D, edge


# =============================================================================
def main():
    rng = np.random.default_rng(SEED)
    os.makedirs(OUT_DIR, exist_ok=True)

    F, P, feats, mmpp = feature_mask(rng, SIDE_PX, SIDE_TILE_M, SIDE_CLASSES,
                                     n_clusters=12, cluster_sd_mm=(3.0, 8.0))
    path = os.path.join(OUT_DIR, "starter_side_bubbles.png")
    write_png_la(path, F, P)
    print("WROTE %s  %dx%d  %d features  %.4f mm/px  tile %.2f mm  coverage %.1f%%"
          % (path, SIDE_PX, SIDE_PX, len(feats), mmpp, SIDE_TILE_M * 1000,
             100.0 * np.mean(F > 0)))

    F, P, feats, mmpp = feature_mask(rng, TOP_PX, TOP_TILE_M, TOP_CLASSES,
                                     n_clusters=9, cluster_sd_mm=(2.5, 6.0))
    path = os.path.join(OUT_DIR, "starter_top_pits.png")
    write_png_la(path, F, P)
    print("WROTE %s  %dx%d  %d features  %.4f mm/px  tile %.2f mm  coverage %.1f%%"
          % (path, TOP_PX, TOP_PX, len(feats), mmpp, TOP_TILE_M * 1000,
             100.0 * np.mean(F > 0)))

    E, D, _edge = liner_mask(rng)
    path = os.path.join(OUT_DIR, "starter_liner_streaks.png")
    write_png_la(path, E, D)
    print("WROTE %s  %dx%d  %.4f mm/px  span %.2f mm  peak line at v=%.2f"
          % (path, LINER_W, LINER_H, LINER_TILE_W_M * 1000 / LINER_W,
             LINER_SPAN_M * 1000, LINER_EDGE_V))


if __name__ == "__main__":
    main()
