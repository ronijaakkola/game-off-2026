class_name CreditsCounter
extends HBoxContainer
## The player's credits in the resource bar, beside a dollar sign: 12,480. It shows the
## credits of its [member ledger] and animates each change the ledger signals; it keeps no
## credits of its own. Payments collect in a gain, a [ChangeChip] under the bar ("+15"),
## which shows the new sum with each payment.
## Once [method commit] is called, after a short delay the gain slides back under the bar
## while the total counts up to include it, number by number, in the gain's colour. The
## ledger already counts every payment; only what shows waits.
## Spending shows the same way, in red ("-12"), at once, and adds up while it shows: after
## the same delay the loss slides back under the bar while the total counts down in red.
## It shows in the gain's place, or left of the gain while one waits; a commit meanwhile
## takes both in at once, the total counting to what is left. The total never jumps: it
## counts from what it shows. Credits set outright show at once and clear the gain and the
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
# What the total shows, which a count moves.
var _shown := 0
# The wait from commit() to the gain going into the total.
var _commit: Tween
# The wait from the last spending to the loss going into the total, and what the loss
# shows, which adds up spendings while it waits.
var _loss: Tween
var _loss_amount := 0
# The total counting to a new value, in the change's colour, and turning white again.
var _count: Tween


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
# new sum. The total shown waits for [method commit]; one waiting out its delay is put
# off to the next, so the gain goes in whole.
func _on_earned(amount: int) -> void:
	_pending += amount
	if _commit:
		_commit.kill()
	(%GainChip as ChangeChip).show_change("+%s" % group_digits(_pending), ChangeChip.GAIN_COLOR)


# A bill of [param amount], already in the ledger: it shows in the loss ("-12"), and after
# COMMIT_DELAY the loss leaves as the total counts down to it. While a loss still waits,
# it adds to it and the wait starts over. A gain still waiting for commit() stays.
func _on_spent(amount: int) -> void:
	if _loss and _loss.is_running():
		_loss.kill()
		_loss_amount += amount
	else:
		_loss_amount = amount
	(%LossChip as ChangeChip).show_change("-%s" % group_digits(_loss_amount), ChangeChip.LOSS_COLOR)
	_loss = create_tween()
	_loss.tween_interval(COMMIT_DELAY)
	_loss.tween_callback(_take_in_loss)


## Moves the gain into the total: after [constant COMMIT_DELAY], the gain slides back
## under the bar while the total counts up one credit at a time. A loss still waiting
## goes in with it. Nothing happens without a gain.
func commit() -> void:
	if _pending == 0:
		return
	if _commit:
		_commit.kill()
	_commit = create_tween()
	_commit.tween_interval(COMMIT_DELAY)
	_commit.tween_callback(_take_in_gain)


## The total, for something that points it out.
func get_total_label() -> Control:
	return %TotalLabel


# The credits were set outright: shows them at once, and clears the gain and the loss.
func _on_set() -> void:
	_pending = 0
	for tween: Tween in [_commit, _loss, _count]:
		if tween:
			tween.kill()
	if is_node_ready():
		(%GainChip as ChangeChip).hide_now()
		(%LossChip as ChangeChip).hide_now()
		(%TotalLabel as Label).self_modulate = Color.WHITE
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
	_shown = value
	var label := %TotalLabel as Label
	var text := format_credits(value)
	if label.text != text:
		label.text = text


# The gain goes into the total, and with it a loss still waiting.
func _take_in_gain() -> void:
	_pending = 0
	if _loss:
		_loss.kill()
	(%GainChip as ChangeChip).leave()
	(%LossChip as ChangeChip).leave()
	_count_to(ledger.credits)


# The loss goes into the total. A gain still waiting stays out of it.
func _take_in_loss() -> void:
	(%LossChip as ChangeChip).leave()
	_count_to(ledger.credits - _pending)


# Counts the total from what it shows to [param value], one credit at a time, green on
# the way up and red on the way down, then turns it white again. A count under way goes
# on from where it is.
func _count_to(value: int) -> void:
	if _count:
		_count.kill()
	var label := %TotalLabel as Label
	if value != _shown:
		label.self_modulate = (ChangeChip.GAIN_COLOR if value > _shown else ChangeChip.LOSS_COLOR)
	var seconds := minf(absi(value - _shown) * SECONDS_PER_CREDIT, MAX_COUNT_SECONDS)
	_count = create_tween()
	_count.tween_method(_show_total, _shown, value, seconds)
	_count.tween_property(label, ^"self_modulate", Color.WHITE, TINT_OUT_SECONDS)
