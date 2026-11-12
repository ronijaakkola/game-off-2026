class_name TransmissionPanel
extends CanvasLayer
## The transmission modal: a [Transmission]'s caller on their screen beside what they say,
## in the middle of the screen over a dimmed, paused game. It holds the game paused while it
## shows, with the pause menu's [method PauseMenu.hold], so the pause menu closing over it
## leaves the game paused. It processes always, so it animates while paused, and its layer
## sits over the HUD and under the pause menu.
## It opens in steps: the tube turns on, then the caller says their text a letter at a
## time at a speaking pace, a beat between words and a pause at each comma and full stop,
## talking as they do and falling quiet in the pauses. Only then do the quest, the reward
## and the buttons fade in one after another. A click on the modal before that shows it
## all at once.

## The player answered: [param accepted] is true for the primary button.
signal answered(accepted: bool)

const FLASK_ICON := preload("res://game/solar_system/icons/flask_conical.svg")
## Seconds the scrim and the modal take to come in, and to go.
const FADE_IN_SECONDS := 0.4
const FADE_OUT_SECONDS := 0.2
## How small the modal starts as it comes in.
const START_SCALE := 0.96
## Seconds after opening before the caller starts talking: once the tube is on, and a beat.
const TALK_DELAY := TransmissionScreen.ON_SECONDS + 0.35
## Seconds after each letter, after a space, after a comma, colon or dash, and after a full
## stop, question or exclamation mark.
const LETTER_SECONDS := 0.04
const SPACE_SECONDS := 0.07
const COMMA_SECONDS := 0.25
const STOP_SECONDS := 0.5
## How much each wait varies either way, as a share of it, so the pace isn't mechanical.
const PACE_JITTER := 0.35
## A pause at least this long stops the talking until the next word starts.
const QUIET_SECONDS := 0.2
## Seconds after the last word before the rest comes in, so the player finishes reading.
const CASCADE_BEAT := 0.4
## Seconds each of the quest, the reward and the buttons takes to come in, and from one
## starting to the next; a skip runs it tighter and with no beat.
const CASCADE_SECONDS := 0.5
const CASCADE_STEP := 0.18
const SKIP_STEP := 0.08
## How far each rises as it comes in, in pixels, in [method _cascaded]'s order: the most for
## what matters most.
const CASCADE_RISE: Array[float] = [8.0, 6.0, 4.0]
## Seconds into closing before the modal fades: once the tube has shut, and a beat on its
## dark screen. And how small the modal ends.
const CLOSE_DELAY := TransmissionScreen.OFF_SECONDS + 0.15
const END_SCALE := 0.98
## A reward's colour, as a gain.
const GAIN_COLOR := Color(0.549, 0.851, 0.4)
## How strongly a research reward's chip is tinted in its race's colour.
const CHIP_TINT := 0.18

var _transmission: Transmission
var _revealed := false
# The one tween for each thing that moves: the scrim and modal fading in and out, the text,
# and the cascade.
var _fade: Tween
var _typing: Tween
var _cascade: Tween


func _ready() -> void:
	hide()


# The pause is the modal's while it shows, so it goes with it.
func _exit_tree() -> void:
	if visible:
		PauseMenu.release(self)


## Whether a transmission shows.
func is_open() -> bool:
	return visible


## Shows [param transmission] and pauses the game until the player answers it.
func open(transmission: Transmission) -> void:
	_transmission = transmission
	PauseMenu.hold(self)
	_fill(transmission)
	show()
	var still := Settings.reduce_motion
	var modal := %Modal as Control
	modal.pivot_offset = modal.size * 0.5
	modal.scale = Vector2.ONE if still else Vector2.ONE * START_SCALE
	(%Root as Control).modulate.a = 0.0
	if _fade:
		_fade.kill()
	_fade = create_tween().set_parallel().set_ease(Tween.EASE_OUT)
	_fade.tween_property(%Root, "modulate:a", 1.0, FADE_IN_SECONDS).set_trans(Tween.TRANS_CUBIC)
	_fade.tween_property(modal, "scale", Vector2.ONE, FADE_IN_SECONDS).set_trans(Tween.TRANS_EXPO)
	(%Screen as TransmissionScreen).turn_on()
	_revealed = false
	for part: Control in _cascaded():
		part.modulate.a = 0.0
	_set_buttons_live(false)
	var message := %Message as Label
	message.visible_characters = 0
	if _typing:
		_typing.kill()
	if still:
		_reveal(true)
		return
	_typing = create_tween()
	_typing.tween_interval(TALK_DELAY)
	var text := message.text
	for i: int in text.length():
		var wait := _wait_after(text[i])
		_typing.tween_callback(_say.bind(i + 1, wait < QUIET_SECONDS))
		_typing.tween_interval(wait * randf_range(1.0 - PACE_JITTER, 1.0 + PACE_JITTER))
	_typing.tween_callback(_reveal.bind(false))


# Shows the first [param letters] letters, talking unless a pause comes next.
func _say(letters: int, talking: bool) -> void:
	(%Message as Label).visible_characters = letters
	_set_talking(talking)


# How long the caller waits after saying [param letter] before the next.
static func _wait_after(letter: String) -> float:
	if letter in [".", "!", "?"]:
		return STOP_SECONDS
	if letter in [",", ";", ":", "—"]:
		return COMMA_SECONDS
	if letter == " ":
		return SPACE_SECONDS
	return LETTER_SECONDS


## Shows the whole text at once and fades in the rest, as a click on the modal does.
func skip() -> void:
	if not _revealed:
		_reveal(true)


func _on_modal_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and not _revealed:
		skip()
		(%Modal as Control).accept_event()


func _on_accept_button_pressed() -> void:
	_answer(true)


func _on_decline_button_pressed() -> void:
	_answer(false)


func _answer(accepted: bool) -> void:
	_set_buttons_live(false)
	(%Screen as TransmissionScreen).turn_off()
	if _fade:
		_fade.kill()
	_fade = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_fade.tween_property(%Root, "modulate:a", 0.0, FADE_OUT_SECONDS).set_delay(CLOSE_DELAY)
	if not Settings.reduce_motion:
		var modal := %Modal as Control
		modal.pivot_offset = modal.size * 0.5
		_fade.tween_property(modal, "scale", Vector2.ONE * END_SCALE, FADE_OUT_SECONDS).set_delay(
			CLOSE_DELAY
		)
	await _fade.finished
	hide()
	(%Screen as TransmissionScreen).clear()
	PauseMenu.release(self)
	answered.emit(accepted)


# The text in full, then, after a beat to finish reading, the quest, the reward and the
# buttons fade and rise in one after another. A skip has no beat and a tighter stagger.
# Under Reduce motion they only fade.
func _reveal(skipped: bool) -> void:
	_revealed = true
	if _typing:
		_typing.kill()
	(%Message as Label).visible_characters = -1
	_set_talking(false)
	if _cascade:
		_cascade.kill()
	var still := Settings.reduce_motion
	if not still:
		# Each part rises back to where its container put it, so the containers lay out
		# the shown text first: a skip in the frame the modal opened has no layout yet.
		await get_tree().process_frame
	_cascade = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	var delay := 0.0 if skipped else CASCADE_BEAT
	var parts := _cascaded()
	for i: int in parts.size():
		var part := parts[i]
		if not part.visible:
			continue
		_cascade.tween_property(part, "modulate:a", 1.0, CASCADE_SECONDS).set_delay(delay)
		if not still:
			var rest := part.position.y
			part.position.y = rest + CASCADE_RISE[i]
			_cascade.tween_property(part, "position:y", rest, CASCADE_SECONDS).set_delay(delay)
		if part == %Buttons:
			_cascade.tween_callback(_set_buttons_live.bind(true)).set_delay(delay)
		delay += SKIP_STEP if skipped else CASCADE_STEP


# What fades in after the text, in order.
func _cascaded() -> Array[Control]:
	return [%Quest, %Reward, %Buttons]


func _set_talking(value: bool) -> void:
	(%Screen as TransmissionScreen).talking = value


# Buttons take no clicks until they show, so a click that skips the text can't land on
# one. A click on one then reaches the modal and skips instead.
func _set_buttons_live(live: bool) -> void:
	for button: Button in [%AcceptButton, %DeclineButton]:
		button.mouse_filter = Control.MOUSE_FILTER_STOP if live else Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_ALL if live else Control.FOCUS_NONE


func _fill(transmission: Transmission) -> void:
	(%Screen as TransmissionScreen).show_caller(transmission)
	(%CallerName as Label).text = transmission.caller_name
	(%Destination as Control).visible = transmission.destination != null
	(%DestinationIcon as PlanetIcon).planet = transmission.destination
	(%DestinationLabel as Label).text = _planet_name(transmission.destination)
	(%Message as Label).text = transmission.text
	(%Quest as Control).visible = transmission.is_quest()
	(%QuestLabel as Label).text = transmission.quest
	(%QuestPlanetIcon as PlanetIcon).planet = transmission.quest_planet
	(%QuestPlanetLabel as Label).text = _planet_name(transmission.quest_planet)
	(%QuestPlanet as Control).visible = transmission.quest_planet != null
	_fill_reward(transmission)
	(%AcceptButton as Button).text = transmission.accept_text
	(%DeclineButton as Button).text = transmission.decline_text
	(%DeclineButton as Button).visible = transmission.decline_text != ""


func _fill_reward(transmission: Transmission) -> void:
	(%Reward as Control).visible = transmission.has_reward()
	(%Credits as Control).visible = transmission.reward_credits > 0
	(%CreditsLabel as Label).text = str(transmission.reward_credits)
	var chips := %ResearchChips as Control
	for chip: Node in chips.get_children():
		chips.remove_child(chip)
		chip.queue_free()
	for race: Race.Type in transmission.reward_research:
		chips.add_child(_research_chip(race, transmission.reward_research[race]))


# A chip tinted in the race's colour, with its flask and the points.
func _research_chip(race: Race.Type, points: int) -> Control:
	var color := Race.SKIN_COLORS[race]
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, CHIP_TINT)
	style.set_corner_radius_all(6)
	style.content_margin_left = 4.0
	style.content_margin_right = 6.0
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.custom_minimum_size.y = 20.0
	chip.add_theme_stylebox_override(&"panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	chip.add_child(row)
	var flask := TextureRect.new()
	flask.texture = FLASK_ICON
	flask.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flask.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flask.custom_minimum_size = Vector2(12, 12)
	flask.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	flask.self_modulate = color
	row.add_child(flask)
	var label := Label.new()
	label.theme_type_variation = &"StrongLabel"
	label.add_theme_color_override(&"font_color", GAIN_COLOR)
	label.text = str(points)
	row.add_child(label)
	return chip


func _planet_name(planet: Planet) -> String:
	if not planet:
		return ""
	return planet.display_name if planet.display_name else String(planet.name)
