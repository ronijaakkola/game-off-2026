extends RefCounted
## One moment of text on the text desk: what the player reads at once, as a guide card's
## title and what it says, or a call's caller, words and answers. Each part is a
## [Field], one text in one file.


## One text in one file. Entries that show the same text share it, so a change in one
## shows in the others.
class Text:
	## The file that holds it and where in it (the readers say how a key reads).
	var path := ""
	var key := ""
	## What it says now on the desk, and what its file says.
	var value := ""
	var saved := ""
	## Whether its file has no text at [member key]: the running order is out of date.
	var missing := false

	func is_changed() -> bool:
		return value != saved


## One part of an entry: a text, and what part of the moment it is.
class Field:
	## Tells the stage where to show it: "title", "text", "accept" and so on.
	var role := ""
	var text: Text


## The line the desk lists it under.
var title := ""
## Which stage shows it (stages.gd): "guide", "transmission", "tooltip", "notice", "quick" or
## "label".
var stage := "label"
var fields: Array[Field] = []
## What the stage needs to know beside the text, such as who calls.
var options := {}


func is_changed() -> bool:
	return fields.any(func(field: Field) -> bool: return field.text.is_changed())


## What each role says, the roles that come more than once joined in order.
func get_values() -> Dictionary[String, String]:
	var values: Dictionary[String, String] = {}
	for field: Field in fields:
		values[field.role] = values.get(field.role, "") + field.text.value
	return values
