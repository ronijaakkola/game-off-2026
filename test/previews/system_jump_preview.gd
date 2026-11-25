extends Node
## The solar system right after a promotion in Vela, jumping to Lyra, for capturing the jump.
## With "join" after `--`, it goes on: promoted in Lyra, it jumps to Sol, and promoted
## there, it joins every system. With "loading", the jump stops where the player's does, on
## the next level's loading screen: `capture <this scene> --frames 400 -- loading`. Without,
## nothing waits for Start, so the jump plays through.


func _ready() -> void:
	var system := $SolarSystem as Node3D
	var progression := system.get_node(^"Progression") as Progression
	var jump := system.get_node(^"SystemJump") as SystemJump
	var bus := system.get_node(^"Bus") as FrameshiftBus
	jump.shows_loading_screen = "loading" in OS.get_cmdline_user_args()
	await get_tree().process_frame
	var jumps := 2 if "join" in OS.get_cmdline_user_args() else 1
	for i: int in jumps:
		progression.advance()
		await jump.finished
		await bus.docked
	if jumps > 1:
		progression.advance()
