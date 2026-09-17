#!/usr/bin/env python3
"""Rebuild the hand-merged project.godot from its two halves.

project.godot was the one configuration file both repositories already had when
mythosunwritten was adopted, so it could not be copied and could not be left
alone -- ADOPTION.md's "Collision resolutions" section records it as
hand-merged.  This script is that hand-merge written down as a rule, so the next
import re-applies it instead of re-deciding it:

    this repo's whole project.godot, verbatim
  + a banner saying what follows and why
  + exactly five of the source repo's sections, verbatim, in this order:
        [debug] [filesystem] [input] [physics] [shader_globals]

Their [application] is dropped (ours names our main scene and the 4.7 feature
flag) and their [display] is dropped (this repo's pixel-interface measurements
are taken against the default window).  Anything the source repo adds *inside*
one of the five adopted sections -- a new input action, a new shader global --
arrives automatically; a section it adds that is not in the list above does not,
and that is a decision for whoever runs the import, not a silent drop.

    usage: upstream_merge_project_godot.py OURS THEIRS SHORT_PIN

OURS is this repo's own project.godot as it stood before the adoption (the
parent of the adoption commit); THEIRS is the source repo's project.godot at the
commit being imported; SHORT_PIN is that commit abbreviated, for the banner.

Verified against its own output: run with this repo's pre-adoption
project.godot and the source tree at the pinned commit, it reproduces the
committed project.godot byte for byte.  See docs/upstream-delta-import.md.
"""
import sys

ADOPTED_SECTIONS = ["[debug]", "[filesystem]", "[input]", "[physics]", "[shader_globals]"]

BANNER = """; ------------------------------------------------------------------
; Everything below is adopted verbatim from mythosunwritten at commit
; {pin} (see ADOPTION.md): the input actions its player controller
; answers, the gravity its character tuning assumes, the integer-
; division warning setting its scripts were written under, the Blender
; import switch, and the shader globals its terrain, grass and wind
; shaders read. Its [display] window size is deliberately not adopted:
; this repo's pixel-interface measurements are taken against the
; default window, and its loading screen scales. Its "4.5" features
; flag is superseded by the "4.7" flag above, which is the engine both
; halves now run under.
; ------------------------------------------------------------------
"""


def sections(text):
    """Split an .ini-shaped file into {section header: section text}."""
    out, name, buf = {}, None, []
    for line in text.splitlines(keepends=True):
        if line.startswith("["):
            if name is not None:
                out[name] = "".join(buf)
            name, buf = line.strip(), [line]
        elif name is not None:
            buf.append(line)
    if name is not None:
        out[name] = "".join(buf)
    return out


def main(argv):
    if len(argv) != 4:
        sys.exit(__doc__.strip().splitlines()[-6].strip())
    ours = open(argv[1], encoding="utf-8").read()
    theirs = sections(open(argv[2], encoding="utf-8").read())
    missing = [s for s in ADOPTED_SECTIONS if s not in theirs]
    if missing:
        sys.exit("upstream-merge: %s has no %s -- decide what replaces it"
                 % (argv[2], " ".join(missing)))
    unknown = [s for s in theirs
               if s not in ADOPTED_SECTIONS and s not in ("[application]", "[display]")]
    for s in unknown:
        print("upstream-merge: NOT adopted, decide by hand: %s in %s" % (s, argv[2]),
              file=sys.stderr)
    parts = [ours.rstrip("\n") + "\n\n", BANNER.format(pin=argv[3]), "\n"]
    parts += ["\n".join([theirs[s].strip("\n"), ""]) + "\n" for s in ADOPTED_SECTIONS]
    sys.stdout.write("".join(parts)[:-1])
    return 1 if unknown else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
