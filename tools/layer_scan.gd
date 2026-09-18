extends SceneTree
## The layer scan, as one command: does anything under sim/ name a render type
## or a resource path?
##
## The rule itself is `tests/layer_check.gd`, and `tests/test_layering.gd` fails
## the build on it. This runs the same four scans on their own and prints a
## count per scan, so that "the simulation still knows nothing about the
## picture" is a command anybody can type and read the answer to -- which is
## what the render seam's evidence needs, because whichever shell draws the
## world, this must stay true.
##
##   ./tools/layer_scan.sh
##
## Exit 0 when every scan is empty, 1 otherwise, with each violation printed.
func _init() -> void:
	var groups := {
		"sim names the render layer": LayerCheck.run(),
		"render holds the fight": LayerCheck.run_render(),
		"the interface names its own art": LayerCheck.run_ui(),
		"the keyboard invents no sentence": LayerCheck.run_notes(),
	}
	var bad := 0
	for label in groups:
		var violations: Array = groups[label]
		print("layer-scan %-38s violations=%d" % [label, violations.size()])
		for one in violations:
			bad += 1
			print("    %s" % one)
	print("layer-scan total=%d" % bad)
	quit(0 if bad == 0 else 1)
