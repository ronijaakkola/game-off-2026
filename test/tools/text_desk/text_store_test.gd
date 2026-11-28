extends GdUnitTestSuite

const Store := preload("res://tools/text_desk/text_store.gd")

const FOLDER := "user://text_desk_test"
const SCRIPT_PATH := FOLDER + "/sample.gd"
const SCENE_PATH := FOLDER + "/sample.tscn"
const SCRIPT_SOURCE := """extends Node
## Says hello.

const HELLO := "Hello."
const LINES: Array[String] = ["One.", "Two."]


func greet() -> String:
	return HELLO + " " + LINES[1]
"""
const SCENE_SOURCE := """[gd_scene format=3]

[node name="Root" type="Label"]
text = "Before"
visible = false
"""

var _store: Store


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	_write(SCRIPT_PATH, SCRIPT_SOURCE)
	_write(SCENE_PATH, SCENE_SOURCE)
	_store = Store.new()
	_store.formats = false


func after() -> void:
	DirAccess.remove_absolute(SCRIPT_PATH)
	DirAccess.remove_absolute(SCENE_PATH)
	DirAccess.remove_absolute(FOLDER)


func test_save_changes_only_the_texts() -> void:
	var problems := (
		_store
		. save(
			[
				{path = SCRIPT_PATH, key = "HELLO", old = "Hello.", new = 'Well, "hello" there.'},
				{path = SCRIPT_PATH, key = "LINES/1", old = "Two.", new = "Second."},
				{path = SCENE_PATH, key = "node:./text", old = "Before", new = "After\nall"},
			]
		)
	)
	assert_array(problems).is_empty()
	var script := FileAccess.get_file_as_string(SCRIPT_PATH)
	var expected := SCRIPT_SOURCE.replace('"Hello."', '"Well, \\"hello\\" there."')
	assert_str(script).is_equal(expected.replace('"Two."', '"Second."'))
	var scene := FileAccess.get_file_as_string(SCENE_PATH)
	assert_str(scene).is_equal(SCENE_SOURCE.replace('"Before"', '"After\nall"'))
	assert_str(_store.read(SCENE_PATH, "node:./text")).is_equal("After\nall")


func test_save_leaves_a_text_that_changed_in_the_file() -> void:
	_store.read(SCRIPT_PATH, "HELLO")
	_write(SCRIPT_PATH, SCRIPT_SOURCE.replace("Hello.", "Hi."))
	var problems := _store.save(
		[{path = SCRIPT_PATH, key = "HELLO", old = "Hello.", new = "Good day."}]
	)
	assert_int(problems.size()).is_equal(1)
	assert_str(_store.read(SCRIPT_PATH, "HELLO")).is_equal("Hi.")


func _write(path: String, source: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()
