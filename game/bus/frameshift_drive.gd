class_name FrameshiftDrive
extends RefCounted
## The bus's frameshift drive, charged by hand. While the player holds the Frameshift key
## ([member held]) it charges, and it is charged after [member charge_time]. Let go, it
## drains back [member drain] times as fast as it charged. The bus decides when a charge
## starts and what being charged or drained does.
## Docking starts a stop ([method begin_stop]). Once those getting off are off, the stop's
## clock runs ([method wait]): leaving within [member quick_time] of it is a quick stop.
## With the Warm drive the drive is warm meanwhile, cooling over [member quick_time]; a
## charge started warm starts from the warmth left and builds as if a whole one took
## [member warm_charge_time], and leaving on it is a quick stop too. Let go, it goes cold,
## draining [member warm_drain] times as fast as a cold charge builds.

## Seconds of holding from empty to charged.
var charge_time: float
## How many times faster the charge drains than it builds, once let go.
var drain := 2.0
## Seconds of holding a charge started warm would take from empty: it starts from the
## warmth left, so it takes at most this.
var warm_charge_time: float
## How many times faster than a cold charge builds one started warm drains, once let go.
var warm_drain := 4.0
## Seconds after those getting off are off within which leaving is a quick stop.
var quick_time: float
## Whether the player holds the Frameshift key. The bus lets go for them when it leaves or
## its course is cleared, so a key held through either doesn't charge the next one.
var held := false

var _charged := 0.0
var _warmth := 0.0
# The charge under way started warm and hasn't been let go.
var _warm_charge := false
# A warm charge was let go: it drains fast until held again.
var _dropped := false
# Seconds the stop's clock has run. INF with no stop that can be a quick one.
var _stop_time := INF


## Made with the bus's [param charge] for [member charge_time], [param quick] for
## [member quick_time] and [param warm_charge] for [member warm_charge_time].
func _init(charge: float, quick: float, warm_charge: float) -> void:
	charge_time = charge
	quick_time = quick
	warm_charge_time = warm_charge


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


## Charges while held and drains while not.
func advance(delta: float) -> void:
	if held:
		_dropped = false
		_charged = minf(_charged + delta * (_warm_rate() if _warm_charge else 1.0), charge_time)
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
	var rate := _warm_rate() if is_warm() or _warm_charge else 1.0
	return maxf(charge_time - from, 0.0) / rate


## The bus docked: a stop starts, with the drive warm for [member quick_time] if
## [param warm] (the Warm drive). With [param quick] false, as when towed in, the drive is
## cold and it can't be a quick stop.
func begin_stop(quick: bool, warm: bool) -> void:
	_warmth = quick_time if quick and warm else 0.0
	_stop_time = 0.0 if quick else INF


## The bus left, or its stop is no quick one: cold, and no quick stop ahead.
func end_stop() -> void:
	_warmth = 0.0
	_warm_charge = false
	_stop_time = INF


## The stop runs on for [param delta] seconds, once those getting off are off: the drive
## cools and the quick stop's time runs out.
func wait(delta: float) -> void:
	_warmth = maxf(_warmth - delta, 0.0)
	_stop_time += delta


## Whether leaving now is a quick stop: within [member quick_time], or on a charge started
## warm and never let go.
func is_quick_stop() -> bool:
	return _stop_time <= quick_time or _warm_charge


## The share of the quick stop's time left, from 1 as those getting off are off to 0 once
## it has run out. 0 with no stop that can be a quick one.
func get_quick_stop_left() -> float:
	return clampf(1.0 - _stop_time / quick_time, 0.0, 1.0) if quick_time > 0.0 else 0.0


func is_warm() -> bool:
	return _warmth > 0.0


## How much warmth is left, from 1 just docked to 0 cold.
func get_warmth() -> float:
	return _warmth / quick_time if quick_time > 0.0 else 0.0


# How many times as fast as a cold charge a warm one builds.
func _warm_rate() -> float:
	return charge_time / warm_charge_time if warm_charge_time > 0.0 else INF
