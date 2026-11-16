class_name RockScatter
## Scatters rocks through an [AsteroidBelt] into a [MultiMesh], so the whole field draws as
## one draw call per rock shape however many rocks it has. Rocks thin out over the band's
## edges and keep clear of its gaps, whose sides come out a little ragged. The band is
## thickest at its middle, like a lens seen side-on. Each rock gets its own size, turn, shade
## and tumble; the shader reads the shade from the instance colour and the tumble from the
## custom data.

## How far from the band's edges the rocks thin out to none, in units.
const EDGE_FADE := 0.6
## Up to how much further out from a gap's side than its size each rock stays, in units, so
## the sides are ragged rather than ruled.
const GAP_RAGGEDNESS := 0.25
## How many tries per rock before the scatter gives up, should the band be all gaps.
const TRIES_PER_ROCK := 20


## A MultiMesh of [param mesh] with [param count] rocks through [param belt], each from
## [param min_size] to [param max_size] across, at up to [param height] above or below the
## orbit plane, placed by [param rng].
static func scatter(
	belt: AsteroidBelt,
	mesh: Mesh,
	count: int,
	min_size: float,
	max_size: float,
	height: float,
	rng: RandomNumberGenerator
) -> MultiMesh:
	var placed: Array[Transform3D] = []
	var tries := count * TRIES_PER_ROCK
	while placed.size() < count and tries > 0:
		tries -= 1
		var size := lerpf(min_size, max_size, pow(rng.randf(), 2.0))
		var point := _random_point(belt, rng)
		if not _keeps(belt, point, size, rng):
			continue
		var middle := (belt.inner_radius + belt.outer_radius) * 0.5
		var half := (belt.outer_radius - belt.inner_radius) * 0.5
		var across := absf(Vector2(point.x, point.z).length() - middle) / half
		point.y = rng.randf_range(-1.0, 1.0) * height * sqrt(maxf(1.0 - across * across, 0.0))
		var stretch := Vector3(
			rng.randf_range(0.75, 1.25), rng.randf_range(0.6, 1.0), rng.randf_range(0.75, 1.25)
		)
		var basis := Basis(_random_axis(rng), rng.randf() * TAU).scaled(stretch * size)
		placed.append(Transform3D(basis, point))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = placed.size()
	for i: int in placed.size():
		multimesh.set_instance_transform(i, placed[i])
		var shade := rng.randf_range(0.82, 1.08)
		multimesh.set_instance_color(i, Color(shade, shade, shade))
		var axis := _random_axis(rng) * 0.5 + Vector3.ONE * 0.5
		multimesh.set_instance_custom_data(i, Color(axis.x, axis.y, axis.z, rng.randf()))
	return multimesh


# A point spread evenly over the band's area, on the orbit plane.
static func _random_point(belt: AsteroidBelt, rng: RandomNumberGenerator) -> Vector3:
	var inner := belt.inner_radius * belt.inner_radius
	var outer := belt.outer_radius * belt.outer_radius
	var distance := sqrt(lerpf(inner, outer, rng.randf()))
	var angle := rng.randf() * TAU
	return Vector3(cos(angle), 0.0, -sin(angle)) * distance


# Whether a rock [param size] across at [param point] stays: clear of the gaps, and less
# often the nearer it is to the band's edges.
static func _keeps(
	belt: AsteroidBelt, point: Vector3, size: float, rng: RandomNumberGenerator
) -> bool:
	var clear := size * 0.5 + rng.randf() * GAP_RAGGEDNESS
	if belt.is_in_gap(point, -clear):
		return false
	var distance := Vector2(point.x, point.z).length()
	var edge := minf(distance - belt.inner_radius, belt.outer_radius - distance)
	return rng.randf() < smoothstep(0.0, EDGE_FADE, edge)


static func _random_axis(rng: RandomNumberGenerator) -> Vector3:
	var axis := Vector3(rng.randfn(), rng.randfn(), rng.randfn())
	return axis.normalized() if axis.length() > 0.001 else Vector3.UP
