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
| Esc | Open or close the pause menu |
| Pause button (top right) | Open the pause menu. Browser fullscreen swallows Esc, so this is the way to pause there |

Mouse only, apart from Esc. Open question: whether right-drag orbits the camera.

## Scenes and flow

```
main menu ──Play──▶ game ──Esc or Pause──▶ pause menu ──Main menu──▶ main menu
    │                                           │
    └──Settings──▶ settings panel ◀───────────Settings
```

- **Main menu** (`ui/main_menu/`): the main scene. Title, Play, Settings, Quit (Quit hidden on web). On web, a title card (game title, "Click to start") comes first, and that click starts the menu music.
- **Game** (`game/`): camera, one shadowed sun, the soft-look environment, the board, and the HUD (`game/hud.tscn`) with the placed count and a Pause button. Placing a piece emits `Events.piece_placed`, and the HUD listens. Placing a piece calls `Feedback.shake`, which does nothing when Reduce motion is on. It instances the pause menu.
- **Pause menu** (`ui/pause_menu/`): Resume, Settings, Main menu. Pauses the tree; music keeps playing.
- **Settings panel** (`ui/settings/`): Master, Music and SFX volume, and Reduce motion. Shared by the main menu and the pause menu.

Scene changes go through `SceneFlow.go_to`, which fades to black and back.

## Scope

- **In:** the scenes above, ambient menu music, UI and placement SFX, settings saved across sessions.
- **Out:** levels, goals, scoring, saving progress, dialogue, positional or adaptive audio. These depend on the game idea and are built during the jam.

## Online

Online services run on Talo (`docs/online.md`), picked over Firestore in issue #5: analytics events, stats and play sessions now, leaderboards once there's a score. The example tracks one event, `piece_placed`. Uploaded replays (ghosts of other players' runs) don't fit Talo; a player's own ghost can stay in `user://`.
