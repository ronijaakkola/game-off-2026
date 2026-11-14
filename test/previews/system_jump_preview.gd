extends Node
## The solar system right after a promotion in Sol, jumping to Lyra, for capturing the jump.
## With "join" after `--`, it goes on: promoted in Lyra, it jumps to Draco, and promoted
## there, it joins every system.


func _ready() -> void:
	var system := $SolarSystem as Node3D
	var progression := system.get_node(^"Progression") as Progression
	var dock := system.get_node(^"Hud/TopRight/Stack/DockPanel") as DockPanel
	var jump := system.get_node(^"SystemJump") as SystemJump
	var bus := system.get_node(^"Bus") as FrameshiftBus
	await get_tree().process_frame
	var jumps := 2 if "join" in OS.get_cmdline_user_args() else 1
	for i: int in jumps:
		progression.promote()
		await get_tree().process_frame
		dock.jump_pressed.emit()
		await jump.finished
		await bus.docked
	if jumps > 1:
		progression.promote()
