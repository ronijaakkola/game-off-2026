extends Node
## The solar system jumped on to Sol, whose star swells, to play or capture its heat zone.
## Run with F6, the bus arrives at Mars with the swell held at rest and the run plays on as
## usual: 3 deliveries in, the mechanic calls and warns of it, and it starts as the call
## closes. The debug panel's "Swell Sol's star" (F2) skips to just before the next swell.
## With "peak" after `--`, the swell is at its widest as the bus docks; with "warning", the
## star is about to swell. Both skip The Boss's arrival call, for a clear frame:
## `capture <this scene> --frames 700 -- peak`.


func _ready() -> void:
	var system := $SolarSystem as Node3D
	var progression := system.get_node(^"Progression") as Progression
	var jump := system.get_node(^"SystemJump") as SystemJump
	var bus := system.get_node(^"Bus") as FrameshiftBus
	var star_map := system.get_node(^"StarMap") as StarMap
	jump.shows_loading_screen = false
	await get_tree().create_timer(1.0).timeout
	# The jumps play fast, so Sol comes in a few seconds. Lyra leaves the bus at rest in
	# space; Sol has it fly in to dock at Mars.
	Engine.time_scale = 4.0
	for i: int in 2:
		progression.advance()
		await jump.finished
	await bus.docked
	Engine.time_scale = 1.0
	var sol := star_map.get_current()
	# Lyra's stage, as its mechanic's call would have opened, so Sol's call is the one with
	# its warning.
	var research := (system.get_node(^"ResearchLab") as ResearchLab).get_research()
	while research.get_open_stages() < 2:
		research.open_next_stage()
	var args := OS.get_cmdline_user_args()
	if "peak" in args:
		sol.skip_swell(sol.swell_rest_seconds + sol.swell_grow_seconds)
	elif "warning" in args:
		sol.skip_swell(sol.swell_rest_seconds - 1.0)
	else:
		return
	(system.get_node(^"FirstShiftCall") as FirstShiftCall).cancel()
