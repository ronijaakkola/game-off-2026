extends Node
## Warns as the bus's temperature climbs to [constant BusStatusPanel.TEMPERATURE_HIGH],
## where the gauge turns amber: a closable warning notice that clears by itself once it is
## back under it, or once the bus overheats. Overheated, an error notice shows until the
## cooldown is over, and then an info notice for [constant COOLED_SECONDS] says the drive
## can charge again. Overheating also scares everyone on board
## ([constant OVERHEAT_SHOCK]) and gives them a line about it on their card for the length
## of the cooldown.

const WARNING_TEXT := "The bus is overheating. Steer away from the star."
const OVERHEATED_TEXT := "The bus overheated. Cooling down..."
const COOLED_TEXT := "The bus has now cooled down. You can charge your frameshift drive again."
## The scare everyone on board takes when the bus overheats: less than running dry, since
## the cooldown costs time on top.
const OVERHEAT_SHOCK := -5.0
## Seconds the cooled down notice shows.
const COOLED_SECONDS := 6.0

@export var bus: FrameshiftBus
@export var notices: NoticeStack
@export var cabin: Cabin

# The temperature last frame.
var _last := 0.0
var _warning: Notice
var _overheated: Notice


func _ready() -> void:
	_last = bus.temperature.temperature
	bus.temperature.overheated.connect(_on_overheated)


func _process(_delta: float) -> void:
	var temperature := bus.temperature
	var degrees := temperature.temperature
	var high := degrees >= BusStatusPanel.TEMPERATURE_HIGH
	var cooling := temperature.is_cooling()
	if high and _last < BusStatusPanel.TEMPERATURE_HIGH and not cooling:
		_warning = notices.push(WARNING_TEXT, Notice.Kind.WARNING, true)
	elif _warning and (not high or cooling):
		_dismiss(_warning)
		_warning = null
	if cooling and not _overheated:
		_overheated = notices.push(OVERHEATED_TEXT, Notice.Kind.ERROR)
	elif _overheated and not cooling:
		_dismiss(_overheated)
		_overheated = null
		notices.push(COOLED_TEXT, Notice.Kind.INFO, false, COOLED_SECONDS)
	_last = degrees


# The shock first, so anyone it wakes reacts too.
func _on_overheated() -> void:
	cabin.shock(OVERHEAT_SHOCK)
	cabin.react_to_overheat(bus.temperature.cooldown_time)


func _dismiss(notice: Notice) -> void:
	if is_instance_valid(notice):
		notice.dismiss()
