extends Node
## Which bus events become analytics: Talo events (Online.track) and stats (Online.add_stat).
## The one place that says what the game tracks, so wire new bus events here. Online adds it.
## Name an event after its bus event; create a stat in the Talo dashboard before adding to it.


func _ready() -> void:
	Events.piece_placed.connect(_on_piece_placed)


func _on_piece_placed(_position: Vector3) -> void:
	Online.track("piece_placed")
