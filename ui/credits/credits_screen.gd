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
	visibility_changed.connect(_render_while_shown)
	_render_while_shown()


# The portraits move and render only while the screen shows. Hiding, they render once
# more: the frame the screen shows for as the menu loads ([method MenuScreen._warm_up]) is
# over before the viewport has drawn, so that last render is where the portraits' shaders
# compile, and not in the first frame the screen opens, which stalled the transition.
func _render_while_shown() -> void:
	var shown := is_visible_in_tree()
	var studio := %Studio as SubViewport
	studio.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_ONCE
	)
	(%Portraits as Node3D).process_mode = (
		Node.PROCESS_MODE_INHERIT if shown else Node.PROCESS_MODE_DISABLED
	)
