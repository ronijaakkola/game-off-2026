extends Node
## Offers the warp drive feature hint the first time the bus docks at a planet with a warp
## gate: on the dock panel's warp row, once the panel is all the way in and the row has
## shown for [constant SETTLE_SECONDS], so the card opens on a panel that has stopped moving.

## Seconds the warp row shows in a panel that is in before the hint opens: a beat.
const SETTLE_SECONDS := 0.3

@export var hints: FeatureHints
@export var dock_panel: DockPanel

# How long the warp row has shown in a panel that is in.
var _shown_for := 0.0


func _ready() -> void:
	hints.set_debug_target(&"warp_drive", dock_panel.get_teleport_row)


func _process(delta: float) -> void:
	var row := dock_panel.get_teleport_row()
	if not dock_panel.is_in() or not row.is_visible_in_tree():
		_shown_for = 0.0
		return
	_shown_for += delta
	if _shown_for >= SETTLE_SECONDS and hints.offer(&"warp_drive", row):
		set_process(false)
