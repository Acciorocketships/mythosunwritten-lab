#!/usr/bin/env python3
"""Draw reports/assets/item-trade.png from reports/assets/item-trade.csv.

Two panels, same generator and same seed. Left: worn items that all came out
with the identical power budget of 32, so movement and defence are two halves
of one pool. Right: the same 400 worn items with the equal-budget filter
dropped, where a bigger budget lifts both axes at once and the trade vanishes.

No third-party packages: the PNG is written by hand with zlib.

  python3 tools/plot_item_trade.py
"""
import csv, math, struct, zlib

W, H = 1000, 520
BG = (255, 255, 255)
INK = (34, 38, 46)
GRID = (222, 226, 232)
WARM = (214, 122, 48)
COOL = (58, 118, 156)

buf = bytearray()
for _ in range(W * H):
    buf += bytes(BG)


def px(x, y, rgb, a=1.0):
    if not (0 <= x < W and 0 <= y < H):
        return
    i = (y * W + x) * 3
    for k in range(3):
        buf[i + k] = int(round(buf[i + k] * (1 - a) + rgb[k] * a))


def rect(x0, y0, x1, y1, rgb, a=1.0):
    for y in range(int(y0), int(y1) + 1):
        for x in range(int(x0), int(x1) + 1):
            px(x, y, rgb, a)


def line(x0, y0, x1, y1, rgb, a=1.0):
    n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for s in range(n + 1):
        t = s / n
        px(int(round(x0 + (x1 - x0) * t)), int(round(y0 + (y1 - y0) * t)), rgb, a)


def disc(cx, cy, r, rgb, a=1.0):
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= r * r:
                px(cx + dx, cy + dy, rgb, a)


# A 5x7 bitmap font, enough for the labels used here.
GLYPHS = {
    " ": [0, 0, 0, 0, 0], "0": [0x3E, 0x45, 0x49, 0x51, 0x3E], "1": [0x00, 0x42, 0x7F, 0x40, 0x00],
    "2": [0x62, 0x51, 0x49, 0x49, 0x46], "3": [0x22, 0x41, 0x49, 0x49, 0x36],
    "4": [0x18, 0x14, 0x12, 0x7F, 0x10], "5": [0x27, 0x45, 0x45, 0x45, 0x39],
    "6": [0x3C, 0x4A, 0x49, 0x49, 0x30], "7": [0x01, 0x71, 0x09, 0x05, 0x03],
    "8": [0x36, 0x49, 0x49, 0x49, 0x36], "9": [0x06, 0x49, 0x49, 0x29, 0x1E],
    "=": [0x14, 0x14, 0x14, 0x14, 0x14], "-": [0x08, 0x08, 0x08, 0x08, 0x08],
    ".": [0x00, 0x60, 0x60, 0x00, 0x00], ",": [0x00, 0x80, 0x60, 0x00, 0x00],
    "(": [0x00, 0x1C, 0x22, 0x41, 0x00], ")": [0x00, 0x41, 0x22, 0x1C, 0x00],
    ":": [0x00, 0x36, 0x36, 0x00, 0x00], "+": [0x08, 0x08, 0x3E, 0x08, 0x08],
    "A": [0x7E, 0x11, 0x11, 0x11, 0x7E], "B": [0x7F, 0x49, 0x49, 0x49, 0x36],
    "C": [0x3E, 0x41, 0x41, 0x41, 0x22], "D": [0x7F, 0x41, 0x41, 0x22, 0x1C],
    "E": [0x7F, 0x49, 0x49, 0x49, 0x41], "F": [0x7F, 0x09, 0x09, 0x09, 0x01],
    "G": [0x3E, 0x41, 0x49, 0x49, 0x7A], "H": [0x7F, 0x08, 0x08, 0x08, 0x7F],
    "I": [0x00, 0x41, 0x7F, 0x41, 0x00], "J": [0x20, 0x40, 0x41, 0x3F, 0x01],
    "K": [0x7F, 0x08, 0x14, 0x22, 0x41], "L": [0x7F, 0x40, 0x40, 0x40, 0x40],
    "M": [0x7F, 0x02, 0x0C, 0x02, 0x7F], "N": [0x7F, 0x04, 0x08, 0x10, 0x7F],
    "O": [0x3E, 0x41, 0x41, 0x41, 0x3E], "P": [0x7F, 0x09, 0x09, 0x09, 0x06],
    "Q": [0x3E, 0x41, 0x51, 0x21, 0x5E], "R": [0x7F, 0x09, 0x19, 0x29, 0x46],
    "S": [0x46, 0x49, 0x49, 0x49, 0x31], "T": [0x01, 0x01, 0x7F, 0x01, 0x01],
    "U": [0x3F, 0x40, 0x40, 0x40, 0x3F], "V": [0x1F, 0x20, 0x40, 0x20, 0x1F],
    "W": [0x3F, 0x40, 0x38, 0x40, 0x3F], "X": [0x63, 0x14, 0x08, 0x14, 0x63],
    "Y": [0x07, 0x08, 0x70, 0x08, 0x07], "Z": [0x61, 0x51, 0x49, 0x45, 0x43],
}


def text(x, y, s, rgb, scale=2, a=1.0):
    s = s.upper()
    cx = x
    for ch in s:
        cols = GLYPHS.get(ch, GLYPHS[" "])
        for ci, bits in enumerate(cols):
            for row in range(7):
                if bits >> row & 1:
                    rect(cx + ci * scale, y + row * scale,
                         cx + ci * scale + scale - 1, y + row * scale + scale - 1, rgb, a)
        cx += (5 + 1) * scale
    return cx


def corr(xs, ys):
    n = len(xs)
    mx, my = sum(xs) / n, sum(ys) / n
    cov = sum((x - mx) * (y - my) for x, y in zip(xs, ys))
    vx = sum((x - mx) ** 2 for x in xs)
    vy = sum((y - my) ** 2 for y in ys)
    return cov / math.sqrt(vx * vy)


rows = list(csv.DictReader(open("reports/assets/item-trade.csv")))
worn = [r for r in rows if r["kind"] == "worn"]
equal = [r for r in worn if r["budget"] == "32"]


def panel(ox, oy, w, h, pts, hi, title, sub, colour, ceiling=None):
    rect(ox, oy, ox + w, oy + h, (252, 252, 253))
    for t in range(0, hi + 1, max(1, hi // 4)):
        gx = ox + int(w * t / hi)
        gy = oy + h - int(h * t / hi)
        line(gx, oy, gx, oy + h, GRID)
        line(ox, gy, ox + w, gy, GRID)
        text(gx - 8, oy + h + 10, str(t), INK, 1)
        text(ox - 22, gy - 4, str(t), INK, 1)
    line(ox, oy, ox, oy + h, INK)
    line(ox, oy + h, ox + w, oy + h, INK)
    if ceiling:
        line(ox, oy + h - int(h * ceiling / hi), ox + int(w * ceiling / hi), oy + h, (150, 60, 60), 0.8)
    for r in pts:
        m, d = int(r["movement"]), int(r["defence"])
        cx = ox + int(w * m / hi)
        cy = oy + h - int(h * d / hi)
        disc(cx, cy, 3, colour, 0.5)
    text(ox, oy - 34, title, INK, 2)
    text(ox, oy - 14, sub, (110, 116, 124), 1)


P_W, P_H = 380, 320
panel(70, 116, P_W, P_H, equal, 32,
      "one budget: 194 worn items, all P=32",
      "R(MOVEMENT, DEFENCE) = -0.9382   RED LINE: MOVEMENT + DEFENCE = 32",
      WARM, ceiling=32)
mx = max(int(r["movement"]) for r in worn)
dx = max(int(r["defence"]) for r in worn)
panel(590, 116, P_W, P_H, worn, max(mx, dx),
      "control: 400 worn, budgets mixed",
      "R(MOVEMENT, DEFENCE) = -0.0586   SAME GENERATOR, FILTER DROPPED",
      COOL)
text(70, 28, "movement against defence on one worn item", INK, 3)
text(70, 470, "movement axis (horizontal) against defence axis (vertical), seed 1234, source level 8", (110, 116, 124), 1)
text(70, 488, "tools/item_trade_dump.sh | python3 tools/plot_item_trade.py", (110, 116, 124), 1)

raw = b"".join(b"\x00" + bytes(buf[y * W * 3:(y + 1) * W * 3]) for y in range(H))


def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))


png = (b"\x89PNG\r\n\x1a\n"
       + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
       + chunk(b"IDAT", zlib.compress(raw, 9))
       + chunk(b"IEND", b""))
open("reports/assets/item-trade.png", "wb").write(png)
print("wrote reports/assets/item-trade.png  %d bytes" % len(png))
print("equal-budget n=%d r=%.4f" % (len(equal), corr([int(r["movement"]) for r in equal], [int(r["defence"]) for r in equal])))
print("control     n=%d r=%.4f" % (len(worn), corr([int(r["movement"]) for r in worn], [int(r["defence"]) for r in worn])))
