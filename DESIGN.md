# Design

What the game is. Read this before gameplay work and update it when the design changes.

**Frameshift Bus.** The core loop below is the design. Built so far: the bus docks, charges and flies routes in the solar system (steps 1 to 4: docking, charging, flying and rerouting, without passengers, fuel or the planets' cost and time labels). What Play opens today is that solar system (Scenes and flow). The example game scene is still in the repo and shows the patterns to copy.

## Pitch

You drive a bus around a small solar system. Pick up passengers, plot a route through space and get them to their planet before they lose patience. The planets keep orbiting, so a route that is short now may not be short in a few seconds.

## Core loop

1. **Docked.** The bus starts docked at a planet. Passengers wait at planets, each with a destination planet, a fare and a patience timer. While docked (or charging), the player picks passengers up into the bus's seats.
2. **Set course.** Right-clicking a planet sets it as the destination. Each planet shows the fuel cost and travel time to it, both from the distance right now. Right-clicking empty space sets a point in space as the destination instead. Shift + right-click adds a waypoint to the end of the route, so a route can have several points. Left click is for selecting things, such as opening a planet. The route is drawn as a line from the bus through each point.
3. **Charge.** The frameshift drive charges for 3 s before the bus leaves a planet, and the bus turns toward its next stop meanwhile. While it charges, the player can cancel, or change the route.
4. **Fly.** The bus flies the route point by point. The player can reroute at any time from wherever the bus is, the same way as setting a course, with no charge-up and no extra fuel cost: fuel burns by distance flown, so a reroute costs only the distance it adds.
5. **Arrive.** At a planet, passengers going there get off and pay by their mood: happy pays 1.2× the fare, okay 1×, annoyed 0.5×, furious nothing.
6. **Refuel.** Three of the six planets have a fuel depot. Docked at one, the player can refuel; it takes a few seconds. If the bus runs out of fuel in space, the player pays for a tow to the nearest depot planet. The tow costs money, and the time it takes costs passengers' patience.

A passenger's patience holds until the bus leaves the planet they boarded at, then runs down while they ride, at half speed while the bus is docked. It starts at the direct trip time with some slack, so a straight trip keeps them happy and detours cost mood. Mood comes from patience left: happy at 60 % or more, okay at 30 % or more, annoyed above 0, furious at 0. The fare grows with the distance to the destination.

### On board

Each passenger on board has a card down the left edge of the screen: name, type, destination (a small flat icon of the planet and its name), a patience bar in their mood's colour, and a short line saying what they are doing ("Sleeping...", "Counting stars"), starting with "Finding their seat..." for a few seconds after boarding. Built in `game/passengers/`, and running in the solar system:

- **Waiting and boarding (first phase).** Each planet, the Moon included, gets a new passenger every 8 to 20 s, up to 3 waiting, each going to another planet at random. They are hidden for now and lose no patience while they wait. Whenever the bus docks at a planet, it makes a stop there: the passengers going there get off one at a time and pay, then those waiting board one at a time, longest waiting first, while any of the 4 seats are free. Each takes 0.6 s, so a busy stop takes longer and an empty one none. The drive can't charge until the stop is over: a course set during it charges once the last passenger is on. A passenger getting off pays by the mood they arrived in. Their card slides out past the left edge of the screen and the cards below move up into the gap; one boarding slides in at the bottom from past the left edge. The game starts with one passenger on board at Ember.
- **Trip time and fare** come from the straight distance at boarding: the trip time is the charge plus that distance at the bus's top speed, and the fare is 3 credits per unit times the type's multiplier. Planets move, so it is only an estimate.
- **Credits** show in the top right. Payments at a stop collect in a green gain just under the total ("+15"): with each one it pops bigger for a moment and shows the new sum. Once everyone going there is off, after a short delay the total counts up to include it one credit at a time, while the gain fades out drifting upward.
- **Bus status** shows in the bottom right (`game/bus/bus_status_panel.tscn`): what the bus is doing ("Docked at Terra", "Charging frameshift", "Travelling to Terra", "Docking to Terra", "Heading to waypoint", "Stopping", "Holding in space"), a track from the planet it left (or "Space") to the next planet on the route with the time left to it, and a person for each seat, filled while taken, with the count ("3/4 seats"). Docking is the braking at the end of a flight to a planet. The time left is an estimate from the distance now: the charge left, the route's straight legs at top speed, speeding up and braking. The track never moves back, so a planet that moves away slows it instead. While the bus charges or flies, a button cancels the course: "Cancel" keeps a charging bus docked, and "Cancel route" slows a flying one to a stop in space.

- **Needs.** Each passenger type has a few needs, such as a snack or a drink. Each need asks again a random while after the last one was served. While a request is open, the card says so ("Hungry. Wants a snack") and shows a button to serve it, and patience runs down several times faster. A request stays open until it is served, never expiring, since a request that expired would make ignoring a passenger cheaper than serving them. One request at a time, and the other needs' timers wait while it is open, so serving one doesn't set off the rest at once. A served need shows its own line ("Munching a snack") for a few seconds.
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
- **Planet icons** (`planet_icon.gdshader`). The UI shows a planet as a flat disc in its one icon colour, with the same purple night side as in the world, lit from the upper left. A planet with rings shows them as a line at its tilt, passing behind the disc at the top and in front at the bottom; its disc is smaller, so the rings fit at any tilt. Each planet's icon colour is set by hand to the colour it reads as from the camera.
- **Names.** Each planet and moon has its name just under it: small off-white text with the sky's lilac, a little see-through, with a thin navy outline so it still reads where it crosses an orbit line. The text faces the camera and keeps its size on screen at any zoom; the bus passes in front of it.
- **Sky** (`SpaceSky`). A deep navy-violet background with faint coloured fog and two layers of small stars. It is dim on purpose, so the planets stand out. It doesn't light the planets.

- **Bus** (`game/bus/models/bus.glb`, from the model library). A flat yellow space bus with rounded, faceted edges: a sloped windscreen, a row of dark lilac side windows over a white stripe, a door, a white roof with two vents, a dark hull underneath (no wheels) and two thrusters at the back. It is lit with the planets' two tones in the colours it was made with. The thrusters are dark while it is docked. As the drive charges, a pale cyan exhaust cone grows out of each one, full length in flight, and shrinks back after it docks. In flight the bus leaves a flat pale cyan trail on the orbit plane that narrows and fades out over 2.5 s.

Anything new (passengers, UI) follows the same rules: flat colour, hard edges, a two-tone shade at most, no textures. It keeps the scene cheap on the web too: no post-processing so far, since each effect adds a full-screen pass (`docs/web-constraints.md`).

## Controls

Planned for the core loop, not built yet:

| Input | Action |
|---|---|
| Left click a planet | Open its panel: the fuel cost and time to get there, and who is waiting |
| Left click empty space | Close the open panel |
| Left click a waiting passenger | Pick them up |

Esc stays pause only. In browser fullscreen the browser takes Esc to leave fullscreen and the game never sees it, so Esc can't close a panel the same way in a window and in fullscreen.

Built, in the solar system, which Play opens:

| Input | Action |
|---|---|
| Pointer over a planet | Shows a white border round it (over its orange route border) |
| Right click a planet | Set course straight to it |
| Right click empty space | Set course to that point on the orbit plane |
| Shift + right click | Add a planet or point to the end of the route |
| Right click the last stop | Remove it from the route, with or without Shift. Only the last one: right-clicking a stop in the middle sets course there, and Shift adds it again, so a route can come back to a planet. With no stop left, the course is cancelled |
| Right click the planet the bus is docked at | Cancel the course: a charging drive stops |
| The bus status panel's Cancel / Cancel route button | Cancel the course while the bus charges or flies. A flying bus slows to a stop in space |
| W A S D, the arrow keys, or the pointer at a window edge | Pan the camera across the orbit plane. The look-at point stops at the outermost orbit |
| Mouse wheel | Zoom in and out toward the point under the pointer, between a closest and a farthest distance |
| Esc | Open or close the pause menu. In browser fullscreen, Esc leaves fullscreen and the pause menu opens |

The bus flies on the orbit plane at 1.2 units a second, a little faster than the mockup's trip times: a planet orbits at under 40 % of the bus's speed, so the bus catches one without a long chase. Docked, it floats beside its planet (a barely visible bob and sway) and moves with it. Leaving a planet charges the drive first: a white ring round the bus fills clockwise (temporary), and the bus shakes slightly, unless Reduce motion is on. While it charges, the bus turns toward its next stop, so it leaves already facing it, and speeds up as it goes. It passes through points in space, docks at every planet on the route and charges again before leaving each one, and holds still at a point in space that ends the route. A planet stop is the planet's near side, so the bus chases a moving planet. Right-clicking the planet it is docked at cancels the course. Until the player first sets a course, a hint at the bottom of the screen says how: "Right-click a planet or space to set course. Shift + right-click adds a stop." The route is a flat orange line from the bus through each stop, with a diamond at each point in space. It runs to a planet's surface, and every planet on the route has an orange border, so planets read as part of the route. Under the pointer, the last stop's diamond turns white, as a planet's border does, and right-clicking it removes it. Diamonds earlier on the route stay orange.

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
- **Solar system** (`game/solar_system/`): what Play opens. A yellow star and four flat, toon-lit planets (one with a moon, one with rings) on circular orbits, over the `SpaceSky` with parallax on (its star and fog layers drift slightly as the camera moves, and hold still under Reduce motion), seen through an RTS camera rig (`camera_rig.tscn`): one Phantom Camera shot that pans and zooms within limits set on the rig. The scene's script turns the pointer into planet hover and course clicks for the bus (`game/bus/bus.tscn`), which starts docked at Ember. It also runs the passengers (a `Cabin`, `WaitingPassengers`, and the HUD with the passenger cards and credits). It instances the pause menu.

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
