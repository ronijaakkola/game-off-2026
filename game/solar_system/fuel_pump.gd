class_name FuelPump
extends Node
## Sells the bus fuel at the planet it is docked at while the player holds a fuel button:
## fuel flows slowly at first and faster the longer they hold, and costs the planet's fuel
## price, taken from the credits a whole credit at a time. What is left under a credit
## carries over to the next refuel. The parent says each frame whether a button is held.

## Fuel a second the pump gives as the button goes down, the most it speeds up to, and the
## seconds it takes to get there.
const START_RATE := 12.0
const MAX_RATE := 60.0
const RAMP_SECONDS := 1.5

# Seconds the pump has run since the button went down.
var _pump_time := 0.0
# Credits owed for fuel pumped but not yet taken: under one, since whole ones go at once.
var _owed := 0.0


## Why [param tank] can't take fuel at [param planet] now, or "" when it can.
func get_stop(planet: Planet, tank: FuelTank, counter: CreditsCounter) -> String:
	if not planet.sells_fuel:
		return "No fuel sold here."
	if tank.fuel >= tank.capacity:
		return "Tank full."
	if _affordable(planet, counter) <= 0.0:
		return "Not enough credits."
	return ""


## Pumps [param delta] seconds of fuel into [param tank] at [param planet] while
## [param held] and nothing stops it, and takes the credits from [param counter].
## Otherwise the pump stops, and starts slow again next time.
func run(delta: float, planet: Planet, held: bool, tank: FuelTank, counter: CreditsCounter) -> void:
	if not held or not get_stop(planet, tank, counter).is_empty():
		_pump_time = 0.0
		return
	_pump_time += delta
	var ramp := clampf(_pump_time / RAMP_SECONDS, 0.0, 1.0)
	var amount := minf(lerpf(START_RATE, MAX_RATE, ramp) * delta, _affordable(planet, counter))
	amount = minf(amount, tank.capacity - tank.fuel)
	tank.refuel(amount)
	_owed += amount * planet.fuel_price
	var whole := floori(_owed)
	if whole > 0:
		counter.spend(whole)
		_owed -= whole


# How much fuel the credits left buy at [param planet].
func _affordable(planet: Planet, counter: CreditsCounter) -> float:
	if planet.fuel_price <= 0.0:
		return INF
	return maxf(counter.credits - _owed, 0.0) / planet.fuel_price
