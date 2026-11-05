extends MarginContainer
## The Phase Miner HUD: the run's fuel, hull, score and combo, and a line saying what the last
## move did. The scene calls down to it after every move.


func show_run(field: PhaseField) -> void:
	%FuelLabel.text = "Fuel  %d / %d" % [field.fuel, PhaseField.TANK]
	%HullLabel.text = "Hull  %d / %d" % [maxi(field.hull, 0), PhaseField.START_HULL]
	%ScoreLabel.text = "Score  %d" % field.score
	%ComboLabel.text = "Combo  x%d   best x%d" % [field.combo, field.best_combo]


func show_message(text: String) -> void:
	%MessageLabel.text = text
