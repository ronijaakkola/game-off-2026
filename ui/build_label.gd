extends Label
## The build's commit, "Commit a1b2c3d", for a tester to name in a report. The export writes
## it into [constant BUILD_COMMIT] (`check.py export`), so the editor has none and the label
## stays hidden there.

const BUILD_COMMIT := "res://ui/main_menu/build_commit.txt"


func _ready() -> void:
	visible = FileAccess.file_exists(BUILD_COMMIT)
	if visible:
		text = "Commit %s" % FileAccess.get_file_as_string(BUILD_COMMIT).strip_edges()
