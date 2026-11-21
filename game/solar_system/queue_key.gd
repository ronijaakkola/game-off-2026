class_name QueueKey
## The key the player holds to add a stop to the end of the route rather than replace it:
## the queue_stop action, Shift or Q. Firefox opens its own context menu on Shift + right
## click, and a page can't stop it, so Q works too, everywhere, and is the only one a guide
## card names there ([method get_icons]).


## Whether the player holds the key now.
static func is_held() -> bool:
	return Input.is_action_pressed(&"queue_stop")


## The key for a guide card to name, as [ControlIcons] in its text: Shift or Q, or only Q
## where Shift + right click opens the browser's menu.
static func get_icons() -> String:
	return "{q}" if _is_shift_taken() else "{shift} or {q}"


# Whether the browser is Firefox, which takes Shift + right click for its own menu.
static func _is_shift_taken() -> bool:
	if not OS.has_feature("web"):
		return false
	var agent: Variant = JavaScriptBridge.eval("navigator.userAgent", true)
	return agent is String and (agent as String).contains("Firefox")
