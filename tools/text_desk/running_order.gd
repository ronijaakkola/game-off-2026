extends "res://tools/text_desk/order_builder.gd"
## The text desk's running order: every text the player reads, in sections in the order
## a run meets them, each with the stage that shows it as the game does. Text that comes
## at no fixed moment, such as what a passenger is doing, has its own sections after the
## moments it could first show in.
## It names where each text is, never what it says: a file and a key in it (the readers,
## gd_strings.gd and scene_strings.gd, say how a key reads). To move a moment, move its
## line here. A text this file doesn't name still shows on the desk, under
## [constant REST]: [method build] ends with every other text in the game that looks
## written for the player.
## test/tools/text_desk/running_order_test.gd fails when a key named here no longer finds
## a text, as after a constant is renamed.

const MENU := "res://ui/main_menu/main_menu.tscn"
const TITLE_CARD := "res://ui/main_menu/title_card.tscn"
const LEVEL_CARD := "res://ui/campaign/level_card.tscn"
const LEVEL_CARD_SCRIPT := "res://ui/campaign/level_card.gd"
const LOADING := "res://core/scene_flow/loading_card.gd"
const TUTORIAL_CALL := "res://game/tutorial/tutorial_call.gd"
const TUTORIAL_CARDS := "res://game/tutorial/tutorial_cards.gd"
const TUTORIAL_RIDE := "res://game/tutorial/tutorial_ride.gd"
const FIRST_SHIFT := "res://game/goals/first_shift_call.gd"
const GOAL_PANEL := "res://game/goals/goal_panel.gd"
const GOALS_MET := "res://game/goals/goals_met_call.gd"
const MECHANIC := "res://game/research/mechanic_call.gd"
const RESEARCH_GUIDE := "res://game/research/research_guide.gd"
const QUEST_GIVER := "res://game/quests/quest_giver.gd"
const VIP_CALLS := "res://game/quests/vip_calls.gd"
const NOTICE := "res://game/solar_system/notice.gd"
const NOTICES := "res://game/solar_system/notice_stack.gd"
const HEAT := "res://game/solar_system/heat_warning.gd"
const PROGRESSION := "res://game/solar_system/progression.gd"
const TREES := "res://game/research/trees/%s_tree.tres"
const HAPPINESS := "res://game/passengers/happiness_cause.gd"
const PASSENGER_TYPE := "res://game/passengers/passenger_type.gd"

## A quest's file, what its lines are called there, and who says them.
const QUESTS: Array[Array] = [
	["errand", ["LINES"], "passenger"],
	["errand", ["BUSINESS_LINES"], "business"],
	["express", ["LINES"], "passenger"],
	["flyby", ["LINES"], "passenger"],
	["warp", ["LINES"], "passenger"],
	["photo_stop", ["PHOTO_LINES"], "business"],
	["rock_ride", ["LINES"], "business"],
	["sauna", ["LINES"], "business"],
	["rescue", ["LINES", "RETURNING_LINES"], "castaway"],
	["hop", ["HOP_LINES", "HOP_RETURNING_LINES"], "castaway"],
	["vip_tour", ["LINES"], "vip"],
]


## The whole running order, read from the game's files.
func build() -> Array[Section]:
	_sections.clear()
	_named.clear()
	_add_start()
	_add_tutorial()
	_add_first_shift()
	_add_shift()
	_add_passengers()
	_add_hints()
	_add_quests()
	_add_research()
	_add_promotion()
	_add_menus()
	add_rest()
	return _sections


func _add_start() -> void:
	section("1. Main menu and loading")
	all(TITLE_CARD, "node:", "label", {button = false})
	all(MENU, "node:", "label", {button = true})
	all(LEVEL_CARD, "node:", "label")
	all(LEVEL_CARD_SCRIPT, "show_level", "label")
	for level: int in [1, 2, 3]:
		one(
			"Level %d's name" % level,
			"label",
			{title = ["res://shared/level_art/level_%d.tres" % level, "resource/title"]}
		)
	all(LOADING, "TIPS/", "label", {width = 360})
	all(LOADING, "show_", "label")


func _add_tutorial() -> void:
	section("2. Tutorial")
	call_from(
		"The Boss's first call",
		TUTORIAL_CALL,
		"boss",
		"FIRST_CALLER",
		["FIRST_TEXT"],
		"FIRST_ANSWERS"
	)
	groups(TUTORIAL_CARDS, "CARDS/", "guide", {got_it = true})
	one("{stars} in the Rating card", "label", {text = [TUTORIAL_RIDE, "describe_rating"]})
	call_from(
		"The Boss's last call", TUTORIAL_CALL, "boss", "LAST_CALLER", ["LAST_TEXT"], "LAST_ANSWERS"
	)


func _add_first_shift() -> void:
	section("3. First shift (Vela)")
	one("A call rings", "notice", {text = [NOTICES, "CALL_TEXT"]}, {kind = "call"})
	one("A caller the player hasn't met", "label", {text = [NOTICE, "UNKNOWN_CALLER"]})
	call_from(
		"The Boss's welcome", FIRST_SHIFT, "boss", "CALLER", ["OPENING", "WELCOME"], "ANSWERS"
	)
	call_from(
		"The Boss's welcome, left ringing",
		FIRST_SHIFT,
		"boss",
		"CALLER",
		["UNANSWERED_OPENING", "WELCOME"],
		"ANSWERS",
		{mood = "annoyed"}
	)
	hint("goals")
	one("Goal panel header", "label", {text = [GOAL_PANEL, "HEADER"]})
	for goal: String in ["delivery_count", "earn_credits", "rating"]:
		all("res://game/goals/%s_goal.gd" % goal, "get_text", "label", {width = 200})
	planets("vela")


func _add_shift() -> void:
	section("4. During a shift: panels, notices and stamps")
	all("res://game/solar_system/dock_panel.tscn", "node:", "label")
	all("res://game/solar_system/dock_panel.gd", "_show_buttons", "label", {button = true})
	all("res://game/solar_system/boarding_row.gd", "_show_along", "label")
	all("res://game/solar_system/fuel_button.gd", "IDLE_TEXT", "label", {button = true})
	all("res://game/solar_system/fuel_pump.gd", "get_stop", "notice", {kind = "error"})
	all("res://game/bus/route_bar.gd", "STATE_TEXTS/", "label")
	all("res://game/bus/route_bar.gd", "_status_text", "label")
	all("res://game/bus/route_bar.gd", "_flying_text", "label")
	one("Bus full", "notice", {text = [NOTICES, "BUS_FULL"]})
	one(
		"Low fuel",
		"notice",
		{text = ["res://game/solar_system/low_fuel_warning.gd", "TEXT"]},
		{kind = "warning"}
	)
	one(
		"Out of fuel",
		"notice",
		{text = [NOTICES, "offer_tow"], action = [NOTICES, "offer_tow#1"]},
		{kind = "error"}
	)
	one("Overheating", "notice", {text = [HEAT, "WARNING_TEXT"]}, {kind = "warning"})
	one("Overheated", "notice", {text = [HEAT, "OVERHEATED_TEXT"]}, {kind = "error"})
	one("Cooled down", "notice", {text = [HEAT, "COOLED_TEXT"]})
	one(
		"Reserve tank opens", "quick", {text = ["res://game/bus/bus_quick_text.gd", "RESERVE_TEXT"]}
	)
	one("Quick stop", "quick", {text = ["res://game/solar_system/solar_system.gd", "QUICK_STOP"]})
	one(
		"Knocked in the rocks",
		"quick",
		{text = ["res://game/asteroid_field/asteroid_field.gd", "ROUGH_RIDE"]},
		{kind = "loss"}
	)
	one(
		"Capsule: someone inside",
		"quick",
		{text = ["res://game/capsules/capsule_field.gd", "RESCUED_TEXT"]},
		{kind = "gain"}
	)
	one(
		"Capsule: they jump out",
		"quick",
		{text = ["res://game/capsules/capsule_field.gd", "HOPPED_TEXT"]},
		{kind = "gain"}
	)
	all("res://game/capsules/capsule_field.gd", "_collect", "label")
	tooltip("Credits", "res://game/solar_system/credits_counter.tscn", "node:Tooltip")
	tooltip("Research points", "res://game/solar_system/research_counter.tscn", "node:Tooltip")
	tooltip("Rating", "res://game/solar_system/rating_counter.tscn", "node:Tooltip")
	tooltip("Menu button", "res://ui/pause_menu/pause_button.tscn", "node:Card/Button/Tooltip")
	for tip: Array in [
		["Drifting capsule", "res://game/capsules/capsule_tooltip.gd", "TEXT"],
		["Asteroid field", "res://game/asteroid_field/asteroid_field_tooltip.gd", "TEXT"],
		["Warp drive", "res://game/warp_gate/warp_gate_tooltip.gd", "TEXT"],
		["Research planet", "res://game/solar_system/lab_badges.gd", "TOOLTIP_TEXT"],
		["Remove a stop", "res://game/bus/remove_badge.gd", "TEXT"],
	]:
		one("Tooltip: %s" % tip[0], "tooltip", {title = [tip[1], tip[2]]})
	all("res://game/solar_system/waiting_markers.gd", "_show_tooltip", "tooltip", {role = "text"})
	all("res://game/warp_gate/gate_service.gd", "TEXT", "label", {button = true})
	all("res://game/bus/bus_panel.tscn", "node:", "label")
	all("res://game/bus/bus_panel.gd", "STAT_NAMES/", "label")
	all("res://game/bus/bus_panel.gd", "TRAIT_NAMES/", "label")


func _add_passengers() -> void:
	section("5. Passengers: what they are doing and how they feel (any time)")
	all("res://game/passengers/passenger_panel.tscn", "node:", "label")
	one(
		"Boarding",
		"label",
		{text = ["res://game/passengers/passenger.gd", "BOARDING_LINE"]},
		{width = 150}
	)
	all(PASSENGER_TYPE, "idle_lines/", "label", {width = 150})
	all(PASSENGER_TYPE, "docked_lines/", "label", {width = 150})
	for need: String in ["snack", "drink"]:
		all("res://game/passengers/needs/%s.tres" % need, "resource/", "label", {width = 150})
	for amenity: String in ["food_dispenser", "serving_robots"]:
		all(
			"res://game/passengers/amenities/%s.tres" % amenity, "resource/", "label", {width = 150}
		)
	one(
		"Station serves them",
		"label",
		{text = ["res://game/passengers/cabin.gd", "STATION_LINE"]},
		{width = 150}
	)
	one(
		"Getting off",
		"label",
		{text = ["res://game/passengers/passenger_card.gd", "show_rating"]},
		{width = 150}
	)
	all(HAPPINESS, "get_ups", "label", {width = 150})
	all(HAPPINESS, "get_downs", "label", {width = 150})
	all(HAPPINESS, "EVENT_LABELS/", "label", {width = 150})
	one(
		"Bus quality",
		"label",
		{text = ["res://game/passengers/comfort.gd", "from_traits"]},
		{width = 150}
	)
	one(
		"Tooltip: docked",
		"tooltip",
		{text = ["res://game/passengers/docked_mark.gd", "TOOLTIP_TEXT"]}
	)
	one(
		"Tooltip: frustrated",
		"tooltip",
		{text = ["res://game/passengers/happiness_cap.gd", "TOOLTIP_TEXT"]}
	)
	one(
		"Tooltip: returning passenger",
		"tooltip",
		{
			title = ["res://game/passengers/passenger_photo.gd", "RETURNING_TITLE"],
			text = ["res://game/passengers/passenger_photo.gd", "RETURNING_TEXT"]
		}
	)
	for type: String in ["business", "vip"]:
		one(
			"Tooltip: %s badge" % type,
			"tooltip",
			{text = ["res://game/passengers/types/%s.tres" % type, "resource/description"]}
		)


func _add_hints() -> void:
	section("6. Feature hints, as the player meets each")
	for hint: String in [
		"business", "returning", "quests", "heat_zone", "asteroid_field", "warp_drive", "vip"
	]:
		hint(hint)


func _add_quests() -> void:
	section("7. Quests: passengers calling")
	for quest: Array in QUESTS:
		var path := "res://game/quests/%s_quest.gd" % quest[0]
		for lines: String in quest[1]:
			for key: String in keys(path, lines + "/"):
				var roles := {text = [path, key], quest = [path, "get_ask"]}
				var title := "%s (%s) %s" % [str(quest[0]).capitalize(), quest[2], key.get_file()]
				one(title, "transmission", roles, {caller = quest[2]})
		all(path, "get_ask#", "label")
		all(path, "get_transmission", "label")
		all("res://game/goals/%s_goal.gd" % quest[0], "get_text", "label", {width = 200})
	one("VIP: unknown caller", "label", {text = [VIP_CALLS, "UNKNOWN_NAME"]})
	one("VIP: waiting marker", "tooltip", {title = [VIP_CALLS, "MARKER_LINE"]})
	hint("quests")
	one("Quest done", "quick", {text = [QUEST_GIVER, "COMPLETED_TEXT"]}, {kind = "gain"})
	one("Quest failed", "quick", {text = [QUEST_GIVER, "FAILED_TEXT"]}, {kind = "loss"})
	one("Quest done notice", "notice", {text = [QUEST_GIVER, "_on_goal_completed"]})
	one(
		"Quest failed notice",
		"notice",
		{text = [QUEST_GIVER, "_on_goal_failed"]},
		{kind = "warning"}
	)


func _add_research() -> void:
	section("8. Research: the mechanic and the lab")
	call_from(
		"Rusty opens research", MECHANIC, "mechanic", "", ["RESEARCH_TEXT"], "RESEARCH_ANSWERS"
	)
	groups(RESEARCH_GUIDE, "CARDS/", "guide", {got_it = true})
	one("{what} in the New upgrades cards", "label", {text = [RESEARCH_GUIDE, "REMIND_TEXT"]})
	all("res://game/research/research_screen.tscn", "node:", "label")
	one(
		"Locked upgrade",
		"label",
		{text = ["res://game/research/research_screen.gd", "PROMOTION_TEXT"]}
	)
	one(
		"Can't afford", "label", {text = ["res://game/research/upgrade_tooltip.gd", "LACKING_TEXT"]}
	)
	for tree: String in ["blue", "green", "orange"]:
		groups(TREES % tree, "sub:", "tooltip", {}, "Upgrade: ")
	call_from("Rusty's second shipment", MECHANIC, "mechanic", "", ["STAGE_TEXTS/0"], "ANSWERS")
	call_from("Rusty's last shipment", MECHANIC, "mechanic", "", ["STAGE_TEXTS/1"], "ANSWERS")
	one(
		"Rusty's last shipment in Sol",
		"transmission",
		{
			text = [SYSTEMS % "sol", "node:./mechanic_call"],
			decline = [MECHANIC, "ANSWERS/0"],
			accept = [MECHANIC, "ANSWERS/1"]
		},
		{caller = "mechanic", alike = true}
	)


func _add_promotion() -> void:
	section("9. Promotion and the next star systems")
	one(
		"The Boss's promotion",
		"transmission",
		{
			caller = [GOALS_MET, "CALLER"],
			opening = [GOALS_MET, "TEXT"],
			text = [GOALS_MET, "OFFER"],
			decline = [GOALS_MET, "STAY_ANSWER"],
			accept = [GOALS_MET, "JUMP_ANSWER"]
		},
		{caller = "boss"}
	)
	one(
		"The Boss's promotion, left ringing",
		"transmission",
		{
			caller = [GOALS_MET, "CALLER"],
			opening = [GOALS_MET, "UNANSWERED_TEXT"],
			text = [GOALS_MET, "OFFER"],
			decline = [GOALS_MET, "STAY_ANSWER"],
			accept = [GOALS_MET, "JUMP_ANSWER"]
		},
		{caller = "boss", mood = "annoyed"}
	)
	one("Promoted", "label", {text = [GOAL_PANEL, "PROMOTED_HEADER"]})
	one("Jump card", "label", {text = ["res://game/goals/jump_card.gd", "LEVEL"]}, {button = true})
	hint("jump")
	one(
		"Lyra: the Boss on arrival",
		"transmission",
		{
			caller = [FIRST_SHIFT, "CALLER"],
			text = [SYSTEMS % "lyra", "node:./arrival_call"],
			decline = [FIRST_SHIFT, "ANSWERS/0"],
			accept = [FIRST_SHIFT, "ANSWERS/1"]
		},
		{caller = "boss", alike = true}
	)
	planets("lyra")
	one(
		"Lyra: the Boss's promotion",
		"transmission",
		{
			caller = [GOALS_MET, "CALLER"],
			opening = [GOALS_MET, "TEXT"],
			text = [SYSTEMS % "lyra", "node:./promotion_call"],
			decline = [GOALS_MET, "STAY_ANSWER"],
			accept = [GOALS_MET, "JUMP_ANSWER"]
		},
		{caller = "boss"}
	)
	one(
		"Sol: the Boss on arrival",
		"transmission",
		{
			caller = [FIRST_SHIFT, "CALLER"],
			text = [SYSTEMS % "sol", "node:./arrival_call"],
			decline = [FIRST_SHIFT, "ANSWERS/0"],
			accept = [FIRST_SHIFT, "ANSWERS/1"]
		},
		{caller = "boss", alike = true}
	)
	planets("sol")
	all(
		"res://game/solar_system/dock_panel.tscn",
		"node:Card/Clip/Content/AbandonedMessage",
		"label"
	)
	one(
		"The Boss joins every system",
		"transmission",
		{
			caller = [GOALS_MET, "CALLER"],
			opening = [GOALS_MET, "TEXT"],
			text = [GOALS_MET, "JOIN_OFFER"],
			accept = [GOALS_MET, "JOIN_ANSWER"]
		},
		{caller = "boss"}
	)
	one("Every system joined", "notice", {text = [PROGRESSION, "JOINED"]})


func _add_menus() -> void:
	section("10. Menus (any time)")
	all("res://ui/pause_menu/pause_menu.tscn", "node:", "label", {button = true})
	all("res://ui/settings/settings_menu.tscn", "node:", "label")
	all("res://ui/controls/controls_screen.tscn", "node:", "label")
	all("res://ui/campaign/campaign_screen.tscn", "node:", "label")
	all("res://ui/campaign/campaign_screen.gd", "_pick", "label", {button = true})
	all("res://ui/campaign/restart_dialog.gd", "ask", "label", {width = 280})
	all("res://ui/credits/credits_screen.tscn", "node:", "label")
	all("res://ui/guide_card/guide_card.tscn", "node:Pad/Rows/Header", "label")
	all("res://ui/guide_card/guide_card.tscn", "node:Pad/Rows/Footer", "label", {button = true})
