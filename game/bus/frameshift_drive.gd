class_name FrameshiftDrive
extends RefCounted
## The bus's frameshift drive, charged by hand. While the player holds the Frameshift key
## ([member held]) it charges, and it is charged after [member charge_time]. Let go, it
## drains back [member drain] times as fast as it charged. While passengers board it holds
## where it is. The bus decides when a charge starts and what being charged or drained does.
## Just docked, it is warm ([method warm_up]) and cools over [member cool_time]. A charge
## started warm starts from the warmth left and builds [member warm_boost] times as fast;
## let go, it goes cold, draining [member warm_drain] times as fast as a charge builds.

## Seconds of holding from empty to charged.
var charge_time := 3.0
## How many times faster the charge drains than it builds, once let go.
var drain := 2.0
## Seconds a warm drive takes to go cold.
var cool_time := 6.0
## How many times as fast a charge started warm builds.
var warm_boost := 1.5
## How many times faster than a charge builds one started warm drains, once let go.
var warm_drain := 4.0
## Whether the player holds the Frameshift key. The bus lets go for them when it leaves or
## its course is cleared, so a key held through either doesn't charge the next one.
var held := false

var _charged := 0.0
var _warmth := 0.0
# The charge under way started warm and hasn't been let go.
var _warm_charge := false
# A warm charge was let go: it drains fast until held again.
var _dropped := false


## Empties the charge.
func clear() -> void:
	_charged = 0.0
	_warm_charge = false
	_dropped = false


## Starts a charge: from the warmth left while warm, which it uses up, else from empty.
func start() -> void:
	clear()
	if is_warm():
		_charged = get_warmth() * charge_time
		_warm_charge = true
	_warmth = 0.0


## Charges while held and drains while not, unless [param boarding].
func advance(delta: float, boarding: bool) -> void:
	if boarding:
		return
	if held:
		_dropped = false
		_charged = minf(_charged + delta * (warm_boost if _warm_charge else 1.0), charge_time)
		return
	if _warm_charge:
		_warm_charge = false
		_dropped = true
	_charged = maxf(_charged - delta * (warm_drain if _dropped else drain), 0.0)


func is_charged() -> bool:
	return _charged >= charge_time


## Empty and let go: the charge is over without leaving.
func is_drained() -> bool:
	return not held and _charged <= 0.0


## Whether the charge under way started warm and hasn't been let go.
func is_warm_charge() -> bool:
	return _warm_charge


## How far it has charged, from 0 to 1.
func get_progress() -> float:
	return clampf(_charged / charge_time, 0.0, 1.0) if charge_time > 0.0 else 1.0


## Seconds of holding still needed to be charged, from where it is or the warmth left.
func get_time_left() -> float:
	var from := get_warmth() * charge_time if is_warm() else _charged
	var rate := warm_boost if is_warm() or _warm_charge else 1.0
	return maxf(charge_time - from, 0.0) / rate


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
