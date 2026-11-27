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
var _replies: Array[CreatorReply] = []


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
		var race := CreatorPortrait.RACES[card.creator]
		var reply := _add_reply(portrait, race, CreatorReply.PITCHES[card.creator])
		if card.creator == CreatorPortrait.Creator.SAMI:
			_add_guest(portrait, reply, card)
		else:
			card.photo_tapped.connect(func(_across: float) -> void: reply.answer())
	visibility_changed.connect(_render_while_shown)
	_render_while_shown()


# How [param portrait] answers a tap: in [param race]'s voice at [param pitch].
func _add_reply(portrait: AlienPortrait, race: Race.Type, pitch: float) -> CreatorReply:
	var reply := CreatorReply.new()
	%Portraits.add_child(reply)
	reply.setup(portrait, race, pitch)
	_replies.append(reply)
	return reply


# Henna, who squeezes into [param host]'s photo now and then, her name showing on
# [param card] while she does. A tap there is answered by whoever it is on. She stands
# with the portraits, so she waits while the screen is hidden.
func _add_guest(host: AlienPortrait, host_reply: CreatorReply, card: CreatorCard) -> void:
	var portrait := CreatorPortrait.new_portrait(CreatorPortrait.Creator.SAMI)
	%Portraits.add_child(portrait)
	CreatorPortrait.frame(portrait, CreatorPortrait.Creator.SAMI)
	CreatorPortrait.dress_guest(portrait)
	var race := CreatorPortrait.RACES[CreatorPortrait.Creator.SAMI]
	var reply := _add_reply(portrait, race, CreatorReply.GUEST_PITCH)
	_guest = CreatorGuest.new()
	_guest.name = "Guest"
	%Portraits.add_child(_guest)
	_guest.moved.connect(card.show_guest)
	_guest.mood_changed.connect(
		func(joy: float) -> void:
			host_reply.resting_joy = joy
			reply.resting_joy = joy
	)
	_guest.setup(host, portrait)
	card.photo_tapped.connect(
		func(across: float) -> void:
			var tapped := reply if _guest.is_guest_at(across) else host_reply
			_guest.linger()
			tapped.answer()
	)


# The portraits move and render only while the screen shows. Hiding, they render once
# more: the frame the screen shows for as the menu loads ([method MenuScreen._warm_up]) is
# over before the viewport has drawn, so that last render is where the portraits' shaders
# compile, and not in the first frame the screen opens, which stalled the transition.
func _render_while_shown() -> void:
	var shown := is_visible_in_tree()
	# Each opening starts with Sami alone and everyone quiet.
	if not shown:
		if _guest:
			_guest.leave()
		for reply: CreatorReply in _replies:
			reply.reset()
	var studio := %Studio as SubViewport
	studio.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_ONCE
	)
	(%Portraits as Node3D).process_mode = (
		Node.PROCESS_MODE_INHERIT if shown else Node.PROCESS_MODE_DISABLED
	)
