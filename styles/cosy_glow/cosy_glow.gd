extends "res://styles/style_base.gd"
## Cosy glow: the base scene dressed as a teal dusk with one warm light. Keys 1 to 4 switch
## the pieces on and off, so a browser build can show what each of them costs and does.

@onready var _environment: Environment = (%WorldEnvironment as WorldEnvironment).environment
@onready var _fakes: Node3D = %Fakes
@onready var _vignette: CanvasLayer = %Vignette
@onready var _hud: Label = %Hud


func _ready() -> void:
	_refresh_hud()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			_environment.glow_enabled = not _environment.glow_enabled
		KEY_2:
			_environment.fog_enabled = not _environment.fog_enabled
		KEY_3:
			_fakes.visible = not _fakes.visible
		KEY_4:
			_vignette.visible = not _vignette.visible
		_:
			return
	_refresh_hud()


func _refresh_hud() -> void:
	_hud.text = "1 glow %s   2 fog %s   3 fake light %s   4 vignette %s" % [
		_state(_environment.glow_enabled),
		_state(_environment.fog_enabled),
		_state(_fakes.visible),
		_state(_vignette.visible),
	]


func _state(on: bool) -> String:
	return "on" if on else "off"
