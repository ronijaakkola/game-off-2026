class_name PickUpMarker
extends Control
## The live portrait of one person the player has to pick up, on a small dark card with a
## notch pointing down at the planet they wait at ([PickUpMarkers] places it). At rest it
## holds the portrait alone; [method set_open] widens it both ways from the notch to show
## their name over one dim line, the text laid out once at full width and only uncovered.
## It grows out of the notch's tip as it comes ([method appear]) and shrinks back into it as
## it goes ([method leave]). Under Reduce motion each of those only fades.
## The root sits where [method place] puts it, centred on the notch wherever that is, off
## screen too; [b]Body[/b], inside it, does the motion, so the root's own opacity is free
## for fading with the planet's name. The photo is a flat rounded square in a thin light
## border, tilted a little as a card's.

## The card's body without the notch, its corners, and the notch's base and length, in
## pixels.
const CLOSED_WIDTH := 38.0
const BODY_HEIGHT := 38.0
const CORNER_RADIUS := 8.0
const NOTCH_WIDTH := 12.0
const NOTCH_LENGTH := 6.0
const HEIGHT := BODY_HEIGHT + NOTCH_LENGTH
## The photo's size and how far inside the card's left and top edges it sits; the room
## between it and the text, and after the text to the right edge.
const PHOTO_SIZE := 28.0
const PHOTO_INSET := 5.0
const TEXT_GAP := 9.0
const TEXT_END := 10.0
const TEXT_LEFT := PHOTO_INSET + PHOTO_SIZE + TEXT_GAP
## How far the photo is tilted, in degrees.
const PHOTO_TILT := 2.0
const FILL_COLOR := Color(0.0431, 0.0353, 0.1255)
const BORDER_COLOR := Color(1.0, 1.0, 1.0, 0.2)
## The part of the edge that shows a wait running out: its width, and the colour it turns
## when this little of the wait is left.
const TIME_WIDTH := 2.0
const TIME_LOW := 0.25
const TIME_LOW_COLOR := Color(0.949, 0.302, 0.4)
## Appearing: from this scale past full size and back, fading in over the first part.
const APPEAR_FROM := 0.85
const APPEAR_PEAK := 1.06
const APPEAR_RISE_SECONDS := 0.2
const APPEAR_SETTLE_SECONDS := 0.15
const APPEAR_FADE_SECONDS := 0.12
const APPEAR_REDUCED_SECONDS := 0.2
## Leaving: shrinking toward the notch's tip while fading out.
const LEAVE_TO := 0.85
const LEAVE_SECONDS := 0.15
## Opening: the card widens, then the text fades in sliding out from the photo.
const OPEN_SECONDS := 0.15
const TEXT_DELAY := 0.04
const TEXT_IN_SECONDS := 0.11
const TEXT_SLIDE := 4.0
## Closing: the text fades out and the card narrows, most of the way at once.
const CLOSE_SECONDS := 0.12
const TEXT_OUT_SECONDS := 0.08

## Where the portrait is rendered. Set it before [method show_passenger].
var portrait_studio: PortraitStudio
## How much of their wait is left, from 1 to 0, drawn as that much of the card's edge in
## gold from the notch's tip clockwise. Under 0, they wait for as long as it takes and the
## edge shows nothing.
var time_left := -1.0:
	set(value):
		time_left = value
		if is_node_ready():
			(%Body as Control).queue_redraw()

# How open the card is, from 0 (the portrait alone) to 1 (the whole text uncovered).
var _openness := 0.0
var _opening := false
var _leaving := false
# The card's width open, from the text's.
var _open_width := CLOSED_WIDTH
var _width_tween: Tween
var _text_tween: Tween
var _body_tween: Tween


func _ready() -> void:
	(%Body as Control).draw.connect(_draw_card)
	(%Framed as Control).rotation = deg_to_rad(PHOTO_TILT)
	_set_openness(0.0)


## Shows [param passenger]'s portrait, their name and [param line] under it.
func show_passenger(passenger: Passenger, line: String) -> void:
	var photo := %Photo as PassengerPhoto
	photo.studio = portrait_studio
	photo.passenger = passenger
	(%Name as Label).text = passenger.name
	(%Line as Label).text = line
	var width := maxf(
		(%Name as Control).get_combined_minimum_size().x,
		(%Line as Control).get_combined_minimum_size().x
	)
	(%TextBox as Control).size = Vector2(width, BODY_HEIGHT)
	_open_width = TEXT_LEFT + width + TEXT_END
	_set_openness(_openness)


## Puts the notch's tip on [param tip], the card above it, and fades it to
## [param opacity] with the planet's name.
func place(tip: Vector2, opacity: float) -> void:
	position = tip - Vector2(size.x * 0.5, HEIGHT)
	modulate.a = opacity
	var body := %Body as Control
	# The portrait fades with everything over it.
	(%Photo as PassengerPhoto).opacity = opacity * body.modulate.a


## The card as it would be closed, on screen, were its notch's tip on [param tip]: what
## the pointer has to reach to open it.
static func get_closed_rect(tip: Vector2) -> Rect2:
	return Rect2(tip.x - CLOSED_WIDTH * 0.5, tip.y - HEIGHT, CLOSED_WIDTH, BODY_HEIGHT)


## Whether the card is open or opening.
func is_open() -> bool:
	return _opening


## Opens the card to show the text, or closes it to the portrait alone, turning round from
## where it is. [param at_once] skips the motion, as when a panel opens.
func set_open(open: bool, at_once := false) -> void:
	if open == _opening and not at_once:
		return
	_opening = open
	if _width_tween:
		_width_tween.kill()
	if _text_tween:
		_text_tween.kill()
	var text := %TextBox as Control
	if at_once:
		_set_openness(1.0 if open else 0.0)
		text.modulate.a = 1.0 if open else 0.0
		text.position.x = 0.0
		return
	var seconds := OPEN_SECONDS if open else CLOSE_SECONDS
	if Settings.reduce_motion:
		_set_openness(1.0 if open else 0.0)
	else:
		_width_tween = create_tween()
		(
			_width_tween
			. tween_method(_set_openness, _openness, 1.0 if open else 0.0, seconds)
			. set_trans(Tween.TRANS_QUINT)
			. set_ease(Tween.EASE_OUT)
		)
	_text_tween = create_tween().set_parallel()
	if open:
		if not Settings.reduce_motion and text.modulate.a <= 0.0:
			text.position.x = -TEXT_SLIDE
		_text_tween.tween_property(text, ^"modulate:a", 1.0, TEXT_IN_SECONDS).set_delay(TEXT_DELAY)
		(
			_text_tween
			. tween_property(text, ^"position:x", 0.0, TEXT_IN_SECONDS)
			. set_delay(TEXT_DELAY)
			. set_trans(Tween.TRANS_CUBIC)
			. set_ease(Tween.EASE_OUT)
		)
	else:
		_text_tween.tween_property(text, ^"modulate:a", 0.0, TEXT_OUT_SECONDS)


## Grows the card out of the notch's tip past its size and settles it, fading it in.
func appear() -> void:
	var body := %Body as Control
	if _body_tween:
		_body_tween.kill()
	body.modulate.a = 0.0
	_body_tween = create_tween()
	if Settings.reduce_motion:
		body.scale = Vector2.ONE
		_body_tween.tween_property(body, ^"modulate:a", 1.0, APPEAR_REDUCED_SECONDS)
		return
	body.scale = Vector2.ONE * APPEAR_FROM
	_body_tween.set_parallel()
	_body_tween.tween_property(body, ^"modulate:a", 1.0, APPEAR_FADE_SECONDS)
	(
		_body_tween
		. tween_property(body, ^"scale", Vector2.ONE * APPEAR_PEAK, APPEAR_RISE_SECONDS)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_body_tween
		. tween_property(body, ^"scale", Vector2.ONE, APPEAR_SETTLE_SECONDS)
		. set_delay(APPEAR_RISE_SECONDS)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)


## Whether [method leave] has started.
func is_leaving() -> bool:
	return _leaving


## Shrinks the card toward the notch's tip while fading it out, as it is, open or not,
## then frees it.
func leave() -> void:
	_leaving = true
	var body := %Body as Control
	if _body_tween:
		_body_tween.kill()
	_body_tween = create_tween().set_parallel()
	_body_tween.tween_property(body, ^"modulate:a", 0.0, LEAVE_SECONDS)
	if not Settings.reduce_motion:
		(
			_body_tween
			. tween_property(body, ^"scale", Vector2.ONE * LEAVE_TO, LEAVE_SECONDS)
			. set_trans(Tween.TRANS_CUBIC)
			. set_ease(Tween.EASE_OUT)
		)
	_body_tween.chain().tween_callback(queue_free)


# Widens the card to [param value] of the way open; [PickUpMarkers] places it about the
# notch again this frame. The text's window is what the card's width leaves it.
func _set_openness(value: float) -> void:
	_openness = value
	var width := lerpf(CLOSED_WIDTH, _open_width, value)
	size = Vector2(width, HEIGHT)
	var body := %Body as Control
	body.size = size
	# Its tip, which it grows from and shrinks into.
	body.pivot_offset = Vector2(width * 0.5, HEIGHT)
	(%Text as Control).size = Vector2(maxf(0.0, width - TEXT_LEFT - TEXT_END), BODY_HEIGHT)
	body.queue_redraw()


# The card's outline with the notch, filled, and its thin light border.
func _draw_card() -> void:
	var body := %Body as Control
	var outline := _outline(size.x, 0.5)
	body.draw_colored_polygon(_outline(size.x, 0.0), FILL_COLOR)
	outline.append(outline[0])
	body.draw_polyline(outline, BORDER_COLOR, 1.0, true)
	if time_left > 0.0:
		var color := TIME_LOW_COLOR if time_left <= TIME_LOW else Vip.GOLD
		body.draw_polyline(_part_from_tip(outline, time_left), color, TIME_WIDTH, true)


# The first [param part], from 0 to 1, of the closed [param outline]'s length, starting at
# the notch's tip and going clockwise.
func _part_from_tip(outline: PackedVector2Array, part: float) -> PackedVector2Array:
	var count := outline.size() - 1
	var tip := 0
	for i: int in count:
		if outline[i].y > outline[tip].y:
			tip = i
	var total := 0.0
	for i: int in count:
		total += outline[i].distance_to(outline[i + 1])
	var left := total * clampf(part, 0.0, 1.0)
	var points := PackedVector2Array([outline[tip]])
	for step: int in count:
		var from := outline[(tip + step) % count]
		var to := outline[(tip + step + 1) % count]
		var length := from.distance_to(to)
		if length >= left:
			points.append(from.lerp(to, left / length))
			break
		points.append(to)
		left -= length
	return points


# The card's edge, [param inset] pixels inside it, clockwise from the top left corner, the
# notch's tip in the middle of the bottom edge.
func _outline(width: float, inset: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var r := CORNER_RADIUS - inset
	var corners: Array[Vector2] = [
		Vector2(CORNER_RADIUS, CORNER_RADIUS),
		Vector2(width - CORNER_RADIUS, CORNER_RADIUS),
		Vector2(width - CORNER_RADIUS, BODY_HEIGHT - CORNER_RADIUS),
		Vector2(CORNER_RADIUS, BODY_HEIGHT - CORNER_RADIUS),
	]
	var steps := 6
	for i: int in corners.size():
		var start := PI + i * PI * 0.5
		for step: int in steps + 1:
			var angle := start + step * PI * 0.5 / steps
			points.append(corners[i] + Vector2.from_angle(angle) * r)
		if i == 2:
			var half := NOTCH_WIDTH * 0.5
			var bottom := BODY_HEIGHT - inset
			var middle := width * 0.5
			points.append(Vector2(middle + half, bottom))
			points.append(Vector2(middle, HEIGHT - inset * 2.0))
			points.append(Vector2(middle - half, bottom))
	return points
