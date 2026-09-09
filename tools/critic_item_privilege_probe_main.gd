extends SceneTree
## Entry point for the critic's privilege probe. Exit 0.


func _initialize() -> void:
	var written := PackedStringArray()
	written.append("the same weapon in two hands, and the same picture out the other end")
	written.append_array(CriticItemPrivilegeProbe.compare(
		"melee", Weapon.spear(), "common spear", ScriptedActions.DUEL_APART, 60))
	written.append_array(CriticItemPrivilegeProbe.compare(
		"ranged", Weapon.bow(), "common bow", 21.0, 60))
	written.append_array(CriticItemPrivilegeProbe.a_blow_that_found_nobody(
		Weapon.bow(), "common bow", ScriptedActions.DUEL_APART, 40))
	for line in written:
		print(line)
	quit(0)
