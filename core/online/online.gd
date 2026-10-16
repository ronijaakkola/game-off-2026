extends Node
## The online services, through Talo (https://trytalo.com): the player's identity, analytics
## events and stats, leaderboards and play sessions. Game code calls this, not Talo.
##
## Online stays offline without an access key in core/online/talo_settings.cfg, and in headless
## runs (CI and check.py), so tests and checks never reach the network. Every call is safe when
## offline: it does nothing, or returns an empty result. docs/online.md has the setup.

## Keeps the player's anonymous identifier between sessions.
const PLAYER_PATH := "user://online.cfg"
## The Talo alias service for players who haven't signed in to anything.
const SERVICE := "anonymous"
## The player prop holding the name the player picked. The dashboard's display name prop key
## must be this, so leaderboards show it.
const NAME_PROP := "name"
## How often queued events and stat changes are sent. Closing a browser tab loses what's queued.
const FLUSH_SECONDS := 15.0
## Events tracked before the player is identified wait for it, up to this many.
const MAX_WAITING_EVENTS := 50
const TRACKING := preload("res://core/online/tracking.gd")

var _waiting_events: Array[Dictionary] = []
var _stat_changes: Dictionary[String, float] = {}


func _ready() -> void:
	# Flush while the game is paused too.
	process_mode = PROCESS_MODE_ALWAYS
	add_child(TRACKING.new())
	if not is_enabled():
		return
	var timer := Timer.new()
	timer.timeout.connect(flush)
	add_child(timer)
	timer.start(FLUSH_SECONDS)
	Talo.players.identified.connect(_on_identified)
	# Sessions come from the socket. Turned on here rather than in the settings file, so the
	# socket also reconnects after a dropped connection.
	Talo.settings.auto_connect_socket = true
	Talo.socket.open_connection()
	Talo.players.identify(SERVICE, _identifier())


func _notification(what: int) -> void:
	# Talo sends its event queue then too, but not the stat changes queued here.
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST]:
		flush()


## True when Online talks to Talo: an access key is set and the game has a window.
func is_enabled() -> bool:
	return not Talo.settings.access_key.is_empty() and DisplayServer.get_name() != "headless"


## True once Talo knows who the player is. Calls before then wait (events) or do nothing.
func is_identified() -> bool:
	return is_enabled() and Talo.has_identity()


## Queues the analytics event [param event_name], sent with the next batch. Each value in
## [param props] becomes a string. Talo adds the OS, game version and window size to every event.
func track(event_name: String, props: Dictionary[String, Variant] = {}) -> void:
	if not is_enabled():
		return
	var text_props: Dictionary[String, String] = {}
	for key: String in props:
		text_props[key] = str(props[key])
	if is_identified():
		Talo.events.track(event_name, text_props)
	elif _waiting_events.size() < MAX_WAITING_EVENTS:
		_waiting_events.append({name = event_name, props = text_props})


## Adds [param change] to the player's stat [param internal_name], sent with the next batch. The
## stat must exist in the Talo dashboard, or the batch logs an error.
func add_stat(internal_name: String, change := 1.0) -> void:
	if is_enabled():
		_stat_changes[internal_name] = _stat_changes.get(internal_name, 0.0) + change


## Sends queued events and stat changes now. A timer and the window losing focus also send them;
## call this when a run ends.
func flush() -> void:
	if not is_identified():
		return
	for internal_name: String in _stat_changes:
		Talo.stats.track(internal_name, _stat_changes[internal_name])
	_stat_changes.clear()
	Talo.events.flush()


## Submits [param score] to the leaderboard [param leaderboard] (its internal name in the
## dashboard), with [param props] stored on the entry. Returns the entry, whose
## [code]position[/code] is the player's rank from 0, or null when offline or the request fails.
func submit_score(
	leaderboard: String, score: float, props: Dictionary[String, Variant] = {}
) -> TaloLeaderboardEntry:
	if not is_identified():
		return null
	var result := await Talo.leaderboards.add_entry(leaderboard, score, props)
	return result.entry if result.success else null


## The best [param limit] entries of [param leaderboard], best first, up to one page (50). Each
## entry's [code]player_alias.display_name[/code] is the player's name. Empty when offline or the
## request fails.
func get_scores(leaderboard: String, limit := 10) -> Array[TaloLeaderboardEntry]:
	if not is_enabled():
		return []
	var page := await Talo.leaderboards.get_entries(leaderboard)
	if page == null:
		return []
	return page.entries.slice(0, limit)


## True when [param entry] is one of this player's own.
func is_own(entry: TaloLeaderboardEntry) -> bool:
	return is_identified() and entry.player_alias.player.id == Talo.current_player.id


## The name the player picked for leaderboards, or "" before they pick one or while offline.
func get_player_name() -> String:
	return Talo.current_player.get_prop(NAME_PROP) if is_identified() else ""


## Sets the name leaderboards show for this player, on every entry they've submitted. Does
## nothing until the player is identified.
func set_player_name(player_name: String) -> void:
	if is_identified():
		Talo.current_player.set_prop(NAME_PROP, player_name)


func _on_identified(_alias: TaloPlayerAlias) -> void:
	for event: Dictionary in _waiting_events:
		Talo.events.track(event.name, event.props)
	_waiting_events.clear()


# Made on first run and kept in PLAYER_PATH, so the player stays the same player while the
# browser keeps user://.
func _identifier() -> String:
	var file := ConfigFile.new()
	file.load(PLAYER_PATH)  # A missing file means a new player.
	var identifier: String = file.get_value("player", "identifier", "")
	if identifier.is_empty():
		identifier = Crypto.new().generate_random_bytes(16).hex_encode()
		file.set_value("player", "identifier", identifier)
		file.save(PLAYER_PATH)
	return identifier
