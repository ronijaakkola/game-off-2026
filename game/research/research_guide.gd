class_name ResearchGuide
extends Node
## Shows the player how to research, a guide card at a time, once the mechanic's first call
## has opened research ([signal MechanicCall.research_opened]): beside the badge of the
## nearest planet with a lab until the bus docks at one, then on the station's Research
## button until the research screen opens, then in the screen on its title, with a Got it
## button, beside an upgrade the player can research (Fuel tank 1 when they can) until one
## is researched, and on its close button until it closes. The bus leaving the lab before
## the screen opens goes back to the badge; the screen closing early ends it. The game runs
## throughout, as in the tutorial; the cards are [TutorialCards] with its own.
## It shows once across every run until the player deletes their save data, as a feature
## hint does ([SaveGame.has_seen_hint]), and only in a run the main menu started
## ([method GameSaver.is_saved_run]), where it is kept as seen once it ends; with no
## [member saver], it always shows and is never kept. The debug panel's Research guide
## starts it at once.
## Every other call of the mechanic's that opens research has a reminder instead
## ([method remind]): the same cards on the lab badge and the Research button, saying what
## is new, with a ring round the target and a Got it button, until the research screen
## opens or the player presses Got it. It shows in every run, every time.

enum Step { NONE, LAB, BUTTON, SCREEN, UPGRADE, CLOSE }

## What it is kept as seen under, beside the feature hints.
const SEEN := &"research_guide"
## Seconds after the bus docks before the card on the Research button opens, once the
## station panel has slid in.
const BUTTON_DELAY := 0.6
## Seconds after the research screen opens, once its sheet has grown in, before the card
## on its title opens.
const SCREEN_DELAY := ResearchScreen.OPEN_SECONDS + 0.15
## The upgrade the card points at when the player can research it.
const FIRST_UPGRADE := "Fuel tank 1"
const DEBUG_TEXT := "Research guide"
## What a reminder says is new: a tree's upgrades, by its title, or a stage in every tree.
const REMIND_TREE_TEXT := "Your mechanic brought %s upgrades."
const REMIND_STAGE_TEXT := "Your mechanic brought new upgrades for every tree."
## Each step's card, as [constant TutorialCards.CARDS] has them.
const CARDS := {
	"LAB":
	{
		title = "Research",
		text =
		(
			"You can spend credits and research points on upgrades at planets with a research "
			+ "lab, like {planet}. Look for this icon, and dock there."
		),
		side = GuideCard.Side.RIGHT,
		got_it = false,
	},
	"BUTTON":
	{
		title = "Services",
		text = "This planet has a research lab. Click here to open it.",
		side = GuideCard.Side.LEFT,
		got_it = false,
	},
	"SCREEN":
	{
		title = "The research lab",
		text =
		(
			"Welcome to the research lab. Here you can spend research points to upgrade your bus. "
			+ "Your mechanic brings more upgrades as you go."
		),
		side = GuideCard.Side.RIGHT,
		got_it = true,
	},
	"UPGRADE":
	{
		title = "An upgrade",
		text = "This one you can afford. Press and hold it to research it.",
		side = GuideCard.Side.RIGHT,
		got_it = false,
	},
	"REMIND_LAB":
	{
		title = "New upgrades",
		text = "{what} Dock at a planet with a research lab, like {planet}, to research them.",
		side = GuideCard.Side.RIGHT,
		got_it = true,
	},
	"REMIND_BUTTON":
	{
		title = "New upgrades",
		text = "{what} Open the research lab here.",
		side = GuideCard.Side.LEFT,
		got_it = true,
	},
	"CLOSE":
	{
		title = "Close the lab",
		text =
		(
			"Make sure to check the lab regularly to see if you could improve your services. "
			+ "Now, let's close the lab view."
		),
		side = GuideCard.Side.LEFT,
		got_it = false,
	},
}

## Starts it once it has opened research.
@export var mechanic: MechanicCall
@export var bus: FrameshiftBus
## Which planets passengers travel between, for the nearest lab.
@export var star_map: StarMap
## Where the Research button is.
@export var dock_panel: DockPanel
@export var lab_badges: LabBadges
@export var research_lab: ResearchLab
@export var research_screen: ResearchScreen
## The card it shows on: the tutorial's, which is over by then.
@export var guide: GuideCard
## It shows only in a run it saves.
@export var saver: GameSaver

var _step := Step.NONE
var _cards: TutorialCards
# The lab the card on the badge points at.
var _lab: Planet
# Whether it only reminds the player of new upgrades, and what it says is new.
var _reminding := false
var _new_text := ""


func _ready() -> void:
	set_process(false)
	_cards = TutorialCards.new(guide, CARDS)
	mechanic.research_opened.connect(_on_research_opened)
	mechanic.research_added.connect(_on_research_added)
	guide.acknowledged.connect(_on_guide_acknowledged)
	research_screen.closed.connect(_on_screen_closed)
	dock_panel.research_pressed.connect(_on_research_pressed.unbind(1))
	DebugPanel.add_button(DEBUG_TEXT, start, self)


func _process(_delta: float) -> void:
	match _step:
		Step.LAB:
			var docked := bus.get_docked_planet() if bus.is_at_planet() else null
			if docked and docked.has_lab:
				_go_to(Step.BUTTON)
			elif not _lab:
				_open_lab_card()
		Step.BUTTON:
			if not bus.is_at_planet():
				_go_to(Step.LAB)


## Starts it, at whichever step fits where the bus is.
func start() -> void:
	# Here, not when ready: the lab makes its research once it is ready, after this node.
	var research := research_lab.get_research()
	if not research.researched.is_connected(_on_researched):
		research.researched.connect(_on_researched)
	_reminding = false
	guide.ring = false
	set_process(true)
	if research_screen.is_open():
		_go_to(Step.SCREEN)
	else:
		_go_to(Step.LAB)


## Reminds the player that [param tree] has upgrades in the lab now, or every tree when it
## is null, pointing at the nearest lab and then the Research button.
func remind(tree: ResearchTree) -> void:
	if tree:
		_new_text = REMIND_TREE_TEXT % tree.title
	else:
		_new_text = REMIND_STAGE_TEXT
	_reminding = true
	guide.ring = true
	set_process(true)
	_step = Step.NONE
	_go_to(Step.LAB)


## Whether it is showing the player how to research.
func is_running() -> bool:
	return _step != Step.NONE


func _go_to(step: Step) -> void:
	if step == _step:
		return
	_step = step
	_cards.close()
	match step:
		Step.LAB:
			_lab = null
			_open_lab_card()
		Step.BUTTON:
			_open_button_card()
		Step.SCREEN:
			_open_screen_card()
		Step.UPGRADE:
			var upgrade := _upgrade_to_research()
			if upgrade:
				_open_card(research_screen.get_button(upgrade))
			else:
				_go_to(Step.CLOSE)
		Step.CLOSE:
			_open_card(research_screen.get_close_button())


func _open_card(target: Control, names := {}) -> void:
	var key: String = Step.keys()[_step]
	if _reminding:
		key = "REMIND_" + key
	var filled := names.duplicate()
	filled["what"] = _new_text
	await _cards.open(key, target, filled)


# The card beside the badge of the nearest planet with a lab, which it stays on.
func _open_lab_card() -> void:
	_lab = _nearest_lab()
	if not _lab:
		return
	_open_card(lab_badges.get_badge(_lab), {"planet": _lab.display_name})


# Once the station panel has slid in with its Research button, the card points at it.
func _open_button_card() -> void:
	await get_tree().create_timer(BUTTON_DELAY).timeout
	if _step == Step.BUTTON:
		_open_card(dock_panel.get_research_button())


# Once the screen has grown in, the card on its title.
func _open_screen_card() -> void:
	await get_tree().create_timer(SCREEN_DELAY).timeout
	if _step == Step.SCREEN:
		_open_card(research_screen.get_title())


# The upgrade to point at: Fuel tank 1 when the player can research it, else the first
# they can, or null.
func _upgrade_to_research() -> Upgrade:
	var research := research_lab.get_research()
	var credits := research_lab.get_credits()
	var points := research_lab.get_points()
	var first: Upgrade = null
	for tree: ResearchTree in research_lab.trees:
		for upgrade: Upgrade in tree.upgrades:
			if research.get_state(upgrade, credits, points) != Research.State.AVAILABLE:
				continue
			if upgrade.title == FIRST_UPGRADE:
				return upgrade
			if not first:
				first = upgrade
	return first


# The planet with a lab nearest the bus, among those passengers travel between.
func _nearest_lab() -> Planet:
	var nearest: Planet = null
	var best := INF
	for planet: Planet in star_map.get_active_planets():
		if not planet.has_lab or not lab_badges.is_shown(planet):
			continue
		var distance := bus.global_position.distance_to(planet.get_body_global_position())
		if distance < best:
			best = distance
			nearest = planet
	return nearest


func _finish() -> void:
	_step = Step.NONE
	set_process(false)
	_cards.close()
	if _reminding:
		_reminding = false
		guide.ring = false
	elif saver and saver.is_saved_run():
		SaveGame.mark_hint_seen(SEEN)


func _on_research_opened() -> void:
	if not saver:
		start()
	elif saver.is_saved_run() and not SaveGame.has_seen_hint(SEEN):
		start()


# A call that opened research, the first one included once the guide has been seen: a
# reminder, unless the guide is showing.
func _on_research_added(tree: ResearchTree) -> void:
	if not is_running() or _reminding:
		remind(tree)


func _on_research_pressed() -> void:
	if _reminding:
		_finish()
	elif _step in [Step.LAB, Step.BUTTON]:
		_go_to(Step.SCREEN)


func _on_guide_acknowledged() -> void:
	if _reminding:
		_finish()
	elif _step == Step.SCREEN:
		_go_to(Step.UPGRADE)


func _on_researched(_upgrade: Upgrade) -> void:
	if _step == Step.UPGRADE:
		_go_to(Step.CLOSE)


func _on_screen_closed() -> void:
	if _step in [Step.SCREEN, Step.UPGRADE, Step.CLOSE]:
		_finish()
