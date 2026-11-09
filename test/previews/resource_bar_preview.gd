extends Node
## Resource bars stacked down the right edge over the solar system, for capturing how the
## bar's width follows its numbers: at the start of a game, either side of each step up in
## digits, the design's values, and big ones. The last three animate across steps during the
## capture: a payment counts 990 up past 1,000, a refuel's bill counts 1,005 down past it,
## and the debug panel's 1,000 credits count up from 0 past three steps, the pill gliding to
## each new width. The last takes about 1.7 s: capture it with --frames 120.

const BAR := preload("res://game/solar_system/resource_bar.tscn")
## Credits, research points (blue, orange, green), and the average rating or -1 for none.
const STILL_BARS: Array[Array] = [
	[0, [0, 0, 0], -1.0],
	[999, [9, 9, 9], 4.6],
	[1000, [10, 10, 10], 4.6],
	[12480, [34, 21, 8], 4.6],
	[100000, [120, 45, 9], 5.0],
]
## Seconds into the capture when the payment commits and the bill is paid.
const MOVE_AT := 0.1


func _ready() -> void:
	var stack := %Bars as VBoxContainer
	for values: Array in STILL_BARS:
		_add_bar(stack, values[0], values[1], values[2])
	var paid := _add_bar(stack, 990, [3, 2, 1], 4.0)
	var billed := _add_bar(stack, 1005, [3, 2, 1], 4.0)
	var debug := _add_bar(stack, 0, [3, 2, 1], 4.0)
	paid.ledger.earn(15)
	await get_tree().create_timer(MOVE_AT).timeout
	paid.commit()
	billed.ledger.spend(15)
	debug.ledger.earn(1000)
	debug.commit()


func _add_bar(stack: VBoxContainer, credits: int, research: Array, rating: float) -> ResourceBar:
	var ledger := Ledger.new()
	ledger.credits = credits
	for i: int in research.size():
		if research[i] > 0:
			ledger.earn_research(Race.Type.values()[i] as Race.Type, research[i])
	if rating >= 0.0:
		ledger.rate(rating)
	var bar := BAR.instantiate() as ResourceBar
	bar.size_flags_horizontal = Control.SIZE_SHRINK_END
	bar.ledger = ledger
	stack.add_child(bar)
	return bar
