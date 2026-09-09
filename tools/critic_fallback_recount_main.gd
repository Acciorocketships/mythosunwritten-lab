extends SceneTree
## Entry point for the critic's fallback recount. Exit 0.


func _initialize() -> void:
	for line in CriticFallbackRecount.report():
		print(line)
	quit(0)
