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

def light(col, f):
    return tuple(min(255, int(c + (255 - c) * f)) for c in col[:3])

def dark(col, f):
    return tuple(max(0, int(c * (1 - f))) for c in col[:3])

def draw_soldier(d, cx, cy, s, uni, helm, acc, phase):
    swing = math.sin(phase) * 0.30 * s
    cy += -abs(math.sin(phase)) * 0.05 * s
    OW = int(3 * SS)
    uni_l = light(uni, 0.30); uni_d = dark(uni, 0.28)
    # boots (back)
    rr(d, cx - 0.66 * s, cy - 0.34 * s + swing, 0.20 * s, 0.13 * s, helm, r=0.09 * s, ow=OW)
    rr(d, cx - 0.66 * s, cy + 0.34 * s - swing, 0.20 * s, 0.13 * s, helm, r=0.09 * s, ow=OW)
    # big gun: receiver + magazine + long barrel + muzzle
    rr(d, cx + 0.30 * s, cy + 0.12 * s, 0.22 * s, 0.20 * s, dark(RIFLE, 0.18), r=0.06 * s, ow=OW)
    rr(d, cx + 0.30 * s, cy + 0.36 * s, 0.09 * s, 0.16 * s, RIFLE, r=0.04 * s, ow=OW)
    rr(d, cx + 0.98 * s, cy + 0.00 * s, 0.72 * s, 0.10 * s, RIFLE, r=0.05 * s, ow=OW)
    rr(d, cx + 0.98 * s, cy - 0.045 * s, 0.66 * s, 0.028 * s, light(RIFLE, 0.45), r=0.02 * s, ow=0)
    rr(d, cx + 1.66 * s, cy + 0.00 * s, 0.06 * s, 0.12 * s, dark(RIFLE, 0.3), r=0.03 * s, ow=OW)
    # arms to the grip
    rr(d, cx + 0.42 * s, cy - 0.28 * s, 0.34 * s, 0.13 * s, uni, r=0.1 * s, ow=OW)
    rr(d, cx + 0.42 * s, cy + 0.26 * s, 0.30 * s, 0.12 * s, uni, r=0.1 * s, ow=OW)
    circ(d, cx + 0.74 * s, cy - 0.28 * s, 0.11 * s, SKIN, ow=OW)
    circ(d, cx + 0.40 * s, cy + 0.32 * s, 0.11 * s, SKIN, ow=OW)
    # torso with top highlight + bottom shade
    rr(d, cx, cy, 0.58 * s, 0.74 * s, uni, r=0.34 * s, ow=OW)
    rr(d, cx + 0.04 * s, cy - 0.30 * s, 0.48 * s, 0.26 * s, uni_l, r=0.26 * s, ow=0)
    rr(d, cx, cy + 0.52 * s, 0.54 * s, 0.20 * s, uni_d, r=0.24 * s, ow=0)
    # accent shoulder pads + chest stripe
    rr(d, cx + 0.06 * s, cy - 0.62 * s, 0.20 * s, 0.15 * s, acc, r=0.09 * s, ow=OW)
    rr(d, cx + 0.06 * s, cy + 0.62 * s, 0.20 * s, 0.15 * s, acc, r=0.09 * s, ow=OW)
    rr(d, cx - 0.06 * s, cy, 0.09 * s, 0.46 * s, acc, r=0.07 * s, ow=0)
    # head + big helmet
    circ(d, cx + 0.16 * s, cy, 0.32 * s, SKIN, ow=OW)
    circ(d, cx - 0.02 * s, cy, 0.44 * s, helm, ow=OW)
    rr(d, cx + 0.24 * s, cy, 0.08 * s, 0.22 * s, acc, r=0.05 * s, ow=0)     # visor band
    d.ellipse([cx - 0.24 * s, cy - 0.36 * s, cx + 0.00 * s, cy - 0.08 * s], fill=(255, 255, 255, 70))
    circ(d, cx - 0.06 * s, cy, 0.11 * s, acc, outline=None, ow=0)           # team dot

def draw_zombie(d, cx, cy, s, phase):
    swing = math.sin(phase) * 0.34 * s
    cx += math.sin(phase * 0.5) * 0.05 * s
    OW = int(3 * SS)
    # feet
    rr(d, cx - 0.56 * s, cy - 0.30 * s + swing, 0.18 * s, 0.12 * s, Z_DARK, r=0.08 * s, ow=OW)
    rr(d, cx - 0.56 * s, cy + 0.30 * s - swing, 0.18 * s, 0.12 * s, Z_DARK, r=0.08 * s, ow=OW)
    # reaching arms + claws
    rr(d, cx + 0.55 * s, cy - 0.26 * s - 0.10 * s * math.sin(phase), 0.44 * s, 0.12 * s, Z_BODY, r=0.09 * s, ow=OW)
    rr(d, cx + 0.55 * s, cy + 0.26 * s + 0.10 * s * math.sin(phase), 0.44 * s, 0.12 * s, Z_BODY, r=0.09 * s, ow=OW)
    for hy in (-0.26, 0.26):
        hx = cx + 1.0 * s; yy = cy + hy * s
        for k in (-1, 0, 1):
            base = yy + k * 0.07 * s
            d.polygon([(hx, base - 0.03 * s), (hx + 0.13 * s, base), (hx, base + 0.03 * s)],
                      fill=A(Z_SKIN), outline=A(OUTLINE))
    # blob body with shading
    circ(d, cx, cy, 0.56 * s, Z_BODY, ow=OW)
    d.ellipse([cx - 0.5 * s, cy + 0.08 * s, cx + 0.5 * s, cy + 0.62 * s], fill=A(dark(Z_BODY, 0.30), 170))
    circ(d, cx - 0.12 * s, cy - 0.20 * s, 0.26 * s, light(Z_BODY, 0.16), outline=None, ow=0)
    circ(d, cx - 0.18 * s, cy + 0.16 * s, 0.09 * s, Z_DARK, outline=None, ow=0)
    # face
    circ(d, cx + 0.22 * s, cy, 0.30 * s, Z_SKIN, ow=OW)
    # big glowing red eyes
    for ey in (-0.12, 0.12):
        ex = cx + 0.31 * s; eyy = cy + ey * s
        circ(d, ex, eyy, 0.12 * s, (255, 40, 40), outline=None, ow=0)
        circ(d, ex, eyy, 0.075 * s, (255, 80, 80), ow=int(2 * SS))
        circ(d, ex + 0.02 * s, eyy, 0.028 * s, (255, 210, 210), outline=None, ow=0)
    # angry brows
    d.line([cx + 0.18 * s, cy - 0.22 * s, cx + 0.34 * s, cy - 0.08 * s], fill=A(Z_DARK), width=int(3 * SS))
    d.line([cx + 0.18 * s, cy + 0.22 * s, cx + 0.34 * s, cy + 0.08 * s], fill=A(Z_DARK), width=int(3 * SS))
    # snarling mouth + teeth
    d.line([(cx + 0.42 * s, cy - 0.13 * s), (cx + 0.47 * s, cy), (cx + 0.42 * s, cy + 0.13 * s)],
           fill=(40, 18, 18, 255), width=int(3 * SS), joint="curve")
    for ty in (-0.07, 0.0, 0.07):
        d.polygon([(cx + 0.44 * s, cy + ty * s - 0.022 * s), (cx + 0.505 * s, cy + ty * s),
                   (cx + 0.44 * s, cy + ty * s + 0.022 * s)], fill=(255, 255, 255, 235))

def base_tile(kind, phase):
    """Render one character, centered, on a transparent FRAME tile."""
    big = Image.new("RGBA", (FRAME * SS, FRAME * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    c = FRAME * SS / 2
    if kind == "player":
        draw_soldier(d, c, c, S * SS, P_UNI, P_HELM, P_ACC, phase)
    elif kind == "zombie":
        draw_zombie(d, c, c, S * SS, phase)
    else:
        u, h, a = SOLDIER_COLORS[kind]
        draw_soldier(d, c, c, S * SS, u, h, a, phase)
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

# Soldier color sets. "ally" is the neutral (uncollected) soldier; the four
# ally_<weapon> variants recolor the uniform to match each gun's color so a
# collected soldier visibly reads as its weapon.
SOLDIER_COLORS = {
    "player":       (P_UNI, P_HELM, P_ACC),
    "ally":         (A_UNI, A_HELM, A_ACC),
    "ally_railgun": (hx("6a46b8"), hx("452f86"), hx("cbb0ff")),
    "ally_rocket":  (hx("c8702f"), hx("8a4c20"), hx("ffc48a")),
    "ally_sniper":  (hx("2f86b0"), hx("205a80"), hx("bfeeff")),
    "ally_flame":   (hx("c8452f"), hx("8a2f20"), hx("ffb08a")),
}

if __name__ == "__main__":
    for kind in list(SOLDIER_COLORS.keys()) + ["zombie"]:
        walk = [base_tile(kind, 2 * math.pi * i / WALK_FRAMES) for i in range(WALK_FRAMES)]
        death = [death_tile(kind, (i + 1) / DEATH_FRAMES) for i in range(DEATH_FRAMES)]
        save(f"{kind}_walk.png", strip(walk))
        save(f"{kind}_death.png", strip(death))
    print("done")
