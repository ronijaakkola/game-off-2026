class_name StarCard
extends Control
## What the [StarChart] says about one star while the pointer is on it: its name over how
## many planets it has, what the player has to fetch there as a transmission shows a quest
## (a flag, what it asks and its planet), and a button to jump there. The button is off for a
## star more than one link away, and the star the bus is beside has "You are here" in its
## place. A solid dark card with a notch pointing down at the star ([method place]). It
## comes as a tooltip does ([method appear]): rising a little from the star while it fades
## in and grows out of the notch's tip, fast at first, with no overshoot. It goes quicker
## ([method leave]), fading and shrinking a little toward the tip. Either turns round from
## where the other left it. Under Reduce motion it only fades.
## The root sits where [method place] puts it; [b]Body[/b], inside it, does the motion.

## The player pressed the button to jump to the star.
signal jump_pressed

## Where the star is from the bus: the one it is beside, one link away, or further.
enum Reach { HERE, NEAR, FAR }

const WIDTH := 240.0
const PADDING := 12.0
const CORNER_RADIUS := 8.0
const NOTCH_WIDTH := 12.0
const NOTCH_LENGTH := 6.0
const FILL_COLOR := Color(0.0431, 0.0353, 0.1255)
const BORDER_COLOR := Color(1.0, 1.0, 1.0, 0.2)
## Coming: from this scale and this many pixels nearer the star, over these seconds.
const APPEAR_FROM := 0.94
const APPEAR_RISE := 6.0
const APPEAR_SECONDS := 0.18
## Going: to this scale, over these seconds.
const LEAVE_TO := 0.97
const LEAVE_SECONDS := 0.1
const JUMP_TEXT := "Jump here"
const FAR_TEXT := "Too far to jump"

var _shown := false
var _body_height := 0.0
var _tween: Tween


func _ready() -> void:
	(%Body as Control).draw.connect(_draw_card)
	(%Body as Control).modulate.a = 0.0
	hide()


## Fills the card for [param system], [param reach] from the bus, with [param fetch] still
## to do there, or null.
func show_star(system: StarSystem, reach: Reach, fetch: FetchGoal) -> void:
	(%NameLabel as Label).text = system.display_name
	var planets := system.get_planets().filter(
		func(planet: Planet) -> bool: return planet.get_parent() == system
	)
	(%PlanetsLabel as Label).text = "%d planets" % planets.size()
	(%Dot as Panel).self_modulate = get_star_color(system)
	(%Here as Control).visible = reach == Reach.HERE
	(%Quest as Control).visible = fetch != null
	if fetch:
		(%QuestLabel as Label).text = fetch.get_text()
		(%QuestPlanetIcon as PlanetIcon).planet = fetch.planet
		(%QuestPlanetLabel as Label).text = fetch.planet.display_name
	var button := %JumpButton as Button
	button.visible = reach != Reach.HERE
	button.disabled = reach == Reach.FAR
	button.text = FAR_TEXT if reach == Reach.FAR else JUMP_TEXT
	button.theme_type_variation = &"Button" if reach == Reach.FAR else &"PrimaryButton"
	var content := %Content as Control
	_body_height = content.get_combined_minimum_size().y + PADDING * 2.0
	content.size = Vector2(WIDTH - PADDING * 2.0, _body_height - PADDING * 2.0)
	size = Vector2(WIDTH, _body_height + NOTCH_LENGTH)
	var body := %Body as Control
	body.size = size
	# Its tip, which it grows from and shrinks into.
	body.pivot_offset = Vector2(WIDTH * 0.5, size.y)
	body.queue_redraw()


## The colour of [param system]'s star.
static func get_star_color(system: StarSystem) -> Color:
	for node: Node in system.star.find_children("*", "MeshInstance3D", true, false):
		var material := (node as MeshInstance3D).get_surface_override_material(0)
		if material is StandardMaterial3D:
			return (material as StandardMaterial3D).albedo_color
	return Color.WHITE


## Puts the notch's tip on [param tip], the card above it.
func place(tip: Vector2) -> void:
	position = (tip - Vector2(WIDTH * 0.5, size.y)).round()


## Whether the card is there, or coming.
func is_shown() -> bool:
	return _shown


## Brings the card in from where it is: rising from the star, fading in and growing out of
## the notch's tip.
func appear() -> void:
	var body := %Body as Control
	if not visible:
		body.modulate.a = 0.0
		body.scale = Vector2.ONE * APPEAR_FROM
		body.position.y = APPEAR_RISE
	_shown = true
	show()
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_tween.tween_property(body, ^"modulate:a", 1.0, APPEAR_SECONDS)
	if Settings.reduce_motion:
		body.scale = Vector2.ONE
		body.position.y = 0.0
		return
	_tween.tween_property(body, ^"scale", Vector2.ONE, APPEAR_SECONDS)
	_tween.tween_property(body, ^"position:y", 0.0, APPEAR_SECONDS)


## Fades the card out from where it is, shrinking a little toward the notch's tip, then
## hides it.
func leave() -> void:
	if not _shown:
		return
	_shown = false
	var body := %Body as Control
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(body, ^"modulate:a", 0.0, LEAVE_SECONDS)
	if not Settings.reduce_motion:
		_tween.tween_property(body, ^"scale", Vector2.ONE * LEAVE_TO, LEAVE_SECONDS)
	_tween.chain().tween_callback(hide)


func _on_jump_button_pressed() -> void:
	jump_pressed.emit()


# The card's outline with the notch, filled, and its thin light border.
func _draw_card() -> void:
	var body := %Body as Control
	var outline := _outline(0.5)
	body.draw_colored_polygon(_outline(0.0), FILL_COLOR)
	outline.append(outline[0])
	body.draw_polyline(outline, BORDER_COLOR, 1.0, true)


# The card's edge, [param inset] pixels inside it, clockwise from the top left corner, the
# notch's tip in the middle of the bottom edge.
func _outline(inset: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var r := CORNER_RADIUS - inset
	var corners: Array[Vector2] = [
		Vector2(CORNER_RADIUS, CORNER_RADIUS),
		Vector2(WIDTH - CORNER_RADIUS, CORNER_RADIUS),
		Vector2(WIDTH - CORNER_RADIUS, _body_height - CORNER_RADIUS),
		Vector2(CORNER_RADIUS, _body_height - CORNER_RADIUS),
	]
	var steps := 6
	for i: int in corners.size():
		var start := PI + i * PI * 0.5
		for step: int in steps + 1:
			points.append(corners[i] + Vector2.from_angle(start + step * PI * 0.5 / steps) * r)
		if i == 2:
			var half := NOTCH_WIDTH * 0.5
			var middle := WIDTH * 0.5
			points.append(Vector2(middle + half, _body_height - inset))
			points.append(Vector2(middle, _body_height + NOTCH_LENGTH - inset * 2.0))
			points.append(Vector2(middle - half, _body_height - inset))
	return points
