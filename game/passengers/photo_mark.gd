class_name PhotoMark
extends Label
## The question mark over the photo of someone the player doesn't know yet
## ([BossPassenger]), in the middle of it, as on an unknown caller's ([CallerPhoto]).

## The mark's height as a share of the photo's.
const SIZE := 0.6
const COLOR := Color(0.812, 0.745, 1.0)
const OUTLINE_COLOR := Color(0.043, 0.035, 0.125, 0.8)


func _ready() -> void:
	text = "?"
	theme_type_variation = &"HeadingLabel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_color_override(&"font_color", COLOR)
	add_theme_color_override(&"font_outline_color", OUTLINE_COLOR)
	add_theme_constant_override(&"outline_size", 4)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_fit)
	_fit()


func _fit() -> void:
	add_theme_font_size_override(&"font_size", maxi(roundi(size.y * SIZE), 8))
