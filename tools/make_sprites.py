#!/usr/bin/env python3
"""Generate top-down character spritesheets (walk + death) for the soldier,
ally soldier, and zombie. Transparent PNG strips, N frames laid out
horizontally. Deterministic. Output: ../art/<kind>_<anim>.png
Run:  python3 tools/make_sprites.py
"""
import math, os
from PIL import Image, ImageDraw

SS = 4                      # supersample
FRAME = 128                 # per-frame tile size (px)
WALK_FRAMES = 6
DEATH_FRAMES = 5
S = 44                      # character draw scale within the tile
OUT = os.path.join(os.path.dirname(__file__), "..", "art")
os.makedirs(OUT, exist_ok=True)

def hx(c):
    c = c.lstrip("#")
    return tuple(int(c[i:i+2], 16) for i in (0, 2, 4))

# Brighter, higher-contrast so characters pop against the dark game background.
SKIN, RIFLE, OUTLINE = hx("f2c48f"), hx("2c313c"), hx("0c1018")
P_UNI, P_HELM, P_ACC = hx("3d86e0"), hx("2b5a9e"), hx("9becff")   # player (bright blue)
A_UNI, A_HELM, A_ACC = hx("4cc85a"), hx("2f8a3c"), hx("caffb0")   # ally (bright green)
Z_SKIN, Z_BODY, Z_DARK, Z_BLOOD = hx("bfe07a"), hx("9bb85f"), hx("6b8040"), hx("d84540")  # zombie (brighter)

def A(c, a=255):
    return c + (a,)

def rr(d, cx, cy, hw, hh, col, r=None, outline=OUTLINE, ow=None):
    if r is None: r = min(hw, hh) * 0.5
    if ow is None: ow = int(2 * SS)
    kw = {"fill": A(col)}
    if outline is not None and ow > 0:
        kw["outline"] = A(outline); kw["width"] = ow
    d.rounded_rectangle([cx - hw, cy - hh, cx + hw, cy + hh], radius=r, **kw)

def circ(d, cx, cy, rad, col, outline=OUTLINE, ow=None):
    if ow is None: ow = int(2 * SS)
    kw = {"fill": A(col)}
    if outline is not None and ow > 0:
        kw["outline"] = A(outline); kw["width"] = ow
    d.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], **kw)

def draw_soldier(d, cx, cy, s, uni, helm, acc, phase):
    swing = math.sin(phase) * 0.30 * s
    cy += -abs(math.sin(phase)) * 0.05 * s
    rr(d, cx - 0.62 * s, cy - 0.34 * s + swing, 0.20 * s, 0.13 * s, helm, r=0.1 * s)
    rr(d, cx - 0.62 * s, cy + 0.34 * s - swing, 0.20 * s, 0.13 * s, helm, r=0.1 * s)
    rr(d, cx + 0.75 * s, cy + 0.02 * s, 0.62 * s, 0.075 * s, RIFLE, r=0.05 * s)
    rr(d, cx + 0.18 * s, cy + 0.16 * s, 0.14 * s, 0.14 * s, RIFLE, r=0.06 * s)
    rr(d, cx, cy, 0.56 * s, 0.72 * s, uni, r=0.34 * s)
    rr(d, cx - 0.1 * s, cy, 0.14 * s, 0.72 * s, acc, r=0.12 * s, ow=0)
    rr(d, cx + 0.42 * s, cy - 0.30 * s, 0.30 * s, 0.12 * s, uni, r=0.1 * s)
    rr(d, cx + 0.42 * s, cy + 0.30 * s, 0.30 * s, 0.12 * s, uni, r=0.1 * s)
    circ(d, cx + 0.72 * s, cy - 0.30 * s, 0.10 * s, SKIN)
    circ(d, cx + 0.72 * s, cy + 0.30 * s, 0.10 * s, SKIN)
    circ(d, cx + 0.12 * s, cy, 0.36 * s, SKIN)
    circ(d, cx - 0.02 * s, cy, 0.40 * s, helm)
    circ(d, cx - 0.02 * s, cy, 0.12 * s, acc, outline=None, ow=0)

def draw_zombie(d, cx, cy, s, phase):
    swing = math.sin(phase) * 0.34 * s
    cx += math.sin(phase * 0.5) * 0.05 * s
    rr(d, cx - 0.58 * s, cy - 0.30 * s + swing, 0.18 * s, 0.12 * s, Z_DARK, r=0.08 * s)
    rr(d, cx - 0.58 * s, cy + 0.30 * s - swing, 0.18 * s, 0.12 * s, Z_DARK, r=0.08 * s)
    rr(d, cx + 0.55 * s, cy - 0.26 * s - 0.10 * s * math.sin(phase), 0.42 * s, 0.11 * s, Z_BODY, r=0.09 * s)
    rr(d, cx + 0.55 * s, cy + 0.26 * s + 0.10 * s * math.sin(phase), 0.42 * s, 0.11 * s, Z_BODY, r=0.09 * s)
    circ(d, cx + 0.96 * s, cy - 0.26 * s, 0.10 * s, Z_SKIN)
    circ(d, cx + 0.96 * s, cy + 0.26 * s, 0.10 * s, Z_SKIN)
    rr(d, cx, cy, 0.50 * s, 0.60 * s, Z_BODY, r=0.28 * s)
    circ(d, cx - 0.12 * s, cy - 0.22 * s, 0.10 * s, Z_DARK, outline=None, ow=0)
    circ(d, cx + 0.10 * s, cy + 0.18 * s, 0.08 * s, Z_BLOOD, outline=None, ow=0)
    circ(d, cx + 0.20 * s, cy + 0.04 * s, 0.34 * s, Z_SKIN)
    circ(d, cx + 0.30 * s, cy - 0.10 * s, 0.055 * s, OUTLINE, outline=None, ow=0)
    circ(d, cx + 0.30 * s, cy + 0.14 * s, 0.055 * s, OUTLINE, outline=None, ow=0)
    d.line([cx + 0.44 * s, cy - 0.02 * s, cx + 0.40 * s, cy + 0.10 * s], fill=A(Z_BLOOD), width=int(2 * SS))

def base_tile(kind, phase):
    """Render one character, centered, on a transparent FRAME tile."""
    big = Image.new("RGBA", (FRAME * SS, FRAME * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    c = FRAME * SS / 2
    if kind == "player":
        draw_soldier(d, c, c, S * SS, P_UNI, P_HELM, P_ACC, phase)
    elif kind == "ally":
        draw_soldier(d, c, c, S * SS, A_UNI, A_HELM, A_ACC, phase)
    else:
        draw_zombie(d, c, c, S * SS, phase)
    return big.resize((FRAME, FRAME), Image.LANCZOS)

def fade(im, factor):
    r, g, b, a = im.split()
    a = a.point(lambda v: int(v * factor))
    return Image.merge("RGBA", (r, g, b, a))

def death_tile(kind, t):
    """Compose a death frame: topple (squash + rotate) + fade over a pool."""
    canvas = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    d = ImageDraw.Draw(canvas)
    # ground pool grows as it dies (blood for zombie, shadow for soldiers)
    pr = int(FRAME * (0.18 + 0.22 * t))
    pool = Z_BLOOD if kind == "zombie" else (10, 12, 18)
    palpha = int(150 * t)
    cx = FRAME // 2
    cy = int(FRAME * 0.56)
    d.ellipse([cx - pr, cy - pr * 0.5, cx + pr, cy + pr * 0.5], fill=pool + (palpha,))
    # transform the body
    body = base_tile(kind, 0.0)
    sy = max(0.05, 1.0 - 0.55 * t)
    body = body.resize((FRAME, max(1, int(FRAME * sy))), Image.LANCZOS)
    body = body.rotate(18 * t, expand=True, resample=Image.BICUBIC)
    body = fade(body, 1.0 - 0.82 * t)
    bx = cx - body.width // 2
    by = int(FRAME * 0.5) - body.height // 2 + int(FRAME * 0.06 * t)
    canvas.alpha_composite(body, (bx, by))
    return canvas

def strip(frames):
    w = FRAME * len(frames)
    sheet = Image.new("RGBA", (w, FRAME), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.alpha_composite(fr, (i * FRAME, 0))
    return sheet

def save(name, sheet):
    p = os.path.join(OUT, name)
    sheet.save(p)
    print("wrote", os.path.relpath(p), sheet.size)

if __name__ == "__main__":
    for kind in ("player", "ally", "zombie"):
        walk = [base_tile(kind, 2 * math.pi * i / WALK_FRAMES) for i in range(WALK_FRAMES)]
        death = [death_tile(kind, (i + 1) / DEATH_FRAMES) for i in range(DEATH_FRAMES)]
        save(f"{kind}_walk.png", strip(walk))
        save(f"{kind}_death.png", strip(death))
    print("done")
