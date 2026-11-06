# Design

What the game is. Read this before gameplay work and update it when the design changes.

**Frameshift Bus.** The core loop below is the design; it isn't built yet. What Play opens today is the solar system look prototype (Scenes and flow). The example game scene is still in the repo and shows the patterns to copy.

## Pitch

You drive a bus around a small solar system. Pick up passengers, plot a route through space and get them to their planet before they lose patience. The planets keep orbiting, so a route that is short now may not be short in a few seconds.

## Core loop

1. **Docked.** The bus starts docked at a planet. Passengers wait at planets, each with a destination planet, a fare and a patience timer. While docked (or charging), the player picks passengers up into the bus's seats.
2. **Set course.** Clicking a planet sets it as the destination. Each planet shows the fuel cost and travel time to it, both from the distance right now. Clicking empty space sets a point in space as the destination instead. Shift-click adds a waypoint to the end of the route, so a route can have several points. The route is drawn as a line from the bus through each point.
3. **Charge.** The frameshift drive charges for 3 s before the bus leaves a planet. While it charges, the player can cancel, or change the route.
4. **Fly.** The bus flies the route point by point. The player can reroute at any time from wherever the bus is, the same way as setting a course, with no charge-up and no extra fuel cost: fuel burns by distance flown, so a reroute costs only the distance it adds.
5. **Arrive.** At a planet, passengers going there get off and pay by their mood: happy pays 1.2× the fare, okay 1×, annoyed 0.5×, furious nothing.
6. **Refuel.** Three of the six planets have a fuel depot. Docked at one, the player can refuel; it takes a few seconds.

A passenger's patience runs down while they ride, at half speed while the bus is docked. It starts at the direct trip time with some slack, so a straight trip keeps them happy and detours cost mood. Mood comes from patience left: happy at 60 % or more, okay at 30 % or more, annoyed above 0, furious at 0. The fare grows with the distance to the destination.

## Goal

A temporary goal while the loop is tuned:

- **Win:** deliver 50 passengers.
- **Lose:** the happiness score stays at 0 for 20 s.

The happiness score isn't defined yet (see Open questions).

## Controls

Planned for the core loop, not built yet:

| Input | Action |
|---|---|
| Left click a planet | Set course to it |
| Left click empty space | Set course to that point |
| Shift + left click | Add a waypoint to the end of the route |
| Left click a waiting passenger | Pick them up |

Built, in the solar system, which Play opens:

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
- **Solar system** (`game/solar_system/`): what Play opens: a look prototype for the space game. A yellow star and four flat, toon-lit planets (one with a moon, one with rings) on circular orbits, over the `SpaceSky`, seen through an RTS camera rig (`camera_rig.tscn`): one Phantom Camera shot that pans and zooms within limits set on the rig. It instances the pause menu.

Scene changes go through `SceneFlow.go_to`, which fades to black and back.

## Scope

- **In:** the core loop, the temporary goal, one kind of passenger, fuel and depots. Already built: the scenes above, ambient menu music, UI and placement SFX, settings saved across sessions.
- **Out for now:** everything under Research until it is designed, saving progress, dialogue, positional or adaptive audio.

## Research

Features we will very probably build, but that need more design work first.

- **Research tree.** Upgrades for the bus, bought with credits and research points. Each passenger type gives a different kind of research point.
- **Passenger types.** Around three types with different qualities. The prototype had Business (pays 1.6×, little patience), Tourist (pays 1×, lots of patience) and Student (pays 0.7×, in between).
- **Environment.** How space affects the bus and passengers. A hot star makes passengers on a route near it hot; a big planet's gravity slows the bus down near it.

### Open questions

- **Happiness score.** What it measures. One option: the average mood of the passengers on board, with the 20 s countdown paused when the bus is empty, so a bus full of furious passengers is the losing state.
- **Out of fuel in space.** Fuel burns as the bus flies, so it can run dry between planets. Does it drift, get towed for a fee, or end the run?
- **Fuel shown for a free point and for waypoints.** Whether the route line shows the total fuel and time like a planet does.
- **Seats and waiting passengers.** The prototype had 4 seats and up to 3 waiting per planet; keep them until playtests say otherwise.

## Online

Online services run on Talo (`docs/online.md`), picked over Firestore in issue #5: analytics events, stats and play sessions now, leaderboards once there's a score. The example tracks one event, `piece_placed`. Uploaded replays (ghosts of other players' runs) don't fit Talo; a player's own ghost can stay in `user://`.
