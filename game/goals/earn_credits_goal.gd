class_name EarnCreditsGoal
extends Goal
## A milestone: earn [member target] credits, counted from when the goal is added. Spending
## them takes nothing off: it counts what came in, from fares, quests and capsules alike.

var target: int
var earned := 0


func _init(credits: int) -> void:
	target = maxi(credits, 1)


func get_text() -> String:
	return "Earn %s credits" % CreditsCounter.group_digits(target)


func get_progress() -> float:
	return minf(float(earned) / target, 1.0)


func to_save() -> Dictionary:
	var saved := super()
	saved["earned"] = earned
	return saved


func load_save(saved: Dictionary) -> void:
	earned = int(saved.get("earned", earned))
	super(saved)


func _on_credits_earned(amount: int) -> void:
	earned += amount
	if earned >= target:
		_complete()
	else:
		changed.emit()
