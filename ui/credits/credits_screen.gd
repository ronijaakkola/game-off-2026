extends MenuScreen
## The credits screen: the team, then what the game is made with and its licences. The
## main menu opens it over itself ([MenuScreen]). The engine's line names the version the
## game runs on, so it stays true after an upgrade.


func _ready() -> void:
	super._ready()
	var version := Engine.get_version_info()
	(%EngineName as Label).text = "Godot %d.%d.%d" % [version.major, version.minor, version.patch]
