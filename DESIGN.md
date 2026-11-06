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
6. **Refuel.** Three of the six planets have a fuel depot. Docked at one, the player can refuel; it takes a few seconds. If the bus runs out of fuel in space, the player pays for a tow to the nearest depot planet. The tow costs money, and the time it takes costs passengers' patience.

A passenger's patience runs down while they ride, at half speed while the bus is docked. It starts at the direct trip time with some slack, so a straight trip keeps them happy and detours cost mood. Mood comes from patience left: happy at 60 % or more, okay at 30 % or more, annoyed above 0, furious at 0. The fare grows with the distance to the destination.

### On board

Each passenger on board has a card down the left edge of the screen: name, type, destination, a patience bar in their mood's colour, and a short line saying what they are doing ("Sleeping...", "Counting stars"). Built in `game/passengers/` (the cabin and the cards), not yet reached from Play: picking up at planets and getting off at the destination come once the bus is in.

- **Needs.** Each passenger type has a few needs, such as a snack or a drink. Each need asks again a random while after the last one was served. While a request is open, the card says so ("Hungry. Wants a snack") and shows a button to serve it, and patience runs down several times faster. One request at a time; a served need shows its own line ("Munching a snack") for a few seconds.
- **Amenities.** Something on the bus that serves one need by itself, the moment it is asked for, with its own line ("Getting a drink from the dispenser"). This is what upgrades buy: each one takes a chore off the player. None exist yet.
- **Passenger types** are data (a `PassengerType` resource): fare multiplier, patience slack, needs, idle lines and names. There is one, the Commuter.

## Goal

A temporary goal while the loop is tuned:

- **Win:** deliver 30 passengers.
- **Lose:** the happiness score stays at 0 for 20 s.

The happiness score isn't defined yet (see Open questions).

## Look

Flat and cartoony, like a picture book of the solar system: solid colours with crisp edges, no textures, no realistic light. Everything is generated from shaders and meshes in code, so there are no image assets to make.

- **Camera.** Looks down at the orbit plane at an angle, with a narrow field of view (30°), so the system reads almost like a map but the planets still look round.
- **Planets** (`planet.gdshader`). Each is a sphere with up to three colour bands with hard edges: noise blobs for rocky planets (continents, craters), wobbly horizontal stripes for gas giants, and optional polar caps. The pattern turns with the planet's spin. Light is two tones only: a lit side in the planet's own colours, and a night side tinted by the same purple multiply on every planet, split by a line about a pixel wide at any zoom. The star's distance and the ambient light don't change a planet's colours.
- **Colours.** Soft, warm and saturated, never dark: sandy orange, leaf green, a pale lilac moon, an orange-striped gas giant with lilac rings, a pink ice planet with white caps. Planets are told apart by colour first, so each new one needs its own hue.
- **Star.** An unlit yellow sphere with a flat halo of a few see-through discs that always face the camera. No bloom or glow pass.
- **Rings and orbits.** Unlit, flat bands with hard edges. Every orbit is drawn as a thin, faint lilac line, so the player can see where each planet is going.
- **Sky** (`SpaceSky`). A deep navy-violet background with faint coloured fog and two layers of small stars. It is dim on purpose, so the planets stand out. It doesn't light the planets.

Anything new (the bus, passengers, route line, UI) follows the same rules: flat colour, hard edges, a two-tone shade at most, no textures. It keeps the scene cheap on the web too: no post-processing so far, since each effect adds a full-screen pass (`docs/web-constraints.md`).

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
- **Passenger types.** Around three types with different qualities. The prototype had Business (pays 1.6×, little patience), Tourist (pays 1×, lots of patience) and Student (pays 0.7×, in between). Types also differ in what they need on board, so a rich passenger might want a sleeping pod where a student wants only snacks.
- **Environment.** How space affects the bus and passengers. A hot star makes passengers on a route near it hot; a big planet's gravity slows the bus down near it.

### Open questions

- **Happiness score.** What it measures. One option: the average mood of the passengers on board, with the 20 s countdown paused when the bus is empty, so a bus full of furious passengers is the losing state.
- **Tow.** What it costs, how fast it is, and what happens when the player can't afford it.
- **Fuel shown for a free point and for waypoints.** Whether the route line shows the total fuel and time like a planet does.
- **Seats and waiting passengers.** The prototype had 4 seats and up to 3 waiting per planet; keep them until playtests say otherwise.

## Online

Online services run on Talo (`docs/online.md`), picked over Firestore in issue #5: analytics events, stats and play sessions now, leaderboards once there's a score. The example tracks one event, `piece_placed`. Uploaded replays (ghosts of other players' runs) don't fit Talo; a player's own ghost can stay in `user://`.
