#!/usr/bin/env python3
"""Measure the frames a playtest session photographed.

A playtest judgement has to be checkable by somebody who was not here, so every
claim about a frame in reports/playtest.md is one of these numbers rather than a
sentence about a picture.

    ./tools/playtest_measure.py panels  <frame.png>              rows the interface covers
    ./tools/playtest_measure.py diff    <a.png> <b.png> [box]    mean |dRGB| and mean green
    ./tools/playtest_measure.py motion  <frame.png> ...          world-band difference matrix
    ./tools/playtest_measure.py height  <frame.png> [box]        tallest run of armour grey
    ./tools/playtest_measure.py ink     <frame.png> [box]        how much of a box is not sky

`box` is `left,top,right,bottom` in pixels.
"""
import sys

import numpy as np
from PIL import Image


def load(path):
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.int16)


def crop(image, box):
    if box is None:
        return image
    left, top, right, bottom = (int(n) for n in box.split(","))
    return image[top:bottom, left:right]


# The pack's panel browns: the plank the panels are drawn on and the lighter
# board inside their frames, as the shell actually renders them.
PANEL_BROWNS = np.array([[170, 121, 89], [196, 154, 108], [143, 95, 68]])
PANEL_NEAR = 45


def panels(path):
    """Which rows of a frame the interface covers, and what share of it that is.

    A panel pixel is one near any of the pack's panel browns. Nothing else in
    this world is that warm: the ground is green, the sky is pale, and the tree
    trunks that share the hue are a few pixels wide, which is why the test asks
    for a quarter of a row rather than for any pixel at all.
    """
    image = load(path)
    height, width, _ = image.shape
    near = np.zeros(image.shape[:2], dtype=bool)
    for brown in PANEL_BROWNS:
        near |= np.abs(image - brown).sum(axis=2) < PANEL_NEAR
    share = near.mean(axis=1)
    rows = np.flatnonzero(share > 0.25)
    if rows.size == 0:
        print(f"{path}: {width}x{height} no panel rows")
        return
    band = rows.max() - rows.min() + 1
    print(
        f"{path}: {width}x{height} panel rows {rows.min()}-{rows.max()} "
        f"({band} rows, {100.0 * band / height:.1f}% of the height, "
        f"{100.0 * near.mean():.1f}% of all pixels)"
    )


def diff(first, second, box=None):
    a = crop(load(first), box)
    b = crop(load(second), box)
    if a.shape != b.shape:
        print(f"different shapes: {a.shape} vs {b.shape}")
        return
    print(
        f"mean |dRGB| {np.abs(a - b).mean():.2f}  "
        f"mean green {a[:, :, 1].mean():.2f} vs {b[:, :, 1].mean():.2f}  "
        f"box {box or 'whole frame'}"
    )


# The band of a frame the world is drawn in, above the interface panels.
WORLD_BAND = (100, 390)


def motion(paths):
    """How much each pair of frames differs in the world band, in grey levels."""
    greys = []
    for path in paths:
        image = load(path)
        greys.append(image[WORLD_BAND[0]:WORLD_BAND[1], :, :].mean(axis=2))
    names = [p.rsplit("/", 1)[-1].rsplit("-", 1)[-1].removesuffix(".png") for p in paths]
    print("        " + "".join(f"{n:>8}" for n in names))
    for i, name in enumerate(names):
        row = "".join(f"{np.abs(greys[i] - greys[j]).mean():8.2f}" for j in range(len(names)))
        print(f"{name:>8}{row}")


def height(path, box=None):
    """The tallest unbroken run of armour grey in a box, in pixels.

    Fen's plate is a desaturated mid grey; the ground and the grass around it are
    not, so the longest column-run of it is the character's height on the screen.
    """
    image = crop(load(path), box)
    red, green, blue = image[:, :, 0], image[:, :, 1], image[:, :, 2]
    spread = image.max(axis=2) - image.min(axis=2)
    grey = (spread < 26) & (red > 70) & (red < 190) & (green > 70) & (blue > 70)
    best, best_column, best_top = 0, -1, -1
    for column in range(grey.shape[1]):
        run, top = 0, -1
        for row in range(grey.shape[0]):
            if grey[row, column]:
                if run == 0:
                    top = row
                run += 1
                if run > best:
                    best, best_column, best_top = run, column, top
            else:
                run = 0
    print(f"{path}: tallest armour-grey run {best} px at column {best_column}, rows {best_top}-{best_top + best - 1} of box {box}")


def ink(path, box=None):
    """How much of a box is something other than flat sky, as a share."""
    image = crop(load(path), box)
    flat = np.abs(image - image.mean(axis=(0, 1))).sum(axis=2) < 30
    print(f"{path}: {100.0 * (1.0 - flat.mean()):.1f}% of box {box} is not the box's own mean colour")


if __name__ == "__main__":
    what = sys.argv[1]
    if what == "panels":
        for path in sys.argv[2:]:
            panels(path)
    elif what == "diff":
        diff(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else None)
    elif what == "motion":
        motion(sys.argv[2:])
    elif what == "height":
        height(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
    elif what == "ink":
        ink(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
    else:
        print(__doc__)
        sys.exit(2)
