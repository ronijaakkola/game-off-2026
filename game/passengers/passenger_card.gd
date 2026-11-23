class_name PassengerCard
extends Control
## One passenger's row in the On board panel: their name, what they are doing, and their
## happiness as a bar along the bottom in their mood's colour, which blends into the next
## mood's as it changes. A big drop in happiness, such as a scare, leaves a red trail on the
## bar that holds a moment, then shrinks to it. While they ask for something, a button held
## down serves it ([ServeButton]) in the activity's place, with the need's icon, filling
## as it is served. It only reads the passenger;
## the [Cabin] runs the ride.
## Chevrons on the bar ([TrendChevrons]) show where their happiness is heading
## ([member Passenger.trend]): one to three, pointing right while it climbs and left while
## it falls, the more the further it is going soon. They ride the end of the fill, inside it,
## and once the fill is too short to hold them they sit just past its end on the track, in
## the mood's colour. They fade in and out.
## What frustration has taken off the most they can reach shows as a striped end of the
## bar's track ([HappinessCap]), the part they can no longer fill, and the fill stops there.
## While the bus is [member docked] their happiness holds, and a pause mark sits where the
## chevrons would ([DockedMark]); a request open then reads as the station serving it.
## The pointer on the bar opens a panel that says what is moving their happiness
## ([HappinessBreakdown]). Their portrait sits on the left, as a [PassengerPhoto].
## When the passenger boards, the card's place in the list opens while the card slides in
## from past the left edge of the screen.
## When the bus stops at their destination, [method show_rating] swaps the bottom row,
## their happiness, for the stars they rate the ride, which fill
## up one by one, and the activity reads "Getting off". The card lingers like that, and
## only then [method leave] slides it back out past the left edge and folds its place away
## so the cards below it move up. The root is a slot that holds the card's place in the
## list, the gap above it included, so it closes without a jump; the panel moves inside it,
## cut off at the slot's bottom while it opens. The card never fades as it moves: its
## portrait blends by adding, so see-through it would flash white over its frame.
## The pointer over the card fades its options in to its right: for now one button, which
## kicks the passenger off the bus. They fade out once the pointer leaves both, and stay
## away once the card shows the rating or leaves, or while it isn't [member kickable].

## The serve button for [member passenger]'s open request was pressed down, with
## [param held] true, or let go, with it false.
signal serve_held(held: bool)
## The kick button was pressed: the player wants [member passenger] off the bus.
signal kick_pressed
## The card has slid out of sight after [method leave], and its place starts to fold.
signal slid_out
## The card has slid out and folded away after [method leave]. It can be freed.
signal left

## Seconds to slide in, and to slide back out.
const ENTER_SECONDS := 0.35
const EXIT_SECONDS := 0.25
## Seconds for the slot to open to the card's height, and to fold away once the card is out.
const FOLD_SECONDS := 0.25
## How far past the left edge of the screen the card starts and ends, in pixels, so its
## shadow is off it too.
const OFF_SCREEN := 8.0
## Pixels above the card, kept in its slot.
const GAP := 8.0
# How far past the slot's sides the clip reaches, so it cuts only the card's bottom, never
# a badge that reaches past the photo's corner.
const CLIP_ROOM := 16.0
## A drop in happiness this big in one frame, as a fraction of the bar, leaves a trail:
## shocks do, the steady slide doesn't.
const TRAIL_JUMP := 0.05
## Seconds the trail holds after a drop before it shrinks, and how fast it shrinks then, in
## bars a second. A slow slide it follows at once, so it never shows.
const TRAIL_HOLD_SECONDS := 0.5
const TRAIL_SHRINK_RATE := 0.5
## Seconds the bar's colour takes to blend into the new mood's. A blend is no motion, so
## Reduce motion keeps it.
const MOOD_FADE_SECONDS := 0.3
## Seconds the bottom row takes to swap the happiness bar for the stars: the bar sinks and
## fades out while the stars drop in from above and fade in, a little behind it.
const SWAP_SECONDS := 0.3
const SWAP_STAGGER := 0.1
## How far the bar sinks and the stars drop, in pixels. Reduce motion only fades them.
const SWAP_PIXELS := 6.0
## Seconds the options take to fade in, or out. A fade is no motion, so Reduce motion keeps
## it.
const OPTIONS_SECONDS := 0.18
## Seconds each star takes to fill once the stars are in.
const STAR_FILL_SECONDS := 0.18
## Seconds the card shows the rating before it can slide out, counted from
## [method show_rating]. Long enough for five stars to fill and be read.
const LINGER_SECONDS := 2.2

const MOOD_COLORS: Dictionary[Passenger.Mood, Color] = {
	Passenger.Mood.HAPPY: Color(0.549, 0.851, 0.4),
	Passenger.Mood.OKAY: Color(0.98, 0.8, 0.38),
	Passenger.Mood.ANNOYED: Color(0.98, 0.549, 0.302),
	Passenger.Mood.FURIOUS: Color(0.949, 0.302, 0.4),
}

## How far right of the card its options sit. The panel the card is in sets it, so they
## clear its edge. The gap still counts as the card for the pointer, so the options stay
## while it crosses.
var options_gap := 6.0
## Whether the passenger can be kicked off. Without it the card has no options.
var kickable := true
## Whether the bus is docked, so their happiness holds, and what its comfort upgrades
## give. The panel the card is in sets them.
var docked := false
var comfort := Comfort.new()

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
# The mood shown, so the colours change only when it does. -1 before the first show.
var _mood := -1
# How much of the card's height the slot keeps: 1 in the list, 0 folded away.
var _fold := 1.0
# How far right of its place the panel sits, in pixels: negative is left.
var _shift := 0.0
# The tween that slides the panel, and the one that opens and folds the slot.
var _motion: Tween
var _gap: Tween
# The bar's blend into the new mood's colour.
var _fill_fade: Tween
# Whether the card shows the rating: the passenger is getting off, so it stops following
# them.
var _rated := false
# Seconds left until the card has shown the rating long enough to slide out.
var _linger_left := 0.0
# The request shown, so a new one is heard once.
var _shown_request: Need
# The middle row's swap from the happiness bar to the stars, then the stars filling.
var _rating_swap: Tween
# Whether the card is on its way out, after leave().
var _leaving := false
# How far the options have faded in: 0 gone, 1 shown.
var _reveal := 0.0
# Whether the options are out, or on their way out.
var _options_open := false
var _options_fade: Tween


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
	(%Options as Control).add_theme_constant_override(&"margin_left", roundi(options_gap))
	_show()
	_fit_slot()


func _process(delta: float) -> void:
	_linger_left = maxf(_linger_left - delta, 0.0)
	if not _rated:
		_show()
		_follow_trail(delta)
		var trend := passenger.trend if passenger else 0.0
		(%HappinessTrend as TrendChevrons).follow(trend, delta, %HappinessBar, _fill.bg_color)
		(%DockedMark as DockedMark).follow(docked, delta, %HappinessBar)
		if passenger:
			var breakdown := %HappinessBreakdown as HappinessBreakdown
			breakdown.follow(passenger, comfort, docked, %HappinessBar, MOOD_COLORS)
	_fade_options(_wants_options())
	_fit_slot()


## Opens the card's place in the list while the card slides in from past the left edge of
## the screen. Under Reduce motion it fades in in place, its place open at once.
func slide_in() -> void:
	_kill_motion()
	var panel := %Panel as Control
	_motion = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	if Settings.reduce_motion:
		_set_fold(1.0)
		panel.modulate.a = 0.0
		_motion.tween_property(panel, ^"modulate:a", 1.0, ENTER_SECONDS)
		return
	_set_fold(0.0)
	_gap = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_gap.tween_method(_set_fold, 0.0, 1.0, FOLD_SECONDS)
	var start := _off_left()
	_set_shift(start)
	_motion.tween_method(_set_shift, start, 0.0, ENTER_SECONDS)


## Folds the card's place shut, so it is out of sight until [method slide_in].
func tuck() -> void:
	_set_fold(0.0)


## Shows that the passenger is getting off and rated the ride [param stars] out of
## [constant Passenger.MAX_STARS]. The bottom row swaps: the happiness bar sinks and fades
## out while empty stars drop in from above and fade in, then the stars fill up to the
## rating one after another, each swelling as it fills. The activity morphs to "Getting
## off", and the serve button goes. The name stays. The card
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
	# The bar fades out, and so does asking about it.
	(%HappinessBreakdown as Control).visible = false
	(%ActivityLabel as Control).visible = true
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


## The serve button, for a guide card to point at.
func get_serve_button() -> Control:
	return %ServeButton


## The happiness bar, for a guide card to point at.
func get_happiness_bar() -> Control:
	return %HappinessBar


## The rating's stars, for a guide card to point at.
func get_rating_stars() -> Control:
	return %RatingStars


## Whether the card shows the rating, after [method show_rating].
func is_rated() -> bool:
	return _rated


## Slides the card out past the left edge of the screen, from wherever it is, then folds
## its place away and emits [signal left]. Under Reduce motion it fades out in place and
## its place closes at once. After [method show_rating], it first waits until the rating has
## shown for [constant LINGER_SECONDS]. The serve button stops working at once.
func leave() -> void:
	var panel := %Panel as Control
	(%ServeButton as ServeButton).release()
	(%ServeButton as ServeButton).disabled = true
	(%KickButton as Button).disabled = true
	_leaving = true
	if _motion:
		_motion.kill()
	_motion = create_tween()
	if _linger_left > 0.0:
		_motion.tween_interval(_linger_left)
	_motion.tween_callback(_slide_out.bind(panel))


# Slides the panel out past the left edge from wherever it is, then folds the slot away.
func _slide_out(panel: Control) -> void:
	_motion = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if Settings.reduce_motion:
		_motion.tween_property(panel, ^"modulate:a", 0.0, EXIT_SECONDS)
	else:
		_motion.tween_method(_set_shift, _shift, _off_left(), EXIT_SECONDS)
	_motion.tween_callback(_fold_away)


# How far the panel shifts to sit just past the left edge of the screen.
func _off_left() -> float:
	return -(global_position.x + (%Panel as Control).size.x + OFF_SCREEN)


func _fold_away() -> void:
	slid_out.emit()
	if _gap:
		_gap.kill()
	if Settings.reduce_motion:
		_set_fold(0.0)
		left.emit()
		return
	_gap = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_gap.tween_method(_set_fold, _fold, 0.0, FOLD_SECONDS)
	_gap.tween_callback(left.emit)


func _kill_motion() -> void:
	for tween: Tween in [_motion, _gap]:
		if tween:
			tween.kill()


func _set_shift(pixels: float) -> void:
	_shift = pixels
	_fit_slot()


func _set_fold(value: float) -> void:
	_fold = value
	_fit_slot()


# The slot is as tall as the card and the gap above it, times the fold, and the panel
# fills its width. The clip is the slot, reaching past its sides and as far left as the
# panel has shifted, so it cuts only the card's bottom, and only while the slot is part
# open. The bottom row's slot is as tall as the bar's row, which fills its
# width; the swap moves the row and the stars inside it.
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
	var reach := CLIP_ROOM + maxf(-_shift, 0.0)
	panel.position = Vector2(reach + _shift, GAP)
	# Whole pixels, so a place opening as another folds add up to one place throughout.
	var slot := Vector2(size_needed.x, roundf((size_needed.y + GAP) * _fold))
	if custom_minimum_size != slot:
		custom_minimum_size = slot
	var clip := %Clip as Control
	clip.clip_contents = _fold < 1.0
	clip.position = Vector2(-reach, 0.0)
	clip.size = Vector2(slot.x + reach + CLIP_ROOM, slot.y)
	_place_options()


# Whether the options should be out: the pointer is over the card or them, and the
# passenger is still riding.
func _wants_options() -> bool:
	if _rated or _leaving or not kickable:
		return false
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered != null and is_ancestor_of(hovered)


# Fades the options in, or out, when [param open] changes.
func _fade_options(open: bool) -> void:
	if open == _options_open:
		return
	_options_open = open
	if _options_fade:
		_options_fade.kill()
	var target := 1.0 if open else 0.0
	_options_fade = create_tween()
	(
		_options_fade
		. tween_property(self, ^"_reveal", target, OPTIONS_SECONDS * absf(target - _reveal))
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)


# The options sit right of the card, past [member options_gap], centred on the panel.
func _place_options() -> void:
	var options := %Options as Control
	options.visible = _reveal > 0.0
	if not options.visible:
		return
	var panel := %Panel as Control
	options.size = options.get_combined_minimum_size()
	options.position = Vector2(size.x + _shift, GAP + (panel.size.y - options.size.y) * 0.5)
	options.modulate.a = _reveal


func _show() -> void:
	if not passenger:
		return
	# A new passenger's lines appear at once; later changes morph.
	var first := _mood == -1
	_set_text(%NameLabel, passenger.name)
	var value := passenger.get_happiness_fraction()
	var cap := %HappinessCap as HappinessCap
	cap.lost = passenger.frustration / Passenger.MAX_HAPPINESS
	cap.happiness = value
	cap.color = _fill.bg_color
	# The fill stops at what they can reach; the cap shows what is above it.
	value = minf(value, cap.get_reach())
	(%HappinessBar as ProgressBar).value = value
	if first:
		(%HappinessTrail as ProgressBar).value = value
		_shown_happiness = value
		_trail_hold = 0.0
	var mood := passenger.get_mood()
	if mood != _mood:
		_mood = mood
		if _fill_fade:
			_fill_fade.kill()
		if first:
			_fill.bg_color = MOOD_COLORS[mood]
		else:
			_fill_fade = create_tween()
			_fill_fade.tween_property(_fill, ^"bg_color", MOOD_COLORS[mood], MOOD_FADE_SECONDS)
	_morph_text(%ActivityLabel, passenger.activity, first)
	var button := %ServeButton as ServeButton
	button.visible = passenger.request != null
	# The button takes the activity's place, across the card.
	(%ActivityLabel as Control).visible = not button.visible
	button.progress = passenger.serving
	# A request already open when the card first shows was heard on its old card, if any.
	if passenger.request and passenger.request != _shown_request and not first:
		Psst.play()
	_shown_request = passenger.request
	if passenger.request:
		# Docked, the station serves it, and the cabin's line says so.
		var label := passenger.activity if docked else passenger.request.serve_label
		button.show_request(label, passenger.request.icon)


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
