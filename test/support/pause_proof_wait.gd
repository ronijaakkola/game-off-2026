extends RefCounted
## Waits that keep their deadline while the tree is paused. gdUnit's own timeouts are
## pausable Timers, so a test that awaits with them while paused hangs instead of
## failing. This deadline is wall-clock time, checked every frame: process_frame keeps
## firing while paused.


## Waits up to [param timeout_ms] of wall-clock time for [param sig]. Returns whether it
## fired.
static func for_signal(sig: Signal, timeout_ms: int) -> bool:
	# A lambda captures locals by value, so it flags through an array.
	var fired := [false]
	var on_fired := func(..._args: Array) -> void: fired[0] = true
	sig.connect(on_fired, CONNECT_ONE_SHOT)
	var tree := Engine.get_main_loop() as SceneTree
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not fired[0] and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	if sig.is_connected(on_fired):
		sig.disconnect(on_fired)
	return fired[0]
