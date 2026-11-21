class_name ControlsPrototype
## PROTOTYPE, throwaway: which of two ways to show what a right click does is on, to
## compare them in the real HUD. A is a legend in the bottom right corner
## ([ControlLegendPrototype]); B is a ghost stop at the end of the route bar's line
## ([GhostStopPrototype]). The debug panel's Controls prototype card switches, and so does
## `controls=a`, `b`, `both` or `off` after `--` on the command line.

enum Variant { OFF, LEGEND, GHOST, BOTH }

static var variant := Variant.BOTH
## Whether a right click would change the route now: not in the tutorial, a call, a tow or
## with the route locked. The legend works it out each frame; the ghost stop reads it.
static var can_route := true


static func shows_legend() -> bool:
	return variant in [Variant.LEGEND, Variant.BOTH]


static func shows_ghost() -> bool:
	return variant in [Variant.GHOST, Variant.BOTH]


## Reads the variant from the command line, if it names one.
static func read_args() -> void:
	var named := {"off": Variant.OFF, "a": Variant.LEGEND, "b": Variant.GHOST}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("controls="):
			variant = named.get(arg.trim_prefix("controls="), Variant.BOTH)
