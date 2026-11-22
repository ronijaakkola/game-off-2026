class_name RockScatter
## Scatters rocks through an [AsteroidBelt] into a [MultiMesh], so the whole field draws as
## one draw call per rock shape however many rocks it has. Rocks thin out over the band's
## edges and keep clear of its gaps, whose sides come out a little ragged. The band is
## thickest at its middle, like a lens seen side-on. Each rock gets its own size, turn, shade
## and tumble; the shader reads the shade from the instance colour and the tumble from the
## custom data.
##
## Scattered at random, the rocks leave open spots that look like a way through and aren't.
## Asked to, the scatter plugs them: wherever a circle wider than a given size fits between
## the rocks, clear of the gaps, it puts one more rock, sized to fill it. So the only places
## that look open are the gaps.

## How far from the band's edges the rocks thin out to none, in units.
const EDGE_FADE := 0.6
## Up to how much further out from a gap's side than its size each rock stays, in units, so
## the sides are ragged rather than ruled.
const GAP_RAGGEDNESS := 0.25
## How many tries per rock before the scatter gives up, should the band be all gaps.
const TRIES_PER_ROCK := 20
## How far apart the scatter looks for open spots to plug, in units.
const PLUG_STEP := 0.3
## A plugging rock is this much of the open spot across, and no larger than this.
const PLUG_FILL := 0.8
const PLUG_MAX_SIZE := 0.9
## How much of its size a rock covers, seen from above, lumpy and squashed as it is.
const ROCK_COVER := 0.85


## A MultiMesh of [param mesh] with [param count] rocks through [param belt], each from
## [param min_size] to [param max_size] across, at up to [param height] above or below the
## orbit plane, placed by [param rng]. With [param plug_over] above 0, every open spot wider
## than that gets one more rock.
static func scatter(
	belt: AsteroidBelt,
	mesh: Mesh,
	count: int,
	min_size: float,
	max_size: float,
	height: float,
	rng: RandomNumberGenerator,
	plug_over := 0.0
) -> MultiMesh:
	var placed: Array[Transform3D] = []
	# Each rock seen from above: where it is on the orbit plane, and its radius.
	var discs: Array[Vector3] = []
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
		discs.append(Vector3(point.x, point.z, size * 0.5 * ROCK_COVER))
	if plug_over > 0.0:
		_plug(belt, placed, discs, plug_over, rng)
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


# Puts a rock in every open spot wider than [param over], the widest first, until none is
# left. It looks for them on a grid of rings through the band, in from its edges, where the
# rocks thin out anyway.
static func _plug(
	belt: AsteroidBelt,
	placed: Array[Transform3D],
	discs: Array[Vector3],
	over: float,
	rng: RandomNumberGenerator
) -> void:
	var spots: Array[Vector2] = []
	# How far each spot is from the nearest rock's side.
	var room := PackedFloat32Array()
	var radius := belt.inner_radius + PLUG_STEP
	while radius <= belt.outer_radius - PLUG_STEP:
		var slots := ceili(TAU * radius / PLUG_STEP)
		for slot: int in slots:
			var angle := TAU * slot / slots
			var spot := Vector2(cos(angle), -sin(angle)) * radius
			if belt.is_in_gap(Vector3(spot.x, 0.0, spot.y)):
				continue
			var nearest := INF
			for disc: Vector3 in discs:
				nearest = minf(nearest, Vector2(disc.x, disc.y).distance_to(spot) - disc.z)
			spots.append(spot)
			room.append(nearest)
		radius += PLUG_STEP
	while true:
		var widest := -1
		for i: int in spots.size():
			if room[i] > over * 0.5 and (widest < 0 or room[i] > room[widest]):
				widest = i
		if widest < 0:
			return
		var spot := spots[widest]
		var point := Vector3(spot.x, 0.0, spot.y)
		var size := minf(room[widest] * 2.0 * PLUG_FILL, PLUG_MAX_SIZE)
		# Beside a gap, no wider than keeps it out of the gap.
		while size > 0.1 and belt.is_in_gap(point, -size * 0.5):
			size *= 0.8
		var stretch := Vector3(
			rng.randf_range(0.9, 1.2), rng.randf_range(0.6, 1.0), rng.randf_range(0.9, 1.2)
		)
		var basis := Basis(_random_axis(rng), rng.randf() * TAU).scaled(stretch * size)
		placed.append(Transform3D(basis, point))
		var cover := size * 0.5 * ROCK_COVER
		for i: int in spots.size():
			room[i] = minf(room[i], spots[i].distance_to(spot) - cover)
		# Beside a gap the rock may be too small to close the spot: don't try it again.
		room[widest] = 0.0


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
