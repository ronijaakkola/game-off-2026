class_name StatModifier
extends Resource
## One change to one of the bus's [Stat]s, such as an upgrade's "+10 % top speed".
## [method BusStats.add_modifier] applies it to the stat [member stat] names.

enum Kind {
	## [member amount] is added to the stat's base, in the stat's own units.
	FLAT = 0,
	## [member amount] is a percent of the base plus the flat modifiers: 20 is +20 %.
	PERCENT = 1,
}

## The stat it changes.
@export var stat := BusStats.Type.MAX_SPEED
@export var kind := Kind.FLAT
## Added to the base when [member kind] is FLAT, a percent when it is PERCENT. Negative
## takes away.
@export var amount := 0.0


func _init(
	changes := BusStats.Type.MAX_SPEED, modifier_kind := Kind.FLAT, modifier_amount := 0.0
) -> void:
	stat = changes
	kind = modifier_kind
	amount = modifier_amount
