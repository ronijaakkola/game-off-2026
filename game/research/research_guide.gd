class_name ResearchGuide
extends Node
## Shows the player how to research, a guide card at a time, once the mechanic's first call has
## opened research ([signal MechanicCall.research_opened]), which it does with the bus docked at a
## lab: under the resource bar's research points, as a feature hint shows, until the player presses
## Got it; then on the station's Research button until the research screen opens, the game paused
## from the first card until then; then in the screen beside its "Game paused" tag until an upgrade
## is researched, which ends it, as does the screen closing. The bus can't leave ([member
## FrameshiftBus.grounded]) until the screen opens. Away from a lab, as when the debug panel rings
## the call there, it ends after the research points. The cards are [TutorialCards] with its own.
## It shows once across every run until the player deletes their save data, as a feature hint does
## ([SaveGame.has_seen_hint]), and only in a run the main menu started ([method
## GameSaver.is_saved_run]), where it is kept as seen once it ends; with no [member saver], it
## always shows and is never kept. Every other call of the mechanic's that opens research has a
## reminder instead ([method remind]): a card beside the badge of the nearest planet with a lab, or
## on the Research button while the bus is docked at one, saying what is new, with a ring round the
## target and a Got it button, until the research screen opens or the player presses Got it. It
## shows in every run, every time.

enum Step { NONE, POINTS, LAB, BUTTON, SCREEN }

## What it is kept as seen under, beside the feature hints.
const SEEN := &"research_guide"
## Seconds after the bus docks before the card on the Research button opens, once the
## station panel has slid in.
const BUTTON_DELAY := 0.6
## Seconds after the mechanic's call closes, once the research points have grown into the
## resource bar, before the card on them opens.
const POINTS_DELAY := 0.75
## Seconds after the research screen opens, once its sheet has grown in, before the card
## on its tag opens.
const SCREEN_DELAY := ResearchScreen.OPEN_SECONDS + 0.15
## What a reminder says is new.
const REMIND_TEXT := "Your mechanic brought new upgrades for every tree."
## Each step's card, as [constant TutorialCards.CARDS] has them.
const CARDS := {
	"POINTS":
	{
		title = "Research points",
		text =
		(
			"You earn one for each passenger you deliver. Some special passengers may give you "
			+ "more. Upgrades cost credits and research points."
		),
		side = GuideCard.Side.BELOW,
		got_it = true,
		kind = GuideCard.Kind.FEATURE_HINT,
	},
	"BUTTON":
	{
		title = "Research",
		text = "This planet has a research lab. Click here to open it.",
		side = GuideCard.Side.LEFT,
		got_it = false,
	},
	"SCREEN":
	{
		title = "The research lab",
		text =
		(
			"The game is paused while the lab is open, so take your time. Research points are "
			+ "only used for research, so don't be afraid of spending them!"
		),
		side = GuideCard.Side.ABOVE,
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
## Where the research points are.
@export var resource_bar: ResourceBar
## The card it shows on: the tutorial's, which is over by then.
@export var guide: GuideCard
## It shows only in a run it saves.
@export var saver: GameSaver

var _step := Step.NONE
var _cards: TutorialCards
# The lab the card on the badge points at.
var _lab: Planet
# Whether it only reminds the player of new upgrades.
var _reminding := false
# Whether the card on the research points holds the game paused and the music muffled.
var _held := false


func _ready() -> void:
	set_process(false)
	_cards = TutorialCards.new(guide, CARDS)
	mechanic.research_opened.connect(_on_research_opened)
	mechanic.research_added.connect(_on_research_added)
	guide.acknowledged.connect(_on_guide_acknowledged)
	research_screen.closed.connect(_on_screen_closed)
	dock_panel.research_pressed.connect(_on_research_pressed.unbind(1))


# The pause and the muffled music are the guide's, so they go with the scene.
func _exit_tree() -> void:
	_let_go()


func _process(_delta: float) -> void:
	match _step:
		Step.LAB:
			if _is_at_lab():
				_go_to(Step.BUTTON)
			elif not _lab:
				_open_lab_card()
		Step.BUTTON:
			if not bus.is_at_planet():
				_go_to(Step.LAB)


## Starts it, on the research points.
func start() -> void:
	# Here, not when ready: the lab makes its research once it is ready, after this node.
	var research := research_lab.get_research()
	if not research.researched.is_connected(_on_researched):
		research.researched.connect(_on_researched)
	_reminding = false
	guide.ring = false
	set_process(true)
	_step = Step.NONE
	_go_to(Step.POINTS)


## Reminds the player that every tree has new upgrades in the lab now, pointing at the
## nearest lab and then the Research button.
func remind() -> void:
	_reminding = true
	guide.ring = true
	set_process(true)
	_step = Step.NONE
	_go_to(Step.BUTTON if _is_at_lab() else Step.LAB)


## Whether it is showing the player how to research.
func is_running() -> bool:
	return _step != Step.NONE


func _go_to(step: Step) -> void:
	if step == _step:
		return
	var docking := _step == Step.LAB
	_step = step
	_cards.close()
	bus.grounded = not _reminding and step in [Step.POINTS, Step.BUTTON] and _is_at_lab()
	if step != Step.BUTTON:
		_let_go()
	match step:
		Step.POINTS:
			_open_points_card()
		Step.LAB:
			_lab = null
			_open_lab_card()
		Step.BUTTON:
			_open_button_card(BUTTON_DELAY if docking else 0.0)
		Step.SCREEN:
			_open_screen_card()


func _open_card(target: Control, names := {}) -> void:
	var key: String = Step.keys()[_step]
	if _reminding:
		key = "REMIND_" + key
	var filled := names.duplicate()
	filled["what"] = REMIND_TEXT
	await _cards.open(key, target, filled)


# The card beside the badge of the nearest planet with a lab, which it stays on.
func _open_lab_card() -> void:
	_lab = _nearest_lab()
	if not _lab:
		return
	_open_card(lab_badges.get_badge(_lab), {"planet": _lab.display_name})


# Once the research points have grown into the resource bar, the card points at them as a
# feature hint does: the game pauses, the music muffles and a ring goes round them.
func _open_points_card() -> void:
	await get_tree().create_timer(POINTS_DELAY, false).timeout
	if _step != Step.POINTS:
		return
	_held = true
	# The Research button takes a click while the pause holds on, through the next card.
	dock_panel.get_research_row().process_mode = Node.PROCESS_MODE_ALWAYS
	PauseMenu.hold(self)
	Audio.muffle_music(true)
	guide.ring = true
	_open_card(resource_bar.get_research_counter())


# The game runs again, unless something else holds it, and the music clears.
func _let_go() -> void:
	if not _held:
		return
	_held = false
	dock_panel.get_research_row().process_mode = Node.PROCESS_MODE_INHERIT
	PauseMenu.release(self)
	Audio.muffle_music(false)
	guide.ring = _reminding


# The card points at the Research button, [param delay] seconds on when the station panel
# has yet to slide in.
func _open_button_card(delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if _step == Step.BUTTON:
		_open_card(dock_panel.get_research_row())


# Once the screen has grown in, the card beside its "Game paused" tag.
func _open_screen_card() -> void:
	await get_tree().create_timer(SCREEN_DELAY).timeout
	if _step == Step.SCREEN:
		_open_card(research_screen.get_paused_tag())


# Whether the bus is docked at a planet with a lab.
func _is_at_lab() -> bool:
	var planet := bus.get_docked_planet()
	return bus.is_at_planet() and planet != null and planet.has_lab


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
	_let_go()
	bus.grounded = false
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
func _on_research_added() -> void:
	if not is_running() or _reminding:
		remind()


func _on_research_pressed() -> void:
	if _reminding:
		_finish()
	elif _step != Step.NONE:
		_go_to(Step.SCREEN)


func _on_guide_acknowledged() -> void:
	if _reminding:
		_finish()
	elif _step == Step.POINTS and _is_at_lab():
		_go_to(Step.BUTTON)
	elif _step == Step.POINTS:
		_finish()


func _on_researched(_upgrade: Upgrade) -> void:
	if _step == Step.SCREEN:
		_finish()


func _on_screen_closed() -> void:
	if _step == Step.SCREEN:
		_finish()
