class_name FlightTime
## How long the bus takes to fly a straight line, from its speeds and acceleration.


## Seconds to cover [param distance] in a straight line from [param start_speed], speeding
## up toward [param top] speed at [param acceleration] and braking to [param end_speed] at
## the end.
static func straight(
	distance: float, start_speed: float, end_speed: float, top: float, acceleration: float
) -> float:
	var speed_up := (top * top - start_speed * start_speed) / (2.0 * acceleration)
	var brake := (top * top - end_speed * end_speed) / (2.0 * acceleration)
	if speed_up + brake <= distance:
		var cruise := (distance - speed_up - brake) / top
		return (top - start_speed) / acceleration + cruise + (top - end_speed) / acceleration
	# Never reaches top speed: speeds up to a peak, then brakes.
	var ends := (start_speed * start_speed + end_speed * end_speed) * 0.5
	var peak := sqrt(maxf(acceleration * distance + ends, 0.0))
	if peak < start_speed:
		return maxf(start_speed - end_speed, 0.0) / acceleration
	return (peak - start_speed) / acceleration + maxf(peak - end_speed, 0.0) / acceleration
