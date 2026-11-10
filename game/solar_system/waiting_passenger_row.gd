class_name WaitingPassengerRow
extends Control
## One passenger waiting at a planet, as a row in its panel: their portrait (a
## [PassengerPhoto]), their name with where they are going under it (an arrow, an icon of the
## planet and its name), and their fare. It reads the passenger when [member passenger] is
## set; a passenger's details don't change while they wait.
## The root is a slot that holds the row's place in the list, and the panel moves inside it,
## so the row can slide in from the right.

## Seconds to slide in from past the right edge.
const SLIDE_IN_SECONDS := 0.35
# How far past the slot's right edge the panel starts, so it begins out of sight.
const OFF_RIGHT := 32.0
const OFF_SCREEN := 4096.0

var passenger: Passenger:
	set(value):
		passenger = value
		if is_node_ready():
			_show()
## Where the portrait is rendered. Set it before [member passenger].
var portrait_studio: PortraitStudio

var _slide: Tween


func _ready() -> void:
	resized.connect(_fit)
	(%Panel as Control).minimum_size_changed.connect(_fit)
	_show()
	_fit()


## Starts the row past the right edge and slides it into place. Under Reduce motion it
## fades in in place instead.
func slide_in() -> void:
	if _slide:
		_slide.kill()
	var panel := %Panel as Control
	if size.x <= 0.0:
		# Just added: its list gives it a width later this frame. Out of sight till then.
		panel.position.x = OFF_SCREEN
		await resized
	_slide = create_tween()
	if Settings.reduce_motion:
		panel.position.x = 0.0
		panel.modulate.a = 0.0
		_slide.tween_property(panel, ^"modulate:a", 1.0, SLIDE_IN_SECONDS)
		return
	panel.position.x = size.x + OFF_RIGHT
	(
		_slide
		. tween_property(panel, ^"position:x", 0.0, SLIDE_IN_SECONDS)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)


func _show() -> void:
	if not passenger:
		return
	var photo := %PassengerPhoto as PassengerPhoto
	photo.studio = portrait_studio
	photo.passenger = passenger
	(%NameLabel as Label).text = passenger.name
	(%DestinationIcon as PlanetIcon).planet = passenger.destination
	(%DestinationLabel as Label).text = _destination_name()
	(%FareLabel as Label).text = "%d credits" % roundi(passenger.fare)


func _destination_name() -> String:
	if not passenger.destination:
		return "?"
	if passenger.destination.display_name:
		return passenger.destination.display_name
	return passenger.destination.name


# The slot is as tall as the panel needs, and the panel fills the slot's width.
func _fit() -> void:
	var panel := %Panel as Control
	var needed := panel.get_combined_minimum_size()
	panel.size = Vector2(size.x, needed.y)
	if custom_minimum_size != needed:
		custom_minimum_size = needed
