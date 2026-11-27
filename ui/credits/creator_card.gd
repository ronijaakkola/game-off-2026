class_name CreatorCard
extends MarginContainer
## One of the game's makers on the credits screen: their portrait as a passenger's photo,
## a white print tilted a little over a hard shadow, with their name and what they did
## under it. The screen renders the portrait and hands the card its picture
## ([method show_photo]).

## Whose card it is.
@export var creator := CreatorPortrait.Creator.RONI
@export var display_name := ""
## What they did, as a sentence.
@export var roles := ""
## How far the photo is tilted, in degrees, counter-clockwise.
@export var tilt := 0.0
## Someone who squeezes into the photo now and then ([CreatorGuest]), and what they did:
## shown under the rest while they are there ([method show_guest]).
@export var guest_name := ""
@export var guest_roles := ""


func _ready() -> void:
	(%Name as Label).text = display_name
	(%Roles as Label).text = roles
	(%GuestName as Label).text = guest_name
	(%GuestRoles as Label).text = guest_roles
	(%Frame as Control).rotation = deg_to_rad(-tilt)
	var backdrop := (%Backdrop as ColorRect).material as ShaderMaterial
	var race := CreatorPortrait.RACES[creator]
	backdrop.set_shader_parameter(&"backdrop_color", Race.BACKDROP_COLORS[race])
	backdrop.set_shader_parameter(&"seed", float(creator) * 7.0 + 3.0)


## Shows the guest's name and what they did as far as they are in the photo, from 0 not
## at all to 1.
func show_guest(here: float) -> void:
	(%Guest as Control).modulate.a = here


## Shows [param photo], the render of their portrait, in the frame.
func show_photo(photo: Texture2D) -> void:
	(%Photo as TextureRect).texture = photo
