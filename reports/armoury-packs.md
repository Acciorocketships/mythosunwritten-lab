# The three armoury packs, opened and catalogued

The last three archives the user bought and dropped into `assets/` are now
unpacked, imported and measured: Daniel Mistage's *STYLIZED Battle Pack* (672
models), *STYLIZED Forge & Armory* (435) and *STYLIZED The Alchemist's Workshop*
(823). 1,930 models, 152 MB on disk.

This report does one job: say what is in them, and lay every gear shape the game
needs beside a model that could draw it. **Nothing is repointed here.** No row of
`render/asset_library.gd` changed, no tag was added, and nothing under `sim/` was
touched. The table at the end is what the next work item spends.

---

## 1. What came out of each archive

`bsdtar` reads RAR5 and is on this machine at
`/home/ryko/.miniforge3/bin/bsdtar`; there is no `unrar` and no `7z`, and none is
needed. `./tools/extract_armoury.sh` unpacks all three in **2.3 s** total:

```
$ ./tools/extract_armoury.sh
672 models into assets/mistage_battle, 7 atlas name(s) mapped
435 models into assets/mistage_forge, 1 atlas name(s) mapped
823 models into assets/mistage_alchemy, 1 atlas name(s) mapped
```

By file count and kind, straight off the archive listings:

| archive | destination | `.fbx` | `.png` atlases | other entries | on disk |
| --- | --- | ---: | ---: | ---: | ---: |
| `BattlePackFBX.rar` | `assets/mistage_battle/` | 672 | 7 | 98 directory entries | 60 MB |
| `ForgeFBX.rar` | `assets/mistage_forge/` | 435 | 1 | 21 directory entries | 36 MB |
| `AlchemyPackFBX.rar` | `assets/mistage_alchemy/` | 823 | 1 | 21 directory entries | 56 MB |

Every archive holds exactly two kinds of file — FBX models and PNG texture
atlases — plus the directories that hold them. No `.meta`, no `.unitypackage`, no
prefab, no licence file, no readme.

What the FBX are, by the directory the artist filed them under:

| pack | top-level group | models | what it is |
| --- | --- | ---: | --- |
| battle | `Battle Props/` | 272 | siege engines, banners, barriers, tents, bombs, targets |
| battle | `General Props/` | 218 | camp dressing: barrels, crates, food, candles, chests, scrolls |
| battle | `Weapons/` | 84 | swords, axes, maces, hammers, polearms, bows, arrows, shields, potions |
| battle | `Wooden Walls/` | 56 | palisade sections and a tower |
| battle | `Tents/` + `Wagons and Carts/` + `Weapon Racks/` | 42 | camp structures |
| forge | `Weapons/` | 196 | eleven weapon families in iron / gold / runical trios, plus firearms |
| forge | `Forge Props/` + `Forge Building/` | 62 | anvils, ovens, bellows, the smithy itself |
| forge | `General Props/`, `Tools and Stands/`, `Metals Blades and Other/`, `Reception Table/`, `Weapons Racks and Stands/` | 177 | smith's tools, ingots, blades in progress, furniture |
| alchemy | `Alchemy Props/` | 602 | 238 potions, 97 cauldrons, 70 books, 58 tools, 14 bags, 12 scrolls |
| alchemy | `Furniture/`, `Decorative Props/`, `Lights…/`, `Building…/` | 191 | the workshop interior |
| alchemy | `Weapons and Tools/` | 13 | seven crosiers, a wand, an axe, a broom, two ladles, a hoe |
| alchemy | `Scene Prefabs/` | 17 | pre-assembled corners of a room |

Only three of those twelve groups are gear: `battle/Weapons/` (84),
`forge/Weapons/` (196) and `alchemy/Weapons and Tools/` (13) — 293 models, 15% of
the 1,930. The rest is scenery, which is not what this item is for and is left
for later.

---

## 2. Import: what the engine does with these files here

**Godot 4.7.2 imports all 1,930 with its built-in ufbx importer and no external
converter.** Every FBX produced an `.import` sibling; every model loads; not one
file failed.

| pack | models | import wall-clock | `.import` files written | failures |
| --- | ---: | ---: | ---: | ---: |
| battle | 672 | 12.7 s | 672 | 0 |
| forge | 435 | 9.0 s | 435 | 0 |
| alchemy | 823 | 13.7 s | 823 | 0 |

Measured one pack at a time against a warm cache — the three trees were moved
aside, a baseline `--headless --import` was timed at **2.19 s** with none of them
present, then each was moved back and re-imported:

```
env -u DISPLAY -u WAYLAND_DISPLAY HOME=$PWD/tools/godot-home \
    ./tools/godot/godot4 --headless --path . --import
```

The import cache grows from 288 MB to 443 MB — **155 MB of `.godot/imported/`**
for the three packs. That cache is already `.gitignore`d, as are the `.import`
files themselves.

The three import logs are 6 121, 3 952 and 7 444 lines of progress and contain
not one line matching `error`, `warn`, `fail`, `cannot`, `unable` or `invalid`.

### The one thing that had to be fixed: texture basenames

Same defect as the village and market packs, and the same one-line fix. Every FBX
names its atlas by an absolute Windows path off the artist's machine, so nothing
resolves and Godot falls back to the **basename** beside the model and in its
parent directories. Each pack ships its atlases at the archive root under a
pack-prefixed name while the FBX ask for the unprefixed name, so the whole fix is
to copy each shipped atlas to the pack root a second time under the name asked
for — **nine files across three packs, no material path edited, no FBX
rewritten**:

| pack | shipped file | copied to | asked for by | models |
| --- | --- | --- | --- | ---: |
| battle | `SFBP_TEXTURE.png` | `TEXTURE.png` | `SFBP_MAIN_MATERIAL`, `SFBP_TRANSPARENT` | 650 |
| battle | `SFBP_TEXTURE_BLACK.png` | `TEXTURE_BLACK.png` | `SFBP_TENT_BLACK` | 11 |
| battle | `SFBP_TEXTURE_BLUE.png` | `TEXTURE_BLUE.png` | `SFBP_TENT_BLUE` | 4 |
| battle | `SFBP_TEXTURE_GREEN.png` | `TEXTURE_GREEN.png` | `SFBP_TENT_GREEN` | 4 |
| battle | `SFBP_TEXTURE_PURPLE.png` | `TEXTURE_PURPLE.png` | `SFBP_TENT_PURPLE` | 4 |
| battle | `SFBP_TEXTURE_RED.png` | `TEXTURE_RED.png` | `SFBP_TENT_RED` | 4 |
| battle | `SFBP_NATURE.png` | `NATURE.png` | `SFBP_NATURE` | 4 |
| forge | `SFFA_MAIN_TEXTURE.png` | `TEXTURE.png` | `SFFA_MAIN_MATERIAL`, `SFFA_TRANSPARENT` | 425 |
| alchemy | `AWS_MAIN_TEXTURE.png` | `TEXTURE.png` | `AWS_MAIN_MATERIAL` + `MAIN_MATERIAL` (807 models), `AWS_TRANSPARENT` + `TRANSPARENT` (138 more slots) | 807 |

That mapping is read out of the binaries rather than guessed —
`./tools/fbx_texture_map.py assets/mistage_battle assets/mistage_forge
assets/mistage_alchemy` prints it without loading the engine, and after the copy
its "NOT FINDABLE" section is empty for all three packs. **These three are
cleaner than the village pack**: the village names an atlas belonging to a
different Mistage pack that its archive does not contain, and none of these
three does. Every basename any material asks for has a shipped counterpart.

### Every file that does not fully bind, named

No file fails to import. What some files do is carry a material that names no
texture at all — which is a different thing, and worth naming precisely because
"33 models with no albedo" would otherwise read as breakage.

`./tools/inventory_pack.sh assets/<pack> --require-textures --every-material`
exits 1 on all three, and this is the complete list of what it objects to:

| pack | material | surfaces | what it is |
| --- | --- | ---: | --- |
| battle | `SFBP_GLOW_YELLOW`, `_CANDLE`, `_BLUE`, `_GREEN`, `_PINK`, `_RED` | 29 | flame and lamp glow |
| battle | `SFBP_DOUBLE_SIDED_MATERIAL` | 6 | grass and ivy cards |
| battle | `SFBP_TENT_BLACK` (second, untextured slot) | 4 | tent-piece trim |
| forge | `SFFA_BLUE_GLOW` | 186 | the runical weapons' rune glow |
| forge | `SFFA_GLOW_YELLOW`, `_RED_GLOW`, `_CANDLE_GLOW` | 29 | forge fire and candles |
| alchemy | `AWS_GLOW_*` and `GLOW_*` (blue, green, pink, red, yellow) | 352 | potion and cauldron glow |
| alchemy | `LEAF_MATERIAL` | 36 | plant leaves |
| alchemy | *(one unnamed material)* | 4 | — |

Every one of them is a glow, a leaf card or an untextured trim slot: in the FBX
these materials name **no** texture, which `tools/fbx_texture_map.py` reports
separately as "materials that name no texture at all". In Unity the colour lived
in a shader the archive does not ship. The 33 models on which *no* material binds
at all are the ones made of nothing but such a material — `SFBP_Candle_Flame_001`
(22 tris), `SFFA_Blade_Glow_001`, `AWS_Cauldron_Liquid_001` (13 tris),
`AWS_Flame_001` — glow overlays meant to be laid over a solid model, not models.
**No weapon, shield or armour model is among them.** The main material of every
gear model binds `TEXTURE.png`.

### What the models measure

Scale is already metres, as with the other Mistage packs, and one mesh with one
material is the norm — which is what the chunk streamer wants:

| pack | models | triangles | mean tris/model | models needing >1 mesh |
| --- | ---: | ---: | ---: | ---: |
| battle | 672 | 1,341,915 | 1,997 | few (largest: a palisade tower at 23,574) |
| forge | 435 | 792,510 | 1,822 | few (crossbows are 4) |
| alchemy | 823 | 1,069,907 | 1,300 | few |

A weapon costs 200–2,400 triangles. For comparison the KayKit adventurer weapons
cost 52–800. Both are cheap enough for a thing held in a hand; neither is cheap
enough to scatter thousands of.

**One scale caveat for whoever repoints the rows.** The KayKit adventurer gear is
drawn heroically oversized — `sword_1handed.gltf` is 1.775 m tall, `staff.gltf`
2.155 m — while the Mistage weapons are true-to-life (`SFFA_Weapon_Sword_Iron_002`
1.166 m, `SFBP_Sword_001` 0.663 m). The gear rows already carry a `scene_height`
that the shell divides by, so this is a number to set per row, not a problem; but
a Mistage sword dropped into a row whose `scene_height` was measured off a KayKit
one will come out at roughly half size.

---

## 3. Licence, and where the files live

One line each, and it is the same line, because all three are the same kind of
purchase:

- **STYLIZED Battle Pack** — paid Unity Asset Store content by Daniel Mistage, licensed to this user under the Asset Store EULA: usable in this project, **not** redistributable as source art, so the archive and the unpacked tree stay out of git.
- **STYLIZED Forge & Armory** — same vendor, same Asset Store EULA, same handling.
- **STYLIZED The Alchemist's Workshop** — same vendor, same Asset Store EULA, same handling.

No pack ships a `License.txt`; the terms are the Asset Store's standard ones,
which is why the position is stated here rather than quoted from a file in the
tree. This is looser than the Sprout Lands UI pack (non-commercial, no
redistribution even if modified) and stricter than the CC0 KayKit packs.

`.gitignore` now excludes `/assets/mistage_battle/`, `/assets/mistage_forge/` and
`/assets/mistage_alchemy/` alongside the three trees that were already there, and
`/assets/*.rar` already covered the archives. `git status` after extracting shows
only `.gitignore` and `tools/extract_armoury.sh`. The extracted trees are
reproducible from the archives beside them by one committed script, exactly as
the village, market and JustCreate trees are.

---

## 4. The table

One row per gear shape the game needs. Paths are abbreviated by these roots:

| short | full path |
| --- | --- |
| `ADV/` | `res://assets/kaykit_adventurers/KayKit_Adventurers_2.0_FREE/Assets/gltf/` |
| `DUN/` | `res://assets/kaykit_dungeon_remastered/KayKit_Dungeon_Pack_1.1_FREE/Assets/gltf/` |
| `BAT/` | `res://assets/mistage_battle/FBX/` |
| `FRG/` | `res://assets/mistage_forge/FBX/` |
| `ALC/` | `res://assets/mistage_alchemy/FBX/` |

"tag today" is the `gear_*` tag in `sim/asset_tags.gd` that already covers the
shape, or `—` where the shape has no tag. "drawn today" is what
`render/asset_library.gd` puts on the ground for that tag right now.

| # | gear shape | tag today | drawn today | best candidate | pack | tris | size w×h×d (m) | alternatives |
| ---: | --- | --- | --- | --- | --- | ---: | --- | ---: |
| 1 | sword, one-handed | `gear_blade` | `ADV/sword_1handed.gltf` | `FRG/Weapons/Sword/SFFA_Weapon_Sword_Iron_002.fbx` | forge | 932 | 0.21 × 1.17 × 0.06 | 24 swords (forge 18, battle 6) |
| 2 | sword, two-handed | — | *(no tag)* | `ADV/sword_2handed.gltf` | adventurers | 412 | 0.84 × 2.37 × 0.25 | + `sword_2handed_color`, 23 longswords in the packs |
| 3 | dagger / knife | — | *(no tag)* | `ADV/dagger.gltf` | adventurers | 172 | 0.26 × 1.21 × 0.15 | `FRG/…/Knife/SFFA_Weapon_Knife_Iron_001.fbx`, `BAT/Weapons/Dagger/SFBP_Dagger_001.fbx` — 23 in the packs |
| 4 | axe, one-handed | — | *(no tag)* | `ADV/axe_1handed.gltf` | adventurers | 274 | 0.71 × 1.24 × 0.19 | `BAT/Weapons/Axe/SFBP_Axe_001.fbx` (0.67 m) |
| 5 | axe, two-handed | — | *(no tag)* | `ADV/axe_2handed.gltf` | adventurers | 508 | 1.24 × 1.73 × 0.26 | `FRG/…/Axe/SFFA_Weapon_Axe_Iron_001.fbx` (1.77 m), `BAT/…/SFBP_Axe_004.fbx` (1.49 m) |
| 6 | spear | `gear_spear` | **placeholder** | `FRG/Weapons/Spear/SFFA_Weapon_Spear_Iron_001.fbx` | forge | 1,496 | 0.22 × 1.84 × 0.07 | 18 spears (iron/gold/runical) |
| 7 | polearm / halberd | — | *(no tag)* | `BAT/Weapons/Polearm/SFBP_Polearm_001.fbx` | battle | 820 | 0.18 × 1.91 × 0.06 | 12 polearms |
| 8 | lance | — | *(no tag)* | `BAT/Weapons/Lance/SFBP_Lance_001.fbx` | battle | 1,214 | 0.17 × 2.53 × 0.17 | the only one |
| 9 | mace | — | *(no tag)* | `FRG/Weapons/Mace/SFFA_Weapon_Mace_Iron_001.fbx` | forge | 554 | 0.10 × 0.59 × 0.10 | 26 maces (forge 21, battle 5) |
| 10 | warhammer | — | *(no tag)* | `FRG/Weapons/Hammer/SFFA_Weapon_Hammer_Iron_001.fbx` | forge | 902 | 0.52 × 0.90 × 0.17 | 24 hammers, `BAT/…/SFBP_Hammer_003.fbx` two-handed at 1.50 m |
| 11 | flail | `gear_flail` | **placeholder** | **GAP** | — | — | — | no chained flail in any pack; the mace at row 9 is the near miss |
| 12 | staff | `gear_staff` | `ADV/staff.gltf` | `ALC/Weapons and Tools/AWS_Crossier_001.fbx` | alchemy | 236 | 0.23 × 1.23 × 0.08 | 7 alchemy crosiers, `BAT/Weapons/Crosier/SFBP_Crosier_001.fbx` (1.98 m) |
| 13 | wand | — | *(no tag)* | `ADV/wand.gltf` | adventurers | 150 | 0.16 × 0.97 × 0.16 | `ALC/Weapons and Tools/AWS_Wand_001.fbx` (0.28 m, tiny) |
| 14 | bow | `gear_bow` | `ADV/bow_withString.gltf` | `FRG/Weapons/Bows and Arrows/SFFA_Bow_001.001.fbx` | forge | 1,474 | 0.46 × 1.63 × 0.14 | 7 forge bows; the battle pack ships bow and string as **separate** models |
| 15 | crossbow, one-handed | — | *(no tag)* | `ADV/crossbow_1handed.gltf` | adventurers | 584 | 0.91 × 0.41 × 1.22 | `FRG/Weapons/Guns/SFFA_Weapon_Crossbow_001.fbx` (6 variants, 4 meshes each) |
| 16 | crossbow, two-handed | — | *(no tag)* | `ADV/crossbow_2handed.gltf` | adventurers | 792 | 1.22 × 0.48 × 1.44 | the forge crossbows again |
| 17 | **arrow (bow), in flight** | — | *(no tag)* | **`ADV/arrow_bow.gltf`** | adventurers | 52 | 0.16 × 0.14 × **1.26** | `FRG/…/SFFA_Arrow_Iron_001.fbx` (0.71 m), 10 battle arrows |
| 18 | **bolt (crossbow), in flight** | — | *(no tag)* | **`ADV/arrow_crossbow.gltf`** | adventurers | 52 | 0.12 × 0.10 × **0.75** | as above |
| 19 | arrow sheaf (a bundle at rest) | — | *(no tag)* | `ADV/arrow_bow_bundle.gltf` | adventurers | 280 | 0.44 × 1.10 × 0.43 | + `arrow_crossbow_bundle`; `BAT/…/SFBP_Arrows_001.fbx` is 60 meshes and 16,440 tris — a scatter prop, not an item |
| 20 | quiver | — | *(no tag)* | `ADV/quiver.gltf` | adventurers | 255 | 0.31 × 0.93 × 0.19 | `FRG/…/SFFA_Arrow_Bag_001.fbx` (0.82 m), 4 variants |
| 21 | thrown ring — chakram | — | *(no tag)* | `FRG/Weapons/Chakram/SFFA_Weapon_Chakram_Iron_001.fbx` | forge | 1,330 | 0.41 × 0.29 × 0.04 | 9 (iron/gold/runical) |
| 22 | thrown star — shuriken | — | *(no tag)* | `FRG/Weapons/Shuriken/SFFA_Shuriken_Iron_001.fbx` | forge | 498 | 0.10 × 0.003 × 0.09 | 3 |
| 23 | thrown bomb / smoke bomb | — | *(no tag)* | `ADV/smokebomb.gltf` | adventurers | 310 | 0.38 × 0.42 × 0.36 | `BAT/Battle Props/Bombs/SFBP_Bomb_001.fbx` (0.37 m), 2 |
| 24 | hurled rock (siege projectile) | — | *(no tag)* | `BAT/Battle Props/Rock Projectile/SFBP_Rock_Projectile_001.fbx` | battle | 320 | 1.92 × 1.59 × 1.75 | 4; boulder-sized, for a catapult not a hand |
| 25 | firearm (pistol / rifle / shotgun) | — | *(no tag)* | `FRG/Weapons/Guns/SFFA_Pistol_001.fbx` | forge | 1,024 | 0.52 × 0.18 × 0.09 | 16; **off-genre** — listed because the pack has them, not because the game wants them |
| 26 | spellbook, closed | — | *(no tag)* | `ADV/spellbook_closed.gltf` | adventurers | 292 | 0.29 × 0.58 × 0.43 | `ALC/Alchemy Props/Books/AWS_Book_001.fbx`, 24 closed books across two packs |
| 27 | spellbook, open | — | *(no tag)* | `ADV/spellbook_open.gltf` | adventurers | 292 | 0.83 × 0.57 × 0.22 | `ALC/…/Books/AWS_Book_Opened_001.fbx`, 9 opened |
| 28 | scroll | — | *(no tag)* | `ALC/Alchemy Props/Scrolls/AWS_Scroll_001.fbx` | alchemy | 1,756 | 0.44 × 0.74 × 0.52 | 21 (alchemy 12, battle 7, forge 2) |
| 29 | orb / focus stone | — | *(no tag)* | `ALC/Alchemy Props/Other/AWS_Magic_Ball_001.fbx` | alchemy | 1,000 | 0.23 × 0.33 × 0.22 | 18 magical stones in `ALC/Alchemy Props/Magical Stones/` |
| 30 | shield, round | `gear_buckler` | `ADV/shield_round.gltf` | `BAT/Weapons/Shields/SFBP_Shield_006.fbx` | battle | 1,535 | 0.94 × 0.97 × 0.33 | 4 round battle shields, 4 square-ish forge wooden ones; `ADV/shield_round_color`, `ADV/shield_round_barbarian` |
| 31 | shield, square / kite | — | *(no tag)* | `ADV/shield_square.gltf` | adventurers | 262 | 0.88 × 1.19 × 0.30 | + `shield_square_color`; `FRG/…/SFFA_Shield_Wooden_001.fbx` (0.67 × 1.18) |
| 32 | shield, spiked | — | *(no tag)* | `ADV/shield_spikes.gltf` | adventurers | 420 | 1.01 × 1.04 × 0.46 | + `shield_spikes_color`; nothing spiked in the packs |
| 33 | shield, heater / badge | — | *(no tag)* | `ADV/shield_badge.gltf` | adventurers | 262 | 0.88 × 1.02 × 0.25 | + `shield_badge_color`; `FRG/…/SFFA_Shield_Stylized_001.fbx` |
| 34 | shield, tower | — | *(no tag)* | `BAT/Weapons/Shields/SFBP_Shield_001.fbx` | battle | 1,692 | 1.03 × 1.76 × 0.33 | 4 |
| 35 | **boots** | `gear_boots` | **placeholder** | **GAP** | — | — | — | no footwear model in any of the three packs, nor in the adventurer pack — the boots are painted on the character meshes |
| 36 | **leggings** | `gear_leggings` | **placeholder** | **GAP** | — | — | — | same: no leg armour off a body anywhere |
| 37 | **chestplate** | `gear_chestplate` | **placeholder** | **GAP** (near miss) | forge | 9,780 | 1.23 × 2.24 × 0.94 | `FRG/General Props/SFFA_Armor_001.fbx` is a **whole suit on a stand**, 2.24 m tall — scenery for a smithy, not a wearable piece; 2 variants |
| 38 | **helmet** | `gear_helmet` | **placeholder** | **GAP** (near miss) | alchemy | 810 | 0.60 × 0.34 × 0.64 | `ALC/Alchemy Props/Other/AWS_Wizard_Hat_001.fbx` is the only head-worn model on this machine, and it is a soft pointed hat, not a helm |
| 39 | draught / potion bottle | `gear_draught` | `DUN/bottle_A_green.gltf` | `ALC/Alchemy Props/Potions/AWS_Potion_Blue_001.fbx` | alchemy | 124 | 0.05 × 0.20 × 0.05 | **243** potions: nine colour families (24 shapes each for blue, green and orange, 12 for the rest), plus 50 glow overlays, 16 jars and 10 hanging; `BAT/Weapons/Potion/SFBP_Potion_001.fbx` |
| 40 | potion jar (a wide one) | — | *(no tag)* | `ALC/Alchemy Props/Potions/AWS_Potion_Jar_001.fbx` | alchemy | 154 | 0.12 × 0.18 × 0.12 | 16 jars + 10 `AWS_Jar_*` |
| 41 | pouch / bundle | `gear_bundle` | **placeholder** *(by design)* | `ALC/Alchemy Props/Bags/AWS_Bag_001.fbx` | alchemy | 296 | 0.19 × 0.15 × 0.21 | 23 bags (alchemy 14, battle 9); the placeholder is deliberate — an unidentified thing should not read as anything in particular |
| 42 | ingot / crafting material | — | *(no tag)* | `FRG/Metals Blades and Other/SFFA_Iron_Bar_001.fbx` | forge | 108 | 0.22 × 0.07 × 0.11 | bronze, gold, iron bars, coal, horseshoes, rupees — nothing in the game wants these yet |
| 43 | mug (not gear) | — | *(no tag)* | `ADV/mug_empty.gltf` | adventurers | 366 | 0.53 × 0.49 × 0.40 | + `mug_full`; the two adventurer-pack models that are neither weapon nor armour, listed so the pack's 31 are accounted for |

### The four gaps, stated plainly

| shape | tag | why there is no candidate |
| --- | --- | --- |
| flail | `gear_flail` | no chained weapon exists in any pack on this machine. Either the tag is redrawn as a mace, or the flail keeps its primitive. |
| boots | `gear_boots` | none of the six packs ships footwear as a separate model. |
| leggings | `gear_leggings` | none ships leg armour as a separate model. |
| chestplate / helmet | `gear_chestplate`, `gear_helmet` | the only body armour anywhere is `SFFA_Armor_001`, a 2.24 m display suit on a stand, and the only headgear is a wizard's hat. Neither is a piece a character could hold or a pile could show. |

So of the twelve `gear_*` tags, this work moves **four** from "no model exists" to
"a model exists and is named" — spear, and the three already-drawn rows that gain
a better or a second candidate — and leaves **four** as real gaps: flail, boots,
leggings, and the chestplate/helmet pair. The eight worn-armour and flail
primitives in `render/asset_library.gd` are not going away because the packs
solved the held half of the problem and not the worn half.

### The two arrow models part six needs: found

Both are in the adventurer pack, both import, both bind a texture, and both are
tiny:

| model | tris | size | long axis | texture |
| --- | ---: | --- | --- | --- |
| `ADV/arrow_bow.gltf` | 52 | 0.163 × 0.142 × 1.261 m | **+Z**, 1.26 m | `ranger_texture.png` |
| `ADV/arrow_crossbow.gltf` | 52 | 0.117 × 0.102 × 0.749 m | **+Z**, 0.75 m | `rogue_texture.png` |

Both lie along **+Z** with their floor near zero, which is the orientation a
flight object wants — point the node at the target cell and the arrow points with
it, no per-model correction. 52 triangles each is nothing; a volley is free.

The packs offer alternatives if a heavier look is wanted:
`FRG/Weapons/Bows and Arrows/SFFA_Arrow_Iron_001.fbx` (206 tris, 0.71 m, lying
along **+X** instead) and ten battle-pack arrows such as
`BAT/Weapons/Arrows/SFBP_Arrow_White_001.fbx` (226 tris, 0.65 m, along **+Y**).
The adventurer pair is the recommendation: cheapest, already installed, already
CC0, and the only two that share the game's existing forward axis.

---

## 5. What this item did not do

- No row of `render/asset_library.gd` was repointed and no `gear_*` tag was added — that is the next item, and this table is its input.
- Nothing under `sim/` changed. `tests/asset_check.gd` still passes, which is the check that no simulation file may name an asset path.
- No wrapper scene was written under `assets/tag_scenes/`.
- The 1,637 non-gear models in the three packs — the siege engines, the forge building, the alchemist's furniture — are catalogued at the group level in §1 and otherwise untouched. They are scenery, and scenery is a different item.

## 6. Reproducing this

```
./tools/extract_armoury.sh                                  # 2.3 s, three trees
./tools/fbx_texture_map.py assets/mistage_battle \
    assets/mistage_forge assets/mistage_alchemy             # what the FBX ask for
./tools/inventory_pack.sh assets/mistage_forge              # tris, size, floor, texture
./tools/inventory_pack.sh assets/mistage_battle \
    --require-textures --every-material                     # the unbound-material roll call
```
