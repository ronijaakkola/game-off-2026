extends CanvasLayer
## The frame rate, in the top right corner over every scene, while
## [code]Settings.show_fps[/code] is on, which the settings screen's Show FPS toggle turns
## on and off. It reads the setting every frame, so a change shows at once, paused or not.
## Beside it, only while one is changed, what the debug panel's rendering switches have
## turned off or changed.


func _process(_delta: float) -> void:
	visible = Settings.show_fps
	if visible:
		var switches := (%RenderDiagnostics as RenderDiagnostics).describe()
		var label := %Label as Label
		label.text = "%d FPS" % Engine.get_frames_per_second()
		if not switches.is_empty():
			label.text += " · " + switches
		# A Control only grows to fit, so squeeze it to nothing and let it grow back left
		# to the text, or its backing stays as wide as the longest text it ever held.
		label.offset_left = label.offset_right
