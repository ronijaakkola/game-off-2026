class_name LevelControl
extends HBoxContainer
## A level from 0 to [constant ClipLevels.MAX] to set: a slider, small steps either side of it,
## and the number. [signal changed] says what it was set to. The mixer's rows use it.

signal changed(level: float)

## How far the − and + buttons move it.
const STEP := 0.05

var _level := 1.0


func _ready() -> void:
	var slider := %Slider as HSlider
	slider.max_value = ClipLevels.MAX
	slider.value_changed.connect(_on_slider_value_changed)
	(%LowerButton as Button).pressed.connect(_nudge.bind(-STEP))
	(%RaiseButton as Button).pressed.connect(_nudge.bind(STEP))
	_show()


## Shows [param level] without saying it changed.
func set_level(level: float) -> void:
	_level = clampf(snappedf(level, 0.01), 0.0, ClipLevels.MAX)
	if is_node_ready():
		_show()


func get_level() -> float:
	return _level


func _nudge(by: float) -> void:
	_take(_level + by)


func _on_slider_value_changed(value: float) -> void:
	_take(value)


# Takes a level from the player and says so, if it is a change.
func _take(level: float) -> void:
	level = clampf(snappedf(level, 0.01), 0.0, ClipLevels.MAX)
	if is_equal_approx(level, _level):
		return
	_level = level
	_show()
	changed.emit(_level)


func _show() -> void:
	(%Slider as HSlider).set_value_no_signal(_level)
	(%Readout as Label).text = "%.2f" % _level
