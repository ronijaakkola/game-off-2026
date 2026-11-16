class_name AsteroidBelt
extends Resource
## Where an asteroid field's rocks are: a band round its centre on the orbit plane, from
## [member inner_radius] to [member outer_radius], cut across by straight gaps the bus can
## fly through. Each gap runs out from the centre at one of [member gap_angles] and is
## [member gap_width] wide all the way across, so a gap is as easy to thread at its outer
## end as at its inner one. Points are in the field's own frame, which turns with the belt.

## From the centre to the band's inner and outer edges.
@export_range(0.5, 100.0, 0.05, "or_greater") var inner_radius := 16.2
@export_range(0.5, 100.0, 0.05, "or_greater") var outer_radius := 18.4
## Where each gap crosses the band, in degrees round the centre: counter-clockwise from +X
## seen from above, as the planets go.
@export var gap_angles: Array[float] = [20.0, 140.0, 255.0]
## How wide each gap is, in units, the same from the band's inner edge to its outer one.
@export_range(0.1, 10.0, 0.05) var gap_width := 1.8


## Whether [param point] lies in the band, gap or not, [param margin] in from its edges.
## Height is ignored.
func is_in_band(point: Vector3, margin := 0.0) -> bool:
	var distance := Vector2(point.x, point.z).length()
	return distance > inner_radius + margin and distance < outer_radius - margin


## Whether [param point] lies in a gap's corridor, [param margin] in from its sides,
## anywhere along it, in the band or past it.
func is_in_gap(point: Vector3, margin := 0.0) -> bool:
	return get_gap_offset(point) < gap_width * 0.5 - margin


## Whether [param point] is among the rocks: in the band and in no gap. [param margin]
## narrows the band and widens the gaps, so a point just touching the rocks counts as out.
func is_in_rocks(point: Vector3, margin := 0.0) -> bool:
	return is_in_band(point, margin) and not is_in_gap(point, -margin)


## How far [param point] is from the nearest gap's centre line, sideways. INF with no gaps.
func get_gap_offset(point: Vector3) -> float:
	var flat := Vector2(point.x, point.z)
	var nearest := INF
	for angle: float in gap_angles:
		var along := get_gap_direction(angle)
		var direction := Vector2(along.x, along.z)
		# Only the half of the line on the gap's side of the centre.
		if flat.dot(direction) <= 0.0:
			continue
		nearest = minf(nearest, absf(flat.cross(direction)))
	return nearest


## Which way a gap at [param degrees] runs out from the centre, on the orbit plane.
static func get_gap_direction(degrees: float) -> Vector3:
	var angle := deg_to_rad(degrees)
	return Vector3(cos(angle), 0.0, -sin(angle))
