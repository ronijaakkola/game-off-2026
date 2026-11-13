class_name NoticeStack
extends VBoxContainer
## The notices above the bus bars, centred, the newest on top so a new one never moves
## those already showing. [method push] adds one and returns it, so its owner can listen
## for its action or dismiss it; one that leaves lets those above it glide down into its
## place. A new one goes under any still leaving, so one replacing another, as the
## tutorial's steps do, comes in where it rests and never drops as the old one's gap
## closes. While the stack is hidden, a new notice waits to come in until it shows, and the
## countdowns of those showing stop. [method offer_tow] and [method announce_transmission]
## are the notices with an action of their own.

const NOTICE := preload("res://game/solar_system/notice.tscn")


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)


## Adds a notice saying [param text], of [param kind], on top. [param closable] gives it a
## close button, [param seconds] closes it by itself after that long (never when 0), and
## [param action] gives it an action button with that label (none when empty).
func push(
	text: String,
	kind := Notice.Kind.INFO,
	closable := false,
	seconds := 0.0,
	action := "",
) -> Notice:
	var notice := NOTICE.instantiate() as Notice
	notice.setup(kind, text, closable, seconds, action)
	add_child(notice)
	move_child(notice, _top_of_showing())
	if is_visible_in_tree():
		notice.enter()
	else:
		notice.postpone()
	return notice


# Where a new notice goes: just above the top one not leaving, so those leaving close
# their gaps above it. The new one, already added at the bottom, counts.
func _top_of_showing() -> int:
	var notices := get_notices()
	return notices.find_custom(func(notice: Notice) -> bool: return not notice.is_leaving())


## The notices showing, top first, leaving ones included until they are gone.
func get_notices() -> Array[Notice]:
	var notices: Array[Notice] = []
	notices.assign(get_children())
	return notices


## The out of fuel notice: a tow for [param fee] credits. It stays until its button is
## pressed.
func offer_tow(fee: int) -> Notice:
	return push("You ran out of fuel", Notice.Kind.ERROR, false, 0.0, "Tow (%d credits)" % fee)


## Someone calls the bus: "Incoming transmission..." and an Answer button. It stays until
## answered.
func announce_transmission() -> Notice:
	return push("Incoming transmission...", Notice.Kind.CALL, false, 0.0, "Answer")


func _on_visibility_changed() -> void:
	for notice: Notice in get_notices():
		notice.hold(not is_visible_in_tree())
