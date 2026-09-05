#!/usr/bin/env python3
"""Draw reports/assets/local-bench.png from reports/assets/local-bench.csv.

Two panels over the same ten arms of the side-by-side comparison, in the order
the table lists them. Left: median seconds a decision, which is the axis every
local arm wins on. Right: what the engine made of each arm's turns, as a share
of that arm's own turns -- resolved, refused by the world, faulted by the
catalogue, nothing readable, and turns spent on a tool rather than an action.
The point of putting them side by side is that the two do not line up: the
fastest arms are among the worst-behaved.

No third-party packages: the PNG is written by hand with zlib.

  python3 tools/plot_local_bench.py
"""
import csv, struct, zlib

W, H = 1320, 620
BG = (255, 255, 255)
INK = (34, 38, 46)
GREY = (110, 116, 124)
GRID = (222, 226, 232)
WARM = (214, 122, 48)
COOL = (58, 118, 156)
GOOD = (72, 132, 96)
BAD = (176, 66, 66)
FAULT = (214, 122, 48)
DARK = (96, 84, 132)
TOOL = (150, 152, 158)

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
    "%": [0x62, 0x64, 0x08, 0x13, 0x23], "/": [0x20, 0x10, 0x08, 0x04, 0x02],
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


rows = list(csv.DictReader(open("reports/assets/local-bench.csv")))
LABEL = {"z-ai/glm-5.3-flash": "GLM-5.3-FLASH (CLOUD)"}

TOP, ROW = 120, 44
LEFT_X, LEFT_W = 400, 300
RIGHT_X, RIGHT_W = 790, 340

# --- left panel: median seconds a decision ---------------------------------
hi = max(float(r["median_s"]) for r in rows)
for t in (0.0, 0.5, 1.0, 1.5, 2.0):
    if t > hi + 0.1:
        continue
    gx = LEFT_X + int(LEFT_W * t / 2.0)
    line(gx, TOP - 12, gx, TOP + ROW * len(rows) - 12, GRID)
    text(gx - 10, TOP + ROW * len(rows) - 4, "%.1f" % t, GREY, 1)
for i, r in enumerate(rows):
    y = TOP + i * ROW
    name = LABEL.get(r["arm"], r["arm"])
    text(24, y - 2, name, INK, 2)
    v = float(r["median_s"])
    w = max(2, int(LEFT_W * v / 2.0))
    colour = COOL if r["arm"].startswith("z-ai") else WARM
    rect(LEFT_X, y - 4, LEFT_X + w, y + 12, colour, 0.85)
    text(LEFT_X + w + 8, y - 1, "%.3f" % v, GREY, 1)

# --- right panel: what the engine made of each arm's turns ------------------
KEYS = [("ok", GOOD), ("world", COOL), ("fault", FAULT), ("unreadable", BAD), ("tool", TOOL)]
for i, r in enumerate(rows):
    y = TOP + i * ROW
    total = sum(int(r[k]) for k, _ in KEYS) or 1
    x = RIGHT_X
    for k, colour in KEYS:
        n = int(r[k])
        if n == 0:
            continue
        w = max(1, int(round(RIGHT_W * n / total)))
        rect(x, y - 4, x + w, y + 12, colour, 0.9)
        x += w
    text(RIGHT_X + RIGHT_W + 10, y - 1, "%s TURNS" % r["turns"], GREY, 1)

text(24, 34, "ten arms, one game: how fast, and whether it works", INK, 3)
text(24, 66, "left: median seconds a decision over the whole live pass.  right: what the"
             " engine made of the turns, as a share of the turns that arm took.", GREY, 1)
text(400, 96, "SECONDS A DECISION", INK, 1)
text(790, 96, "WHAT THE ENGINE MADE OF EACH TURN", INK, 1)

ly = TOP + ROW * len(rows) + 24
lx = 790
for k, colour in KEYS:
    rect(lx, ly, lx + 14, ly + 12, colour, 0.9)
    lx = text(lx + 20, ly + 2, k, GREY, 1) + 14
text(24, ly + 2, "seed 1234, all five runs, one live pass per arm, ollama num_ctx=4096, temperature 0", GREY, 1)
text(24, ly + 20, "python3 tools/plot_local_bench.py", GREY, 1)

raw = b"".join(b"\x00" + bytes(buf[y * W * 3:(y + 1) * W * 3]) for y in range(H))


def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))


png = (b"\x89PNG\r\n\x1a\n"
       + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
       + chunk(b"IDAT", zlib.compress(raw, 9))
       + chunk(b"IEND", b""))
open("reports/assets/local-bench.png", "wb").write(png)
print("wrote reports/assets/local-bench.png  %d bytes" % len(png))
