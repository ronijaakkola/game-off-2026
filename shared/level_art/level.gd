class_name Level
extends Resource
## A level as the menus and the loading screen show it: its name, its picture, the crop of
## the picture its card in the campaign screen shows, and what the loading screen's bar
## and tips show while it loads.

## The level's name, as the loading screen shows it.
@export var title := ""
## The star system the level is played in, by its node name, such as Sol.
@export var star_system := ""
## The level's picture, a 16:9 render, loaded only when shown.
@export_file("*.jpg", "*.png") var picture := ""
## The picture's part the level's card shows, in shares of its width and height from its
## top left corner.
@export var card_crop := Rect2()
## The icon colours of the planets at the loading bar's ends: where the bus starts and
## somewhere it goes.
@export var from_planet_color := Color.WHITE
@export var to_planet_color := Color.WHITE
## Tips only this level's loading screen shows, as well as those every level's does.
@export var tips := PackedStringArray()
