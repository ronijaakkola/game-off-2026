extends MenuScreen
## The campaign screen: a card for each level, and under the picked one what it can do. A
## card is picked as it takes focus, by a click or the keyboard.
## It opens with the level in progress picked, or else the next one not done. A level in
## progress continues, with a restart beside it; one done plays again from where it began;
## any other open one plays. Starting a level over, or any level that would replace the
## run in play, asks first ([RestartDialog]). A locked card can't be picked. Level 1's
## card has a Play tutorial box, ticked until the player has been through the tutorial. A
## menu opens it over itself ([MenuScreen]).

## Seconds the actions take to appear under a newly picked card.
const APPEAR_SECONDS := 0.2
## Pixels above their place the actions start as they appear.
const DROP := 6.0
const CARD := preload("res://ui/campaign/level_card.tscn")

var _cards: Array[LevelCard] = []
var _picked: LevelCard
var _appear: Tween


func _ready() -> void:
	super._ready()
	for level: Level in Campaign.LEVELS:
		var card: LevelCard = CARD.instantiate()
		(%Cards as Control).add_child(card)
		card.focus_entered.connect(_pick.bind(card))
		_cards.append(card)
	visibility_changed.connect(_on_shown_or_hidden)


func _opening() -> void:
	var in_progress := Campaign.get_in_progress()
	for i: int in _cards.size():
		var level := Campaign.LEVELS[i]
		var state := LevelCard.State.OPEN
		if level == in_progress:
			state = LevelCard.State.IN_PROGRESS
		elif Campaign.is_done(level):
			state = LevelCard.State.DONE
		elif not Campaign.is_open(level):
			state = LevelCard.State.LOCKED
		_cards[i].show_level(level, i + 1, state)
	_cards[0].set_tutorial(not SaveGame.is_tutorial_done())
	_pick(_first_pick(), true)


# The card in progress, or else the first open one not done, or else the last open one.
func _first_pick() -> LevelCard:
	var last_open := _cards[0]
	for state: LevelCard.State in [LevelCard.State.IN_PROGRESS, LevelCard.State.OPEN]:
		for card: LevelCard in _cards:
			if card.state == state:
				return card
	for card: LevelCard in _cards:
		if card.state != LevelCard.State.LOCKED:
			last_open = card
	return last_open


func _first_control() -> Control:
	return _picked


func _items() -> Array[Control]:
	var items := super._items()
	items.append(%ActionsTrack)
	return items


# Picks [param card]: its border lights, its picture zooms in, and the actions appear under
# it, dropping into place as they fade in, at once while the screen opens. Under Reduce
# motion they only fade.
func _pick(card: LevelCard, at_once := false) -> void:
	if card == _picked and not at_once:
		return
	_picked = card
	for each: LevelCard in _cards:
		each.picked = each == card
	var play := %PlayButton as Button
	match card.state:
		LevelCard.State.IN_PROGRESS:
			play.text = "Continue"
		LevelCard.State.DONE:
			play.text = "Play again"
		_:
			play.text = "Play"
	(%RestartButton as Control).visible = card.state == LevelCard.State.IN_PROGRESS
	var actions := %Actions as Control
	actions.position = Vector2(MenuScreen.rest_position(card).x, 0.0)
	if _appear:
		_appear.kill()
	actions.modulate.a = 1.0
	if at_once or not is_visible_in_tree():
		return
	actions.modulate.a = 0.0
	_appear = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_appear.tween_property(actions, ^"modulate:a", 1.0, APPEAR_SECONDS)
	if not Settings.reduce_motion:
		actions.position.y = -DROP
		_appear.tween_property(actions, ^"position:y", 0.0, APPEAR_SECONDS)


func _on_play_button_pressed() -> void:
	var level := _picked.level
	if Campaign.replaces_run(level):
		(%RestartDialog as RestartDialog).ask(level, Campaign.get_in_progress())
	else:
		Campaign.play(level, _cards[0].wants_tutorial())


func _on_restart_button_pressed() -> void:
	(%RestartDialog as RestartDialog).ask(_picked.level, Campaign.get_in_progress())


func _on_restart_dialog_confirmed() -> void:
	Campaign.restart(_picked.level, _cards[0].wants_tutorial())


# The cards lay out once shown, so the actions find the picked one's place then.
func _on_shown_or_hidden() -> void:
	if visible and _picked:
		await get_tree().process_frame
		(%Actions as Control).position.x = MenuScreen.rest_position(_picked).x
	elif not visible:
		for card: LevelCard in _cards:
			card.clear()
