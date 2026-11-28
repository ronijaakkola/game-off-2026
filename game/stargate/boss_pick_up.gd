class_name BossPickUp
extends Node
## What meeting the last star system's goals leads to. The Boss calls
## ([constant CALL_TEXT], which [Progression] has them say) with someone to pick up at the
## planet the [Stargate] is to be built beside, and [method begin] gives the quest: they
## wait there under a pick-up marker, nobody the player knows ([BossPassenger]), for as long
## as it takes. Once the bus is docked there the meeting plays, with the route, the bus,
## the camera and the HUD out of the player's hands until it is over: nothing takes a click
## but the transmission, the pause button and, once its card shows, the stargate's row.
## They show in the line; The Boss's transmission opens by itself, and the lights come on
## over them; the camera closes in beside the planet while the stargate appears, and draws
## back; everyone on board is kicked
## off as for a VIP ([method Seating.clear]) and The Boss boards; the dock panel grows a row
## to go through the stargate ([StargateRow]), which a guide card has the player press, the
## game paused; and the HUD goes while the map draws back, slowly, to the star chart
## ([StarChart]), where it stays. There The Boss's transmission opens by itself about the
## things they left behind, the HUD comes back over the chart, and The Boss's goals take
## the place of the system's ([FetchGoal]). The chart is then open for the player to go to
## another star or close it ([StarTravel]), with the route and the bus held until it
## closes. From then on nobody calls, a passenger or a VIP, and the row opens the star
## chart the same way, wherever a stargate is. As The Boss's briefcase and bowtie are
## fetched they wear them ([method BossPassenger.dress_up]).
## A save keeps how far it has got ([signal changed]); nothing saves through the meeting,
## so a run continued from the middle of it has it again.

## How far it has got changed, for a save game.
signal changed
## The star chart is to open for the player to go to another star, or is open for it: they
## pressed the stargate's row, or The Boss has given their goals over the chart.
signal travel_pressed

enum Stage { WAITING, CALLED, BUILT }

## What The Boss says as they call, after the telling off when the call opened by itself.
const CALL_TEXT := (
	"Good, you can follow a plan. I have a [money]very important[/money] passenger waiting "
	+ "on Earth. Go and pick them up."
)
## The line under their name on the pick-up marker.
const MARKER_LINE := "Waiting for a pick-up"
## What The Boss says at the meeting: in the dark, then once the lights are on, then about
## the stargate. Each pair of answers means the same.
const MEETING_OPENING := "Well, we finally meet."
const MEETING_TEXT := (
	"Thanks to my [money]tremendous work[/money], I have been invited to a board meeting. "
	+ "They probably want to finally make me a board member!"
)
const MEETING_ANSWERS: Array[String] = ["Congratulations!", "Sure, boss!"]
const STARGATE_TEXT := (
	"Now that we have gathered enough funding for my little project, let me introduce you "
	+ "to the [shout]STARGATE[/shout]! It will let us travel between stars. And "
	+ "[shout]YOU[/shout] will be taking me to see the board, after we have run some errands "
	+ "first."
)
const STARGATE_ANSWERS: Array[String] = ["Sure, boss!", "Ok, I guess"]
## What The Boss says once the star chart has closed, and the goals they give then, over
## their heading: what to fetch, from [member briefcase_planet] and [member bowtie_planet].
const ERRANDS_TEXT := (
	"As I said, I need a few things before I'm ready to receive my [money]promotion[/money]. "
	+ "I forgot my briefcase at my side office on Brume, and my bowtie at my mansion on "
	+ "Giant. [shout]WHY AREN'T YOU DRIVING ALREADY, RESOURCE? MY PROMOTION AWAITS![/shout]"
)
const ERRANDS_ANSWER := "Right away, boss!"
const ERRANDS_HEADER := "To get The Boss promoted"
const BRIEFCASE := "briefcase"
const BOWTIE := "bowtie"
## The guide card on the stargate's row, as [constant TutorialCards.CARDS] has them.
const CARDS := {
	"ROW":
	{
		title = "The stargate",
		text = "The Boss wants to go. Click here to travel between stars.",
		side = GuideCard.Side.LEFT,
		got_it = false,
		ring = true,
	},
}
## Seconds from the bus docking until the transmission opens, with them in the line.
const ARRIVE_SECONDS := 1.4
## Seconds from the transmission closing until the camera closes in, the camera holds on
## the stargate once it is there, and from The Boss boarding until the row grows in.
const BEAT_SECONDS := 0.6
const GATE_HOLD_SECONDS := 1.4
## Seconds the row has been in before its guide card opens.
const CARD_SECONDS := 0.5
## Seconds the map takes to draw back to the star chart the first time, and that the chart
## holds before The Boss's transmission opens.
const REVEAL_SECONDS := 9.0
const REVEAL_HOLD_SECONDS := 1.0
const DEBUG_BEGIN_TEXT := "Boss pick-up quest"

@export var bus: FrameshiftBus
@export var cabin: Cabin
@export var waiting: WaitingPassengers
## Keeps quiet from the meeting on, and says when the line is free for it to start.
@export var quest_giver: QuestGiver
@export var transmission_panel: TransmissionPanel
@export var pick_up_markers: PickUpMarkers
## Shows the quest, and The Boss's goals under their heading.
@export var goal_panel: GoalPanel
## The goals a promotion takes, which The Boss's own replace.
@export var goals: GoalTracker
## Where The Boss left their briefcase, and their bowtie.
@export var briefcase_planet: Planet
@export var bowtie_planet: Planet
## Where the stargate's row is.
@export var dock_panel: DockPanel
@export var hud: HudLayout
@export var rig: CameraRig
@export var star_chart: StarChart
## The stargate is built in its last system.
@export var star_map: StarMap
## The card that has the player press the row.
@export var guide: GuideCard
## Saves nothing through the meeting.
@export var saver: GameSaver

var _stage := Stage.WAITING
var _gate: Stargate
# The Boss, from the call until they are on board, and the quest to pick them up.
var _boss: Passenger
var _quest: BossPickUpQuest
# Whether the meeting plays, or the star chart shows.
var _busy := false
var _cards: TutorialCards


func _ready() -> void:
	_gate = Stargate.find(get_tree(), star_map.get_systems().back())
	_cards = TutorialCards.new(guide, CARDS)
	dock_panel.get_stargate_row().pressed.connect(_on_row_pressed)
	goals.goal_completed.connect(_dress.unbind(1))
	DebugPanel.add_button(DEBUG_BEGIN_TEXT, begin, self, Progression.DEBUG_GROUP)


# The pause is the guide card's while it shows, so it goes with the scene.
func _exit_tree() -> void:
	PauseMenu.release(self)


func _process(_delta: float) -> void:
	var here := _is_at_gate()
	var row := dock_panel.get_stargate_row()
	if row.is_open() and not (here and is_built()):
		row.close(false)
	elif not row.is_open() and here and is_built() and not _busy:
		row.open(false)
	# With The Boss on board nobody calls, a VIP neither: they wait for a free line.
	if is_built():
		quest_giver.enabled = false
	var free := quest_giver.is_line_free() and not cabin.is_stopping()
	if _stage == Stage.CALLED and not _busy and here and free:
		_meet()


## Whether The Boss has called with it, so they don't again.
func is_under_way() -> bool:
	return _stage != Stage.WAITING


## Whether the stargate is built, with The Boss on board.
func is_built() -> bool:
	return _stage == Stage.BUILT


## What The Boss still has the player fetch from one of [param system]'s planets, or null.
func get_fetch(system: StarSystem) -> FetchGoal:
	for goal: Goal in goals.get_goals():
		var fetch := goal as FetchGoal
		if fetch and is_built() and not fetch.is_met() and system.has_planet(fetch.planet):
			return fetch
	return null


## The Boss has called: whoever they sent the player for waits at the stargate's planet,
## under a pick-up marker, and the goal panel shows the quest. Nothing once it has begun,
## or without a stargate.
func begin() -> void:
	if _stage != Stage.WAITING or not _gate:
		return
	_stage = Stage.CALLED
	_wait(true)
	changed.emit()


## How far it has got, for a save game, with The Boss's goals once they are given.
func to_save() -> Dictionary:
	var saved := {"stage": _stage}
	if _stage == Stage.BUILT:
		saved["goals"] = goals.get_goals().map(func(g: Goal) -> Dictionary: return g.to_save())
	return saved


## Puts back what [method to_save] gave: the quest, or the stargate built.
func load_save(saved: Dictionary) -> void:
	_stage = clampi(int(saved.get("stage", 0)), 0, Stage.size() - 1) as Stage
	if not _gate:
		_stage = Stage.WAITING
	elif _stage == Stage.CALLED:
		_wait(false)
	elif is_built():
		Stargate.build_all(get_tree())
		_give_goals(false)
		var saved_goals: Array = saved.get("goals", [])
		var given := goals.get_goals()
		for i: int in mini(saved_goals.size(), given.size()):
			given[i].load_save(saved_goals[i] as Dictionary)
		_dress()


# They wait at the stargate's planet under their marker, and the quest shows.
func _wait(animated: bool) -> void:
	_boss = BossPassenger.create(_gate.planet)
	_quest = BossPickUpQuest.new()
	_quest.passenger = _boss
	_quest.accept()
	pick_up_markers.show_marker(_gate.planet, _boss, MARKER_LINE)
	goal_panel.show_quest(_quest, animated)


# Whether the bus waits at the planet of the stargate The Boss builds or, once it is
# built, of the one in the system the bus works in.
func _is_at_gate() -> bool:
	var gate := Stargate.find(get_tree(), star_map.get_current()) if is_built() else _gate
	return gate != null and bus.is_at_planet() and bus.get_docked_planet() == gate.planet


# The meeting, from the bus docking to the star chart.
func _meet() -> void:
	_busy = true
	saver.holding = true
	quest_giver.enabled = false
	_hold(true)
	hud.cover()
	# A VIP the player agreed to pick up elsewhere gives up their place first in a line
	# for now: nobody sees that line from here.
	var vip := waiting.reserved
	waiting.reserved = _boss
	pick_up_markers.remove_marker(_gate.planet)
	_quest.arrive()
	await _pause(ARRIVE_SECONDS)
	transmission_panel.open(_get_meeting())
	await transmission_panel.answered
	BossPassenger.reveal(_boss)
	await _pause(BEAT_SECONDS)
	await _build_gate()
	await Seating.clear(cabin)
	waiting.take(_gate.planet, _boss)
	# Unless they gave up meanwhile.
	var tour := quest_giver.get_tour()
	if vip and tour and tour.passenger == vip:
		waiting.reserved = vip
	bus.boarding = true
	if cabin.pick_up(_boss):
		while _boss not in cabin.get_passengers():
			await cabin.boarded
	goal_panel.hide_quest(_quest)
	_quest = null
	_boss = null
	_stage = Stage.BUILT
	await _pause(BEAT_SECONDS)
	await _teach_row()
	await hud.hide_all()
	await _send_on_errands(REVEAL_SECONDS)
	saver.holding = false
	_busy = false
	changed.emit()
	# The chart closing, with a jump to another star or without, hands the bus back.
	star_chart.closed.connect(_hold.bind(false), CONNECT_ONE_SHOT)
	travel_pressed.emit()


# The Boss's transmission at the meeting: two parts on one screen, the lights coming on
# over them in the first.
func _get_meeting() -> Transmission:
	var meeting := Transmission.from_boss()
	meeting.caller_name = GoalsMetCall.CALLER
	meeting.opening = MEETING_OPENING
	meeting.text = MEETING_TEXT
	_set_answers(meeting, MEETING_ANSWERS)
	meeting.then = Transmission.from_boss(true)
	meeting.then.caller_name = GoalsMetCall.CALLER
	meeting.then.text = STARGATE_TEXT
	_set_answers(meeting.then, STARGATE_ANSWERS)
	return meeting


# The map draws back to the star chart over [param seconds], and holds there: The Boss's
# transmission opens by itself, about the things they left behind; then the HUD comes back
# over the chart, taking no clicks while it is open, and their goals come in.
func _send_on_errands(seconds: float) -> void:
	await star_chart.open(seconds)
	await _pause(REVEAL_HOLD_SECONDS)
	transmission_panel.open(_get_errands())
	await transmission_panel.answered
	hud.reveal_bars()
	await hud.reveal([HudLayout.Part.RESOURCE_BAR, HudLayout.Part.ON_BOARD, HudLayout.Part.STATION])
	_give_goals(true)


# The Boss's transmission over the star chart: the things they left behind.
func _get_errands() -> Transmission:
	var errands := Transmission.from_boss(true)
	errands.caller_name = GoalsMetCall.CALLER
	errands.text = ERRANDS_TEXT
	errands.accept_text = ERRANDS_ANSWER
	return errands


# The Boss's goals replace the system's under their own heading: [param animated], as the
# goal panel swaps goals ([method GoalPanel.swap_goals]).
func _give_goals(animated: bool) -> void:
	goal_panel.swap_goals(ERRANDS_HEADER, _set_goals, animated)


# The Boss wears what has been fetched.
func _dress() -> void:
	var fetched: Array[String] = []
	for goal: Goal in goals.get_goals():
		if goal is FetchGoal and goal.is_met():
			fetched.append((goal as FetchGoal).thing)
	for passenger: Passenger in cabin.get_passengers():
		if BossPassenger.is_boss(passenger):
			BossPassenger.dress_up(passenger, BRIEFCASE in fetched, BOWTIE in fetched)


func _set_goals() -> void:
	for goal: Goal in goals.get_goals():
		goals.remove(goal)
	goals.frozen = false
	goals.add(FetchGoal.new(BRIEFCASE, briefcase_planet))
	goals.add(FetchGoal.new(BOWTIE, bowtie_planet))


func _set_answers(transmission: Transmission, answers: Array[String]) -> void:
	transmission.decline_text = answers[0]
	transmission.accept_text = answers[1]
	transmission.answers_alike = true


# The camera closes in on the place beside the planet, with the planet in view, the
# stargate appears there, and the camera draws back.
func _build_gate() -> void:
	rig.focus_rect = get_viewport().get_visible_rect()
	var reach := Stargate.DISTANCE + _gate.planet.get_body_radius()
	rig.focus(_gate, Stargate.RADIUS, reach)
	await _pause(rig.get_focus_seconds())
	await _gate.appear()
	Stargate.build_all(get_tree())
	await _pause(GATE_HOLD_SECONDS)
	rig.release_focus()
	await _pause(rig.get_focus_seconds())


# The row grows into the dock panel, and a guide card on it holds the game paused until
# the player presses it.
func _teach_row() -> void:
	var row := dock_panel.get_stargate_row()
	row.open(true)
	await _pause(CARD_SECONDS)
	hud.uncover()
	row.process_mode = Node.PROCESS_MODE_ALWAYS
	PauseMenu.hold(self)
	_cards.open("ROW", row.get_row(), {})
	await row.pressed
	_cards.close()
	guide.ring = false
	hud.cover()
	PauseMenu.release(self)
	row.process_mode = Node.PROCESS_MODE_INHERIT


# Holds the route, the bus and the camera through the meeting, or lets them go.
func _hold(held: bool) -> void:
	bus.route_locked = held
	bus.grounded = held
	rig.locked = held


# Waits [param seconds] of play.
func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


# The row pressed once the stargate is built: the star chart opens to go to another star.
func _on_row_pressed() -> void:
	if _busy or not is_built() or star_chart.is_open():
		return
	travel_pressed.emit()
