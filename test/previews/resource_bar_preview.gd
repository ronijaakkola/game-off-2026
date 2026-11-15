extends Node
## Resource bars stacked down the right edge over the solar system, for capturing that the
## bar keeps its width until a number gains a digit: the design's small to large values. The last
## four animate during the capture: a payment counts 990 up past 1,000, a refuel's bill
## counts 1,005 down past it, the debug panel's 1,000 credits count up from 0, and a busy
## stop holds two fares, two points and a rating while fuel is bought, then ends. The
## counts take about 1.7 s: capture it with --frames 110.

const BAR := preload("res://game/solar_system/resource_bar.tscn")
## Credits, research points (blue, orange, green), and the average rating or -1 for none.
const STILL_BARS: Array[Array] = [
	[40, [0, 0, 0], -1.0],
	[1240, [7, 4, 11], 4.2],
	[9999, [28, 96, 40], 5.0],
	[12480, [99, 99, 99], 4.8],
	[1250000, [99, 99, 99], 4.8],
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
	var busy := _add_bar(stack, 990, [3, 2, 1], 4.0)
	# At the top, where its chips are clear of the screen's edge.
	stack.move_child(busy, 0)
	paid.ledger.earn(15)
	busy.ledger.earn(100)
	busy.ledger.earn_research(Race.Type.BLUE)
	busy.ledger.rate(5.0)
	await get_tree().create_timer(MOVE_AT).timeout
	paid.commit()
	billed.ledger.spend(15)
	debug.ledger.earn(1000)
	debug.commit()
	busy.ledger.earn(50)
	busy.ledger.earn_research(Race.Type.BLUE)
	busy.ledger.spend(100)
	await get_tree().create_timer(MOVE_AT * 4.0).timeout
	busy.commit()


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
