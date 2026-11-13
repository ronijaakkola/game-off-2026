extends CanvasLayer
## The frame rate, in the top right corner over every scene, while
## [code]Settings.show_fps[/code] is on. It reads the setting every frame, so a change in
## the settings panel shows at once, paused or not. Beside it, the size the game renders at
## in real pixels, and the MSAA and whatever else the debug panel's rendering switches set.


func _process(_delta: float) -> void:
	visible = Settings.show_fps
	if visible:
		var size := get_window().size
		var switches := (%RenderDiagnostics as RenderDiagnostics).describe()
		var fps := Engine.get_frames_per_second()
		var label := %Label as Label
		label.text = "%d FPS · %d×%d · %s" % [fps, size.x, size.y, switches]
		# A Control only grows to fit, so squeeze it to nothing and let it grow back left
		# to the text, or its backing stays as wide as the longest text it ever held.
		label.offset_left = label.offset_right
