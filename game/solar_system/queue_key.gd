class_name QueueKey
## The key the player holds to add a stop to the end of the route rather than replace it:
## the queue_stop action, Shift or Q. Firefox opens its own context menu on Shift + right
## click, and a page can't stop it, so Q works too, everywhere.


## Whether the player holds the key now.
static func is_held() -> bool:
	return Input.is_action_pressed(&"queue_stop")
