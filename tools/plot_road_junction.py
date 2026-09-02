#!/usr/bin/env python3
"""Draw reports/assets/road-junction.png from the two road-junction CSVs.

One traverse: in along one road, through the place where three roads meet on
seed 1234, and out along the next. Left panel is the height of the finished
ground, before and after the carve stopped levelling to a blend of two
centrelines, with the land it is worn into behind them. Right panel is what one
3.0-unit step of that walk climbs, against the 3.0 units a character can step up.

No third-party packages: the PNG is written by hand with zlib, the same way
tools/plot_item_trade.py does it.

  ./tools/road_profile_dump.sh > reports/assets/road-junction-after.csv
  python3 tools/plot_road_junction.py
"""
import csv, struct, zlib

W, H = 1020, 520
BG = (255, 255, 255)
INK = (34, 38, 46)
GRID = (222, 226, 232)
WARM = (214, 122, 48)
COOL = (58, 118, 156)
LAND = (168, 174, 182)
LIMIT = (176, 62, 62)

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


def line(x0, y0, x1, y1, rgb, a=1.0, weight=1):
    n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for s in range(n + 1):
        t = s / n
        x = int(round(x0 + (x1 - x0) * t))
        y = int(round(y0 + (y1 - y0) * t))
        for d in range(weight):
            px(x, y + d, rgb, a)


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
    "/": [0x60, 0x18, 0x06, 0x01, 0x00], "'": [0x00, 0x07, 0x00, 0x00, 0x00],
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


def read(path):
    lines = open(path).read().splitlines()
    start = next(i for i, l in enumerate(lines) if l.startswith("s,x,z"))
    rows = list(csv.DictReader(lines[start:]))
    return [(float(r["s"]), float(r["ground"]), float(r["land"])) for r in rows]


before = read("reports/assets/road-junction-before.csv")
after = read("reports/assets/road-junction-after.csv")
STEP = 3.0  # one cell of the tactical lattice
SPACING = 0.5  # how finely the traverse was sampled


def climbs(rows):
    stride = int(round(STEP / SPACING))
    return [(rows[i][0], abs(rows[i][1] - rows[i - stride][1]))
            for i in range(stride, len(rows))]


def frame(ox, oy, w, h, x0, x1, y0, y1, title, sub, ticks):
    rect(ox, oy, ox + w, oy + h, (252, 252, 253))
    for t in ticks:
        gy = oy + h - int(h * (t - y0) / (y1 - y0))
        line(ox, gy, ox + w, gy, GRID)
        text(ox - 34, gy - 4, ("%.1f" % t), INK, 1)
    for s in range(int(x0), int(x1) + 1, 10):
        gx = ox + int(w * (s - x0) / (x1 - x0))
        line(gx, oy, gx, oy + h, GRID)
        text(gx - 8, oy + h + 10, str(s), INK, 1)
    line(ox, oy, ox, oy + h, INK)
    line(ox, oy + h, ox + w, oy + h, INK)
    text(ox, oy - 34, title, INK, 2)
    text(ox, oy - 14, sub, (110, 116, 124), 1)


def plot(ox, oy, w, h, x0, x1, y0, y1, series, rgb, weight=2):
    last = None
    for sx, sy in series:
        gx = ox + int(w * (sx - x0) / (x1 - x0))
        gy = oy + h - int(h * (sy - y0) / (y1 - y0))
        if last is not None:
            line(last[0], last[1], gx, gy, rgb, 1.0, weight)
        last = (gx, gy)


X0, X1 = -33, 33
P_W, P_H = 380, 330
ground = [g for _, g, _ in before + after] + [l for _, _, l in before + after]
Y0, Y1 = min(ground) - 1, max(ground) + 1
frame(80, 116, P_W, P_H, X0, X1, Y0, Y1,
      "the ground along the traverse",
      "SEED 1234, IN ALONG L-1,0/L-2,0 AND OUT ALONG L-2,0/L-3,0",
      [round(Y0) + i * 5 for i in range(int((Y1 - Y0) / 5) + 1)])
plot(80, 116, P_W, P_H, X0, X1, Y0, Y1, [(s, l) for s, _, l in after], LAND, 1)
plot(80, 116, P_W, P_H, X0, X1, Y0, Y1, [(s, g) for s, g, _ in before], WARM)
plot(80, 116, P_W, P_H, X0, X1, Y0, Y1, [(s, g) for s, g, _ in after], COOL)

C0, C1 = 0.0, 4.0
frame(600, 116, P_W, P_H, X0, X1, C0, C1,
      "what one 3.0-unit step climbs",
      "RED: THE 3.0 UNITS A CHARACTER CAN STEP UP",
      [0.0, 1.0, 2.0, 3.0, 4.0])
gy = 116 + P_H - int(P_H * (3.0 - C0) / (C1 - C0))
line(600, gy, 600 + P_W, gy, LIMIT, 0.9, 2)
plot(600, 116, P_W, P_H, X0, X1, C0, C1, climbs(before), WARM)
plot(600, 116, P_W, P_H, X0, X1, C0, C1, climbs(after), COOL)

text(80, 28, "a traverse through the crossroads at (-157, 49)", INK, 3)
rect(80, 470, 104, 474, WARM)
text(112, 466, "levelled to a blend of both roads", INK, 1)
rect(400, 470, 424, 474, COOL)
text(432, 466, "levelled to one road, or to none", INK, 1)
rect(720, 470, 744, 474, LAND)
text(752, 466, "the land it is worn into", INK, 1)
text(80, 490, "horizontal: metres from the junction. tools/road_profile_dump.sh | python3 tools/plot_road_junction.py",
     (110, 116, 124), 1)

raw = b"".join(b"\x00" + bytes(buf[y * W * 3:(y + 1) * W * 3]) for y in range(H))


def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))


png = (b"\x89PNG\r\n\x1a\n"
       + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
       + chunk(b"IDAT", zlib.compress(raw, 9))
       + chunk(b"IEND", b""))
open("reports/assets/road-junction.png", "wb").write(png)
print("wrote reports/assets/road-junction.png  %d bytes" % len(png))
print("worst step before %.3f, after %.3f"
      % (max(c for _, c in climbs(before)), max(c for _, c in climbs(after))))
