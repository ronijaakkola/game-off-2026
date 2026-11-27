extends GdUnitTestSuite

const GdStrings := preload("res://tools/text_desk/gd_strings.gd")
const Found := preload("res://tools/text_desk/found_text.gd")

const SOURCE := """extends Node
## A comment with "quotes" in it.

const PLAIN := "One line."
const LONG := (
	"The first half, "
	+ "and the second."
)
const LINES: Array[String] = [
	"Line one, %s.",
	(
		"Line two "
		+ "goes on."
	),
]
const CARDS := {
	"BUS": {title = "Your bus", text = ("You drive " + "this bus."), side = 3},
	&"vip": {title = 'Say "hi"', text = "It's a VIP."},
}
const NAMES: Dictionary[int, String] = {Kind.FIRST: "First", Kind.SECOND: "Second"}


func describe(count: int) -> String:
	if count == 1:
		return "One stop"
	print(&"a_name", ^"A/Path", $"A Node", r"raw \\d+")
	return "%d stops" % count
"""


func test_a_key_says_where_a_text_is() -> void:
	var texts := _texts(SOURCE)
	(
		assert_dict(texts)
		. is_equal(
			{
				"PLAIN": "One line.",
				"LONG": "The first half, and the second.",
				"LINES/0": "Line one, %s.",
				"LINES/1": "Line two goes on.",
				"CARDS/BUS/title": "Your bus",
				"CARDS/BUS/text": "You drive this bus.",
				"CARDS/vip/title": 'Say "hi"',
				"CARDS/vip/text": "It's a VIP.",
				"NAMES/Kind.FIRST": "First",
				"NAMES/Kind.SECOND": "Second",
				"describe": "One stop",
				"describe#1": "%d stops",
			}
		)
	)


func test_a_span_holds_the_brackets_round_a_text() -> void:
	for found: Found in GdStrings.scan(SOURCE):
		if found.key == "LONG":
			var written := SOURCE.substr(found.start, found.end - found.start)
			assert_str(written).starts_with("(").ends_with(")")
			return
	fail("LONG was not found")


func test_a_written_text_reads_back_the_same() -> void:
	var long := (
		"A sentence that goes on for a good while, so that it can't stay on one line. ".repeat(4)
	)
	for value: String in [
		"Plain.", 'She said "no".', "A back\\slash", "Two\nlines\tand a tab", long
	]:
		var written := GdStrings.write_literal(value, "\t", 20)
		var texts := _texts("const TEXT := %s\n" % written)
		assert_str(texts.get("TEXT", "")).is_equal(value)


func test_a_long_text_breaks_inside_the_line_length() -> void:
	var long := "Words and more words, one after another, until the line is full. ".repeat(5)
	var written := GdStrings.write_literal(long, "\t", 20)
	assert_int(written.count("\n")).is_greater(2)
	for line: String in written.split("\n"):
		var columns := line.length() + line.count("\t") * 3
		assert_int(columns).is_less_equal(GdStrings.LINE_LENGTH)


func _texts(source: String) -> Dictionary:
	var texts := {}
	for found: Found in GdStrings.scan(source):
		texts[found.key] = found.value
	return texts
