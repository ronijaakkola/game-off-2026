class_name PassengerCard
extends Control
## One passenger's card: their name, where they are going (an arrow, an icon of the
## planet and its name), their happiness as a bar in their mood's colour, and what they
## are doing. A big drop in happiness, such as a scare, leaves a red trail on the bar
## that holds a moment, then shrinks to it. While they ask for something, a button held
## down serves it ([ServeButton]), filling as it is served. It only reads the passenger;
## the [Cabin] runs the ride.
## Chevrons on the bar ([TrendChevrons]) show where their happiness is heading
## ([member Passenger.trend]): one to three, pointing right while it climbs and left while
## it falls, the more the further it is going soon. They ride the end of the fill, inside it,
## and once the fill is too short to hold them they sit just past its end on the track, in
## the mood's colour. They fade in and out.
## Their portrait sits on the left, as a [PassengerPhoto].
## The card slides in from past the left edge of the screen when the passenger boards.
## When the bus stops at their destination, [method show_rating] swaps the middle row,
## where they are going and their happiness, for the stars they rate the ride, which fill
## up one by one, and the activity reads "Getting off". The card lingers like that, and
## only then [method leave] slides it back out past the left edge and folds its height
## away so the cards below it move up. The root is a slot that holds
## the card's place in the list, and the panel moves inside it.
## The pointer over the card slides its options out from under it to its right: for now
## one button, which kicks the passenger off the bus. They slide back under once the
## pointer leaves both, and stay away once the card shows the rating or leaves.

## The serve button for [member passenger]'s open request was pressed down, with
## [param held] true, or let go, with it false.
signal serve_held(held: bool)
## The kick button was pressed: the player wants [member passenger] off the bus.
signal kick_pressed
## The card has slid out and folded away after [method leave]. It can be freed.
signal left

## Seconds to slide in from past the left edge of the screen, and back out past it.
const SLIDE_IN_SECONDS := 0.4
const SLIDE_OUT_SECONDS := 0.3
## Seconds to fold the slot's height away once the card is out.
const FOLD_SECONDS := 0.2
## A drop in happiness this big in one frame, as a fraction of the bar, leaves a trail:
## shocks do, the steady slide doesn't.
const TRAIL_JUMP := 0.05
## Seconds the trail holds after a drop before it shrinks, and how fast it shrinks then, in
## bars a second. A slow slide it follows at once, so it never shows.
const TRAIL_HOLD_SECONDS := 0.5
const TRAIL_SHRINK_RATE := 0.5
## How much happiness the trend must cover, either way, for each more chevron, and how far
## under its step a chevron already shown may drop before it goes, so a trend near a step
## doesn't flicker.
const TREND_STEPS: Array[float] = [1.5, 8.0, 20.0]
const TREND_MARGIN := 1.0
## The chevrons' colour inside the fill, dark so they read on every mood's colour.
const TREND_INSIDE_COLOR := Color(0.1, 0.06, 0.18, 0.7)
## Pixels between the chevrons and the fill's end, and between them and the bar's top and
## bottom.
const TREND_PAD := 2.0
const TREND_INSET := 1.0
## Seconds the chevrons take to fade in or out.
const TREND_FADE_SECONDS := 0.2
## Seconds the mood name takes to fade out and back in as the new mood, and the bar's
## colour to blend into the new mood's. A fade is no motion, so Reduce motion keeps it.
const MOOD_FADE_SECONDS := 0.3
## Seconds the middle row takes to swap the happiness bar for the stars: the bar sinks and
## fades out while the stars drop in from above and fade in, a little behind it.
const SWAP_SECONDS := 0.3
const SWAP_STAGGER := 0.1
## How far the bar sinks and the stars drop, in pixels. Reduce motion only fades them.
const SWAP_PIXELS := 6.0
## Seconds the options take to slide out from under the card, or back under it. Under
## Reduce motion they only fade.
const OPTIONS_SECONDS := 0.18
## Seconds each star takes to fill once the stars are in.
const STAR_FILL_SECONDS := 0.18
## Seconds the card shows the rating before it can slide out, counted from
## [method show_rating]. Long enough for five stars to fill and be read.
const LINGER_SECONDS := 2.2

const MOOD_COLORS: Dictionary[Passenger.Mood, Color] = {
	Passenger.Mood.HAPPY: Color(0.55, 0.85, 0.4),
	Passenger.Mood.OKAY: Color(0.98, 0.8, 0.38),
	Passenger.Mood.ANNOYED: Color(0.98, 0.55, 0.3),
	Passenger.Mood.FURIOUS: Color(0.95, 0.3, 0.4),
}
const MOOD_NAMES: Dictionary[Passenger.Mood, String] = {
	Passenger.Mood.HAPPY: "Happy",
	Passenger.Mood.OKAY: "Okay",
	Passenger.Mood.ANNOYED: "Annoyed",
	Passenger.Mood.FURIOUS: "Furious",
}
## How the mood name shakes, as the `[shake]` tag's rate and level, for the moods that
## shake at all. Reduce motion holds it still.
const MOOD_SHAKES: Dictionary[Passenger.Mood, Vector2] = {
	Passenger.Mood.ANNOYED: Vector2(10.0, 4.0),
	Passenger.Mood.FURIOUS: Vector2(18.0, 8.0),
}

var passenger: Passenger:
	set(value):
		passenger = value
		_mood = -1
		if is_node_ready():
			(%PassengerPhoto as PassengerPhoto).passenger = value
			_show()
## Where the portrait is rendered. Set it before [member passenger].
var portrait_studio: PortraitStudio:
	set(value):
		portrait_studio = value
		if is_node_ready():
			(%PassengerPhoto as PassengerPhoto).studio = value

# The bar's fill, this card's own copy, so its colour changes on this card alone.
var _fill: StyleBoxFlat
# The happiness the bar showed last frame, and seconds the trail holds still for.
var _shown_happiness := 1.0
var _trail_hold := 0.0
# How many chevrons the trend calls for, which way, and how far the chevrons have faded in.
# The chevrons keep their count while they fade out.
var _trend_count := 0
var _trend_rising := true
var _trend_alpha := 0.0
# The mood shown, so the colours change only when it does. -1 before the first show.
var _mood := -1
# Whether Reduce motion was on when the mood name was last written.
var _still := false
# How much of the card's height the slot keeps: 1 in the list, 0 folded away.
var _fold := 1.0
# The one tween that moves the panel and folds the slot, in turn.
var _motion: Tween
# The mood name's fade out and in, and the bar's blend into the new mood's colour.
var _mood_fade: Tween
var _fill_fade: Tween
# Whether the card shows the rating: the passenger is getting off, so it stops following
# them.
var _rated := false
# Seconds left until the card has shown the rating long enough to slide out.
var _linger_left := 0.0
# The middle row's swap from the happiness bar to the stars, then the stars filling.
var _rating_swap: Tween
# Whether the card is on its way out, after leave().
var _leaving := false
# How far the options have slid out: 0 under the card, 1 out to its right.
var _reveal := 0.0
# Whether the options are out, or on their way out.
var _options_open := false
var _options_slide: Tween


func _ready() -> void:
	var stars := %RatingStars as StarIcon
	stars.count = roundi(Passenger.MAX_STARS)
	stars.fill = 0.0
	var bar := %HappinessBar as ProgressBar
	_fill = (bar.get_theme_stylebox(&"fill") as StyleBoxFlat).duplicate()
	bar.add_theme_stylebox_override(&"fill", _fill)
	var photo := %PassengerPhoto as PassengerPhoto
	photo.riding = true
	photo.studio = portrait_studio
	photo.passenger = passenger
	_show()
	_fit_slot()


func _process(delta: float) -> void:
	_linger_left = maxf(_linger_left - delta, 0.0)
	if not _rated:
		_show()
		_follow_trail(delta)
		_follow_trend(delta)
	_slide_options(_wants_options())
	_fit_slot()


## Starts the card past the left edge of the screen and slides it into place. Under Reduce
## motion it fades in in place instead.
func slide_in() -> void:
	if _motion:
		_motion.kill()
	var panel := %Panel as Control
	_motion = create_tween()
	if Settings.reduce_motion:
		panel.modulate.a = 0.0
		_motion.tween_property(panel, ^"modulate:a", 1.0, SLIDE_IN_SECONDS)
		return
	panel.position.x = _off_left()
	(
		_motion
		. tween_property(panel, ^"position:x", 0.0, SLIDE_IN_SECONDS)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)


## Shows that the passenger is getting off and rated the ride [param stars] out of
## [constant Passenger.MAX_STARS]. The middle row swaps: the happiness bar, and where they
## are going, sink and fade out while empty stars drop in from above and fade in, then the
## stars fill up to the rating one after another, each swelling as it fills. The activity
## morphs to "Getting off", and the serve button goes. The name and mood stay. The card
## stops following the passenger. Under Reduce motion the row only crossfades and the
## stars only change colour. Only the first call counts.
func show_rating(stars: float) -> void:
	if _rated:
		return
	_rated = true
	_linger_left = LINGER_SECONDS
	var button := %ServeButton as ServeButton
	button.release()
	button.disabled = true
	button.visible = false
	var still := Settings.reduce_motion
	var drop := 0.0 if still else SWAP_PIXELS
	var trip := %Trip as Control
	var rating := %RatingStars as StarIcon
	var rest_y := (trip.size.y - rating.size.y) * 0.5
	rating.fill = 0.0
	rating.bump = not still
	rating.modulate.a = 0.0
	rating.position.y = rest_y - drop
	rating.visible = true
	if _rating_swap:
		_rating_swap.kill()
	_rating_swap = create_tween().set_parallel()
	_rating_swap.tween_property(trip, ^"modulate:a", 0.0, SWAP_SECONDS)
	(
		_rating_swap
		. tween_property(trip, ^"position:y", drop, SWAP_SECONDS)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	_rating_swap.tween_property(rating, ^"modulate:a", 1.0, SWAP_SECONDS).set_delay(SWAP_STAGGER)
	(
		_rating_swap
		. tween_property(rating, ^"position:y", rest_y, SWAP_SECONDS)
		. set_delay(SWAP_STAGGER)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	_rating_swap.chain().tween_property(
		rating, ^"fill", clampf(stars, 0.0, rating.count), stars * STAR_FILL_SECONDS
	)
	(%ActivityLabel as MorphLabel).morph_to("Getting off")


## Whether the card shows the rating, after [method show_rating].
func is_rated() -> bool:
	return _rated


## Slides the card out past the left edge of the screen, then folds its height away, and
## emits [signal left]. Under Reduce motion it fades out in place instead of sliding.
## After [method show_rating], it first waits until the rating has
## shown for [constant LINGER_SECONDS]. The serve button stops working at once.
func leave() -> void:
	if _motion:
		_motion.kill()
	var panel := %Panel as Control
	(%ServeButton as ServeButton).release()
	(%ServeButton as ServeButton).disabled = true
	(%KickButton as Button).disabled = true
	_leaving = true
	_motion = create_tween()
	if _linger_left > 0.0:
		_motion.tween_interval(_linger_left)
	if Settings.reduce_motion:
		_motion.tween_property(panel, ^"modulate:a", 0.0, SLIDE_OUT_SECONDS)
	else:
		(
			_motion
			. tween_property(panel, ^"position:x", _off_left(), SLIDE_OUT_SECONDS)
			. set_trans(Tween.TRANS_CUBIC)
			. set_ease(Tween.EASE_OUT)
		)
	_motion.tween_method(_set_fold, 1.0, 0.0, FOLD_SECONDS).set_trans(Tween.TRANS_QUAD)
	_motion.tween_callback(left.emit)


# Where the panel sits just past the left edge of the screen, from the slot.
func _off_left() -> float:
	return -(global_position.x + (%Panel as Control).size.x + 8.0)


func _set_fold(value: float) -> void:
	_fold = value
	_fit_slot()


# The slot is as tall as the card, times the fold, and the panel fills its width. The
# middle row's slot is as tall as the trip row, which fills its width; the swap moves
# the row and the stars inside it.
func _fit_slot() -> void:
	var middle := %Middle as Control
	var trip := %Trip as Control
	var row := trip.get_combined_minimum_size()
	if middle.custom_minimum_size != row:
		middle.custom_minimum_size = row
	trip.size = Vector2(middle.size.x, row.y)
	var rating := %RatingStars as Control
	rating.size = rating.custom_minimum_size
	var panel := %Panel as Control
	var size_needed := panel.get_combined_minimum_size()
	panel.size = size_needed
	var slot := Vector2(size_needed.x, size_needed.y * _fold)
	if custom_minimum_size != slot:
		custom_minimum_size = slot
	_place_options()


# Whether the options should be out: the pointer is over the card or them, and the
# passenger is still riding.
func _wants_options() -> bool:
	if _rated or _leaving:
		return false
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered != null and is_ancestor_of(hovered)


# Slides the options out from under the card, or back under it, when [param open] changes.
func _slide_options(open: bool) -> void:
	if open == _options_open:
		return
	_options_open = open
	if _options_slide:
		_options_slide.kill()
	var target := 1.0 if open else 0.0
	_options_slide = create_tween()
	(
		_options_slide
		. tween_property(self, ^"_reveal", target, OPTIONS_SECONDS * absf(target - _reveal))
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)


# The options sit beside the panel, centred on it: tucked under its right edge when in, and
# just past it when out. They fade as they go, since the card is see-through. Under Reduce
# motion they stay out and only fade.
func _place_options() -> void:
	var options := %Options as Control
	options.visible = _reveal > 0.0
	if not options.visible:
		return
	var panel := %Panel as Control
	options.size = options.get_combined_minimum_size()
	var slide := 1.0 if Settings.reduce_motion else _reveal
	var tucked := panel.size.x - options.size.x
	options.position = Vector2(
		panel.position.x + lerpf(tucked, panel.size.x, slide),
		panel.position.y + (panel.size.y - options.size.y) * 0.5
	)
	options.modulate.a = _reveal


func _show() -> void:
	if not passenger:
		return
	# A new passenger's lines appear at once; later changes morph.
	var first := _mood == -1
	_set_text(%NameLabel, passenger.name)
	var icon := %DestinationIcon as PlanetIcon
	if icon.planet != passenger.destination:
		icon.planet = passenger.destination
	_set_text(%DestinationLabel, _destination_name())
	var value := passenger.get_happiness_fraction()
	(%HappinessBar as ProgressBar).value = value
	if first:
		(%HappinessTrail as ProgressBar).value = value
		_shown_happiness = value
		_trail_hold = 0.0
	var mood := passenger.get_mood()
	if mood != _mood:
		_mood = mood
		_still = Settings.reduce_motion
		if first:
			if _mood_fade:
				_mood_fade.kill()
			if _fill_fade:
				_fill_fade.kill()
			(%MoodLabel as RichTextLabel).modulate.a = 1.0
			_write_mood()
			_fill.bg_color = MOOD_COLORS[mood]
		else:
			_fade_mood()
	elif Settings.reduce_motion != _still:
		_still = Settings.reduce_motion
		# A fade under way writes the name when it's out of sight, with the setting as it is.
		if not _is_mood_fading():
			_write_mood()
	_morph_text(%ActivityLabel, passenger.activity, first)
	var button := %ServeButton as ServeButton
	button.visible = passenger.request != null
	button.progress = passenger.serving
	if passenger.request and button.text != passenger.request.serve_label:
		button.text = passenger.request.serve_label


# The trail behind the bar: a drop of TRAIL_JUMP or more holds it where it was for
# TRAIL_HOLD_SECONDS, then it shrinks to the bar. A rise takes it along at once.
func _follow_trail(delta: float) -> void:
	var value := (%HappinessBar as ProgressBar).value
	var trail := %HappinessTrail as ProgressBar
	if _shown_happiness - value >= TRAIL_JUMP:
		_trail_hold = TRAIL_HOLD_SECONDS
	_shown_happiness = value
	if value >= trail.value:
		trail.value = value
		_trail_hold = 0.0
	elif _trail_hold > 0.0:
		_trail_hold -= delta
	else:
		trail.value = move_toward(trail.value, value, TRAIL_SHRINK_RATE * delta)


# The chevrons: as many as the passenger's trend calls for, fading in and out, placed at
# the fill's end.
func _follow_trend(delta: float) -> void:
	var trend := passenger.trend if passenger else 0.0
	var rising := trend > 0.0
	# A chevron shown holds until the trend drops TREND_MARGIN under its step; a turn
	# starts afresh.
	var shown := _trend_count if rising == _trend_rising else 0
	var count := 0
	for i: int in TREND_STEPS.size():
		var step := TREND_STEPS[i] - (TREND_MARGIN if i < shown else 0.0)
		if absf(trend) >= step:
			count = i + 1
	_trend_count = count
	if count > 0:
		_trend_rising = rising
	var chevrons := %HappinessTrend as TrendChevrons
	var target := 1.0 if count > 0 else 0.0
	_trend_alpha = move_toward(_trend_alpha, target, delta / TREND_FADE_SECONDS)
	if count > 0:
		chevrons.count = count
		chevrons.rising = rising
	elif _trend_alpha <= 0.0:
		chevrons.count = 0
	chevrons.modulate.a = _trend_alpha
	_place_trend()


# Puts the chevrons inside the fill at its end, or just past its end when it is too short to
# hold them.
func _place_trend() -> void:
	var bar := %HappinessBar as ProgressBar
	var chevrons := %HappinessTrend as TrendChevrons
	var height := bar.size.y - TREND_INSET * 2.0
	chevrons.size = Vector2(chevrons.size.x, height)
	var width := chevrons.get_width()
	chevrons.size = Vector2(width, height)
	var end := bar.size.x * bar.value / bar.max_value
	var x := end - TREND_PAD - width
	var color := TREND_INSIDE_COLOR
	if x < TREND_PAD:
		x = end + TREND_PAD
		color = _fill.bg_color
	chevrons.position = Vector2(x, TREND_INSET)
	chevrons.color = color


# Fades the mood name out, writes the new one, and fades it back in, while the bar blends
# into the new colour. A fade under way carries on from where it is.
func _fade_mood() -> void:
	var label := %MoodLabel as RichTextLabel
	var half := MOOD_FADE_SECONDS * 0.5
	if _mood_fade:
		_mood_fade.kill()
	_mood_fade = create_tween()
	_mood_fade.tween_property(label, ^"modulate:a", 0.0, half * label.modulate.a)
	_mood_fade.tween_callback(_write_mood)
	_mood_fade.tween_property(label, ^"modulate:a", 1.0, half)
	if _fill_fade:
		_fill_fade.kill()
	_fill_fade = create_tween()
	_fill_fade.tween_property(_fill, ^"bg_color", MOOD_COLORS[_mood], MOOD_FADE_SECONDS)


func _is_mood_fading() -> bool:
	return _mood_fade != null and _mood_fade.is_running()


# Writes the shown mood's name and colour.
func _write_mood() -> void:
	var label := %MoodLabel as RichTextLabel
	label.text = _mood_text(_mood as Passenger.Mood)
	label.add_theme_color_override(&"default_color", MOOD_COLORS[_mood])


# The mood's name as BBCode, shaking for the low moods unless Reduce motion is on.
func _mood_text(mood: Passenger.Mood) -> String:
	if Settings.reduce_motion or not MOOD_SHAKES.has(mood):
		return MOOD_NAMES[mood]
	var shake := MOOD_SHAKES[mood]
	return "[shake rate=%s level=%s]%s[/shake]" % [shake.x, shake.y, MOOD_NAMES[mood]]


func _destination_name() -> String:
	if not passenger.destination:
		return "?"
	if passenger.destination.display_name:
		return passenger.destination.display_name
	return passenger.destination.name


# Sets text only when it changes, since this runs every frame.
func _set_text(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text


# Morphs to the text, or sets it at once when [param at_once].
func _morph_text(label: MorphLabel, text: String, at_once: bool) -> void:
	if at_once:
		label.text = text
	else:
		label.morph_to(text)


func _on_serve_button_hold_changed(held: bool) -> void:
	serve_held.emit(held)


func _on_kick_button_pressed() -> void:
	(%KickButton as Button).disabled = true
	kick_pressed.emit()
