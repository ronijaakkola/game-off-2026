class_name QueueKey
## The key the player holds to add a stop to the end of the route rather than replace it:
## the queue_stop action, Shift or Q. Firefox opens its own context menu on Shift + right
## click, and a page can't stop it, so in Firefox the hints name Q. Both work everywhere,
## so a wrong guess at the browser locks nobody out.


## The key to name in hints: "Q" in Firefox, "Shift" anywhere else.
static func get_label() -> String:
	if OS.has_feature("web"):
		var agent: Variant = JavaScriptBridge.eval("navigator.userAgent", true)
		if agent is String and (agent as String).contains("Firefox"):
			return "Q"
	return "Shift"


## Whether the player holds the key now.
static func is_held() -> bool:
	return Input.is_action_pressed(&"queue_stop")
