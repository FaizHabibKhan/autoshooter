#!/usr/bin/env python3
"""Generate the wasteland battleground art: a tileable dirt ground, a cracked
asphalt road tile, scatter decals (rock / rubble / crater), and a vignette.
Deterministic. Output -> ../art/
Run:  python3 tools/make_terrain.py
"""
import math, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "art")
os.makedirs(OUT, exist_ok=True)

def tnoise(w, h, comps, seed):
    """Tileable value noise via a sum of integer-frequency sine gratings."""
    r = np.random.default_rng(seed)
    y, x = np.mgrid[0:h, 0:w].astype(float)
    x /= w; y /= h
    out = np.zeros((h, w))
    for _ in range(comps):
        fx = int(r.integers(1, 6)); fy = int(r.integers(1, 6))
        ph = r.uniform(0, 2 * math.pi); amp = r.uniform(0.4, 1.0)
        out += amp * np.sin(2 * math.pi * (fx * x + fy * y) + ph)
    out = (out - out.min()) / (out.max() - out.min() + 1e-9)
    return out

def save(img, name):
    p = os.path.join(OUT, name)
    img.save(p)
    print("wrote", os.path.relpath(p), img.size)

# --- ground ------------------------------------------------------------------
def ground(size=512):
    n = tnoise(size, size, 5, 1) * 0.6 + tnoise(size, size, 11, 2) * 0.4
    lo = np.array([70, 60, 45]); hi = np.array([108, 92, 66])
    rgb = (lo + (hi - lo) * n[..., None]).astype(np.uint8)
    im = Image.fromarray(rgb, "RGB").convert("RGBA")
    d = ImageDraw.Draw(im, "RGBA")
    r = np.random.default_rng(9)
    # pebbles (wrapped so the tile is seamless)
    for _ in range(46):
        px = int(r.integers(0, size)); py = int(r.integers(0, size)); rad = int(r.integers(2, 6))
        g = int(115 + r.integers(-25, 35))
        for ox in (-size, 0, size):
            for oy in (-size, 0, size):
                d.ellipse([px+ox-rad, py+oy-rad, px+ox+rad, py+oy+rad], fill=(g, g-6, g-14, 150))
    # speckle grain
    arr = np.array(im)
    m = r.random((size, size)) < 0.035
    delta = r.integers(-16, 16, size=(size, size))
    for c in range(3):
        arr[..., c] = np.clip(arr[..., c].astype(int) + np.where(m, delta, 0), 0, 255)
    save(Image.fromarray(arr, "RGBA"), "ground_tile.png")

# --- road (cracked asphalt) --------------------------------------------------
def road(w=512, h=256):
    n = tnoise(w, h, 6, 3)
    lo = np.array([52, 52, 58]); hi = np.array([84, 84, 92])
    rgb = (lo + (hi - lo) * n[..., None]).astype(np.uint8)
    im = Image.fromarray(rgb, "RGB").convert("RGBA")
    d = ImageDraw.Draw(im, "RGBA")
    r = np.random.default_rng(4)
    # aggregate speckle
    for _ in range(400):
        px = int(r.integers(0, w)); py = int(r.integers(0, h)); s = int(r.integers(1, 3))
        v = int(r.integers(90, 150))
        d.ellipse([px, py, px+s, py+s], fill=(v, v, v+4, 120))
    # cracks (wrapped horizontally)
    for _ in range(7):
        x0 = int(r.integers(0, w)); y0 = int(r.integers(0, h))
        pts = [(x0, y0)]
        for _ in range(int(r.integers(3, 6))):
            x0 += int(r.integers(-40, 40)); y0 += int(r.integers(-30, 30))
            pts.append((x0, y0))
        for ox in (-w, 0, w):
            d.line([(px+ox, py) for (px, py) in pts], fill=(28, 28, 32, 180), width=2)
    save(im, "road_tile.png")

# --- decals ------------------------------------------------------------------
def _shadow(d, cx, cy, rx, ry):
    d.ellipse([cx-rx, cy-ry, cx+rx, cy+ry], fill=(0, 0, 0, 70))

def rock(size=110):
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im, "RGBA")
    c = size // 2
    _shadow(d, c, c + 14, 40, 16)
    r = np.random.default_rng(21)
    pts = []
    for i in range(9):
        a = 2 * math.pi * i / 9
        rad = 34 + r.uniform(-7, 7)
        pts.append((c + math.cos(a) * rad, c + math.sin(a) * rad * 0.8))
    d.polygon(pts, fill=(96, 96, 104, 255), outline=(30, 30, 36, 255))
    # top highlight
    d.polygon([(p[0]*0.7 + c*0.3, p[1]*0.7 + (c-8)*0.3) for p in pts[5:9] + pts[0:2]],
              fill=(126, 126, 134, 160))
    save(im, "decal_rock.png")

def rubble(size=130):
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im, "RGBA")
    c = size // 2
    _shadow(d, c, c + 12, 52, 16)
    r = np.random.default_rng(31)
    for _ in range(9):
        px = c + int(r.integers(-40, 40)); py = c + int(r.integers(-18, 22))
        w = int(r.integers(12, 26)); h = int(r.integers(9, 18))
        g = int(r.integers(80, 120))
        d.rectangle([px, py, px+w, py+h], fill=(g, g, g+6, 255), outline=(30, 30, 36, 255), width=2)
        d.rectangle([px, py, px+w, py+3], fill=(g+22, g+22, g+26, 200))
    save(im, "decal_rubble.png")

def crater(size=150):
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im, "RGBA")
    c = size // 2
    d.ellipse([c-58, c-40, c+58, c+40], fill=(30, 24, 18, 150))     # scorch
    d.ellipse([c-40, c-27, c+40, c+27], fill=(18, 14, 10, 220))     # inner
    r = np.random.default_rng(41)
    for _ in range(10):
        a = r.uniform(0, 2*math.pi); l = r.uniform(40, 62)
        d.line([c, c, c + math.cos(a)*l, c + math.sin(a)*l*0.68], fill=(20, 16, 12, 160), width=2)
    im = im.filter(ImageFilter.GaussianBlur(1.2))
    save(im, "decal_crater.png")

# --- vignette (screen overlay) ----------------------------------------------
def vignette(w=1152, h=648):
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    dx = (xx - w/2) / (w/2); dy = (yy - h/2) / (h/2)
    dist = np.sqrt(dx*dx + dy*dy)
    a = np.clip((dist - 0.55) / 0.75, 0, 1) ** 1.6
    img = np.zeros((h, w, 4), np.uint8)
    img[..., 3] = (a * 165).astype(np.uint8)   # dark, transparent center
    save(Image.fromarray(img, "RGBA"), "vignette.png")

if __name__ == "__main__":
    ground(); road(); rock(); rubble(); crater(); vignette()
    print("done")
