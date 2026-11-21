class_name ControlIcons
## The mouse buttons and keys a guide card's text can show as icons in its running text,
## so a sentence says which control to use: "Right click {mouse_right} the planet". Each
## {name} of [constant ICONS] in the text becomes its icon, [constant HEIGHT] pixels tall,
## centred on the line; anything else in braces is left as it is.

## How tall an icon is in the text, in pixels: about a line of the card's text.
const HEIGHT := 16.0
const ICONS: Dictionary[String, Texture2D] = {
	"mouse_left": preload("res://ui/guide_card/icons/mouse_left.svg"),
	"mouse_right": preload("res://ui/guide_card/icons/mouse_right.svg"),
	"mouse_wheel": preload("res://ui/guide_card/icons/mouse_wheel.svg"),
	"shift": preload("res://ui/guide_card/icons/shift.svg"),
	"q": preload("res://ui/guide_card/icons/q.svg"),
	"space": preload("res://ui/guide_card/icons/space.svg"),
	"wasd": preload("res://ui/guide_card/icons/wasd.svg"),
	"arrows": preload("res://ui/guide_card/icons/arrows.svg"),
}

static var _token := RegEx.create_from_string("\\{(\\w+)\\}")


## Replaces what [param label] shows with [param text], each {name} of [constant ICONS] as
## its icon.
static func write(label: RichTextLabel, text: String) -> void:
	label.clear()
	var from := 0
	for found: RegExMatch in _token.search_all(text):
		var name := found.get_string(1)
		if not ICONS.has(name):
			continue
		label.add_text(text.substr(from, found.get_start() - from))
		label.add_image(ICONS[name], 0, HEIGHT)
		from = found.get_end()
	label.add_text(text.substr(from))
