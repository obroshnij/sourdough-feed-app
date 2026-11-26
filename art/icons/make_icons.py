"""Sourdough UI icons (D-034): 21 icons x outline + filled = 42 SVGs.

Run from the repo root:
    python3 -I art/icons/make_icons.py            # writes assets/icons/*.svg
    python3 -I art/icons/make_icons.py --check    # also renders art/previews/icons_check_24px.png
                                                  # (needs rsvg-convert and magick on PATH)

Style (art-direction §11): 24 x 24 grid, 2 px stroke, round caps and joins,
2 px corner radius, 2 px safe margin. One color, pure white (#FFFFFF) on
transparent, so Godot tints an icon with modulate (white x tone = tone).
No masks, filters, text or currentColor: filled variants cut details out with
fill-rule="evenodd" only, which every SVG rasterizer handles the same way.
A hole sub-path is drawn 1 px larger than the visible hole, because the 2 px
stroke also runs around it.

File names: <group>_<canonical id>_<variant>.svg, groups status, action, inspect.
Plus five utility icons, one variant each: ui_settings, ui_close, ui_back,
ui_check, ui_chevron_right.
"""

import math
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(REPO, "assets", "icons")
CHECK_OUT = os.path.join(REPO, "art", "previews", "icons_check_24px.png")
W = "#FFFFFF"

HEAD = ('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" '
        'fill="none" stroke="%s" stroke-width="2" stroke-linecap="round" '
        'stroke-linejoin="round">\n' % W)


def p(d, fill=False, evenodd=False):
    attrs = ' fill="%s"' % W if fill else ""
    if evenodd:
        attrs += ' fill-rule="evenodd"'
    return '  <path d="%s"%s/>\n' % (d, attrs)


def circle(cx, cy, r, fill=False):
    return '  <circle cx="%g" cy="%g" r="%g"%s/>\n' % (cx, cy, r, ' fill="%s"' % W if fill else "")


def ring(cx, cy, r):
    """Closed circle as a path (for evenodd holes)."""
    return "M%g %gA%g %g 0 1 0 %g %gA%g %g 0 1 0 %g %gZ" % (
        cx - r, cy, r, r, cx + r, cy, r, r, cx - r, cy)


def dot(x, y):
    return p("M%g %gh.01" % (x, y))


def dome(top):
    return ("M4 20V%g C4 %g 7.6 %g 12 %g C16.4 %g 20 %g 20 %g V20Z"
            % (top + 5.5, top + 2, top, top, top, top + 2, top + 5.5))


SAG = ("M4 20V15.5C4 12.5 5.8 11 8 11C10 11 10.6 13.2 12 13.2"
       "C13.4 13.2 14 11 16 11C18.2 11 20 12.5 20 15.5V20Z")


def octagon(cx=12.0, cy=12.0, R=9.6):
    pts = [(cx + R * math.cos(math.radians(22.5 + 45 * k)),
            cy + R * math.sin(math.radians(22.5 + 45 * k))) for k in range(8)]
    return "M" + " L".join("%.2f %.2f" % q for q in pts) + "Z"


def rrect(x0, y0, x1, y1, r):
    return ("M%g %gH%gA%g %g 0 0 1 %g %gV%gA%g %g 0 0 1 %g %gH%gA%g %g 0 0 1 %g %gV%gA%g %g 0 0 1 %g %gZ"
            % (x0 + r, y0, x1 - r, r, r, x1, y0 + r, y1 - r, r, r, x1 - r, y1,
               x0 + r, r, r, x0, y1 - r, y0 + r, r, r, x0 + r, y0))


SPARKLE = "M18 1.5Q18.5 5 22 5.5Q18.5 6 18 9.5Q17.5 6 14 5.5Q17.5 5 18 1.5Z"
GRAINS = [
    "M12 17.5C9.2 17 7.6 14.6 8 12C10.6 12.4 12 14.8 12 17.5Z",
    "M12 17.5C14.8 17 16.4 14.6 16 12C13.4 12.4 12 14.8 12 17.5Z",
    "M12 12.5C9.2 12 7.6 9.6 8 7C10.6 7.4 12 9.8 12 12.5Z",
    "M12 12.5C14.8 12 16.4 9.6 16 7C13.4 7.4 12 9.8 12 12.5Z",
    "M12 7.5C10.6 6.3 10.6 3.9 12 2.5C13.4 3.9 13.4 6.3 12 7.5Z",
]
NOSE_OPEN = "M17.5 3.5C17.5 8 15.2 12 13 15C12.1 16.2 12.7 17.8 14.3 17.8H16.4C17.4 17.8 17.8 19.2 17.1 20.3"
NOSE_SOLID = "M17.5 3.5C17.5 8 15.2 12 13 15C12.1 16.2 12.7 17.8 14.3 17.8H16.4C17.4 17.8 17.8 19.2 17.1 20.3L19.5 20.3V3.5Z"
WISPS = ["M6 14Q4 12 6 10T6 6", "M9.8 11Q8.3 9.5 9.8 8T9.8 4.5"]
HOUSE = "M12 3.5L20 10.5H18V18.5A2 2 0 0 1 16 20.5H8A2 2 0 0 1 6 18.5V10.5H4Z"
JAR = rrect(5, 6.5, 19, 20.5, 2.5)
LEAF_TIP = "M17.5 6.5C20 8 20.6 11.2 19.2 13.8C17.1 12.3 16.4 9 17.5 6.5Z"
LEAF_SIDE = "M12 14.5C10.4 12.6 7.4 12.4 5.6 14.2C7.4 16 10.4 16.2 12 14.5Z"
# Pinholes scattered unevenly, never two level dots over one (that reads as a face).
SURF_DOTS = [(7.6, 12.6), (10.6, 9.6), (13.8, 12.4), (16.4, 9.9), (11.2, 14.9)]
DROP = "M12 11C12 11 7.5 15.3 7.5 17.3A4.5 4.5 0 0 0 16.5 17.3C16.5 15.3 12 11 12 11Z"
ORBIT = "M20.18 14.66A8.6 8.6 0 1 1 16.30 4.55"
ORBIT_HEAD = "M15.31 1.51L16.30 4.55L13.17 5.22"
SMALL_JAR = rrect(9.5, 9, 14.5, 16, 1.5)

ICONS = {
    # --- Status (ux-design §11 brief). Distinct silhouettes, readable in grayscale.
    "status_freshly_fed": (   # spoon
        '  <ellipse cx="8.3" cy="8.3" rx="3.4" ry="5.2" transform="rotate(-45 8.3 8.3)"/>\n'
        + p("M12.4 12.4L19.5 19.5"),
        '  <ellipse cx="8.3" cy="8.3" rx="3.4" ry="5.2" transform="rotate(-45 8.3 8.3)" fill="%s"/>\n' % W
        + p("M12.4 12.4L19.5 19.5")),
    "status_developing": (    # two small bubbles
        circle(9.5, 14.5, 4.5) + circle(16.5, 7, 2.75),
        circle(9.5, 14.5, 4.5, True) + circle(16.5, 7, 2.75, True)),
    "status_active": (        # three rising bubbles
        circle(9.5, 17.5, 3.25) + circle(15.5, 11, 2.5) + circle(9.5, 5, 2),
        circle(9.5, 17.5, 3.25, True) + circle(15.5, 11, 2.5, True) + circle(9.5, 5, 2, True)),
    "status_near_peak": (     # dome + up chevron
        p(dome(10)) + p("M8.5 6.5L12 3L15.5 6.5"),
        p(dome(10), True) + p("M8.5 6.5L12 3L15.5 6.5")),
    "status_at_peak": (       # dome + sparkle
        p(dome(9)) + p(SPARKLE),
        p(dome(9), True) + p(SPARKLE, True)),
    "status_collapsing": (    # sagging dome + down chevron
        p(SAG) + p("M8.5 3.5L12 7L15.5 3.5"),
        p(SAG, True) + p("M8.5 3.5L12 7L15.5 3.5")),
    "status_hungry": (        # empty bowl
        p("M3 10H21") + p("M4.5 10C4.5 15 7.8 18.5 12 18.5C16.2 18.5 19.5 15 19.5 10") + p("M9 21.2H15"),
        p("M3 10H21L19.5 10C19.5 15 16.2 18.5 12 18.5C7.8 18.5 4.5 15 4.5 10Z", True) + p("M9 21.2H15")),
    "status_dormant": (       # crescent moon
        p("M20 14.5A8.5 8.5 0 1 1 9.5 4A6.8 6.8 0 0 0 20 14.5Z"),
        p("M20 14.5A8.5 8.5 0 1 1 9.5 4A6.8 6.8 0 0 0 20 14.5Z", True)),
    "status_recovering": (    # half sun with rays
        p("M3 18.5H21") + p("M7 18.5A5 5 0 0 1 17 18.5")
        + p("M12 6V9") + p("M5.3 10L7.4 12.1") + p("M18.7 10L16.6 12.1"),
        p("M3 18.5H21") + p("M7 18.5A5 5 0 0 1 17 18.5Z", True)
        + p("M12 6V9") + p("M5.3 10L7.4 12.1") + p("M18.7 10L16.6 12.1")),
    "status_unhealthy": (     # wilted sprout
        p("M6 21H18") + p("M12 21V13C12 8.8 14.4 6.2 17.5 6.5") + p(LEAF_TIP) + p(LEAF_SIDE),
        p("M6 21H18") + p("M12 21V13C12 8.8 14.4 6.2 17.5 6.5") + p(LEAF_TIP, True) + p(LEAF_SIDE, True)),
    "status_moldy": (         # octagon with !
        p(octagon()) + p("M12 7.5V12.5") + dot(12, 16.5),
        p(octagon() + rrect(10, 6, 14, 14, 2) + ring(12, 17, 2.4), True, evenodd=True)),

    # --- Actions (bottom bar, canonical order). Selected = filled.
    "action_feed": (          # wheat ear (flour)
        p("M12 21.5V8") + "".join(p(g) for g in GRAINS),
        p("M12 21.5V8") + "".join(p(g, True) for g in GRAINS)),
    "action_smell": (         # wisps over the player's nose (the starter has no face)
        "".join(p(w) for w in WISPS) + p(NOSE_OPEN),
        "".join(p(w) for w in WISPS) + p(NOSE_SOLID, True)),
    "action_inspect": (       # magnifier with a bubble in the lens
        circle(10.5, 10.5, 6.5) + p("M15.3 15.3L20.5 20.5") + circle(10.5, 10.5, 1.5),
        p(ring(10.5, 10.5, 6.5) + ring(10.5, 10.5, 2.6), True, evenodd=True) + p("M15.3 15.3L20.5 20.5")),
    "action_environment": (   # house ("Place", sheet "Where it lives")
        p(HOUSE) + p("M10.5 20.5V16.5A1.5 1.5 0 0 1 13.5 16.5V20.5"),
        p(HOUSE + rrect(9.5, 13.5, 14.5, 18.5, 1.5), True, evenodd=True)),
    "action_journal": (       # book with spine and ribbon
        p(rrect(4, 3.5, 20, 20.5, 2)) + p("M8.5 3.5V20.5") + p("M13 3.5V9L14.75 7.75L16.5 9V3.5"),
        p("M6 3.5H6.5V20.5H6A2 2 0 0 1 4 18.5V5.5A2 2 0 0 1 6 3.5Z", True)
        + p("M10 3.5H18A2 2 0 0 1 20 5.5V18.5A2 2 0 0 1 18 20.5H10Z", True)),

    # --- Inspection kinds (chips). P0: height, bubbles, surface. P1: consistency, development.
    "inspect_height": (       # band, rise arrow, top line
        p("M7 3.5H17") + p("M5 20.5H19") + p("M12 7V17") + p("M9 9.5L12 6.5L15 9.5") + p("M9 14.5L12 17.5L15 14.5"),
        p("M7 3.5H17") + p("M5 20.5H19") + p("M12 7V17")
        + p("M9 9.5L12 6.5L15 9.5Z", True) + p("M9 14.5L12 17.5L15 14.5Z", True)),
    "inspect_bubbles": (      # jar with bubbles at the glass
        p("M8.5 3H15.5") + p(JAR) + circle(10, 15.5, 2) + circle(14.5, 11, 1.5),
        p("M8.5 3H15.5") + p(JAR + ring(10, 15.5, 3) + ring(14.5, 11, 2.5), True, evenodd=True)),
    "inspect_surface": (      # top surface seen at an angle, with pinholes
        '  <ellipse cx="12" cy="12" rx="9" ry="6"/>\n' + "".join(dot(x, y) for x, y in SURF_DOTS),
        p("M3 12A9 6 0 1 0 21 12A9 6 0 1 0 3 12Z" + "".join(ring(x, y, 2) for x, y in SURF_DOTS),
          True, evenodd=True)),
    "inspect_consistency": (  # a strand pulled from the spoon, ending in a drop
        p("M7 3H17") + p("M12 3V10.5") + p(DROP),
        p("M7 3H17") + p("M12 3V10.5") + p(DROP, True)),
    "inspect_development": (  # a slow orbit around the jar
        p(SMALL_JAR) + p("M10.5 7H13.5") + p(ORBIT) + p(ORBIT_HEAD),
        p(SMALL_JAR, True) + p("M10.5 7H13.5") + p(ORBIT) + p(ORBIT_HEAD)),
}

def gear():
    pts = []
    for k in range(8):
        c = 45.0 * k
        for a, r in ((c - 12, 9.4), (c + 12, 9.4), (c + 17, 7.2), (c + 28, 7.2)):
            pts.append((12 + r * math.cos(math.radians(a)), 12 + r * math.sin(math.radians(a))))
    return "M" + " L".join("%.2f %.2f" % q for q in pts) + "Z"


# Utility icons for the HUD and sheets (requested by T3). One variant each.
UI = {
    "ui_settings": p(gear()) + circle(12, 12, 2.8),
    "ui_close": p("M6.5 6.5L17.5 17.5") + p("M17.5 6.5L6.5 17.5"),
    "ui_back": p("M15 5L8 12L15 19"),
    "ui_check": p("M5 12.5L10 17.5L19 7"),
    "ui_chevron_right": p("M9 5L16 12L9 19"),
}

STATUS_TONES = {   # ux-design §11 / §16.1: tone, pill fill
    "freshly_fed": ("#4F7A45", "#F1E7D6"), "developing": ("#4F7A45", "#F1E7D6"),
    "active": ("#4F7A45", "#F1E7D6"), "near_peak": ("#4F7A45", "#F1E7D6"),
    "at_peak": ("#4F7A45", "#F1E7D6"), "collapsing": ("#8A6414", "#F1E7D6"),
    "hungry": ("#8A6414", "#F1E7D6"), "dormant": ("#4E6A80", "#F1E7D6"),
    "recovering": ("#4E6A80", "#F1E7D6"), "unhealthy": ("#6E4F12", "#F4E4BE"),
    "moldy": ("#FFFCF5", "#8E2B22"),
}


def write_all():
    os.makedirs(OUT, exist_ok=True)
    written = []
    for name, (outline, filled) in ICONS.items():
        for variant, body in (("outline", outline), ("filled", filled)):
            path = os.path.join(OUT, "%s_%s.svg" % (name, variant))
            with open(path, "w") as f:
                f.write(HEAD + body + "</svg>\n")
            written.append(path)
    for name, body in UI.items():
        path = os.path.join(OUT, "%s.svg" % name)
        with open(path, "w") as f:
            f.write(HEAD + body + "</svg>\n")
        written.append(path)
    return written


def check():
    """Render every icon at 24 px (1x) and lay out a sheet, magnified 4x with
    nearest-neighbor so single pixels stay visible. Row A: ink on surface_alt.
    Row B: status icons in their real tone on their real pill fill, in grayscale
    (moldy and unhealthy filled, as the pill shows them)."""
    for tool in ("rsvg-convert", "magick"):
        if not shutil.which(tool):
            sys.exit("--check needs %s on PATH" % tool)
    tmp = tempfile.mkdtemp(prefix="icons_")
    cells = []

    def render(name, variant, color, bg):
        src = os.path.join(OUT, ("%s_%s.svg" % (name, variant)) if variant else name + ".svg")
        svg = open(src).read().replace(W, color)
        tsvg = os.path.join(tmp, "%s_%s_%s.svg" % (name, variant, color[1:]))
        open(tsvg, "w").write(svg)
        png = tsvg[:-4] + ".png"
        subprocess.check_call(["rsvg-convert", "-w", "24", "-h", "24", "-b", bg, "-o", png, tsvg])
        return png

    groups = [("status", [n for n in ICONS if n.startswith("status_")]),
              ("action", [n for n in ICONS if n.startswith("action_")]),
              ("inspect", [n for n in ICONS if n.startswith("inspect_")])]
    rows = []
    for gname, names in groups:
        for variant in ("outline", "filled"):
            row = [render(n, variant, "#33241A", "#F1E7D6") for n in names]
            rows.append(row)
        if gname == "inspect":
            rows.append([render(n, None, "#33241A", "#F1E7D6") for n in UI])
        if gname == "status":
            gray = []
            for n in names:
                tone, fill = STATUS_TONES[n[len("status_"):]]
                variant = "filled" if n in ("status_unhealthy", "status_moldy") else "outline"
                gray.append(render(n, variant, tone, fill))
            rows.append(gray)
    row_pngs = []
    for i, row in enumerate(rows):
        out = os.path.join(tmp, "row%02d.png" % i)
        subprocess.check_call(["magick"] + row + ["-bordercolor", "#F1E7D6", "-border", "4",
                                                  "+append", out])
        row_pngs.append(out)
    sheet = os.path.join(tmp, "sheet.png")
    spaced = []
    for rp in row_pngs:
        sp = rp[:-4] + "_s.png"
        subprocess.check_call(["magick", rp, "-background", "#FBF6EC", "-gravity", "north",
                               "-splice", "0x6", sp])
        spaced.append(sp)
    subprocess.check_call(["magick"] + spaced + ["-background", "#FBF6EC", "-gravity", "west",
                                                 "-append", sheet])
    # The grayscale row is the third row of the status block.
    subprocess.check_call(["magick", sheet, "-filter", "point", "-resize", "400%", CHECK_OUT])
    gray_row = os.path.join(tmp, "gray.png")
    subprocess.check_call(["magick", row_pngs[2], "-colorspace", "Gray", gray_row])
    subprocess.check_call(["magick", CHECK_OUT, "(", gray_row, "-filter", "point", "-resize", "400%", ")",
                           "-background", "#FBF6EC", "-append", CHECK_OUT])
    shutil.rmtree(tmp)
    return CHECK_OUT


if __name__ == "__main__":
    files = write_all()
    print("WROTE %d files in %s" % (len(files), OUT))
    if "--check" in sys.argv:
        print("CHECK", check())
