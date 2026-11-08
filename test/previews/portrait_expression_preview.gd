extends Control
## Every head shape in its race's colour in each expression, as passenger photos at the
## size their cards show them, for a visual check of how anger, joy, eating and drinking
## read: a row per head, race by race,
## and a column each for okay, happy, annoyed, furious, joyful, eating and drinking. The
## first four get there by their mood, and happy ones beam now and then; the joyful ones'
## full joy is set on the portrait, so their photo doesn't ride and set it by mood. The
## eating and drinking ones asked for a snack or a drink and were served it. Pass `big`
## to show them three times the size, and `swap` to give every head the other eye style.

const PHOTO := preload("res://game/passengers/passenger_photo.tscn")
const STUDIO := preload("res://game/passengers/portrait_studio.tscn")
const COMMUTER := preload("res://game/passengers/types/commuter.tres")
const COLUMNS: Array[String] = [
	"Okay", "Happy", "Annoyed", "Furious", "Joyful", "Eating", "Drinking"
]
# Patience left, as a fraction of the full amount, for each column.
const PATIENCE: Array[float] = [0.45, 0.9, 0.2, 0.0, 0.9, 0.45, 0.45]
const JOYFUL := 4
# The need served to each column's passengers, by id, or none.
const SERVED: Dictionary[int, StringName] = {5: &"snack", 6: &"drink"}
const CELL := Vector2(70.0, 62.0)
const ORIGIN := Vector2(90.0, 40.0)

# The photos in the joyful column.
var _joyful: Array[PassengerPhoto] = []
var _studios: Array[PortraitStudio] = []


func _ready() -> void:
	if "big" in OS.get_cmdline_user_args():
		scale = Vector2.ONE * 3.0
	var home := Planet.new()
	home.icon_color = Color(0.5, 0.82, 0.34)
	add_child(home)
	var rows: Array[Array] = []
	for race: Race.Type in AlienLook.HEADS:
		for head: PackedScene in AlienLook.HEADS[race]:
			rows.append([race, head])
	for column: int in COLUMNS.size():
		var heading := Label.new()
		heading.text = COLUMNS[column]
		heading.position = ORIGIN + Vector2(column * CELL.x, -28.0)
		add_child(heading)
	for row: int in rows.size():
		for column: int in COLUMNS.size():
			var photo := PHOTO.instantiate() as PassengerPhoto
			photo.studio = _studio_with_room()
			photo.passenger = _passenger(rows[row][0], rows[row][1], row, PATIENCE[column], home)
			if SERVED.has(column):
				_serve(photo.passenger, SERVED[column])
			photo.riding = column != JOYFUL
			photo.position = ORIGIN + Vector2(column * CELL.x, row * CELL.y)
			add_child(photo)
			if column == JOYFUL:
				_joyful.append(photo)


func _process(_delta: float) -> void:
	for photo: PassengerPhoto in _joyful:
		var portrait := photo.studio.get_portrait(photo.get_photo() as AtlasTexture)
		if portrait:
			portrait.joy = 1.0


func _studio_with_room() -> PortraitStudio:
	if _studios.is_empty() or _studios[-1].get_portrait_count() >= PortraitStudio.SLOTS:
		var studio := STUDIO.instantiate() as PortraitStudio
		add_child(studio)
		_studios.append(studio)
	return _studios[-1]


# [param row]'s passenger, of [param race] with [param head]; rows take turns at eye style.
func _passenger(
	race: Race.Type, head: PackedScene, row: int, patience: float, home: Planet
) -> Passenger:
	var passenger := Passenger.new(COMMUTER, home, 60.0, 40.0)
	passenger.origin = home
	passenger.patience = passenger.patience_max * patience
	passenger.look.head = head
	var style := row + (1 if "swap" in OS.get_cmdline_user_args() else 0)
	passenger.look.eye_style = AlienLook.EYE_STYLES[style % AlienLook.EYE_STYLES.size()]
	passenger.race = race
	passenger.look.skin_color = Race.SKIN_COLORS[passenger.race]
	return passenger


func _serve(passenger: Passenger, need_id: StringName) -> void:
	for need: Need in COMMUTER.needs:
		if need.id == need_id:
			passenger.request = need
			passenger.serve()
