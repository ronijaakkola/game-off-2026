class_name PhaseField
extends RefCounted
## The rules of the Phase Miner prototype, with no nodes: an 8×8 asteroid field that wraps
## at its edges, the ship on one cell, and the ship's fuel, hull, score and combo.
## [br][br]
## A [b]slide[/b] moves one row or column by whole cells, wrapping, and carries the ship
## along when it sits on that line. It costs 1 fuel per cell.
## A [b]phase[/b] sends the ship in a straight line: it cruises over empty cells to the first
## item, destroys every item in the run that follows, and stops on the first empty cell after
## it. It costs 1 fuel. A line with nothing on it can't be phased.

enum Item { NONE, ROCK, FUEL, CRYSTAL, SCRAP }

const SIZE := 8
const HALF := 4
const START_FUEL := 25
const TANK := 25
const START_HULL := 4
const FUEL_ORE := 3
const PHASE_COST := 1
## Points for each item destroyed. A rock is worth nothing and costs 1 hull.
const POINTS := {Item.ROCK: 0, Item.FUEL: 5, Item.CRYSTAL: 50, Item.SCRAP: 20}
## Points per combo step, paid on each clean phase from the second one in a row.
const COMBO_POINTS := 10
## How often each cell starts as each item. From the 2D prototype.
const WEIGHTS := {Item.NONE: 31, Item.ROCK: 40, Item.FUEL: 5, Item.CRYSTAL: 6, Item.SCRAP: 12}

var fuel := START_FUEL
var hull := START_HULL
var score := 0
## Clean phases in a row: each one destroyed items and hit no rock, with no slide between.
var combo := 0
var best_combo := 0
## The ship's cell: x is the column, y the row. Row 0 is the far edge of the board.
var ship := Vector2i.ZERO
## The direction the ship last moved in, one of the four unit vectors.
var heading := Vector2i.UP

var _cells: Array[int] = []


func _init() -> void:
	_cells.resize(SIZE * SIZE)
	_cells.fill(Item.NONE)


## Fills the field with a fresh random asteroid field around [member ship], keeping the run's
## fuel, hull and score. Every row and column keeps an empty cell besides the ship's, so every
## phase has somewhere to stop.
func generate(rng: RandomNumberGenerator) -> void:
	var total := 0
	for weight: int in WEIGHTS.values():
		total += weight
	for i: int in _cells.size():
		var roll := rng.randi_range(0, total - 1)
		for item: int in WEIGHTS:
			roll -= WEIGHTS[item]
			if roll < 0:
				_cells[i] = item
				break
	set_item(ship, Item.NONE)
	for line: int in SIZE:
		_open_a_cell(_row_cells(line), rng)
		_open_a_cell(_column_cells(line), rng)
	combo = 0


## Starts a new run: full fuel and hull, no score, the ship in the middle, a fresh field.
func reset(rng: RandomNumberGenerator) -> void:
	fuel = START_FUEL
	hull = START_HULL
	score = 0
	combo = 0
	best_combo = 0
	ship = Vector2i(HALF, HALF)
	heading = Vector2i.UP
	generate(rng)


func get_item(cell: Vector2i) -> Item:
	return _cells[_index(cell)] as Item


func set_item(cell: Vector2i, item: Item) -> void:
	_cells[_index(cell)] = item


## Whether the run has ended: the hull is gone, or there's no fuel left to slide or phase.
func is_over() -> bool:
	return hull <= 0 or fuel <= 0


## Whether anything worth mining is left: fuel ore, crystals or scrap. Rocks don't count.
func has_loot() -> bool:
	for item: int in _cells:
		if item != Item.NONE and item != Item.ROCK:
			return true
	return false


## Slides row [param line] by [param cells] (positive is right) or, when [param is_row] is
## false, column [param line] by [param cells] (positive is down). Returns false and changes
## nothing when it moves nothing or costs more fuel than is left.
func slide(is_row: bool, line: int, cells: int) -> bool:
	var steps := _shortest(cells)
	if steps == 0 or absi(steps) > fuel or is_over():
		return false
	var line_cells := _row_cells(line) if is_row else _column_cells(line)
	var items: Array[int] = []
	for cell: Vector2i in line_cells:
		items.append(get_item(cell))
	for i: int in SIZE:
		set_item(line_cells[posmod(i + steps, SIZE)], items[i] as Item)
	var direction := Vector2i.RIGHT if is_row else Vector2i.DOWN
	if (is_row and ship.y == line) or (not is_row and ship.x == line):
		ship = wrap_cell(ship + direction * steps)
		heading = direction * signi(steps)
	fuel -= absi(steps)
	combo = 0
	return true


## The cells a phase in [param direction] would pass through, in order, ending on the cell
## the ship stops on. Empty when the line holds nothing to destroy. Changes nothing.
func plan_phase(direction: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var cell := ship
	var reached_items := false
	for i: int in SIZE:
		cell = wrap_cell(cell + direction)
		path.append(cell)
		if cell == ship:
			break
		var item := get_item(cell)
		if item != Item.NONE:
			reached_items = true
		elif reached_items:
			break
	if not reached_items:
		path.clear()
	return path


## Phases in [param direction] and applies what it hits. Returns each cell the ship passed
## through as [code]{"cell": Vector2i, "item": Item}[/code], in order, with the item it
## destroyed there ([constant Item.NONE] for empty space). The last entry is where the ship
## stopped. Empty when the phase can't happen: an empty line, no fuel, or the run is over.
func phase(direction: Vector2i) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	var path := plan_phase(direction)
	if path.is_empty() or fuel < PHASE_COST or is_over():
		return steps
	fuel -= PHASE_COST
	heading = direction
	var hit_rock := false
	var destroyed := 0
	for cell: Vector2i in path:
		var item := get_item(cell)
		steps.append({"cell": cell, "item": item})
		ship = cell
		if item == Item.NONE:
			continue
		set_item(cell, Item.NONE)
		destroyed += 1
		score += POINTS[item]
		match item:
			Item.ROCK:
				hull -= 1
				hit_rock = true
			Item.FUEL:
				fuel = mini(TANK, fuel + FUEL_ORE)
		if hull <= 0:
			break
	if hit_rock:
		combo = 0
	elif destroyed > 0:
		combo += 1
		best_combo = maxi(best_combo, combo)
		if combo >= 2:
			score += combo * COMBO_POINTS
	return steps


## [param cell] moved back onto the field, wrapping round its edges.
static func wrap_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(posmod(cell.x, SIZE), posmod(cell.y, SIZE))


func _index(cell: Vector2i) -> int:
	var wrapped := wrap_cell(cell)
	return wrapped.y * SIZE + wrapped.x


func _row_cells(row: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for column: int in SIZE:
		cells.append(Vector2i(column, row))
	return cells


func _column_cells(column: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for row: int in SIZE:
		cells.append(Vector2i(column, row))
	return cells


# Empties one random cell of the line, other than the ship's, unless it already has one.
func _open_a_cell(cells: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	var options: Array[Vector2i] = []
	for cell: Vector2i in cells:
		if cell == ship:
			continue
		if get_item(cell) == Item.NONE:
			return
		options.append(cell)
	set_item(options[rng.randi_range(0, options.size() - 1)], Item.NONE)


# The same slide the short way round: 7 cells right is 1 cell left.
func _shortest(cells: int) -> int:
	var steps := posmod(cells, SIZE)
	return steps - SIZE if steps > HALF else steps
