extends Node
## Offers the business feature hint the first time a Business passenger waits in the dock
## panel: on their row, once the panel is all the way in and the row has been there for
## [constant SETTLE_SECONDS], so the card opens on a row that has stopped moving.

## The kind of passenger the hint is about.
const BUSINESS := preload("res://game/passengers/types/business.tres")
## Seconds a Business passenger's row shows in the panel, still, before the hint opens:
## time for the row to slide in, and a beat.
const SETTLE_SECONDS := BoardingRow.GAP_SECONDS + BoardingRow.ENTER_SECONDS + 0.3

@export var hints: FeatureHints
@export var dock_panel: DockPanel

# The row the hint would point at, and for how long it has shown in a panel that is in.
var _row: Control
var _shown_for := 0.0


func _ready() -> void:
	hints.set_debug_target(&"business", _business_row)


func _process(delta: float) -> void:
	var row := _business_row()
	if row != _row:
		_row = row
		_shown_for = 0.0
	if not row:
		return
	_shown_for += delta
	if _shown_for >= SETTLE_SECONDS and hints.offer(&"business", row):
		set_process(false)


# The row of a Business passenger in the line, while the panel is in.
func _business_row() -> Control:
	if not dock_panel.is_in():
		return null
	for passenger: Passenger in dock_panel.get_row_passengers():
		var row := dock_panel.get_row(passenger)
		if passenger.type == BUSINESS and row:
			return row
	return null
