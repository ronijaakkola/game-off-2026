class_name FrameshiftDrive
extends RefCounted
## The bus's frameshift drive, charged by hand. While the player holds the Frameshift key
## ([member held]) it charges, and it is charged after [member charge_time]. Let go, it
## drains back [member drain] times as fast as it charged. While passengers board it holds
## where it is. The bus decides when a charge starts and what being charged or drained does.

## Seconds of holding from empty to charged.
var charge_time := 3.0
## How many times faster the charge drains than it builds, once let go.
var drain := 2.0
## Whether the player holds the Frameshift key. The bus lets go for them when it leaves or
## its course is cleared, so a key held through either doesn't charge the next one.
var held := false

var _charged := 0.0


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


## Seconds of holding still needed to be charged.
func get_time_left() -> float:
	return maxf(charge_time - _charged, 0.0)
