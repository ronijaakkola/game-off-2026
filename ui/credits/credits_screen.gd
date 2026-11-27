extends MenuScreen
## The credits screen: the people who made the game, each a card with their portrait
## ([CreatorCard]). The main menu opens it over itself ([MenuScreen]). The portraits stand
## in one viewport, a tile each, and each card shows its tile, as a [PortraitStudio]'s
## photos do; it renders only while the screen shows.

## Pixels per tile: twice the size a card shows it at, so it stays sharp when the UI scales
## up in fullscreen.
const TILE := 352
## Pixels between tiles, so what reaches past one never shows in its neighbour.
const GUTTER := 96

var _guest: CreatorGuest


func _ready() -> void:
	super._ready()
	var studio := %Studio as SubViewport
	var cards := %Cards.get_children()
	var pitch := TILE + GUTTER
	studio.size = Vector2i(cards.size() * pitch, pitch)
	# World units per tile: a portrait is framed for a tile PortraitStudio.SLOT wide.
	var slot := PortraitStudio.SLOT * pitch / TILE
	(%Camera as Camera3D).size = slot
	for i: int in cards.size():
		var card := cards[i] as CreatorCard
		var portrait := CreatorPortrait.new_portrait(card.creator)
		%Portraits.add_child(portrait)
		CreatorPortrait.frame(portrait, card.creator)
		CreatorPortrait.dress(portrait, card.creator)
		portrait.position.x += (i - (cards.size() - 1) / 2.0) * slot
		var photo := AtlasTexture.new()
		photo.atlas = studio.get_texture()
		photo.region = Rect2(i * pitch + GUTTER / 2.0, GUTTER / 2.0, TILE, TILE)
		card.show_photo(photo)
		if card.creator == CreatorPortrait.Creator.SAMI:
			_add_guest(portrait, card)
	visibility_changed.connect(_render_while_shown)
	_render_while_shown()


# Henna, who squeezes into [param host]'s photo now and then, her name showing on
# [param card] while she does. She stands with the portraits, so she waits while the screen
# is hidden.
func _add_guest(host: AlienPortrait, card: CreatorCard) -> void:
	var portrait := CreatorPortrait.new_portrait(CreatorPortrait.Creator.SAMI)
	%Portraits.add_child(portrait)
	CreatorPortrait.frame(portrait, CreatorPortrait.Creator.SAMI)
	CreatorPortrait.dress_guest(portrait)
	_guest = CreatorGuest.new()
	_guest.name = "Guest"
	%Portraits.add_child(_guest)
	_guest.moved.connect(card.show_guest)
	_guest.setup(host, portrait)


# The portraits move and render only while the screen shows. Hiding, they render once
# more: the frame the screen shows for as the menu loads ([method MenuScreen._warm_up]) is
# over before the viewport has drawn, so that last render is where the portraits' shaders
# compile, and not in the first frame the screen opens, which stalled the transition.
func _render_while_shown() -> void:
	var shown := is_visible_in_tree()
	# Each opening starts with Sami alone.
	if not shown and _guest:
		_guest.leave()
	var studio := %Studio as SubViewport
	studio.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_ONCE
	)
	(%Portraits as Node3D).process_mode = (
		Node.PROCESS_MODE_INHERIT if shown else Node.PROCESS_MODE_DISABLED
	)
