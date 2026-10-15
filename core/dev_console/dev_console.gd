extends Node
## Loads the dev console commands when LimboConsole is running. The web build leaves
## LimboConsole and the commands out, so this script names neither at compile time.

const DEV_COMMANDS := "res://core/dev_console/dev_commands.gd"


func _ready() -> void:
	if get_tree().root.get_node_or_null(^"LimboConsole") == null:
		return
	var commands: GDScript = load(DEV_COMMANDS)
	add_child(commands.new())
