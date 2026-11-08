class_name RoutePlotting
## Where a stop goes when the player adds it to the bus's route, and what goes with a stop
## they remove. Each changes the route it is given in place. Planets only ever go on the
## end, so the points in space on a route all come before its first planet.


## Adds [param stop] to [param route]: a planet goes on the end, in place of the point the
## route ends at when it has no planet, and a point in space becomes the one checkpoint
## before the first planet on the route, or with no planet on it the one stop, in place of
## the points there.
static func add(route: Array[RouteStop], stop: RouteStop) -> void:
	var first_planet := route.find_custom(RouteStop.is_planet)
	if stop.planet and first_planet >= 0:
		route.append(stop)
	elif stop.planet:
		route.assign([stop])
	else:
		route.assign([stop] + (route.slice(first_planet) if first_planet >= 0 else []))


## Removes [param stop] from [param route], wherever it is on it. A planet takes the
## checkpoint before it along. Does nothing when [param stop] isn't on the route.
static func remove(route: Array[RouteStop], stop: RouteStop) -> void:
	var at := route.find(stop)
	if at < 0:
		return
	route.remove_at(at)
	while stop.planet and at > 0 and not route[at - 1].planet:
		at -= 1
		route.remove_at(at)
