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

**Open planet**:
The planet the player left-clicked to look at: the camera follows it on the left of the screen, and its **planet panel** on the right shows who is waiting there. One at a time. `SolarSystem.open_planet()` in code.
_Avoid_: selected planet, focused planet, planet view

**Open bus**:
The bus when the player left-clicked it to look at it: the camera follows it on the left of the screen, and its **bus panel** on the right shows its stats. Opening it closes the open planet, and opening a planet closes it. `SolarSystem.open_bus()`, `BusPanel` in code.
_Avoid_: selected bus, bus view, bus status (that is the panel in the bottom right)

**Dock panel**:
The panel just above the bus status while the bus is docked or charging, for what it can do at that planet: refuelling, and picking up the passengers waiting there, one by one or all at once. `DockPanel` in code.
_Avoid_: boarding popup, station menu, planet panel (that is the open planet's)

**Debug panel**:
A side panel of testing buttons, opened with F2, that each scene fills with its own. It ships in every build until the game is released. `DebugPanel` in code.
_Avoid_: cheat menu, dev menu, dev console (that is LimboConsole's, F1)

**Fuel**:
What the bus burns as it flies, by distance flown, held in its **fuel tank** (`FuelTank` in code). Shown in the bus status. **Refuelling** is buying it at the planet the bus is docked at, from the dock panel or the open planet's panel, at that planet's **fuel price**.
_Avoid_: energy, gas, charge (that is the frameshift drive's)

**Stat**:
A number on the bus that upgrades change, such as its top speed: a base value, with **modifiers** applied on top. `Stat` in code; the bus's are its `BusStats`, one of each `BusStats.Type`. Not the stats `Online.add_stat` sends to Talo, which count what players do.
_Avoid_: attribute, property, Talo stat

**Modifier**:
One change to one stat, flat (+5, in the stat's units) or a percent (+20 %): an upgrade's effect. The flat ones add to the base first, then the percents add together and scale the sum. `StatModifier` in code.
_Avoid_: buff, bonus, effect

**Trait**:
A feature on the bus that an upgrade unlocks, which the bus either has or doesn't, such as the **fuel forecast** (the fuel the course burns, shown over its last stop, `FuelForecast`): the on/off kind of stat. Whatever shows or does the feature asks whether the bus has it first. `BusTraits` in code, one of each `BusTraits.Type`, reached through `BusStats.get_traits()`.
_Avoid_: perk, flag, unlock (the purchase, not the thing)

**Tow**:
What brings a bus that ran out of fuel in space to the nearest planet, slowly and with the route out of the player's hands. A **tow ship** (`TowShip`) flies out from the planet, hitches on with a cable and leads the bus in, where it docks with a full tank, for a fee. `FrameshiftBus.tow_to()` moves the bus.
_Avoid_: rescue, respawn

**Passenger**:
Someone riding the bus to a destination planet, with a fare, a patience that runs down during the ride, and a mood that comes from it and sets what they pay. `Passenger` in code.
_Avoid_: customer, rider, NPC

**Patience**:
How much more riding a passenger will take, in seconds, starting at the direct trip time with some slack.
_Avoid_: frustration, timer, budget

**Rating**:
The stars, from 0 to 5, a passenger gives the ride on getting off. The player's **average rating** is the mean of every rating so far, shown beside the credits. `Passenger.get_rating()` and `RatingCounter` in code.
_Avoid_: reputation, review, score

**Portrait**:
A passenger's alien head and shoulders, shown in a photo frame on their card: a head shape, an eye style and their **race**'s skin colour (their **look**). `AlienPortrait` in code.
_Avoid_: avatar, face, picture

**Race**:
Which kind of alien a passenger is, shown only as their skin colour: teal, coral or mustard. Delivering them earns a research point of it. `Race.Type` in code.
_Avoid_: species, colour (that is how it shows), passenger type (fare, patience and needs)

**Research point**:
What delivering a passenger earns, one of their race's kind per delivery whatever the rating, kept apart by race and spent on upgrades in the research tree. `ResearchCounter` in code.
_Avoid_: science, XP, tech points

**Need**:
Something a passenger asks for during the ride, such as a snack. An open one is a **request**, which the player or an amenity serves.
_Avoid_: want, demand, task

**Amenity**:
Something on the bus that serves one need by itself. Upgrades add them.
_Avoid_: facility, station, upgrade (the purchase, not the thing)

**Cabin**:
The inside of the bus: the passengers on board and the amenities, run as a small simulation. `Cabin` in code.
_Avoid_: interior, passenger manager

**Kick**:
The player throwing a passenger off the bus mid-ride from their card, for nothing in return. A small figure in their skin colour (`KickedPassenger`) tumbles out of the door. `Cabin.kick()` in code.
_Avoid_: remove, drop off (that is getting off at their planet)

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
