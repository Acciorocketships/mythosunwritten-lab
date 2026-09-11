#!/usr/bin/env python3
"""How much of the board's own lattice survives the grass standing on it.

Run it through tools/measure_board_read.sh, which photographs the frames this
reads.  Nothing here renders anything: it is arithmetic over PNGs that were
captured at one seed, one place, one camera and one frame, so two treatments
differ in the treatment and in nothing else.

## What is measured

A square of the board reads when it looks different from the gutter beside it.
So the number is a *contrast*: the mean brightness of the pixels the board
paints, less the mean brightness of the gutter pixels between them, over the
board's own footprint on screen.

Which pixels are which is not guessed and not drawn by hand.  Two frames with
no grass in them at all -- the same view with the board and without it -- say
exactly where the paint lands: a pixel the two differ on is painted, and a
pixel inside the board's footprint that they agree on is gutter.  That
classification is then applied to the frames that do have grass in them.

And it is narrowed to where the question is.  A board is far wider than the
grass around the camera is deep, and out where no blade stands every treatment
scores the same and would water the difference down.  So a fourth frame -- the
same view with grass and no board -- says where the grass is, and only the part
of the board the grass stands on is measured.

Two numbers come out per treatment:

* **contrast** -- painted less gutter, in levels of 255.  The no-grass frame is
  the most the lattice can ever read at this camera, so a treatment's contrast
  as a share of that one is *how much of the lattice reaches the eye*.
* **paint error** -- the mean distance, again in levels, between a painted pixel
  as it comes out under the treatment and the same pixel with no grass on it.
  It says what is standing on the square rather than how the square reads, and
  the two can disagree: grass mown down to nothing leaves a clean square (small
  error), grass thrown away in a dither leaves a speckled one (large error) that
  may still average to a similar brightness.

Both are over the same pixels for every treatment, so the columns compare.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

# Rec. 709 luma: what "brighter" means for a pixel, since the lattice is a
# see-through tint over ground and not a colour of its own.
LUMA = np.array([0.2126, 0.7152, 0.0722])

# How far two frames must differ, in levels of 255, before the difference is
# taken for paint rather than for the encoder's own noise.  The faintest thing
# the board draws is a ground square at alpha 0.26, which lands some 20 levels
# from the grass under it, so this is well clear of both.
PAINT_FLOOR = 3.0

# How far from a painted pixel the gutter is looked for, in pixels.  The gutter
# between two squares is 14% of a 3.0-unit cell, which at this camera is a few
# pixels across; this reaches across it without leaving the board.
GUTTER_REACH = 7


def read(path: Path) -> np.ndarray:
    """One frame as levels of 255, height x width x 3."""
    with Image.open(path) as handle:
        return np.asarray(handle.convert("RGB"), dtype=np.float64)


def luma(frame: np.ndarray) -> np.ndarray:
    return frame @ LUMA


def grown(mask: np.ndarray, reach: int) -> np.ndarray:
    """The mask with every true pixel spread `reach` pixels in each direction."""
    out = mask.copy()
    for step in range(1, reach + 1):
        out[step:, :] |= mask[:-step, :]
        out[:-step, :] |= mask[step:, :]
        out[:, step:] |= mask[:, :-step]
        out[:, :-step] |= mask[:, step:]
    return out


def masks(board: np.ndarray, plain: np.ndarray,
          grassy: np.ndarray | None) -> tuple[np.ndarray, np.ndarray]:
    """Which pixels the board paints, and which are the gutter between them.

    Both are read off the pair of grass-free frames, so neither depends on any
    treatment being compared, and both are cut down to where grass stands when
    a frame with grass and no board is given.
    """
    painted = np.abs(board - plain).mean(axis=2) > PAINT_FLOOR
    footprint = grown(painted, GUTTER_REACH)
    gutter = footprint & ~painted
    if grassy is not None:
        # Where a blade stands, spread a little so that a square between two
        # tufts counts as ground the grass is standing on rather than as ground
        # it has left alone.
        standing = grown(
            np.abs(grassy - plain).mean(axis=2) > PAINT_FLOOR, GUTTER_REACH
        )
        painted &= standing
        gutter &= standing
    return painted, gutter


def measure(frame: np.ndarray, ideal: np.ndarray,
            painted: np.ndarray, gutter: np.ndarray) -> tuple[float, float]:
    bright = luma(frame)
    contrast = float(bright[painted].mean() - bright[gutter].mean())
    error = float(np.abs(frame - ideal)[painted].mean())
    return contrast, error


def main() -> int:
    parse = argparse.ArgumentParser(description=__doc__)
    parse.add_argument("--board", required=True, type=Path,
                       help="the view with the board on it and no grass")
    parse.add_argument("--plain", required=True, type=Path,
                       help="the same view with neither board nor grass")
    parse.add_argument("--grassy", type=Path, default=None,
                       help="the same view with grass and no board, which says"
                            " which part of the board the grass stands on")
    parse.add_argument("--frame", action="append", default=[], metavar="NAME=PATH",
                       help="a treatment to price, named")
    given = parse.parse_args()

    board = read(given.board)
    plain = read(given.plain)
    if board.shape != plain.shape:
        print("the two grass-free frames are not the same size", file=sys.stderr)
        return 1
    grassy = None if given.grassy is None else read(given.grassy)
    painted, gutter = masks(board, plain, grassy)
    pixels = board.shape[0] * board.shape[1]
    print("frame %dx%d  painted %d px (%.1f%%)  gutter %d px (%.1f%%)" % (
        board.shape[1], board.shape[0],
        painted.sum(), 100.0 * painted.sum() / pixels,
        gutter.sum(), 100.0 * gutter.sum() / pixels,
    ))

    top, _ = measure(board, board, painted, gutter)
    print("\n%-28s %9s %9s %11s" % ("treatment", "contrast", "of best", "paint err"))
    print("%-28s %9.2f %8.1f%% %11.2f" % ("no grass at all (the most)", top, 100.0, 0.0))
    for entry in given.frame:
        name, _, path = entry.partition("=")
        frame = read(Path(path))
        if frame.shape != board.shape:
            print("%s is not the size of the grass-free frames" % path, file=sys.stderr)
            return 1
        contrast, error = measure(frame, board, painted, gutter)
        print("%-28s %9.2f %8.1f%% %11.2f" % (
            name, contrast, 100.0 * contrast / top, error,
        ))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
