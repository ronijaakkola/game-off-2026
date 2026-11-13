class_name DestinationGroup
extends VBoxContainer
## The On board panel's passengers going to one planet: a header with the planet's icon,
## its name, a rule and how many on board are going there, then their cards. The header
## holds the gap above the group, and each card the gap above itself, so the header opens
## with the group's first card ([method fade_in]) and, when the last card has left,
## [method fold_away] folds it, gap and all, and the groups below move up smoothly.

## The group's last card has left, so nobody on board is going to [member planet].
signal emptied
## The group has folded away after [method fold_away]. It can be freed.
signal folded

## The planet its passengers are going to.
var planet: Planet:
	set(value):
		planet = value
		if is_node_ready():
			_show_planet()

var _fold := 1.0
# The header's fade, and its place opening or folding.
var _motion: Tween
var _gap: Tween


func _ready() -> void:
	_show_planet()
	_fit_slot()


func _process(_delta: float) -> void:
	_fit_slot()


## Adds [param card] at the bottom of the group, and frees it once it has left.
func add_card(card: PassengerCard) -> void:
	card.left.connect(_on_card_left.bind(card))
	%GroupCards.add_child(card)


## Shows [param count] passengers on board going to [member planet].
func show_count(count: int) -> void:
	(%CountLabel as Label).text = str(count)


## Opens the header's place and fades the header in, in step with the group's first card.
## Under Reduce motion its place is open at once.
func fade_in() -> void:
	_kill_motion()
	var header := %Header as Control
	header.modulate.a = 0.0
	_motion = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_motion.tween_property(header, ^"modulate:a", 1.0, PassengerCard.ENTER_SECONDS)
	if Settings.reduce_motion:
		return
	_set_fold(0.0)
	_gap = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_gap.tween_method(_set_fold, 0.0, 1.0, PassengerCard.FOLD_SECONDS)


## Fades the header out while folding its height away, gap included, then emits
## [signal folded]. Under Reduce motion its place closes at once.
func fold_away() -> void:
	_kill_motion()
	if Settings.reduce_motion:
		_set_fold(0.0)
		folded.emit()
		return
	_motion = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion.tween_property(%Header, ^"modulate:a", 0.0, PassengerCard.EXIT_SECONDS)
	_gap = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_gap.tween_method(_set_fold, _fold, 0.0, PassengerCard.FOLD_SECONDS)
	_gap.tween_callback(folded.emit)


func _kill_motion() -> void:
	for tween: Tween in [_motion, _gap]:
		if tween:
			tween.kill()


func _show_planet() -> void:
	(%DestinationPlanetIcon as PlanetIcon).planet = planet
	var label := %PlanetLabel as Label
	if not planet:
		label.text = "?"
	elif planet.display_name:
		label.text = planet.display_name
	else:
		label.text = planet.name


func _on_card_left(card: PassengerCard) -> void:
	%GroupCards.remove_child(card)
	card.queue_free()
	if %GroupCards.get_child_count() == 0:
		emptied.emit()


func _set_fold(value: float) -> void:
	_fold = value
	_fit_slot()


# The slot is as tall as the header, times the fold, and the header fills its width.
func _fit_slot() -> void:
	var slot := %HeaderSlot as Control
	var header := %Header as Control
	var needed := header.get_combined_minimum_size()
	header.size = Vector2(slot.size.x, needed.y)
	var fitted := Vector2(0.0, needed.y * _fold)
	if slot.custom_minimum_size != fitted:
		slot.custom_minimum_size = fitted
