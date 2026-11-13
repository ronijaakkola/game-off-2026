class_name RouteTime
## How long the bus takes to fly its whole route from where everything is now: to the
## first planet as [method FrameshiftBus.estimate_time_to_next_planet] counts it, then a
## full charge at each planet after it and the straight legs on to the next, docking at
## each, and on to a point in space when the route ends at one. Planets move and the bus
## turns, so it is an estimate.


## Seconds [param bus] takes to finish its route. 0 with no route.
static func estimate(bus: FrameshiftBus) -> float:
	var stops := bus.get_route_stops()
	var next := bus.get_next_planet()
	var waiting := (
		bus.state
		in [FrameshiftBus.State.DOCKED, FrameshiftBus.State.CHARGING, FrameshiftBus.State.HOLDING]
	)
	var time := 0.0
	var from := bus.global_position
	if next:
		time = bus.estimate_time_to_next_planet()
		from = RouteStop.at_planet(next).get_target(from, bus.dock_gap)
		# Parking, the bus has already taken the planet off its route.
		if bus.state != FrameshiftBus.State.PARKING:
			stops = stops.slice(stops.find_custom(RouteStop.is_planet) + 1)
	elif waiting:
		time = bus.charge_time * (1.0 - bus.get_charge_progress())
	var top := bus.get_stats().get_stat(BusStats.Type.MAX_SPEED).get_value()
	# Only a route of points in space ends past the planets, which all come after its
	# points: in flight the bus cruises toward it, and waiting it starts from rest.
	var start_speed := 0.0 if waiting else top
	var distance := 0.0
	for stop: RouteStop in stops:
		var to := stop.get_target(from, bus.dock_gap)
		distance += _flat(from).distance_to(_flat(to))
		from = to
		if stop.planet:
			time += bus.charge_time + _to_planet(distance, top, bus.acceleration)
			distance = 0.0
	if distance > 0.0:
		time += FlightTime.straight(distance, start_speed, 0.0, top, bus.acceleration)
	return time


# Seconds from rest to docked at a planet [param distance] away: the flight brakes to the
# glide's speed where the glide into the dock starts, then glides the rest.
static func _to_planet(distance: float, top: float, acceleration: float) -> float:
	var glide_from := minf(distance, FrameshiftBus.DOCK_DISTANCE)
	var glide := minf(FrameshiftBus.DOCK_SMOOTHING * FrameshiftBus.DOCK_DISTANCE, top)
	var flight := FlightTime.straight(distance - glide_from, 0.0, glide, top, acceleration)
	var park_distance := maxf(glide_from, FrameshiftBus.PARK_DISTANCE)
	return flight + log(park_distance / FrameshiftBus.PARK_DISTANCE) / FrameshiftBus.DOCK_SMOOTHING


static func _flat(at: Vector3) -> Vector3:
	return Vector3(at.x, 0.0, at.z)
