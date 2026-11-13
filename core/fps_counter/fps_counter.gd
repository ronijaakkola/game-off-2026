extends CanvasLayer
## The frame rate, in the top right corner over every scene, while
## [code]Settings.show_fps[/code] is on. It reads the setting every frame, so a change in
## the settings panel shows at once, paused or not.


func _process(_delta: float) -> void:
	visible = Settings.show_fps
	if visible:
		(%Label as Label).text = "%d FPS" % Engine.get_frames_per_second()
