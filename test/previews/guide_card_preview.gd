extends Node
## The solar system with guide cards on the HUD, as in the design: a tutorial step under the
## On board panel, another over the bus bars, and a feature hint beside the station's fuel row.
## `-- edge` points the first at a spot near the screen's right edge instead, so the card
## stops 12 px inside it and its notch slides along to stay on the spot. `-- paused` pauses
## the game first, as a feature hint does, so the cards must fade in and place while paused.
## `-- next` closes the bottom card 1 s in and opens it again on the next step, with new
## text, so its dots move on (about 1.4 to 2 s in, `--frames 130`).

const CARD := preload("res://ui/guide_card/guide_card.tscn")


func _ready() -> void:
	var hud := $SolarSystem/Hud as CanvasLayer
	await get_tree().process_frame
	get_tree().paused = "paused" in OS.get_cmdline_user_args()
	var top := _add(hud, GuideCard.Kind.TUTORIAL_STEP, GuideCard.Side.BELOW)
	top.title = "Your passengers"
	top.text = "Everyone on the bus has a card here, with how happy they are."
	top.step = 1
	top.step_count = 5
	if "edge" in OS.get_cmdline_user_args():
		var screen := get_viewport().get_visible_rect().size
		top.target_rect = Rect2(screen.x - 60.0, 300.0, 24.0, 24.0)
	else:
		top.target = hud.get_node(^"PassengerPanel") as Control
	top.open()
	var bottom := _add(hud, GuideCard.Kind.TUTORIAL_STEP, GuideCard.Side.ABOVE)
	bottom.title = "Leave for the Moon"
	bottom.text = "Hold Frameshift to charge the drive. Let go early and the charge drains back."
	bottom.step = 2
	bottom.step_count = 5
	bottom.target = hud.get_node(^"BusStatusPanel") as Control
	bottom.open()
	var feature := _add(hud, GuideCard.Kind.FEATURE_HINT, GuideCard.Side.LEFT)
	feature.title = "Fuel"
	feature.text = "This planet sells fuel. Hold the button to fill the tank."
	feature.target = hud.get_node(^"TopRight/Stack/DockPanel/Card/Clip/Content/FuelRow") as Control
	feature.open()
	if "next" in OS.get_cmdline_user_args():
		await get_tree().create_timer(1.0).timeout
		bottom.close()
		await get_tree().create_timer(0.2).timeout
		bottom.title = "Serve your passenger"
		bottom.text = "They want a snack. Hold the button on their card."
		bottom.step = 3
		bottom.open()


func _add(hud: CanvasLayer, kind: GuideCard.Kind, side: GuideCard.Side) -> GuideCard:
	var card := CARD.instantiate() as GuideCard
	card.kind = kind
	card.side = side
	hud.add_child(card)
	return card
