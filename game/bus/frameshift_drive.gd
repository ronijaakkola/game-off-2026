class_name FrameshiftDrive
extends RefCounted
## The bus's frameshift drive, charged by hand. While the player holds the Frameshift key
## ([member held]) it charges, and it is charged after [member charge_time]. Let go, it
## drains back [member drain] times as fast as it charged. While passengers board it holds
## where it is. The bus decides when a charge starts and what being charged or drained does.
## Docked with the route going on, it is warm ([method warm_up]): a press leaves at once,
## until it cools over [member cool_time].

## Seconds of holding from empty to charged.
var charge_time := 3.0
## How many times faster the charge drains than it builds, once let go.
var drain := 2.0
## Seconds a warm drive takes to go cold.
var cool_time := 8.0
## Whether the player holds the Frameshift key. The bus lets go for them when it leaves or
## its course is cleared, so a key held through either doesn't charge the next one.
var held := false

var _charged := 0.0
var _warmth := 0.0


## Empties the charge.
func clear() -> void:
	_charged = 0.0


## Charges while held and drains while not, unless [param boarding].
func advance(delta: float, boarding: bool) -> void:
	if boarding:
		return
	if held:
		_charged = minf(_charged + delta, charge_time)
	else:
		_charged = maxf(_charged - delta * drain, 0.0)


func is_charged() -> bool:
	return _charged >= charge_time


## Empty and let go: the charge is over without leaving.
func is_drained() -> bool:
	return not held and _charged <= 0.0


## How far it has charged, from 0 to 1.
func get_progress() -> float:
	return clampf(_charged / charge_time, 0.0, 1.0) if charge_time > 0.0 else 1.0


## Seconds of holding still needed to be charged: none while warm.
func get_time_left() -> float:
	return 0.0 if is_warm() else maxf(charge_time - _charged, 0.0)


## Makes it warm for [member cool_time], or cold with [param warm] false.
func warm_up(warm := true) -> void:
	_warmth = cool_time if warm else 0.0


## Cools for [param delta] seconds.
func cool(delta: float) -> void:
	_warmth = maxf(_warmth - delta, 0.0)


func is_warm() -> bool:
	return _warmth > 0.0


## How much warmth is left, from 1 just docked to 0 cold.
func get_warmth() -> float:
	return _warmth / cool_time if cool_time > 0.0 else 0.0
