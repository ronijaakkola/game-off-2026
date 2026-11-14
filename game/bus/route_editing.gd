class_name RouteEditing
## How the bus's route changes when the player adds or removes a stop. Each changes the
## route it is given in place.


## Adds [param stop] to the end of [param route], unless it is the planet the route
## already ends at.
static func add(route: Array[RouteStop], stop: RouteStop) -> void:
	if route.is_empty() or not stop.planet or stop.planet != route.back().planet:
		route.append(stop)


## Removes [param stop] from [param route], wherever it is. A planet takes the points in
## space just before it along: they were the way there, and the route bar doesn't show
## them. Two of the same planet left side by side become one, as does a first stop that is
## [param docked_at], the planet the bus waits at. Does nothing when [param stop] isn't on
## the route.
static func remove(route: Array[RouteStop], stop: RouteStop, docked_at: Planet = null) -> void:
	var at := route.find(stop)
	if at < 0:
		return
	route.remove_at(at)
	while stop.planet and at > 0 and not route[at - 1].planet:
		at -= 1
		route.remove_at(at)
	if at >= route.size() or not route[at].planet:
		return
	var before: Planet = route[at - 1].planet if at > 0 else docked_at
	if route[at].planet == before:
		route.remove_at(at)
