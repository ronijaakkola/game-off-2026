extends Node3D
## Smoke rising off [member planet] in a few thin plumes, as from fires still burning on
## an abandoned world. It keeps at the planet's body as it orbits and takes its size, so
## the plumes stay on its surface on any map. The puffs are small unshaded balls that
## swell and shrink away, with no transparency, so they sit in the flat look. It builds
## its plumes in code, so the scene saves only its exports.

## Where each plume rises from, as a direction from the body's centre. Toward the camera's
## side of the body (up and +Z), so they show.
const PLUMES: Array[Vector3] = [
	Vector3(0.5, 0.75, 0.45),
	Vector3(-0.65, 0.6, 0.45),
	Vector3(-0.1, 0.35, 0.93),
]
## A puff's radius, how fast it rises and how long it lasts, with the body's radius as 1.
const PUFF_RADIUS := 0.16
const RISE_SPEED := 0.38
const LIFETIME := 4.0
const PUFFS := 9

## The planet it rises from.
@export var planet: Planet
## The puffs' one flat colour.
@export var color := Color(0.5, 0.42, 0.45)


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	var puff := SphereMesh.new()
	puff.radius = PUFF_RADIUS
	puff.height = PUFF_RADIUS * 2.0
	puff.radial_segments = 10
	puff.rings = 5
	puff.material = material
	# Each puff swells as it leaves the surface, then shrinks away.
	var swell := Curve.new()
	swell.add_point(Vector2(0.0, 0.25))
	swell.add_point(Vector2(0.6, 1.0))
	swell.add_point(Vector2(1.0, 0.0))
	for direction: Vector3 in PLUMES:
		var plume := CPUParticles3D.new()
		plume.mesh = puff
		plume.position = direction.normalized()
		# Leaning up, so the plumes drift the same way once clear of the surface.
		plume.direction = (direction.normalized() + Vector3.UP * 0.6).normalized()
		plume.spread = 10.0
		plume.gravity = Vector3.ZERO
		plume.initial_velocity_min = RISE_SPEED * 0.7
		plume.initial_velocity_max = RISE_SPEED
		plume.amount = PUFFS
		plume.lifetime = LIFETIME
		plume.preprocess = LIFETIME
		plume.scale_amount_min = 0.6
		plume.scale_amount_curve = swell
		# With the body, so a plume rises straight however fast the planet moves.
		plume.local_coords = true
		plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(plume, false, Node.INTERNAL_MODE_FRONT)


func _process(_delta: float) -> void:
	if not planet:
		return
	global_position = planet.get_body_global_position()
	scale = Vector3.ONE * planet.get_body_radius() / planet.get_world_scale()
