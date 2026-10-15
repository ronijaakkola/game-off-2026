extends Node
## The dev console commands. The only script that may name LimboConsole, which the web
## build leaves out along with this script. Add new commands here.


func _ready() -> void:
	LimboConsole.register_command(_goto, "goto", "Fade to the scene at a res:// path")


func _goto(path: String) -> void:
	if not ResourceLoader.exists(path):
		LimboConsole.error("No scene at %s" % path)
		return
	SceneFlow.go_to(path)
