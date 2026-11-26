class_name Level
extends Resource
## A level as the menus and the loading screen show it: its name, its picture, the crop of
## the picture its card in the campaign screen shows, the band of it the jump card shows, and
## what the loading screen's bar and tips show while it loads.

## The level's name, as the loading screen shows it.
@export var title := ""
## The star system the level is played in, by its node name, such as Vela. [member Campaign.LEVELS]
## lists the levels in the order the solar system's systems open (campaign_test checks).
@export var star_system := ""
## The level's picture, a 16:9 render, loaded only when shown.
@export_file("*.jpg", "*.png") var picture := ""
## The picture's part the level's card shows, in shares of its width and height from its
## top left corner.
@export var card_crop := Rect2()
## Where the jump card's band of the picture centres, in shares of the picture's height from
## its top. The band is the picture's full width, so this is all that places it: pick the
## height at which the subject shows between the card's words and its arrow.
@export_range(0.0, 1.0, 0.01) var jump_band_middle := 0.45
## The icon colours of the planets at the loading bar's ends: where the bus starts and
## somewhere it goes.
@export var from_planet_color := Color.WHITE
@export var to_planet_color := Color.WHITE
## Tips only this level's loading screen shows, as well as those every level's does.
@export var tips := PackedStringArray()
