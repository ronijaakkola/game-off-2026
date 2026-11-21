class_name QueueKey
## The key the player holds to add a stop to the end of the route rather than replace it:
## the queue_stop action, Shift or Q. Firefox opens its own context menu on Shift + right
## click, and a page can't stop it, so Q works too, everywhere; a guide card names Shift,
## and Q only in Firefox ([method get_icons]). That menu also takes the release of Shift, which
## leaves the key down for good as far as [Input] knows, so the pointer's events, which
## carry the browser's own word on Shift, overrule it.

# Whether Input holds Shift down while the pointer last said it was up.
static var _shift_is_stuck := false


## Whether the player holds the key now.
static func is_held() -> bool:
	if not Input.is_action_pressed(&"queue_stop"):
		return false
	return not _shift_is_stuck or Input.is_physical_key_pressed(KEY_Q)


## Reads from [param event], when it is the pointer's, whether Shift is really down. Call
## it with every input event, before anything asks [method is_held].
static func read(event: InputEvent) -> void:
	var pointer := event as InputEventMouse
	if pointer:
		_shift_is_stuck = Input.is_physical_key_pressed(KEY_SHIFT) and not pointer.shift_pressed


## The key for a guide card to name, as [ControlIcons] in its text: Shift, or Q where
## Shift + right click opens the browser's menu. Never both.
static func get_icons() -> String:
	return "{q}" if _is_shift_taken() else "{shift}"


# Whether the browser is Firefox, which takes Shift + right click for its own menu.
static func _is_shift_taken() -> bool:
	if not OS.has_feature("web"):
		return false
	var agent: Variant = JavaScriptBridge.eval("navigator.userAgent", true)
	return agent is String and (agent as String).contains("Firefox")
