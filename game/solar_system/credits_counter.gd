class_name CreditsCounter
extends HBoxContainer
## The player's credits in the resource bar, beside a dollar sign: 12,480. It shows the
## credits of its [member ledger] and animates each change the ledger signals; it keeps no
## credits of its own. Payments collect in a gain floating under the bar ("+15"), which pops
## bigger for a moment and shows the new sum with each payment.
## Once [method commit] is called, after a short delay the total counts up to include it,
## number by number, while the gain fades out drifting upward. The ledger already counts
## every payment; only what shows waits.
## Spending shows the same way, in red ("-12"), at once: it pops, and after a short delay
## the total counts down while it fades out drifting upward. It shows in the gain's place,
## or under the gain while one waits. Credits set outright show at once and clear the gain
## and the loss.
## A count makes room for its widest number before it starts, and gives back what it no
## longer needs once it ends, so the resource bar changes width once per count rather than
## at each digit it passes (0 to 1,000 passes three). The total sits right-aligned in that
## room, so new digits appear on its left. It always has room for [constant ROOM], so the
## first fares of a game don't change the bar's width either.

## Seconds from [method commit] to the total starting to count up.
const COMMIT_DELAY := 0.25
## Seconds the total takes to count up per credit, and the most it takes in all.
const SECONDS_PER_CREDIT := 0.025
const MAX_COUNT_SECONDS := 1.2
## How much bigger the gain pops with each payment, and the seconds up and back down.
const POP_SCALE := 1.35
const POP_UP_SECONDS := 0.06
const POP_DOWN_SECONDS := 0.14
## Seconds the gain takes to fade out, and how far up it drifts meanwhile, in pixels.
const FADE_OUT_SECONDS := 0.6
const RISE_PIXELS := 14.0
## How far under the total the gain starts, in pixels: clear of the resource bar's pill, so
## that drifting up it fades out just under the pill's edge.
const GAIN_DROP := 23.0
## The total always has room for this many digits.
const ROOM := "000"

## The credits it shows. Until one is set, or when set to null, it shows a ledger
## of its own, so the scene runs by itself.
var ledger: Ledger:
	set(value):
		if ledger:
			ledger.credits_earned.disconnect(_on_earned)
			ledger.credits_spent.disconnect(_on_spent)
			ledger.credits_set.disconnect(_on_set)
		ledger = value if value else Ledger.new()
		ledger.credits_earned.connect(_on_earned)
		ledger.credits_spent.connect(_on_spent)
		ledger.credits_set.connect(_on_set)
		_on_set()

# Paid since the last commit, so not yet in the total shown.
var _pending := 0
# How far the gain has drifted up, in pixels.
var _rise := 0.0
# The commit: the delay, then the count up, the fade and the drift, together.
var _fade: Tween
var _pop: Tween
# How far the loss has drifted up, in pixels.
var _loss_rise := 0.0
# The spending: the pop, the delay, then the count down, the fade and the drift.
var _loss: Tween
# What the loss shows, which adds up spendings while it shows, and the total shown before
# the first of them.
var _loss_amount := 0
var _loss_from := 0
# The total showing now.
var _shown := 0


func _ready() -> void:
	if not ledger:
		ledger = Ledger.new()
	_on_set()
	_place_gain()


func _process(_delta: float) -> void:
	_place_gain()


# A payment of [param amount], already in the ledger: it joins the gain, which pops with
# the new sum. The total shown waits for [method commit].
func _on_earned(amount: int) -> void:
	_pending += amount
	# A commit or a spending still under way finishes at once, so the total stays right.
	if _fade:
		_fade.kill()
	_finish_loss()
	_show_total(ledger.credits - _pending)
	_release_width()
	var label := %GainLabel as Label
	label.text = "+%d" % _pending
	label.modulate.a = 1.0
	_rise = 0.0
	if _pop:
		_pop.kill()
	_pop = create_tween()
	_pop.tween_property(label, ^"scale", Vector2.ONE * POP_SCALE, POP_UP_SECONDS)
	(
		_pop
		. tween_property(label, ^"scale", Vector2.ONE, POP_DOWN_SECONDS)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)


# A bill of [param amount], already in the ledger: it shows in the loss ("-12"), which pops;
# after COMMIT_DELAY the total counts down to it while the loss fades out drifting upward.
# While a loss still shows, it adds to it and pops again, and the count down starts over
# from where it began. A count up under way finishes at once first; a gain still waiting
# for commit() stays.
func _on_spent(amount: int) -> void:
	if _fade and _fade.is_running():
		_fade.kill()
		(%GainLabel as Label).modulate.a = 0.0
	var label := %LossLabel as Label
	if _loss and _loss.is_running():
		_loss.kill()
		_loss_amount += amount
	else:
		_loss_amount = amount
		_loss_from = ledger.credits + amount - _pending
	_hold_width_for(maxi(_shown, _loss_from))
	label.text = "-%d" % _loss_amount
	label.modulate.a = 1.0
	label.scale = Vector2.ONE
	_loss_rise = 0.0
	_place_gain()
	var seconds := minf(_loss_amount * SECONDS_PER_CREDIT, MAX_COUNT_SECONDS)
	_loss = create_tween()
	_loss.tween_property(label, ^"scale", Vector2.ONE * POP_SCALE, POP_UP_SECONDS)
	(
		_loss
		. tween_property(label, ^"scale", Vector2.ONE, POP_DOWN_SECONDS)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	_loss.tween_interval(COMMIT_DELAY)
	_loss.tween_method(_show_total, _loss_from, ledger.credits - _pending, seconds)
	_loss.parallel().tween_property(label, ^"modulate:a", 0.0, FADE_OUT_SECONDS)
	(
		_loss
		. parallel()
		. tween_method(_set_loss_rise, 0.0, RISE_PIXELS, FADE_OUT_SECONDS)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_QUAD)
	)
	_loss.tween_callback(_release_width)


## Moves the gain into the total: after [constant COMMIT_DELAY], the total counts up one
## credit at a time while the gain fades out drifting upward. Nothing happens without a
## gain.
func commit() -> void:
	if _pending == 0:
		return
	_finish_loss()
	_hold_width_for(maxi(_shown, ledger.credits))
	var from := ledger.credits - _pending
	var seconds := minf(_pending * SECONDS_PER_CREDIT, MAX_COUNT_SECONDS)
	_pending = 0
	var label := %GainLabel as Label
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_interval(COMMIT_DELAY)
	_fade.tween_method(_show_total, from, ledger.credits, seconds)
	_fade.parallel().tween_property(label, ^"modulate:a", 0.0, FADE_OUT_SECONDS)
	(
		_fade
		. parallel()
		. tween_method(_set_rise, 0.0, RISE_PIXELS, FADE_OUT_SECONDS)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_QUAD)
	)
	_fade.tween_callback(_release_width)


# The credits were set outright: shows them at once, and clears the gain and the loss.
func _on_set() -> void:
	_pending = 0
	if _fade:
		_fade.kill()
	if _loss:
		_loss.kill()
	if is_node_ready():
		(%GainLabel as Label).modulate.a = 0.0
		(%LossLabel as Label).modulate.a = 0.0
		_show_total(ledger.credits)
		_release_width()


## [param value] with a comma between each group of three digits: 12,480.
static func group_digits(value: int) -> String:
	var digits := str(absi(value))
	var i := digits.length() - 3
	while i > 0:
		digits = digits.insert(i, ",")
		i -= 3
	return ("-" if value < 0 else "") + digits


func _show_total(value: int) -> void:
	_shown = value
	var label := %TotalLabel as Label
	var text := group_digits(value)
	if label.text != text:
		label.text = text


# Ends a spending under way at once: the total at its new value, the loss gone.
func _finish_loss() -> void:
	if not _loss or not _loss.is_running():
		return
	_loss.kill()
	(%LossLabel as Label).modulate.a = 0.0
	_show_total(ledger.credits - _pending)
	_release_width()


# Keeps the total as wide as [param value] shows, however few digits it shows meanwhile.
func _hold_width_for(value: int) -> void:
	var held := maxf(_text_width(group_digits(value)), _text_width(ROOM))
	(%TotalLabel as Label).custom_minimum_size.x = held


# Lets the total be as wide as what it shows, with room for ROOM at least.
func _release_width() -> void:
	(%TotalLabel as Label).custom_minimum_size.x = _text_width(ROOM)


func _text_width(text: String) -> float:
	var label := %TotalLabel as Label
	var font := label.get_theme_font(&"font")
	var font_size := label.get_theme_font_size(&"font_size")
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _set_loss_rise(value: float) -> void:
	_loss_rise = value
	_place_gain()


func _set_rise(value: float) -> void:
	_rise = value
	_place_gain()


# The gain floats centred under the total, GAIN_DROP below it, drifted up by _rise, and
# pops from its centre. The loss sits the same way in the gain's place, or under the gain
# while it shows. Neither takes room in the bar.
func _place_gain() -> void:
	var total := %TotalLabel as Label
	var slot := %GainSlot as Control
	slot.position = Vector2(0.0, total.size.y + GAIN_DROP)
	slot.size = Vector2(total.size.x, 0.0)
	var label := %GainLabel as Label
	var size_needed := label.get_combined_minimum_size()
	label.size = size_needed
	label.position = Vector2((slot.size.x - size_needed.x) * 0.5, -_rise)
	label.pivot_offset = size_needed * 0.5
	var loss := %LossLabel as Label
	var loss_size := loss.get_combined_minimum_size()
	loss.size = loss_size
	var below := size_needed.y if label.modulate.a > 0.0 else 0.0
	loss.position = Vector2((slot.size.x - loss_size.x) * 0.5, below - _loss_rise)
	loss.pivot_offset = loss_size * 0.5
