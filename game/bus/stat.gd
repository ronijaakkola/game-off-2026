class_name Stat
extends RefCounted
## A number that modifiers change, such as the bus's top speed. Its value is [member base]
## plus every flat [StatModifier], times one plus every percent one added together:
## a base of 8 with +5, +10 % and +20 % is (8 + 5) × 1.3. Percents add up rather than
## compound, so the order upgrades come in doesn't matter. The value never goes below 0.
## It is worked out when the base or the modifiers change, not on every read.

## [method get_value] changed.
signal changed

## The value before any modifier.
var base := 0.0:
	set(value):
		base = value
		_update()

var _modifiers: Array[StatModifier] = []
var _value := 0.0


func _init(start := 0.0) -> void:
	base = start


## The value with every modifier applied.
func get_value() -> float:
	return _value


## Applies [param modifier] until [method remove_modifier] takes it out. Changing its amount
## afterwards doesn't change the value: remove it and add it again.
func add_modifier(modifier: StatModifier) -> void:
	_modifiers.append(modifier)
	_update()


## Takes [param modifier] back out. Added twice, it takes out one of them.
func remove_modifier(modifier: StatModifier) -> void:
	_modifiers.erase(modifier)
	_update()


func _update() -> void:
	var flat := 0.0
	var percent := 0.0
	for modifier: StatModifier in _modifiers:
		match modifier.kind:
			StatModifier.Kind.FLAT:
				flat += modifier.amount
			StatModifier.Kind.PERCENT:
				percent += modifier.amount
	var value := maxf((base + flat) * (1.0 + percent / 100.0), 0.0)
	if value == _value:
		return
	_value = value
	changed.emit()
