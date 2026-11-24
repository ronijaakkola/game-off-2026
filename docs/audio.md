# Audio master list

Last updated: 2026-11-23

What plays, what is missing, and what each clip is. Levels are the mixer's table in `core/audio/clip_levels.gd` (1 is as recorded).

## In the game

### Music

| File | Plays when | Level | Status |
|---|---|---|---|
| `ui/audio/bg.ogg` | The music, from the main menu through the game. 88 bpm, 96 beats, loops from beat 32; everything that lands on the beat reads its grid | 1.0 | Done |
| `ui/audio/menu_music.ogg` | Nothing: the menu plays `bg.ogg`. It still shows in the mixer | 1.0 | Unused |

### Bus

| File | Plays when | Level | Status |
|---|---|---|---|
| `game/bus/flying.ogg` | The bus flies: fades in over 0.5 s, loops in step with the music (4 beats long, starting where the music is in its 4 beats) and fades out over 0.5 s when the flight ends. No pitch or speed change | 0.4 | Done |
| `game/bus/dock_bell.ogg` | The bus docks | 0.5 | Placeholder, "to be replaced with the final dock sound" |
| `ui/audio/key_click.ogg` | A bus key goes down, Space working the Frameshift key included. Also the refused click on a research tile that can't be researched | 1.0 | Placeholder |

### Fuel, calls and passengers

| File | Plays when | Level | Status |
|---|---|---|---|
| `game/solar_system/fuel.ogg` | The fuel pump, for as long as fuel flows | 0.35 | Done |
| `game/solar_system/ringtone.ogg` | A call notice shows: 2 beats at 88 bpm, looped from the music's next beat, fading out in 0.15 s as the call is answered or goes. Silent while the notices are hidden or the game is paused | 0.15 | Placeholder, "to be replaced with the final ringtone" |

### Menus and research

| File | Plays when | Level | Status |
|---|---|---|---|
| `ui/audio/ui_click.ogg` | The SFX slider moves in Settings, and a research hold completes. No menu button plays it | 1.0 | Placeholder |

### Alien voices

| Folder | Clips | Plays when | Status |
|---|---|---|---|
| `game/transmissions/voice/blue/` | 53: blips 23, long 8, question 4, exclaim 4, annoyed 4, happy 4, scared 3, kicked 3 | A transmission's text types out: a blip per word of three letters or more, the question and exclaim clips before `?` and `!`, a long clip at the start of a line, a stinger as it opens (the caller's mood). A passenger card opening a request for food or a drink plays the passenger's race's annoyed stinger, at their pitch. Each caller of a race has a pitch of their own. Each race's loudness is its voice's volume, set in the mixer | Done |
| `game/transmissions/voice/orange/` | 61: blips 18, long 8, question 9, exclaim 7, annoyed 3, happy 5, scared 9, kicked 2 | The same | Done |
| `game/transmissions/voice/green/` | 61: blips 19, long 8, question 4, exclaim 7, annoyed 6, happy 8, scared 7, kicked 2 | The same. Wired in with Orange's delivery numbers as a start; its loudness and delivery are still to be tuned in the voice lab and the mixer | Wired, to tune |

A kicked passenger screams one of their race's kicked clips (`k`), at their pitch times the voice's `kicked_pitch`, fading out over `kicked_fade`, at the voice's volume times `kicked_volume`. The kick is off in the game: hear it in the voice lab's Kicked button or the mixer's Kicked line.

## What is still silent

Nothing in the specs asks for these, so none is a bug. Every event below makes no sound today. Ordered by how often a player meets it, most first.

### Most often heard

- **Money.** Credits gained on a delivery (the gain chip), credits spent on fuel, an upgrade or the tow.
- **Boarding and getting off.** A passenger picked up, a passenger paid out, and a rating (a 5-star ride deserves more than a 3).
- **Serving.** The hold that serves a food or drink request (1.2 s, like the fuel pump), and the request done.
- **Setting a course.** A stop added to the route, a stop removed, the route cleared, the route set.
- **The drive.** Holding the Frameshift key charges the drive (the charge builds over 1.5 s), letting go drains it, and the bus leaves. Warm drive. The quick stop's window.
- **Every menu button.** Hover and press on the main menu, the pause menu, Settings, Controls and the campaign screen, the Back buttons, the toggles and the Hold to reset button as it fills. Only the SFX slider clicks today.
- **Notices.** An info notice showing ("The bus is already full!"), a warning, a goal done. A decline button hanging up a call.
- **The transmission.** The modal opening and closing, the tube turning on.

### Moments

- **Goals.** A milestone done, a standing goal met, The Boss's call that every goal holds, a promotion.
- **The jump to the next star system.** The wind-up rumble, the frameshift out, the screen going black, the frameshift in, and the bell.
- **Warp gates.** The ring's hum, the warp drive row pressed, the jump.
- **Quests.** A call answered, accepted, declined, done (and the caller's dance), failed.
- **Research.** The screen opening, a research completing, the badge nudging for a new upgrade.
- **Hints and the tutorial.** A feature hint's card appearing, Got it, a tutorial step finishing, the way-home waypoint being set.
- **Levels.** A level's loading screen, the Start button, a level completed, a scene fade.

### Trouble

- **Heat.** The bus getting too hot (above 32°), overheating and coasting to a stop, the smoke.
- **Fuel.** The tank running low, and empty.
- **The tow.** The tow ship frameshifting in, the cable hitching and twanging taut, the beacon, it reeling in and leaving.
- **The asteroid field.** Rocks slowing the bus, and every knock that shakes the passengers.
- **Passengers.** One leaving the line after 60 s, one losing a lot of happiness at once (a shock), and the mood changing to furious.

### Passenger life

- **Amenities.** The Food Dispenser, Waiter Droids, In-Flight Movies, the Honk and the Door chime upgrades, Pillows, a passenger dozing off.

### Music and ambience

- **Menu music.** `menu_music.ogg` is in the project and unused. The menus play the game's track.
- **A track for each star system** (Sol, Lyra, Draco), and one for the tutorial and the joined systems at the end.
- **A level-complete jingle.**
- **Space ambience** under the map, and the heat zone.

### Voices and the rest

- **The Boss.** His calls use a race's voice; a voice of his own would set him apart.

### Placeholders to replace before release

`dock_bell.ogg`, `key_click.ogg`, `ui_click.ogg` and `ringtone.ogg`.
