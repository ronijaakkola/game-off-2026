extends Node
## Warns once the bus's fuel falls to [constant BusStatusPanel.FUEL_LOW] of a full tank,
## where the fuel gauge turns red: a closable warning notice that clears by itself once the
## fuel is back above it, or once the tank runs dry and the out of fuel notice takes over.
## Only a fall warns, so refuelling up from empty shows nothing.

const TEXT := "Fuel is running low."

@export var bus: FrameshiftBus
@export var notices: NoticeStack

# The share of a full tank last frame.
var _last := 1.0
var _notice: Notice


func _ready() -> void:
	_last = bus.get_fuel_tank().get_fraction()


func _process(_delta: float) -> void:
	var tank := bus.get_fuel_tank()
	var fraction := tank.get_fraction()
	var low := fraction <= BusStatusPanel.FUEL_LOW
	if low and _last > BusStatusPanel.FUEL_LOW and not tank.is_empty():
		_notice = notices.push(TEXT, Notice.Kind.WARNING, true)
	elif _notice and (not low or tank.is_empty()):
		if is_instance_valid(_notice):
			_notice.dismiss()
		_notice = null
	_last = fraction
