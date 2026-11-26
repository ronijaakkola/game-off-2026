class_name EmptyLineLabel
extends Label
## "Nobody waiting.", under the dock panel's rows, so a row going out uncovers it and the
## card only shrinks. It fades in once the last row has faded out, and fades out under the
## first row to come, staying in the layout until that row's place has opened past it, so
## the card never snaps shorter. Under Reduce motion it shows and hides at once.

# Whether it shows, or is on its way in, and its fade.
var _empty := true
var _fade: Tween


## Shows it while [param empty], fading when [param animated].
func show_empty(empty: bool, animated: bool) -> void:
	if animated and empty == _empty:
		return
	_empty = empty
	if _fade:
		_fade.kill()
	if not animated or Settings.reduce_motion:
		visible = empty
		modulate.a = 1.0
		return
	_fade = create_tween()
	if empty:
		if not visible:
			modulate.a = 0.0
			visible = true
		_fade.tween_interval(BoardingRow.EXIT_SECONDS)
		_fade.tween_property(self, ^"modulate:a", 1.0, BoardingRow.EXIT_SECONDS)
	else:
		_fade.tween_property(self, ^"modulate:a", 0.0, BoardingRow.EXIT_SECONDS)
		_fade.tween_interval(BoardingRow.GAP_SECONDS - BoardingRow.EXIT_SECONDS)
		_fade.tween_callback(hide)
