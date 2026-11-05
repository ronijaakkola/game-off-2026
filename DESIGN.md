# Design

What the game is. Read this before gameplay work and update it when the design changes. On jam day the content under each heading is replaced by the real game; the headings stay.

Right now it describes the **example game scene**: the small scene that shows the patterns to copy.

## Pitch

A cosy 3D toy: click a board to place pieces on it. It shows the soft look and the patterns for input, the signal bus, audio and settings working together.

## Core loop

1. The player points at the board, or at the top of a piece.
2. A click places a piece in the grid cell under the pointer: on the board, or stacked on the piece.
3. The game reacts: the placement SFX plays, the camera gives a small shake, and the HUD count goes up.

There is no goal and no failure state.

## Controls

| Input | Action |
|---|---|
| Left click on the board or a piece's top | Place a piece |
| Esc | Open or close the pause menu. In browser fullscreen, Esc leaves fullscreen and the pause menu opens |

Mouse only, apart from Esc. Open question: whether right-drag orbits the camera.

## Scenes and flow

```
main menu ──Play─────────▶ game ─────────Esc──▶ pause menu ──Main menu──▶ main menu
    ├──Phase Miner──▶ phase miner ──Esc──▶ pause menu
    │                                          │
    └──Settings──▶ settings panel ◀──────Settings
```

- **Main menu** (`ui/main_menu/`): the main scene. Title, Play, Settings, Quit (Quit hidden on web). On web, a title card (game title, "Click to start") comes first, and that click starts the menu music.
- **Game** (`game/`): the camera with one Phantom Camera shot (`BoardShot`), one shadowed sun, the soft-look environment, the board, and the HUD (`game/hud.tscn`) with the placed count. Placing a piece emits `Events.piece_placed`, and the HUD listens. Placing a piece calls `Feedback.shake`, which does nothing when Reduce motion is on. It instances the pause menu.
- **Phase Miner** (`phase_miner/`): the Phase Miner prototype, reached from the main menu's Phase Miner button. See Phase Miner prototype below. It instances the pause menu too.
- **Pause menu** (`ui/pause_menu/`): Resume, Settings, Main menu. Pauses the tree; music keeps playing. Also opens when the player leaves browser fullscreen.
- **Settings panel** (`ui/settings/`): Master, Music and SFX volume, and Reduce motion. Shared by the main menu and the pause menu.

Scene changes go through `SceneFlow.go_to`, which fades to black and back.

## Phase Miner prototype

A 3D take on the board scene of the Phase Miner 2D prototype (the "Phase Miner" artifact): only the field, the ship, slides and phases. No frameshift, sector map, trade post or pirates.

- The **field** is 8×8 cells and wraps at its edges. Each cell holds nothing, a rock, fuel ore, a drive crystal or scrap. Every row and column starts with an empty cell besides the ship's.
- A **phase** (arrow keys or WASD, 1 fuel) sends the ship along its row or column: it cruises over empty cells to the first item, destroys every item in the run that follows, and stops on the first empty cell after it. A line with nothing on it can't be phased.
- A **slide** (drag a row or column with the mouse, 1 fuel per cell) moves that line by whole cells, wrapping, and carries the ship when it is on it.
- The pieces use a flat, colourful style (after the flat-shadows style test in ronijaakkola/game-off-2026#4): `phase_miner/flat_face.gdshader` gives every face one flat colour from its direction against a fixed sun, with a violet shadow tint on the faces turned away. It is unshaded, so the scene has no lights, and the environment's tonemapper is set to linear so the colours show as written. Rocks are lavender, ore yellow, crystals magenta, scrap coral, the ship cyan.
- A rock costs 1 hull, ore gives 3 fuel, a crystal 50 points, scrap 20. Phases in a row that destroy items and hit no rock, with no slide between, build a **combo** worth 10 points per step from the second one.
- The run ends at 0 hull or 0 fuel; R starts a new one. A field with only rocks left is replaced by a fresh one.
- There is no board: the field floats in open space under the shared space sky (`shared/space_sky/`). A smoke grid shader (`phase_miner/smoke_grid.gdshader`) draws soft, drifting lines on the cell edges that fade out past the field's edge, and glows faintly over the ship's row and column and over a dragged line.
- The camera looks down at the field from about 52°, like a player across a chessboard, high enough that the back rows stay readable. Rocks, ore and scrap rest on the grid and crystals hover just above, so pieces overlap the cell behind them, while the grid stays readable.

The rules live in `phase_miner/phase_field.gd` (`PhaseField`), with no nodes, so they test without a scene. Open questions: whether slides should show a fuel-cost preview while dragging, and whether a phase should preview its path, as the 2D prototype does on hover.

## Scope

- **In:** the scenes above, ambient menu music, UI and placement SFX, settings saved across sessions.
- **Out:** levels, goals, scoring, saving progress, dialogue, positional or adaptive audio. These depend on the game idea and are built during the jam.

## Online

Online services run on Talo (`docs/online.md`), picked over Firestore in issue #5: analytics events, stats and play sessions now, leaderboards once there's a score. The example tracks one event, `piece_placed`. Uploaded replays (ghosts of other players' runs) don't fit Talo; a player's own ghost can stay in `user://`.
