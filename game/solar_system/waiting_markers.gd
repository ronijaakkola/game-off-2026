class_name WaitingMarkers
extends Control
## Under each planet's name, a dot for each place in its line, filled for someone waiting
## ([WaitingPips]), while the bus has the waiting markers trait, so the player sees who
## waits where while planning a route. With the station cameras trait too, the pointer
## over a planet turns its dots into who waits there ([WaitingCard]): the dots fade out as
## the card opens, and back in as it closes. That shows the line, so it counts as the
## player seeing it ([method WaitingPassengers.get_waiting]). Without the cameras, the
## pointer resting on a planet opens a tooltip under its dots saying how many wait. It
## places itself after the planets and the camera have moved each frame, and hides with
## the planets the zoomed map hides.

## Pixels between a planet's name and its dots.
const GAP_PIXELS := 7.0
## After the solar system, which moves the planets after Phantom Camera's host (300) has
## moved the camera; placed any earlier, the dots trail the planets by a frame.
const PROCESS_PRIORITY := 302
const TOOLTIP := preload("res://ui/tooltip/tooltip.tscn")

## Who waits at each planet.
@export var waiting: WaitingPassengers:
	set(value):
		if waiting:
			waiting.changed.disconnect(_on_waiting_changed)
		waiting = value
		if waiting:
			waiting.changed.connect(_on_waiting_changed)
		for planet: Planet in _pips:
			_show_waiting(planet)
## The bus, whose traits turn the markers and the photos on.
@export var bus: FrameshiftBus
## The camera the planets are seen through.
@export var camera: Camera3D

## Where the photos are rendered.
var portrait_studio: PortraitStudio
## The planet under the pointer, whose line shows as photos with the station cameras
## trait, or else a tooltip with how many wait. The parent sets it every frame.
var hovered: Planet:
	set(value):
		if hovered == value:
			return
		hovered = value
		_rested = 0.0
		if _tooltip:
			_tooltip.close()

var _pips: Dictionary[Planet, WaitingPips] = {}
# Each planet's dots' fade, while one runs.
var _pip_fades: Dictionary[Planet, Tween] = {}
# Made in _ready(), so a scene freed before it enters the tree leaks none.
var _card: WaitingCard
# The planet whose line the card shows, or null while it shows none, and the planet it
# last showed, which it stays under while it closes.
var _card_planet: Planet
var _card_trail: Planet
# Made in _ready(), like the card.
var _tooltip: Tooltip
# Seconds the pointer has rested on the hovered planet.
var _rested := 0.0


func _ready() -> void:
	process_priority = PROCESS_PRIORITY
	_card = WaitingCard.new()
	add_child(_card)
	_tooltip = TOOLTIP.instantiate() as Tooltip
	_tooltip.side = Tooltip.Side.BELOW
	# It follows the dots as the planet moves: placed after them each frame, and not on
	# whole pixels, which would step behind them.
	_tooltip.snap_to_pixels = false
	_tooltip.process_priority = PROCESS_PRIORITY + 1
	add_child(_tooltip)


func _process(delta: float) -> void:
	var traits := bus.get_stats().get_traits() if bus else null
	var unlocked := traits != null and traits.has(BusTraits.Type.WAITING_MARKERS)
	var cameras := unlocked and traits.has(BusTraits.Type.STATION_CAMERAS)
	var card_at: Planet = hovered if cameras and count_at(hovered) > 0 else null
	if card_at != _card_planet:
		_switch_card(card_at)
	for planet: Planet in _pips:
		var at := _under_name(planet) if unlocked and modulate.a > 0.0 else Vector2.INF
		var pips := _pips[planet]
		pips.visible = at != Vector2.INF
		if pips.visible:
			pips.position = at - Vector2(pips.size.x * 0.5, 0.0)
		if planet == _card_trail and pips.visible:
			_card.position = at
	_show_tooltip(delta, unlocked and not cameras)


## Whether the tooltip with how many wait shows at [param planet].
func is_tooltip_shown(planet: Planet) -> bool:
	return planet != null and planet == hovered and _tooltip.visible


## The planets to show dots under. Replaces any from before.
func set_planets(planets: Array[Planet]) -> void:
	for pips: WaitingPips in _pips.values():
		pips.queue_free()
	_pips.clear()
	_pip_fades.clear()
	_card_planet = null
	_card_trail = null
	_card.close()
	for planet: Planet in planets:
		var pips := WaitingPips.new()
		add_child(pips)
		_pips[planet] = pips
		_show_waiting(planet)
	move_child(_card, -1)


## How many the dots under [param planet] say wait there.
func count_at(planet: Planet) -> int:
	var pips: WaitingPips = _pips.get(planet)
	return pips.count if pips else 0


## Whether the dots under [param planet] show.
func is_shown(planet: Planet) -> bool:
	var pips: WaitingPips = _pips.get(planet)
	return pips != null and pips.visible and pips.modulate.a > 0.0


## Whether [param planet]'s line shows as photos, or is opening to.
func is_card_shown(planet: Planet) -> bool:
	return planet != null and planet == _card_planet and _card.is_open()


# Just under [param planet]'s name on screen, or Vector2.INF where it can't be seen: behind
# the camera, or hidden on the zoomed map.
func _under_name(planet: Planet) -> Vector2:
	var center := planet.get_body_global_position()
	if not camera or not planet.is_visible_in_tree() or camera.is_position_behind(center):
		return Vector2.INF
	var bottom := camera.unproject_position(
		center - camera.global_basis.y * planet.get_body_radius()
	)
	return bottom + Vector2(0.0, SolarSystem.LABEL_PIXELS + GAP_PIXELS)


# Opens the card on who waits at [param planet], or closes it with null, crossfading with
# the dots. From one planet straight to another, the first one's dots come back at once.
# Asking for the line is seeing it.
func _switch_card(planet: Planet) -> void:
	var before := _card_planet
	_card_planet = planet
	if not planet:
		_card.close()
		if before:
			_fade_pips(before, 1.0, WaitingCard.OPEN_SECONDS)
		return
	if before:
		_fade_pips(before, 1.0, 0.0)
		_card.close()
	_card_trail = planet
	_card.show_line(waiting.get_waiting(planet), portrait_studio)
	_card.open()
	_fade_pips(planet, 0.0, WaitingCard.CLOSE_SECONDS)


# Opens the tooltip under the hovered planet's dots once the pointer has rested on it as
# long as any tooltip waits, while [param allowed], and closes it while the dots fade out.
func _show_tooltip(delta: float, allowed: bool) -> void:
	var pips: WaitingPips = _pips.get(hovered) if hovered and allowed else null
	if not pips or not pips.visible or modulate.a < 1.0:
		_rested = 0.0
		_tooltip.close()
		return
	var text := "%d waiting passenger%s" % [pips.count, "" if pips.count == 1 else "s"]
	if _tooltip.sentence != text:
		_tooltip.sentence = text
	_rested += delta
	if _rested >= _tooltip.rest_seconds:
		_tooltip.target = pips
		_tooltip.open()


func _fade_pips(planet: Planet, alpha: float, seconds: float) -> void:
	var pips: WaitingPips = _pips.get(planet)
	if not pips:
		return
	var fade: Tween = _pip_fades.get(planet)
	if fade:
		fade.kill()
	if seconds <= 0.0:
		pips.modulate.a = alpha
		return
	fade = pips.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade.tween_property(pips, ^"modulate:a", alpha, seconds)
	_pip_fades[planet] = fade


func _show_waiting(planet: Planet) -> void:
	var pips: WaitingPips = _pips.get(planet)
	if not pips:
		return
	pips.places = waiting.max_per_planet if waiting else pips.places
	pips.count = waiting.count_at(planet) if waiting else 0
	pips.reset_size()
	if planet == _card_planet and pips.count > 0:
		# Someone joined, left or boarded: the open card follows, with no motion.
		_card.show_line(waiting.get_waiting(planet), portrait_studio)


func _on_waiting_changed(planet: Planet) -> void:
	_show_waiting(planet)
