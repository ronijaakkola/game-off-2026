extends RefCounted
## Finds the text a GDScript file holds, and writes a text back as a literal: the text
## desk's reader and writer for scripts.
## A text is a run of plain string literals joined by [code]+[/code], with the brackets
## round it when they hold nothing else, so the whole of
## [code]const TEXT := ("one " + "two")[/code] is one text. A [StringName], a [NodePath],
## a node's name and a raw string are names, never text.
## Each text has a key that says where it is, which stays the same while the text changes:
## the [code]const[/code], [code]var[/code] or [code]func[/code] it is in, then the keys
## and indexes of the dictionaries and arrays down to it, as
## [code]CARDS/BUS/title[/code] or [code]LINES/2[/code]. Texts with the same key, as those
## in a function's body, are numbered after the first: [code]get_ups[/code],
## [code]get_ups#1[/code].

const Found := preload("res://tools/text_desk/found_text.gd")

## The longest line gdformat allows, with a tab as four columns.
const LINE_LENGTH := 100
const TAB_COLUMNS := 4
const NAME_PREFIXES := "&^$%"
## Words a bracket can follow without being a call's.
const KEYWORDS: Array[String] = ["return", "in", "and", "or", "not", "if", "elif", "else", "await"]
const DECLARATION := "^(?:@\\w+(?:\\([^)]*\\))?\\s+)*(?:static\\s+)?(?:const|var|func)\\s+(\\w+)"

static var _declaration := RegEx.create_from_string(DECLARATION)


## Every text in [param source], in the order they are written.
static func scan(source: String) -> Array[Found]:
	var found: Array[Found] = []
	var counts: Dictionary[String, int] = {}
	var declaration := ""
	# One frame per open bracket: its kind, and for an array the index it is at, for a
	# dictionary the key it is at, where that element starts and how many texts were
	# found before it.
	var stack: Array[Dictionary] = []
	var at := 0
	var at_line_start := true
	while at < source.length():
		var letter := source[at]
		if at_line_start:
			at_line_start = false
			var line_end := source.find("\n", at)
			var line := source.substr(at, (line_end if line_end >= 0 else source.length()) - at)
			var match := _declaration.search(line)
			if match:
				declaration = match.get_string(1)
				stack.clear()
		if letter == "\n":
			at_line_start = true
			at += 1
		elif letter == "#":
			var line_end := source.find("\n", at)
			at = line_end if line_end >= 0 else source.length()
		elif letter == '"' or letter == "'":
			at = _read_text(source, at, declaration, stack, found, counts)
		elif letter in "([{":
			stack.append({kind = letter, index = 0, key = "", keyed = false, start = at + 1})
			stack[-1].found = found.size()
			at += 1
		elif letter in ")]}":
			if not stack.is_empty():
				stack.pop_back()
			at += 1
		elif letter == ",":
			if not stack.is_empty():
				var frame := stack[-1]
				frame.index += 1
				frame.key = ""
				frame.keyed = false
				frame.start = at + 1
				frame.found = found.size()
			at += 1
		elif letter == ":" or letter == "=":
			_read_key(source, at, stack, found, counts)
			at += 1
		else:
			at += 1
	return found


## [param value] as GDScript writes it at [param column] of a line indented by
## [param indent]: one literal when it fits the line, else its words over several lines in
## brackets, as the scripts here break a long text. gdformat settles the rest.
static func write_literal(value: String, indent: String, column: int) -> String:
	var whole := quote(value)
	# Room for a comma after it.
	if column + whole.length() + 1 <= LINE_LENGTH:
		return whole
	var inner := indent + "\t"
	var room := LINE_LENGTH - _columns(inner) - 6
	var lines := PackedStringArray()
	var chunk := ""
	for word: String in _words(value):
		if chunk != "" and quote(chunk + word).length() > room:
			lines.append(quote(chunk))
			chunk = ""
		chunk += word
	lines.append(quote(chunk))
	var text := "(\n"
	for i: int in lines.size():
		text += inner + ("+ " if i > 0 else "") + lines[i] + "\n"
	return text + indent + ")"


## [param value] as one double-quoted literal.
static func quote(value: String) -> String:
	var escaped := value.replace("\\", "\\\\").replace('"', '\\"')
	return '"%s"' % escaped.replace("\n", "\\n").replace("\t", "\\t")


## The whitespace that starts the line [param at] is on, and the column [param at] is at.
static func get_indent(source: String, at: int) -> String:
	var line_start := source.rfind("\n", maxi(at - 1, 0)) + 1 if at > 0 else 0
	var end := line_start
	while end < source.length() and source[end] in " \t":
		end += 1
	return source.substr(line_start, end - line_start)


## The column [param at] is at on its line, a tab counting four.
static func get_column(source: String, at: int) -> int:
	var line_start := source.rfind("\n", maxi(at - 1, 0)) + 1 if at > 0 else 0
	return _columns(source.substr(line_start, at - line_start))


# Reads the literal at [param at] and, when it is text, the run it starts, which joins
# [param found]. Returns where reading goes on.
static func _read_text(
	source: String,
	at: int,
	declaration: String,
	stack: Array[Dictionary],
	found: Array[Found],
	counts: Dictionary[String, int]
) -> int:
	var literal := _read_literal(source, at)
	if _is_name(source, at):
		return literal.end
	var parts := PackedStringArray([literal.value])
	var end: int = literal.end
	while true:
		var plus := _skip_space(source, end)
		if plus >= source.length() or source[plus] != "+":
			break
		var next := _skip_space(source, plus + 1)
		if next >= source.length() or not source[next] in "\"'" or _is_name(source, next):
			break
		var more := _read_literal(source, next)
		parts.append(more.value)
		end = more.end
	var start := at
	var before := _skip_space_back(source, at - 1)
	var after := _skip_space(source, end)
	var bracketed := (
		before >= 0
		and source[before] == "("
		and after < source.length()
		and source[after] == ")"
		and not _is_call(source, before)
	)
	if bracketed and not stack.is_empty() and stack[-1].kind == "(":
		start = before
		end = after + 1
		stack.pop_back()
	var text := Found.new()
	text.start = start
	text.end = end
	text.value = "".join(parts)
	text.key = _number(_key(declaration, stack), counts)
	found.append(text)
	return end


# A dictionary's key ends at [param at]: what came before it in this element names what
# follows, and any text in it was a key, not a text.
static func _read_key(
	source: String,
	at: int,
	stack: Array[Dictionary],
	found: Array[Found],
	counts: Dictionary[String, int]
) -> void:
	if stack.is_empty() or stack[-1].kind != "{" or stack[-1].keyed:
		return
	if source[at] == "=":
		var next := source[at + 1] if at + 1 < source.length() else ""
		if next == "=" or (at > 0 and source[at - 1] in "=!<>:+-*/%"):
			return
	var frame := stack[-1]
	var name := source.substr(frame.start, at - frame.start).strip_edges()
	frame.key = name.trim_prefix("&").trim_prefix('"').trim_suffix('"')
	frame.keyed = true
	while found.size() > frame.found:
		var dropped: Found = found.pop_back()
		var plain := dropped.key.get_slice("#", 0)
		counts[plain] -= 1
	frame.found = found.size()


# Where a text under [param stack] in [param declaration] is.
static func _key(declaration: String, stack: Array[Dictionary]) -> String:
	var names := PackedStringArray([declaration])
	for frame: Dictionary in stack:
		if frame.kind == "[":
			names.append(str(frame.index))
		elif frame.kind == "{":
			names.append(frame.key)
	return "/".join(names)


# [param key], numbered when texts before it have the same one.
static func _number(key: String, counts: Dictionary[String, int]) -> String:
	var count: int = counts.get(key, 0)
	counts[key] = count + 1
	return key if count == 0 else "%s#%d" % [key, count]


# The literal that opens at [param at]: what it says and where it ends.
static func _read_literal(source: String, at: int) -> Dictionary:
	var quote_mark := source[at]
	var triple := source.substr(at, 3) == quote_mark.repeat(3)
	var close := quote_mark.repeat(3) if triple else quote_mark
	var i := at + close.length()
	var value := ""
	while i < source.length():
		if source[i] == "\\" and i + 1 < source.length():
			var escaped := source[i + 1]
			if escaped == "u" and i + 5 < source.length():
				value += char(source.substr(i + 2, 4).hex_to_int())
				i += 6
				continue
			value += {"n": "\n", "t": "\t", "\n": ""}.get(escaped, escaped)
			i += 2
		elif source.substr(i, close.length()) == close:
			return {value = value, end = i + close.length()}
		else:
			value += source[i]
			i += 1
	return {value = value, end = source.length()}


# Whether the literal at [param at] is a name: a StringName, a NodePath, a node or a raw
# string.
static func _is_name(source: String, at: int) -> bool:
	if at == 0:
		return false
	var before := source[at - 1]
	if before in NAME_PREFIXES:
		return true
	return before == "r" and (at < 2 or not _is_word(source[at - 2]))


# Whether the bracket at [param at] is a call's or an index's: it follows a name or a
# closing bracket.
static func _is_call(source: String, at: int) -> bool:
	if at == 0:
		return false
	var before := source[at - 1]
	if before in ")]":
		return true
	if not _is_word(before):
		return false
	var start := at - 1
	while start > 0 and _is_word(source[start - 1]):
		start -= 1
	return not source.substr(start, at - start) in KEYWORDS


static func _is_word(letter: String) -> bool:
	return letter == "_" or letter.is_valid_identifier() or letter.is_valid_int()


static func _skip_space(source: String, at: int) -> int:
	while at < source.length() and source[at] in " \t\n":
		at += 1
	return at


static func _skip_space_back(source: String, at: int) -> int:
	while at >= 0 and source[at] in " \t\n":
		at -= 1
	return at


static func _columns(text: String) -> int:
	return text.length() + text.count("\t") * (TAB_COLUMNS - 1)


# [param value] in pieces that each end after a space, so a line breaks between words.
static func _words(value: String) -> PackedStringArray:
	var words := PackedStringArray()
	var from := 0
	while from < value.length():
		var space := value.find(" ", from)
		var to := value.length() if space < 0 else space + 1
		words.append(value.substr(from, to - from))
		from = to
	return words
