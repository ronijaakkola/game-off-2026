extends Control
## The game's HUD: how many pieces have been placed. It counts
## [signal Events.piece_placed], so it doesn't need to know who places them.

var _placed := 0


func _ready() -> void:
	Events.piece_placed.connect(_on_piece_placed)
	_show_count()


func _on_piece_placed(_position: Vector3) -> void:
	_placed += 1
	_show_count()


func _show_count() -> void:
	%PlacedLabel.text = "Placed: %d" % _placed
