extends CPUParticles3D
## Smoke off the bus as it heats, and the red of overheating. From [constant SMOKE_FROM]
## degrees thin wisps puff up off its roof, thicker and more opaque as it nears overheating.
## Overheating sends a burst of smoke out all at once, and for the length of the cooldown
## the model pulses red and the smoke is thick, both fading as it cools; the smoke stops a
## little before the cooldown ends. The puffs are small, faceted and pale lilac grey; they
## rise, grow and fade, left behind in global space as the bus moves. Under Reduce motion
## the red holds steady rather than pulsing.

## Pulses of red a second.
const FLASH_RATE := 2.5
## How red the model gets at the top of a pulse and at its bottom, just after overheating.
const FLASH_HIGH := 0.55
const FLASH_LOW := 0.15
## Degrees from which smoke comes as the bus heats.
const SMOKE_FROM := 40.0
## How opaque and how big the smoke is at SMOKE_FROM, as a share of how it is overheated.
const THIN_SMOKE := 0.25
const THIN_SIZE := 0.5
## The share of the cooldown left below which no new smoke comes.
const SMOKE_UNTIL := 0.25
const SMOKE_COLOR := Color(0.74, 0.71, 0.82, 0.9)
## How many puffs the burst sends out on overheating.
const BURST_PUFFS := 28

@export var temperature: BusTemperature
@export var model: BusModel

var _time := 0.0
var _burst: CPUParticles3D


func _ready() -> void:
	local_coords = false
	emitting = false
	amount = 20
	lifetime = 1.8
	direction = Vector3.UP
	spread = 25.0
	gravity = Vector3(0.0, 0.12, 0.0)
	initial_velocity_min = 0.35
	initial_velocity_max = 0.6
	damping_min = 0.15
	damping_max = 0.3
	emission_shape = EMISSION_SHAPE_BOX
	emission_box_extents = Vector3(0.15, 0.03, 0.2)
	scale_amount_curve = _grow_curve()
	color_ramp = _fade_ramp()
	mesh = _puff()
	material_override = _material()
	cast_shadow = SHADOW_CASTING_SETTING_OFF
	_set_strength(1.0)
	_setup_burst()
	temperature.overheated.connect(_burst.restart)


func _process(delta: float) -> void:
	if temperature.is_cooling():
		var left := temperature.get_cooldown_left() / maxf(temperature.cooldown_time, 0.001)
		emitting = left > SMOKE_UNTIL
		_set_strength(1.0)
		_flash(delta, left)
		return
	_time = 0.0
	model.heat_glow = 0.0
	var heat := inverse_lerp(SMOKE_FROM, temperature.overheat_temperature, temperature.temperature)
	emitting = heat > 0.0
	if emitting:
		_set_strength(clampf(heat, 0.0, 1.0))


# Pulses the model red, by left, the share of the cooldown still to go.
func _flash(delta: float, left: float) -> void:
	_time += delta
	var pulse := 1.0
	if not Settings.reduce_motion:
		pulse = 0.5 + 0.5 * cos(TAU * FLASH_RATE * _time)
	model.heat_glow = lerpf(FLASH_LOW, FLASH_HIGH, pulse) * left


# How thick new puffs are, from 0 (thin wisps) to 1 (as when overheated).
func _set_strength(strength: float) -> void:
	color = Color(1.0, 1.0, 1.0, lerpf(THIN_SMOKE, 1.0, strength))
	var size := lerpf(THIN_SIZE, 1.0, strength)
	scale_amount_min = 0.7 * size
	scale_amount_max = 1.1 * size


# The burst on overheating: the same puffs, all at once, faster and wider.
func _setup_burst() -> void:
	_burst = CPUParticles3D.new()
	_burst.local_coords = false
	_burst.emitting = false
	_burst.one_shot = true
	_burst.explosiveness = 0.9
	_burst.amount = BURST_PUFFS
	_burst.lifetime = 2.2
	_burst.direction = Vector3.UP
	_burst.spread = 70.0
	_burst.gravity = Vector3(0.0, 0.1, 0.0)
	_burst.initial_velocity_min = 0.6
	_burst.initial_velocity_max = 1.2
	_burst.damping_min = 0.8
	_burst.damping_max = 1.2
	_burst.emission_shape = EMISSION_SHAPE_BOX
	_burst.emission_box_extents = Vector3(0.2, 0.05, 0.3)
	_burst.scale_amount_min = 0.9
	_burst.scale_amount_max = 1.4
	_burst.scale_amount_curve = scale_amount_curve
	_burst.color_ramp = color_ramp
	_burst.mesh = mesh
	_burst.material_override = material_override
	_burst.cast_shadow = SHADOW_CASTING_SETTING_OFF
	add_child(_burst)


func _puff() -> SphereMesh:
	var puff := SphereMesh.new()
	puff.radius = 0.13
	puff.height = 0.26
	puff.radial_segments = 8
	puff.rings = 4
	return puff


func _material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	return material


# Each puff grows to about three times its size as it rises.
func _grow_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.35))
	curve.add_point(Vector2(1.0, 1.0))
	return curve


# Each puff fades out as it rises.
func _fade_ramp() -> Gradient:
	var ramp := Gradient.new()
	var clear := SMOKE_COLOR
	clear.a = 0.0
	ramp.set_color(0, SMOKE_COLOR)
	ramp.set_color(1, clear)
	return ramp
