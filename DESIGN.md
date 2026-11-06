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

In the solar system, which Play opens:

| Input | Action |
|---|---|
| W A S D, the arrow keys, or the pointer at a window edge | Pan the camera across the orbit plane. The look-at point stops at the outermost orbit |
| Mouse wheel | Zoom in and out toward the point under the pointer, between a closest and a farthest distance |
| Esc | Open or close the pause menu. In browser fullscreen, Esc leaves fullscreen and the pause menu opens |

WASD reads physical key positions, so it sits in the same place on every keyboard layout. Edge pan starts only once the pointer has moved inside the game, and stops when it leaves the window or the window loses focus, so a pointer that left through an edge doesn't keep the camera moving. In the example game scene, a left click on the board or a piece's top places a piece.

## Scenes and flow

```
main menu ──Play──▶ solar system ──Esc──▶ pause menu ──Main menu──▶ main menu
    │                                          │
    └──Settings──▶ settings panel ◀──────────Settings
```

- **Main menu** (`ui/main_menu/`): the main scene. Title, Play, Settings, Quit (Quit hidden on web). On web, a title card (game title, "Click to start") comes first, and that click starts the menu music.
- **Example game** (`game/game.tscn`): no longer reached from the menu; its tests still load it. The camera with one Phantom Camera shot (`BoardShot`), one shadowed sun, the soft-look environment, the board, and the HUD (`game/hud.tscn`) with the placed count. Placing a piece emits `Events.piece_placed`, and the HUD listens. Placing a piece calls `Feedback.shake`, which does nothing when Reduce motion is on. It instances the pause menu.
- **Pause menu** (`ui/pause_menu/`): Resume, Settings, Main menu. Pauses the tree; music keeps playing. Also opens when the player leaves browser fullscreen.
- **Settings panel** (`ui/settings/`): Master, Music and SFX volume, and Reduce motion. Shared by the main menu and the pause menu.
- **Solar system** (`game/solar_system/`): what Play opens: a look prototype for the space game. A yellow star and four flat, toon-lit planets (one with a moon, one with rings) on circular orbits, over the `SpaceSky` with parallax on, seen through an RTS camera rig (`camera_rig.tscn`): one Phantom Camera shot that pans and zooms within limits set on the rig. It instances the pause menu.

Scene changes go through `SceneFlow.go_to`, which fades to black and back.

## Scope

- **In:** the scenes above, ambient menu music, UI and placement SFX, settings saved across sessions.
- **Out:** levels, goals, scoring, saving progress, dialogue, positional or adaptive audio. These depend on the game idea and are built during the jam.

## Online

Online services run on Talo (`docs/online.md`), picked over Firestore in issue #5: analytics events, stats and play sessions now, leaderboards once there's a score. The example tracks one event, `piece_placed`. Uploaded replays (ghosts of other players' runs) don't fit Talo; a player's own ghost can stay in `user://`.
