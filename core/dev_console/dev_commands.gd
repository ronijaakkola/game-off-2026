extends Node
## The dev console commands. The only script that may name LimboConsole, which the web
## build leaves out along with this script. Add new commands here.


func _ready() -> void:
	LimboConsole.register_command(_goto, "goto", "Fade to the scene at a res:// path")
	LimboConsole.register_command(_online, "online", "Show whether Online reaches Talo")
	LimboConsole.register_command(
		_online_track, "online_track", "Track an analytics event and send it now"
	)
	LimboConsole.register_command(
		_online_score, "online_score", "Submit a score to a leaderboard (internal name)"
	)
	LimboConsole.register_command(
		_online_scores, "online_scores", "List a leaderboard's top 10 (internal name)"
	)


func _goto(path: String) -> void:
	if not ResourceLoader.exists(path):
		LimboConsole.error("No scene at %s" % path)
		return
	SceneFlow.go_to(path)


func _online() -> void:
	if not Online.is_enabled():
		LimboConsole.info("Offline: not a web build, or no Talo access key (docs/online.md)")
		return
	if not Online.is_identified():
		LimboConsole.info("Identifying the player with Talo…")
		return
	var player_name := Online.get_player_name()
	var shown_name := '"%s"' % player_name if player_name else "not set"
	var session := "open" if Talo.socket.is_identified() else "not open"
	var status := "Online as %s, name %s, session %s"
	LimboConsole.info(status % [Talo.current_alias.identifier, shown_name, session])


func _online_track(event_name: String) -> void:
	Online.track(event_name, {"from": "dev console"})
	Online.flush()


func _online_score(leaderboard: String, score: float) -> void:
	var entry := await Online.submit_score(leaderboard, score)
	if entry == null:
		LimboConsole.error("Not submitted. Offline, or no leaderboard %s?" % leaderboard)
		return
	LimboConsole.info("Submitted %s, rank #%d" % [entry.score, entry.position + 1])


func _online_scores(leaderboard: String) -> void:
	var entries := await Online.get_scores(leaderboard)
	if entries.is_empty():
		LimboConsole.info("No entries. Offline, or no leaderboard %s?" % leaderboard)
	for entry: TaloLeaderboardEntry in entries:
		var you := " (you)" if Online.is_own(entry) else ""
		var row := [entry.position + 1, entry.player_alias.display_name, entry.score, you]
		LimboConsole.info("#%d %s %s%s" % row)
