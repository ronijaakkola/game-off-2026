extends SceneTree
## Renders the boot splash, `ui/main_menu/boot_splash.png`: the logo centred on the title
## card's navy, at twice the game's base size, so the web loading page, the engine's boot
## splash and the main menu's title card all show the logo at one size and place.
##
##   godot --headless --path . -s res://tools/render_boot_splash.gd
##
## Run it again when the logo or the base size changes.

const LOGO := "res://ui/main_menu/logo.svg"
const OUT := "res://ui/main_menu/boot_splash.png"
const BASE_SIZE := Vector2i(1152, 648)
const SCALE := 2
## The title card's navy, as `SpacePanel` in `ui/theme.tres` and the loading page's CSS.
const NAVY := Color("#171335")


func _init() -> void:
	var logo := Image.new()
	var error := logo.load_svg_from_string(FileAccess.get_file_as_string(LOGO), SCALE)
	if error != OK:
		push_error("Couldn't load %s: %s" % [LOGO, error_string(error)])
		quit(1)
		return
	logo.convert(Image.FORMAT_RGBA8)
	var size := BASE_SIZE * SCALE
	var splash := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	splash.fill(NAVY)
	splash.blend_rect(logo, Rect2i(Vector2i.ZERO, logo.get_size()), (size - logo.get_size()) / 2)
	splash.convert(Image.FORMAT_RGB8)
	error = splash.save_png(OUT)
	if error != OK:
		push_error("Couldn't save %s: %s" % [OUT, error_string(error)])
	quit(0 if error == OK else 1)
