# Godot jam boilerplate

The starting project the team clones on jam day: core systems, a main menu and the example game scene, ready to be replaced by the real game.

## Language

**Core system**:
A game-wide service that outlives scene changes and has one instance: the signal bus, audio, scene flow, settings, feedback and online.
_Avoid_: manager, singleton, global

**Frameshift Bus**:
The player's vehicle, which flies between planets. `FrameshiftBus` in code, in `game/bus/`; "bus" in prose and node names when the context is the game.
_Avoid_: `Bus` as a class name (it shadows `Audio.Bus`), ship, vehicle

**Route**:
The ordered stops the bus flies through, each a planet or a point in space. A **course** is the route the player sets with a click.
_Avoid_: path, waypoints list

**Docked**:
The bus waiting beside a planet, moving with it. Leaving a planet takes a **charge** of the frameshift drive first.
_Avoid_: landed, parked

**Signal bus**:
The core system that carries bus events between parts of the game that don't know each other. Named `Events` in code.
_Avoid_: event bus, SignalBus, global signals

**Bus event**:
A past-tense broadcast fact on the signal bus whose emitter neither knows nor cares who listens (e.g. `level_completed`).
_Avoid_: global signal, message

**Command**:
A direct request to a core system to do something (e.g. go to a scene, play a sound). Never a bus event.
_Avoid_: request signal, `*_requested`

**Scene flow**:
The core system that moves the player between top-level scenes (menu → game) with transitions. Named `SceneFlow` in code.
_Avoid_: router, scene manager

**Feedback**:
The core system that plays short game-feel effects, such as a camera shake, when game code asks for one. Each effect decides for itself what Reduce motion does to it. Named `Feedback` in code.
_Avoid_: juice, screen effects, FX manager

**Settings**:
The player's preferences (volumes, mouse sensitivity and similar), kept across sessions. Never game progress. Named `Settings` in code.
_Avoid_: options, config, preferences file

**Save game**:
The player's progress in the game itself. It depends on the game idea, so the boilerplate doesn't have one.
_Avoid_: settings, save file (ambiguous)

**Online**:
The core system for the game's online services (analytics events, stats, play sessions and leaderboards) through Talo. It is on only in web builds with an access key. Named `Online` in code.
_Avoid_: backend, network manager, Talo (the service, not our code)

**Tracking**:
Turning bus events into analytics events and stats, all in `core/online/tracking.gd`.
_Avoid_: telemetry, logging, metrics

**Passenger**:
Someone riding the bus to a destination planet, with a fare, a patience that runs down during the ride, and a mood that comes from it and sets what they pay. `Passenger` in code.
_Avoid_: customer, rider, NPC

**Patience**:
How much more riding a passenger will take, in seconds, starting at the direct trip time with some slack.
_Avoid_: frustration, timer, budget

**Portrait**:
A passenger's alien head and shoulders, shown in a photo frame on their card: a head shape, an eye style and a race colour (their **look**). `AlienPortrait` in code.
_Avoid_: avatar, face, picture

**Need**:
Something a passenger asks for during the ride, such as a snack. An open one is a **request**, which the player or an amenity serves.
_Avoid_: want, demand, task

**Amenity**:
Something on the bus that serves one need by itself. Upgrades add them.
_Avoid_: facility, station, upgrade (the purchase, not the thing)

**Cabin**:
The inside of the bus: the passengers on board and the amenities, run as a small simulation. `Cabin` in code.
_Avoid_: interior, passenger manager

**Activity**:
The short line on a passenger's card saying what they are doing now.
_Avoid_: status, action

**Example game scene**:
The small playable scene that shows the patterns to copy; it is replaced by the real game on jam day.
_Avoid_: demo, sample level

**Shot**:
One place and behaviour for the game camera, as a Phantom Camera `PhantomCamera3D` node: fixed, following or looking at a target. The camera shows the active shot, the one with the highest priority, and blends between shots.
_Avoid_: virtual camera, pcam, camera (the `Camera3D` that renders)

**Model library**:
The one Blender file that holds every 3D model in the game, each as its own collection, kept by whoever makes models and never committed. Only the models exported from it are shared.
_Avoid_: blend file, source file, master file

**Visual check**:
A human looking at a change in the editor or browser to judge its feel, which an agent can't sign off on alone.
_Avoid_: QA, review

**Load check**:
Compiling every script in the project at once to catch syntax and type errors before anything runs.
_Avoid_: check-only, compile check

**Smoke run**:
Starting the game briefly without a window and failing if any error is logged, since runtime errors don't stop the game on their own.
_Avoid_: smoke test, headless run

**Handoff**:
An agent's final message when it finishes a task: what it ran and what came out, and what a human still has to do, such as a visual check.
_Avoid_: summary, wrap-up, report, PR body

**PR body**:
The description of one pull request's change, written for whoever reviews it: what changed, the evidence it works, and what it can reach. Distinct from the handoff, which is the agent's final message in chat.
_Avoid_: PR description, handoff

**Scene test**:
A test that runs one scene and drives it the way a player would, with clicks and keys, then checks what the player would see or hear, or a bus event. The default kind of test.
_Avoid_: integration test, end-to-end test, UI test

**Unit test**:
A test that calls a script's public methods directly, with no player input: for logic with many cases, for a bug a scene test can't reach, and for core systems, whose public calls are the unit.
_Avoid_: system test, logic test

**Preview build**:
A playable web build of one open pull request at its own address, with the dev console and script errors visible, removed when the pull request closes. Not a measure of performance; the itch.io build is.
_Avoid_: PR build, staging build, preview deploy
