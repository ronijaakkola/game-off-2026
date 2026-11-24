class_name CapsuleField
extends Node3D
## The capsules adrift in the star system the bus works in ([Capsule]). Once the run proper
## starts, a new one appears every [member min_interval] to [member max_interval] seconds
## while fewer than [member max_capsules] drift, somewhere open: between the heat zone and
## the edge the camera stops at, clear of the planets and away from the bus. Each drifts
## for [member lifetime] seconds and is gone uncollected.
## Every capsule looks alike, and what it holds is rolled as the bus collects it: the
## [Castaway] by [method get_castaway_chance], which climbs with every capsule that held
## someone else ([member castaway_misses]) until it is certain, else credits or research
## points, as likely one as the other. The castaway needs a free seat and can't be on board
## already; without one, the roll is between the other two, and counts as a miss. Credits
## and research points go into the ledger at once, by the star system
## ([constant REWARD_CREDITS], [constant REWARD_RESEARCH]). On board, the castaway calls
## with a [RescueQuest] ([method QuestGiver.rescue]). The debug panel's capsules hold what
## they say, the castaway only when they can board, and roll nothing.
## Capsules aren't stops: a right click on one sets a point in space where it is, as on
## empty space. None appear while the bus jumps, and a new system starts with none.

## What a capsule of credits and one of research points hold in each star system, in the
## order they open: about half of what a fly past pays.
const REWARD_CREDITS: Array[int] = [50, 115, 230]
const REWARD_RESEARCH: Array[int] = [1, 2, 3]
## Units clear of the heat zone's edge, and inside the edge the camera stops at, that a
## capsule appears.
const ZONE_MARGIN := 1.5
const EDGE_MARGIN := 1.0
## Units clear of a planet's surface, and from the bus, that a capsule appears.
const PLANET_CLEARANCE := 1.5
const BUS_CLEARANCE := 5.0
## How many places a new capsule tries before it waits for the next roll.
const PLACE_TRIES := 12
## How far ahead of the bus the debug panel puts a capsule when no place is open.
const DEBUG_AHEAD := 2.5
const DEBUG_GROUP := "Capsules"
const DOLLAR_ICON := preload("res://shared/icons/dollar_sign.svg")
const RESEARCH_ICON := preload("res://shared/icons/flask_conical.svg")
const RESCUED_ICON := preload("res://shared/icons/circle_check.svg")

## Whether new capsules appear. Those adrift stay either way.
@export var enabled := true
@export_range(0, 10) var max_capsules := 2
## Seconds between one capsule appearing and the next, a random value between the two.
@export_range(1.0, 600.0, 1.0) var min_interval := 40.0
@export_range(1.0, 600.0, 1.0) var max_interval := 70.0
## Seconds a capsule drifts before it is gone uncollected.
@export_range(5.0, 600.0, 1.0) var lifetime := 90.0
## Units a second a capsule drifts: a fraction of the slowest planet.
@export_range(0.0, 2.0, 0.01) var drift_speed := 0.05
## How likely a capsule is to hold the castaway, and how much likelier each capsule that
## held something else makes the next: certain by the seventh.
@export_range(0.0, 1.0, 0.01) var passenger_chance := 0.1
@export_range(0.0, 1.0, 0.01) var pity_step := 0.15
@export var bus: FrameshiftBus
@export var cabin: Cabin
@export var star_map: StarMap
## Decides who a stranded passenger is.
@export var waiting: WaitingPassengers
## Has a stranded passenger call with their quest.
@export var quest_giver: QuestGiver
## Stamps what a capsule held over the bus.
@export var quick_text: BusQuickText
@export var system_jump: SystemJump
## Has the resource bars take a capsule's credits or research points in at once, rather than
## at the next stop as a fare's.
@export var research_lab: ResearchLab

## Capsules collected since the castaway was last in one, which make the next likelier to
## hold them. Kept with the run.
var castaway_misses := 0

var _ledger: Ledger
# Which star system the bus works in, counted from 0 in the order they open: capsules pay
# by it.
var _level := 0
var _started := false
var _until_next := 0.0
var _capsules: Array[Capsule] = []
# Made once it is in the tree: a scene stores every member of a node another node exports.
var _rng: RandomNumberGenerator


func _ready() -> void:
	if not _rng:
		_rng = RandomNumberGenerator.new()
	DebugPanel.add_button(
		"Credits capsule", _debug_spawn.bind(Capsule.Contents.CREDITS), self, DEBUG_GROUP
	)
	DebugPanel.add_button(
		"Research capsule", _debug_spawn.bind(Capsule.Contents.RESEARCH), self, DEBUG_GROUP
	)
	DebugPanel.add_button(
		"Passenger capsule", _debug_spawn.bind(Capsule.Contents.PASSENGER), self, DEBUG_GROUP
	)


func _process(delta: float) -> void:
	if not _started or not bus or (system_jump and system_jump.is_jumping()):
		return
	var star := _get_system().global_position
	for capsule: Capsule in _capsules.duplicate():
		capsule.light_source = star
		if capsule.is_gone():
			_remove(capsule)
		elif _is_touching(capsule):
			_collect(capsule)
	if not enabled or _capsules.size() >= max_capsules:
		return
	_until_next -= delta
	if _until_next > 0.0:
		return
	_until_next = _interval()
	var at: Variant = _find_place()
	if at != null:
		spawn(at, Capsule.Contents.UNDECIDED)


## Starts capsules in the star system the bus works in, paying into [param ledger] by
## [param level], counted from 0 in the order the systems open. Those adrift go.
func start(ledger: Ledger, level := 0) -> void:
	_ledger = ledger
	_level = level
	clear()
	_started = true
	_until_next = _interval()


## Makes the dice repeatable.
func seed_dice(value: int) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = value


## The capsules adrift.
func get_capsules() -> Array[Capsule]:
	return _capsules.duplicate()


## Takes every capsule away.
func clear() -> void:
	for capsule: Capsule in _capsules.duplicate():
		_remove(capsule)


## How likely the next capsule collected is to hold the castaway, when they can board.
func get_castaway_chance() -> float:
	var chance := passenger_chance + pity_step * castaway_misses
	# Within a rounding error of certain is certain: 0.1 + 6 × 0.15 comes out under 1.
	return 1.0 if chance > 0.999 else chance


## Puts a capsule at [param at] on the orbit plane, drifting, holding [param contents]:
## [constant Capsule.Contents.UNDECIDED] rolls as it is collected.
func spawn(at: Vector3, contents: Capsule.Contents) -> Capsule:
	var capsule := Capsule.new()
	capsule.contents = contents
	capsule.seconds_left = lifetime
	var angle := _rng.randf() * TAU
	capsule.velocity = Vector3(cos(angle), 0.0, sin(angle)) * drift_speed
	capsule.pick_tumble(_rng)
	capsule.light_source = _get_system().global_position
	add_child(capsule)
	capsule.global_position = Vector3(at.x, 0.0, at.z)
	_capsules.append(capsule)
	return capsule


func _remove(capsule: Capsule) -> void:
	_capsules.erase(capsule)
	capsule.queue_free()


func _is_touching(capsule: Capsule) -> bool:
	var at := Vector3(bus.global_position.x, 0.0, bus.global_position.z)
	return at.distance_to(capsule.get_flat_position()) < FrameshiftBus.RADIUS + Capsule.RADIUS


# Collects [param capsule]: what it holds goes to the player.
func _collect(capsule: Capsule) -> void:
	var at := capsule.get_flat_position()
	var contents := _open(capsule)
	_remove(capsule)
	match contents:
		Capsule.Contents.PASSENGER:
			var passenger := waiting.create_adrift(at)
			if passenger and cabin.board(passenger):
				castaway_misses = 0
				if quest_giver:
					quest_giver.rescue(passenger)
				_stamp("Rescued %s!" % passenger.name, RESCUED_ICON, BusQuickText.Kind.GAIN)
			else:
				_pay_credits()
		Capsule.Contents.RESEARCH:
			var points := _reward(REWARD_RESEARCH)
			if _ledger:
				_ledger.earn_research(points)
			_show_earnings()
			_stamp("+%d research" % points, RESEARCH_ICON, BusQuickText.Kind.GAIN)
		_:
			_pay_credits()


# What [param capsule] turns out to hold: rolled now unless the debug panel set it, and never
# the castaway when they can't board. A debug capsule of theirs then holds credits.
func _open(capsule: Capsule) -> Capsule.Contents:
	var can_rescue := cabin.has_free_seat() and not _is_castaway_aboard()
	var contents := capsule.contents
	if contents == Capsule.Contents.UNDECIDED:
		return _roll(can_rescue)
	if contents == Capsule.Contents.PASSENGER and not can_rescue:
		return Capsule.Contents.CREDITS
	return contents


# The castaway by [method get_castaway_chance] when [param can_rescue], else credits or
# research points, which count as a miss.
func _roll(can_rescue: bool) -> Capsule.Contents:
	if can_rescue and _rng.randf() < get_castaway_chance():
		return Capsule.Contents.PASSENGER
	castaway_misses += 1
	return Capsule.Contents.CREDITS if _rng.randf() < 0.5 else Capsule.Contents.RESEARCH


func _pay_credits() -> void:
	var credits := _reward(REWARD_CREDITS)
	if _ledger:
		_ledger.earn(credits)
	_show_earnings()
	_stamp("+%d" % credits, DOLLAR_ICON, BusQuickText.Kind.GAIN)


# The resource bars count what was just earned into their totals now, wherever the bus is.
func _show_earnings() -> void:
	if research_lab:
		research_lab.commit()


func _is_castaway_aboard() -> bool:
	return cabin.get_passengers().any(Castaway.is_castaway)


func _stamp(text: String, icon: Texture2D, kind: BusQuickText.Kind) -> void:
	if quick_text:
		quick_text.show_text(text, icon, kind)


func _reward(by_level: Array[int]) -> int:
	return by_level[mini(_level, by_level.size() - 1)]


# Somewhere open in the bus's star system for a new capsule, or null when no try finds one.
func _find_place() -> Variant:
	var system := _get_system()
	var centre := system.global_position
	var inner := system.zone_radius + ZONE_MARGIN
	var outer := maxf(system.bounds_radius - EDGE_MARGIN, inner)
	for i: int in PLACE_TRIES:
		var angle := _rng.randf() * TAU
		# Even over the ring's area, not crowded toward its middle.
		var radius := sqrt(_rng.randf_range(inner * inner, outer * outer))
		var at := Vector3(centre.x + cos(angle) * radius, 0.0, centre.z + sin(angle) * radius)
		if _is_open(at, system):
			return at
	return null


func _is_open(at: Vector3, system: StarSystem) -> bool:
	var from_bus := Vector3(bus.global_position.x, 0.0, bus.global_position.z)
	if at.distance_to(from_bus) < BUS_CLEARANCE:
		return false
	for planet: Planet in system.get_planets():
		var body := planet.get_body_global_position()
		var flat := Vector3(body.x, 0.0, body.z)
		if at.distance_to(flat) < planet.get_body_radius() + PLANET_CLEARANCE:
			return false
	return true


# The star system the bus works in, or once they are joined, the one nearest it.
func _get_system() -> StarSystem:
	if star_map.is_joined():
		return star_map.get_nearest_system(bus.global_position)
	return star_map.get_current()


func _interval() -> float:
	return _rng.randf_range(min_interval, maxf(min_interval, max_interval))


# A capsule holding [param contents] somewhere open, as one appearing by itself would be,
# or just ahead of the bus when no place is open. It may go past [member max_capsules].
func _debug_spawn(contents: Capsule.Contents) -> void:
	if not bus or not star_map:
		return
	_started = true
	var at: Variant = _find_place()
	if at == null:
		var ahead := -bus.global_basis.z
		ahead = Vector3(ahead.x, 0.0, ahead.z).normalized()
		if ahead == Vector3.ZERO:
			ahead = Vector3.FORWARD
		at = bus.global_position + ahead * DEBUG_AHEAD
	spawn(at, contents)
