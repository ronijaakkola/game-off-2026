extends Node
## The text desk's stages: shows an entry's text in the running game with the widget the
## player reads it in, and says how it fits there. A call opens the real transmission
## panel, a notice joins the real notice stack and a stamp lands over the bus; a guide
## card, a tooltip and a plain label are the game's own scenes on the HUD, pointing at a
## spot left of the desk rather than at what they belong to in play.
## Names the game fills in show as samples ([constant SAMPLES], and a planet for each
## [code]%s[/code]), so a text reads at about its real length.

const Entry := preload("res://tools/text_desk/desk_entry.gd")

const GUIDE := preload("res://ui/guide_card/guide_card.tscn")
const TOOLTIP := preload("res://ui/tooltip/tooltip.tscn")
const THEME := preload("res://ui/theme.tres")
const BUSINESS := preload("res://game/passengers/types/business.tres")
const VIP := preload("res://game/passengers/types/vip.tres")
## What stands in for the names a text leaves to the game.
const SAMPLES := {
	"home": "Terra",
	"destination": "Moon",
	"stars": "5 stars",
	"queue_key": "{shift}",
	"planet": "Giant",
	"what": "Your mechanic brought new upgrades for every tree.",
}
const SAMPLE_NAMES: Array[String] = ["Frost", "Giant", "Terra"]
## Where on the HUD a guide card and a tooltip point, and where a label sits.
const SPOT := Rect2(300.0, 300.0, 40.0, 40.0)
const LABEL_AT := Vector2(300.0, 240.0)
## The most lines a guide card's text is drawn for (GuideCard's own comment).
const GUIDE_LINES := 3
const NOTICE_KINDS := {
	"info": Notice.Kind.INFO,
	"warning": Notice.Kind.WARNING,
	"error": Notice.Kind.ERROR,
	"tutorial": Notice.Kind.TUTORIAL,
}
const QUICK_KINDS := {
	"remark": BusQuickText.Kind.REMARK,
	"gain": BusQuickText.Kind.GAIN,
	"loss": BusQuickText.Kind.LOSS,
}
const TAG := "\\[/?[a-z_]+[^\\]]*\\]"

## The running solar system the stages show in. Set before it enters the tree.
var solar: Node

var _stage := ""
var _hud: CanvasLayer
var _panel: TransmissionPanel
var _notices: NoticeStack
var _quick: BusQuickText
var _planets: Array[Planet] = []
var _looks: Dictionary[String, AlienLook] = {}
var _guide: GuideCard
var _tooltip: Tooltip
var _target: Control
var _notice: Notice
# The entry the notice showing was pushed for.
var _notice_entry: Entry
var _card: PanelContainer
var _title: Label
var _body: Label
var _button: Button
var _tag := RegEx.create_from_string(TAG)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hud = solar.get_node(^"Hud") as CanvasLayer
	_panel = solar.get_node(^"TransmissionPanel") as TransmissionPanel
	_notices = solar.get_node(^"Hud/Notices") as NoticeStack
	_quick = solar.get_node(^"Hud/BusQuickText") as BusQuickText
	_find_planets(solar)
	_guide = GUIDE.instantiate() as GuideCard
	_guide.side = GuideCard.Side.RIGHT
	_hud.add_child(_guide)
	_target = Control.new()
	_target.position = SPOT.position
	_target.size = SPOT.size
	_target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_target)
	_tooltip = TOOLTIP.instantiate() as Tooltip
	_tooltip.target = _target
	_tooltip.side = Tooltip.Side.RIGHT
	_hud.add_child(_tooltip)
	_add_label()


## Shows [param entry] as the game would. With [param replay], from the start, as a call
## typing itself out; otherwise a text already showing changes where it is.
func show_entry(entry: Entry, replay := false) -> void:
	if entry.stage != _stage:
		_clear()
		_stage = entry.stage
	var values := entry.get_values()
	match entry.stage:
		"transmission":
			_show_call(entry, values, replay)
		"guide":
			_show_guide(entry, values)
		"tooltip":
			_show_tooltip(values)
		"notice":
			_show_notice(entry, values, replay)
		"quick":
			_show_quick(entry, values)
		_:
			_show_label(entry, values)


## How [param entry]'s text fits where it shows, in a line or two, and whether it runs
## past what the widget is drawn for. Ask a frame or two after [method show_entry], once
## the widget has laid it out.
func describe(entry: Entry) -> Dictionary:
	var values := entry.get_values()
	var said := fill(values.get("opening", "") + values.get("text", values.get("title", "")))
	var letters := _tag.sub(said, "", true).length()
	match entry.stage:
		"transmission":
			var message := _panel.get_node(^"%Message") as RichTextLabel
			var modal := _panel.get_node(^"%Modal") as Control
			var grown := modal.size.y > modal.custom_minimum_size.y + 0.5
			var size := "%d letters on %d lines." % [letters, message.get_line_count()]
			if grown:
				size += (
					" The modal has grown to %d px, past its %d."
					% [modal.size.y, modal.custom_minimum_size.y]
				)
			return {text = size, over = grown}
		"guide":
			var lines := (_guide.get_node(^"%BodyLabel") as RichTextLabel).get_line_count()
			var size := (
				"%d letters on %d lines; the card is drawn for 1 to %d."
				% [letters, lines, GUIDE_LINES]
			)
			return {text = size, over = lines > GUIDE_LINES}
		"tooltip":
			var lines := (_tooltip.get_node(^"%SentenceLabel") as Label).get_line_count()
			return {text = "%d letters on %d lines." % [letters, lines], over = lines > 3}
		"notice", "quick":
			return {text = "%d letters." % letters, over = false}
	var font := _body.get_theme_font(&"font")
	var width := font.get_string_size(
		said, HORIZONTAL_ALIGNMENT_LEFT, -1, _body.get_theme_font_size(&"font_size")
	)
	var room: float = entry.options.get("width", 0.0)
	var fit := "%d letters, %d px wide on one line" % [letters, width.x]
	if room > 0.0:
		fit += ", in about %d px: %d lines" % [room, _body.get_line_count()]
	return {text = fit + ".", over = false}


## [param text] with a sample for each name the game fills in.
static func fill(text: String) -> String:
	var filled := text.format(SAMPLES)
	var count := 0
	while filled.contains("%s"):
		var at := filled.find("%s")
		var sample := SAMPLE_NAMES[count % SAMPLE_NAMES.size()]
		filled = filled.substr(0, at) + sample + filled.substr(at + 2)
		count += 1
	filled = filled.replace("%.1f", "4.0").replace("%+d", "+3").replace("%d", "3")
	return filled.replace("%%", "%")


func _show_call(entry: Entry, values: Dictionary[String, String], replay: bool) -> void:
	var call := _caller(entry.options.get("caller", "passenger"))
	if values.has("caller"):
		call.caller_name = fill(values["caller"])
	call.text = fill(values.get("opening", "") + values.get("text", ""))
	if values.has("quest"):
		call.quest = fill(values["quest"])
		call.quest_planet = _planets[1 % _planets.size()]
		call.reward_credits = 140
		call.reward_research = 2
		call.accept_text = "Yes"
		call.decline_text = "No"
	call.accept_text = values.get("accept", call.accept_text)
	call.decline_text = values.get("decline", call.decline_text)
	call.answers_alike = entry.options.get("alike", false)
	if entry.options.get("mood", "") == "annoyed":
		call.mood = Passenger.Mood.ANNOYED
	if _panel.is_open() and not replay:
		_panel._fill(call)
		return
	_panel.open(call)
	if not replay:
		_panel.skip()


func _show_guide(entry: Entry, values: Dictionary[String, String]) -> void:
	var hint: bool = entry.options.get("hint", false)
	_guide.kind = GuideCard.Kind.FEATURE_HINT if hint else GuideCard.Kind.TUTORIAL_STEP
	_guide.got_it = entry.options.get("got_it", false)
	_guide.title = fill(values.get("title", ""))
	_guide.text = fill(values.get("text", ""))
	_guide.target_rect = SPOT
	# Nothing happens while it is open.
	_guide.open()


func _show_tooltip(values: Dictionary[String, String]) -> void:
	_tooltip.title = fill(values.get("title", ""))
	_tooltip.sentence = fill(values.get("text", ""))
	_tooltip.open(true)


func _show_notice(entry: Entry, values: Dictionary[String, String], replay: bool) -> void:
	var text := fill(values.get("text", ""))
	var action := fill(values.get("action", ""))
	var showing := is_instance_valid(_notice) and not _notice.is_leaving()
	# Only its own notice changes in place: another entry has its own kind and button.
	if showing and entry == _notice_entry and not replay:
		(_notice.get_node(^"%Label") as Label).text = text
		if action != "":
			(_notice.get_node(^"%ActionButton") as Button).text = action
		return
	if showing:
		_notice.dismiss()
	_notice_entry = entry
	var kind: String = entry.options.get("kind", "info")
	if kind == "call":
		_notice = _notices.announce_transmission(_caller("boss"))
		(_notice.get_node(^"%Label") as Label).text = text
	else:
		_notice = _notices.push(text, NOTICE_KINDS[kind], false, 0.0, action)


func _show_quick(entry: Entry, values: Dictionary[String, String]) -> void:
	var kind: BusQuickText.Kind = QUICK_KINDS[entry.options.get("kind", "remark")]
	_quick.show_text(fill(values.get("text", "")), BusQuickText.DEBUG_ICONS[kind], kind)


func _show_label(entry: Entry, values: Dictionary[String, String]) -> void:
	var as_button: bool = entry.options.get("button", false)
	var text := fill(values.get("text", ""))
	_title.text = fill(values.get("title", ""))
	_title.visible = _title.text != ""
	_body.text = text
	_body.visible = not as_button and text != ""
	var width: float = entry.options.get("width", 0.0)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if width > 0.0 else TextServer.AUTOWRAP_OFF
	_body.custom_minimum_size.x = width
	_title.autowrap_mode = _body.autowrap_mode
	_title.custom_minimum_size.x = width
	_button.text = text
	_button.visible = as_button
	_card.show()
	# A wrapping label knows its height only once it has its width, a frame on.
	_card.size = Vector2(width, 0.0)
	await get_tree().process_frame
	_card.reset_size()


# Takes away what the last stage showed.
func _clear() -> void:
	_panel.close()
	_guide.close()
	_tooltip.close()
	if is_instance_valid(_notice) and not _notice.is_leaving():
		_notice.dismiss()
	_notice = null
	_notice_entry = null
	_card.hide()


# Who calls: The Boss, the mechanic, or a passenger of a kind, with the same face each
# time.
func _caller(who: String) -> Transmission:
	if who == "boss":
		return Transmission.from_boss()
	if who == "mechanic":
		return Transmission.from_mechanic()
	var call := Transmission.new()
	var race := Race.Type.BLUE if who == "business" else Race.Type.GREEN
	if not _looks.has(who):
		var dice := RandomNumberGenerator.new()
		dice.seed = who.hash()
		_looks[who] = AlienLook.random(dice, race)
	call.look = _looks[who]
	call.race = race
	call.caller_name = Castaway.NAME if who == "castaway" else "Reizhis"
	call.destination = _planets[0] if who != "castaway" else null
	if who == "business":
		call.type = BUSINESS
	elif who == "vip":
		call.type = VIP
		call.backdrop_color = Vip.BACKDROP
	elif who == "castaway":
		call.in_space = true
		call.backdrop_color = Color(0.1, 0.1, 0.26)
	return call


func _find_planets(node: Node) -> void:
	for child: Node in node.get_children():
		var planet := child as Planet
		if planet and planet.display_name != "":
			_planets.append(planet)
		_find_planets(child)


# The plain stage: a card with a title, a text or a button, for a text with no widget of
# its own here.
func _add_label() -> void:
	_card = PanelContainer.new()
	_card.theme = THEME
	_card.theme_type_variation = &"TooltipCardPanel"
	_card.position = LABEL_AT
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rows := VBoxContainer.new()
	_card.add_child(rows)
	_title = Label.new()
	rows.add_child(_title)
	_body = Label.new()
	rows.add_child(_body)
	_button = Button.new()
	_button.focus_mode = Control.FOCUS_NONE
	rows.add_child(_button)
	_card.hide()
	_hud.add_child(_card)
