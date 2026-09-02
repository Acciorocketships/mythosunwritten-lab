class_name AntiAliasing
extends RefCounted
## The anti-aliasing modes the main viewport can be drawn with, in one table.
##
## The game ships one of these, set in project.godot as a project setting, which
## the engine applies to the window's viewport at startup. This file exists so
## that the same modes can also be *switched between at runtime*, which is what
## lets tools/measure_aa.gd render the same paused frame in every mode in one
## process and report what each costs and what each removes -- and what lets a
## capture for a report be taken in a named mode with `run_render.sh --aa fxaa`
## without editing the project file.
##
## Nothing here is read by the simulation, and a headless process never loads it:
## it draws no frames, so it has no viewport to set any of this on.

## Every mode, and what it means on a Viewport.
##
## `msaa` is multi-sample anti-aliasing: the depth and coverage of each pixel are
## sampled several times and the geometry edge inside the pixel is resolved from
## them. It fixes exactly the kind of noise a field of thin blades makes, and its
## cost is paid per covered pixel of geometry, so it is the mode grass is worst
## for. `fxaa` is a filter over the finished picture that finds edge-shaped
## contrast and softens it -- nearly free, but it works from the same aliased
## pixels rather than from more samples, and it blurs texture along with edges.
## `taa` accumulates the previous frames' pixels under a sub-pixel jitter, which
## is very effective on a still frame and is the one that trades against motion.
const MODES := {
	"off": {"msaa": Viewport.MSAA_DISABLED, "fxaa": false, "taa": false,
		"label": "no anti-aliasing"},
	"msaa2": {"msaa": Viewport.MSAA_2X, "fxaa": false, "taa": false,
		"label": "2x multi-sampling"},
	"msaa4": {"msaa": Viewport.MSAA_4X, "fxaa": false, "taa": false,
		"label": "4x multi-sampling"},
	"msaa8": {"msaa": Viewport.MSAA_8X, "fxaa": false, "taa": false,
		"label": "8x multi-sampling"},
	"fxaa": {"msaa": Viewport.MSAA_DISABLED, "fxaa": true, "taa": false,
		"label": "screen-space FXAA"},
	"taa": {"msaa": Viewport.MSAA_DISABLED, "fxaa": false, "taa": true,
		"label": "temporal anti-aliasing"},
	"msaa2+fxaa": {"msaa": Viewport.MSAA_2X, "fxaa": true, "taa": false,
		"label": "2x multi-sampling and FXAA"},
	"msaa4+fxaa": {"msaa": Viewport.MSAA_4X, "fxaa": true, "taa": false,
		"label": "4x multi-sampling and FXAA"},
}

## The order the table is reported in: cheapest first, so a reader walks up the
## cost rather than around it.
const ORDER := [
	"off", "fxaa", "taa", "msaa2", "msaa2+fxaa", "msaa4", "msaa4+fxaa", "msaa8",
]

## The project settings the engine reads at startup, so the mode chosen here and
## the mode written into project.godot are named in one place.
const SETTING_MSAA := "rendering/anti_aliasing/quality/msaa_3d"
const SETTING_SCREEN_SPACE := "rendering/anti_aliasing/quality/screen_space_aa"
const SETTING_TAA := "rendering/anti_aliasing/quality/use_taa"


## Draw this viewport with a named mode. Returns false, and changes nothing, if
## the name is not one of MODES.
static func apply(viewport: Viewport, mode: String) -> bool:
	if not MODES.has(mode):
		return false
	var wanted: Dictionary = MODES[mode]
	viewport.msaa_3d = wanted["msaa"]
	viewport.screen_space_aa = (
		Viewport.SCREEN_SPACE_AA_FXAA if wanted["fxaa"] else Viewport.SCREEN_SPACE_AA_DISABLED
	)
	viewport.use_taa = wanted["taa"]
	return true


## What a viewport is currently drawing with, as one of MODES' names, or
## "custom" for a combination this table does not carry.
static func of(viewport: Viewport) -> String:
	for name in MODES:
		var wanted: Dictionary = MODES[name]
		var fxaa := viewport.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA
		if viewport.msaa_3d == wanted["msaa"] and fxaa == wanted["fxaa"] \
				and viewport.use_taa == wanted["taa"]:
			return name
	return "custom"


## What the project file asks for, as one of MODES' names. This is what a run
## with no `--aa` draws with.
static func from_project_settings() -> String:
	var msaa := int(ProjectSettings.get_setting(SETTING_MSAA, 0))
	var screen_space := int(ProjectSettings.get_setting(SETTING_SCREEN_SPACE, 0))
	var taa := bool(ProjectSettings.get_setting(SETTING_TAA, false))
	for name in MODES:
		var wanted: Dictionary = MODES[name]
		if int(wanted["msaa"]) == msaa and int(wanted["fxaa"]) == screen_space \
				and bool(wanted["taa"]) == taa:
			return name
	return "custom"
