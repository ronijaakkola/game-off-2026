extends Node
## Offers the returning passenger feature hint the first time a returning passenger
## ([member Passenger.returning]) waits in the dock panel: on their row, once the panel is
## all the way in and the row has been there for [constant SETTLE_SECONDS], so the card
## opens on a row that has stopped moving.

## Seconds a returning passenger's row shows in the panel, still, before the hint opens:
## time for the row to slide in, and a beat.
const SETTLE_SECONDS := BoardingRow.GAP_SECONDS + BoardingRow.ENTER_SECONDS + 0.3

@export var hints: FeatureHints
@export var dock_panel: DockPanel

# The row the hint would point at, and for how long it has shown in a panel that is in.
var _row: Control
var _shown_for := 0.0


func _process(delta: float) -> void:
	var row := _returning_row()
	if row != _row:
		_row = row
		_shown_for = 0.0
	if not row:
		return
	_shown_for += delta
	if _shown_for >= SETTLE_SECONDS and hints.offer(&"returning", row):
		set_process(false)


# The row of a returning passenger in the line, while the panel is in.
func _returning_row() -> Control:
	if not dock_panel.is_in():
		return null
	for passenger: Passenger in dock_panel.get_row_passengers():
		var row := dock_panel.get_row(passenger)
		if passenger.returning and row:
			return row
	return null
