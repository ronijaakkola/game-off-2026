# Online

The game's online services run on [Talo](https://trytalo.com) (plugin 1.2.0, `addons/talo/`): analytics events, stats, play sessions and leaderboards. Game code talks to the `Online` core system (`core/online/online.gd`), which keeps the player's identity, batches what it sends, and stays offline wherever it shouldn't reach the network. Read this before wiring anything to it.

Why Talo: hosted free tier under 10,000 players with every feature, an MIT-licensed Godot plugin, and the dashboard does the analysis. Its limits: a prop value is at most 512 characters and there's no file storage, so uploaded ghost replays don't fit (issue #5 has the comparison with Firestore).

## Setup

Once, by a human:

1. Sign up at [dashboard.trytalo.com](https://dashboard.trytalo.com) and create the game.
2. **API keys** page: create a key with these scopes, read and write unless noted:
   - `players`
   - `events` (write)
   - `gameStats`
   - `leaderboards`
   - `continuityRequests` (write): replays requests that failed while offline.
3. Paste the key into `access_key` in `core/online/talo_settings.cfg` and commit it. It isn't a secret: the file ships in the web build as plain text, so anyone who downloads the game can read it, and committing it only spares the team a setup step. Until then, `Online` is offline and a web build logs one error at boot (`Unable to create key file`, from Talo's crypto manager).
4. **Game settings** page: set **Display name prop key** to `name`. Leaderboards then show the name a player picks with `Online.set_player_name()` instead of their random identifier.
5. Check it: run the game from the editor (F5), open the console (F1) and type `online`. It answers `Online as <identifier>, name not set, session open`, and the player appears on the dashboard's **Players** page.

## When it's on

| Run | Online | Data |
|---|---|---|
| Editor (F5, F6) | On | Dev |
| Preview build (debug template) | On | Dev |
| itch.io build (release template) | On | Live |
| Headless: CI, `check.py`, gdUnit4 | Off | None |
| No `access_key` | Off | None |

Dev data is marked in the dashboard and kept apart from live data; dev players stay dev. Talo decides it from the build's `debug` feature tag ([Exporting](https://docs.trytalo.com/1.x/godot/exporting)).

Offline, every `Online` call is safe: it does nothing, or returns null or an empty array.

## What happens on its own

- **Identity.** On first run `Online` makes a random identifier, keeps it in `user://online.cfg`, and identifies the player as an `anonymous` alias. Each browser is one player for as long as it keeps `user://`; incognito or blocked storage makes a new player each visit.
- **Sessions.** Talo counts a session while the player is identified on its socket, which `Online` opens. The dashboard shows sessions and average session length. Closing the tab ends the session.
- **Meta props.** Every event carries the OS, `application/config/version` from `project.godot`, the window mode and the window size.

## Wiring things up

Analytics hang off bus events, so gameplay code only emits what happened. `core/online/tracking.gd` is the one place that turns bus events into Talo events and stats: add the bus event to `core/events/events.gd`, emit it, and connect it there.

```gdscript
# core/online/tracking.gd
func _ready() -> void:
	Events.level_completed.connect(_on_level_completed)
	Events.player_died.connect(_on_player_died)


func _on_level_completed(level: int, seconds: float) -> void:
	Online.track("level_completed", {"level": level, "seconds": snappedf(seconds, 0.1)})


func _on_player_died(level: int) -> void:
	Online.track("player_died", {"level": level})
	Online.add_stat("deaths")
```

| Want | Call | Dashboard setup |
|---|---|---|
| Count what players do, broken down by props (which level, how long) | `Online.track(event_name, props)` | None. Name it after its bus event. |
| A running total per player and across all players (deaths, pieces placed) | `Online.add_stat(internal_name, change)` | Create the stat first: internal name in kebab-case, **Global** on for an all-players total. Leave **Min time between updates** at 0. |
| A high score table | `await Online.submit_score(leaderboard, score, props)` returns the entry; `entry.position` is the rank from 0 | Create the leaderboard: internal name, sort mode, **Unique** on to keep one best entry per player. |
| Show the table | `await Online.get_scores(leaderboard, limit)`; `entry.player_alias.display_name`, `entry.score`, `Online.is_own(entry)` | |
| The player's name on leaderboards | `Online.set_player_name(name)`, `Online.get_player_name()` | The display name prop key (Setup, step 4). |
| Send now, at the end of a run | `Online.flush()` | |

Events and stat changes queue up and go out every 15 seconds, when the window loses focus (Godot's `NOTIFICATION_APPLICATION_FOCUS_OUT`), and on `Online.flush()`. Event props are strings by the time they reach Talo; the dashboard breaks events down by them, and builds funnels (how many reach level 3 after level 1) and retention from them.

For anything else Talo does (saves, live config, feedback, player props, channels), add a method to `core/online/online.gd` that checks `Online.is_identified()` first, as the others do. Only `core/online/` may name the `Talo` autoload: `check.py lint` fails anywhere else (rule `talo-through-online`), except in tests, `tools/` and `dev_commands.gd`. The [Godot docs](https://docs.trytalo.com/1.x/godot/install) cover each one. Before changing anything live after the jam's deadline, such as live config, check the jam's rules.

## Trying it out

The dev console (F1) has commands for each part. It runs in editor runs and preview builds, so the same commands check the web build in Chrome and Safari.

| Command | Does |
|---|---|
| `online` | Shows whether `Online` is on, identified, and has a session |
| `online_track <event>` | Tracks an event and sends it at once |
| `online_score <leaderboard> <score>` | Submits a score and prints its rank |
| `online_scores <leaderboard>` | Prints the top 10 |

To see every request and response in the Output panel, add this to `talo_settings.cfg` without committing it. Talo logs them in debug builds only.

```ini
[logging]

requests=true
responses=true
```

## Cleaning up

The key ships in the build, so anyone can post any score. For a jam that's accepted; clean up in the dashboard. On a leaderboard's page, an entry can be hidden or its score edited, and the whole board reset. On the **Players** page, a player can be deleted with all their data.

## On the web

- Requests are ordinary HTTPS calls from the page, and Talo's API accepts them from any origin ([its CORS middleware](https://github.com/TaloDev/backend/blob/develop/src/middleware/cors-middleware.ts)). No build with a key has run in a browser yet: the first preview build with one is the test, in Chrome and Safari.
- A closed tab sends nothing, so up to 15 seconds of events and stat changes are lost. Call `Online.flush()` at the moments that matter.
- Desktop builds quit through Talo, which sends its event queue before quitting. That's why the main menu's Quit sends a close request instead of calling `get_tree().quit()`.
