class_name CreditsCounter
extends HBoxContainer
## The player's credits in the resource bar, beside a dollar sign: 12,480. It shows the
## credits of its [member ledger] and animates each change the ledger signals; it keeps no
## credits of its own. Payments collect in a gain, a [ChangeChip] under the bar ("+15"),
## which shows the new sum with each payment.
## Once [method commit] is called, after a short delay the gain slides back under the bar
## while the total counts up to include it, number by number, in the gain's colour. The
## ledger already counts every payment; only what shows waits.
## Spending shows the same way, in red ("-12"), at once: after a short delay the total
## counts down in red, and the loss leaves [constant ChangeChip.SPENT_SECONDS] after the
## last spending. It shows in the gain's place, or left of
## the gain while one waits. Credits set outright show at once and clear the gain and the
## loss.
## The total sits right-aligned in a slot with room for three digits, so the resource bar
## keeps its width while the credits stay under 1,000 and glides to fit a longer number:
## exact up to 9,999, then shortened to 12.4k, 125k or 1.25M.

## Seconds from [method commit], or from a spending, to the total starting to count.
const COMMIT_DELAY := ChangeChip.HOLD_SECONDS
## Seconds the total takes to count per credit, and the most it takes in all.
const SECONDS_PER_CREDIT := 0.025
const MAX_COUNT_SECONDS := 0.6
## Seconds the total takes to turn white again once it has counted.
const TINT_OUT_SECONDS := 0.2
## The most credits shown exactly; more are shortened.
const MAX_EXACT := 9999

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
# The commit: the delay, then the gain leaving as the total counts up.
var _fade: Tween
# The spending: the delay, the count down, then the loss leaving.
var _loss: Tween
# What the loss shows, which adds up spendings while it shows, and the total shown before
# the first of them.
var _loss_amount := 0
var _loss_from := 0


func _ready() -> void:
	var gain := %GainChip as ChangeChip
	var loss := %LossChip as ChangeChip
	gain.target = %TotalLabel
	loss.target = %TotalLabel
	gain.row = self
	loss.row = self
	loss.beside = gain
	if not ledger:
		ledger = Ledger.new()
	_on_set()


# A payment of [param amount], already in the ledger: it joins the gain, which shows the
# new sum. The total shown waits for [method commit].
func _on_earned(amount: int) -> void:
	_pending += amount
	# A commit or a spending still under way finishes at once, so the total stays right.
	_end_count()
	_finish_loss()
	_show_total(ledger.credits - _pending)
	(%GainChip as ChangeChip).show_change("+%s" % group_digits(_pending), ChangeChip.GAIN_COLOR)


# A bill of [param amount], already in the ledger: it shows in the loss ("-12"); after
# COMMIT_DELAY the total counts down to it, and the loss leaves SPENT_SECONDS after it
# showed, however long the count took. While a loss still
# shows, it adds to it, and the count down starts over from where it began. A count up
# under way finishes at once first; a gain still waiting for commit() stays.
func _on_spent(amount: int) -> void:
	if _fade and _fade.is_running():
		_end_count()
		(%GainChip as ChangeChip).hide_now()
	var chip := %LossChip as ChangeChip
	if _loss and _loss.is_running():
		_loss.kill()
		_loss_amount += amount
	else:
		_loss_amount = amount
		_loss_from = ledger.credits + amount - _pending
	chip.show_change("-%s" % group_digits(_loss_amount), ChangeChip.LOSS_COLOR)
	var seconds := minf(_loss_amount * SECONDS_PER_CREDIT, MAX_COUNT_SECONDS)
	_loss = create_tween()
	_loss.tween_interval(COMMIT_DELAY)
	_loss.tween_callback(_tint.bind(ChangeChip.LOSS_COLOR))
	_loss.tween_method(_show_total, _loss_from, ledger.credits - _pending, seconds)
	_loss.tween_property(%TotalLabel, ^"self_modulate", Color.WHITE, TINT_OUT_SECONDS)
	var left := ChangeChip.SPENT_SECONDS - COMMIT_DELAY - seconds
	_loss.parallel().tween_callback(chip.leave).set_delay(maxf(left, 0.0))


## Moves the gain into the total: after [constant COMMIT_DELAY], the gain slides back
## under the bar while the total counts up one credit at a time. Nothing happens without
## a gain.
func commit() -> void:
	if _pending == 0:
		return
	_finish_loss()
	var from := ledger.credits - _pending
	var seconds := minf(_pending * SECONDS_PER_CREDIT, MAX_COUNT_SECONDS)
	_pending = 0
	_end_count()
	_fade = create_tween()
	_fade.tween_interval(COMMIT_DELAY)
	_fade.tween_callback((%GainChip as ChangeChip).leave)
	_fade.tween_callback(_tint.bind(ChangeChip.GAIN_COLOR))
	_fade.tween_method(_show_total, from, ledger.credits, seconds)
	_fade.tween_property(%TotalLabel, ^"self_modulate", Color.WHITE, TINT_OUT_SECONDS)


## The total, for something that points it out.
func get_total_label() -> Control:
	return %TotalLabel


# The credits were set outright: shows them at once, and clears the gain and the loss.
func _on_set() -> void:
	_pending = 0
	_end_count()
	if _loss:
		_loss.kill()
	if is_node_ready():
		(%GainChip as ChangeChip).hide_now()
		(%LossChip as ChangeChip).hide_now()
		_show_total(ledger.credits)


## [param value] with a comma between each group of three digits: 12,480.
static func group_digits(value: int) -> String:
	var digits := str(absi(value))
	var i := digits.length() - 3
	while i > 0:
		digits = digits.insert(i, ",")
		i -= 3
	return ("-" if value < 0 else "") + digits


## [param value] as the total shows it: exact up to [constant MAX_EXACT], then three digits
## and a unit, rounded down: 12.4k, 125k, 1.25M.
static func format_credits(value: int) -> String:
	var amount := absi(value)
	if amount <= MAX_EXACT:
		return group_digits(value)
	var unit := "k" if amount < 1_000_000 else "M"
	var unit_digits := 3 if unit == "k" else 6
	var digits := str(amount)
	var whole := digits.length() - unit_digits
	var text := digits.left(whole)
	if whole < 3:
		text += "." + digits.substr(whole, 3 - whole)
	return ("-" if value < 0 else "") + text + unit


func _show_total(value: int) -> void:
	var label := %TotalLabel as Label
	var text := format_credits(value)
	if label.text != text:
		label.text = text


# Turns the total [param color] while it counts.
func _tint(color: Color) -> void:
	(%TotalLabel as Label).self_modulate = color


# Ends a commit under way at once, the total white again. What the total shows is for
# whoever ends it to set.
func _end_count() -> void:
	if _fade:
		_fade.kill()
	if is_node_ready():
		(%TotalLabel as Label).self_modulate = Color.WHITE


# Ends a spending under way at once: the total at its new value, the loss gone.
func _finish_loss() -> void:
	if not _loss or not _loss.is_running():
		return
	_loss.kill()
	(%LossChip as ChangeChip).hide_now()
	(%TotalLabel as Label).self_modulate = Color.WHITE
	_show_total(ledger.credits - _pending)
