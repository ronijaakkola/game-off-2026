class_name QuestKinds
extends RefCounted
## Every kind of [Quest], the one list a saved quest is put back from ([method make]). A kind
## missing here would vanish from a continued run, so its test fails on any class that
## extends [Quest] and isn't listed.

const ALL: Array[GDScript] = [
	preload("res://game/quests/express_quest.gd"),
	preload("res://game/quests/flyby_quest.gd"),
	preload("res://game/quests/errand_quest.gd"),
	preload("res://game/quests/photo_stop_quest.gd"),
	preload("res://game/quests/warp_quest.gd"),
	preload("res://game/quests/rock_ride_quest.gd"),
	preload("res://game/quests/sauna_quest.gd"),
	preload("res://game/quests/rescue_quest.gd"),
	preload("res://game/quests/vip_tour_quest.gd"),
]


## A new quest of the kind [method Quest.get_kind] names [param kind], or null for a kind
## that isn't one.
static func make(kind: String) -> Quest:
	for script: GDScript in ALL:
		var quest := script.new() as Quest
		if quest.get_kind() == kind:
			return quest
	return null
