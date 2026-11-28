# Audio master list

Last updated: 2026-11-27

What plays, what is missing, and what each clip is. Levels are the mixer's table in `core/audio/clip_levels.gd` (1 is as recorded). The mix, each alien voice's volume of 0.4 included, is set with the Master, Music and Sound effects sliders at their default, the middle (0.5).

## In the game

### Music

| File | Plays when | Level | Status |
|---|---|---|---|
| `ui/audio/bgm1.ogg` | The main menu, Level 1 (Vela) and Level 3 (Sol). 88 bpm, 96 beats, loops from beat 32; everything that lands on the beat reads its grid | 0.7 | Done |
| `ui/audio/bgm2.ogg` | Level 2 (Lyra). It fades in as the track before fades out, over 2 s, as the bus crosses into the system or the level starts. 88 bpm, 192 beats, loops from beat 64 (0:43.63 to 2:10.90) | 0.7 | Done |
| `ui/audio/menu_music.ogg` | Nothing: the menu plays `bgm1.ogg`. The itch.io build leaves it out (the Web preset in `export_presets.cfg`), so it shows in the mixer only in the editor and the preview build | 0.7 | Unused |

### Bus

| File | Plays when | Level | Status |
|---|---|---|---|
| `game/bus/flying.ogg` | The bus flies: fades in over 0.5 s, loops in step with the music (4 beats long, starting where the music is in its 4 beats) and fades out over 0.5 s when the flight ends. No pitch or speed change | 0.7 | Done |
| `game/bus/dock_bell.ogg` | The bus docks | 0.5 | Placeholder, "to be replaced with the final dock sound" |
| `ui/audio/key_click.ogg` | A bus key goes down, Space working the Frameshift key included. Also the refused click on a research tile that can't be researched | 1.0 | Placeholder |

### Fuel, calls and passengers

| File | Plays when | Level | Status |
|---|---|---|---|
| `game/solar_system/fuel.ogg` | The fuel pump, for as long as fuel flows | 0.35 | Done |
| `game/solar_system/ringtone.ogg` | A call notice shows: 2 beats at 88 bpm, looped from the music's next beat, fading out in 0.15 s as the call is answered or goes. Silent while the notices are hidden or the game is paused | 0.15 | Done |

### Menus and research

| File | Plays when | Level | Status |
|---|---|---|---|
| `ui/audio/ui_click.ogg` | The SFX slider moves in Settings, and a research hold completes. No menu button plays it | 1.0 | Placeholder |

### Alien voices

| Folder | Clips | Plays when | Status |
|---|---|---|---|
| `game/transmissions/voice/blue/` | 53: blips 23, long 8, question 4, exclaim 4, annoyed 4, happy 4, scared 3, kicked 3 | A transmission's text types out: a blip per word of three letters or more, the question and exclaim clips before `?` and `!`, a long clip at the start of a line, a stinger as it opens (the caller's mood). A passenger card opening a request for food or a drink plays the passenger's race's annoyed stinger, at their pitch. Each caller of a race has a pitch of their own. Each race's loudness is its voice's volume, set in the mixer | Done |
| `game/transmissions/voice/orange/` | 61: blips 18, long 8, question 9, exclaim 7, annoyed 3, happy 5, scared 9, kicked 2 | The same | Done |
| `game/transmissions/voice/green/` | 61: blips 19, long 8, question 4, exclaim 7, annoyed 6, happy 8, scared 7, kicked 2 | The same. Major Tim, the castaway, talks in it too | Done |

A kicked passenger screams one of their race's kicked clips (`k`), at their pitch times the voice's `kicked_pitch`, fading out over `kicked_fade`, at the voice's volume times `kicked_volume`. The kick is off in the game: hear it in the voice lab's Kicked button or the mixer's Kicked line.

## What is still silent

Nothing in the specs asks for these, so none is a bug. Every event below makes no sound today. Ordered by how often a player meets it, most first.

### Most often heard

- **Money.** Credits gained on a delivery (the gain chip), credits spent on fuel, an upgrade or the tow.
- **Boarding and getting off.** A passenger picked up, a passenger paid out, and a rating (a 5-star ride deserves more than a 3).
- **Serving.** The hold that serves a food or drink request (1.2 s, like the fuel pump), and the request done.
- **Setting a course.** A stop added to the route, a stop removed, the route cleared, the route set.
- **The drive.** Holding the Frameshift key charges the drive (the charge builds over 1.5 s), letting go drains it, and the bus leaves. Warm drive. The quick stop's window.
- **Every menu button.** Hover and press on the main menu, the pause menu, Settings, Controls, Credits and the campaign screen, the Back buttons, the toggles and the Hold to reset button as it fills. Only the SFX slider clicks today.
- **Notices.** An info notice showing ("The bus is already full!"), a warning, a goal done. A decline button hanging up a call.
- **The transmission.** The modal opening and closing, the tube turning on.

### Moments

- **Goals.** A milestone done, a standing goal met, The Boss's call that every goal holds, a promotion, and, as the player stays, the goals giving way to the jump card.
- **The jump to the next star system.** The wind-up rumble, the frameshift out, the screen going black, the frameshift in, and the bell.
- **Warp gates.** The ring's hum, the warp drive row pressed, the jump.
- **Quests.** A call answered, accepted, declined, done (and the caller's dance), failed. The ride quests' own moments: a fly past or a photo stop done, a warp through a gate with the caller on board, a rock ride among the asteroids.
- **Capsules.** One appearing and emerging from nothing, its beacon blinking, and drifting off; the bus collecting one (credits, research points, fuel, or the castaway); Major Tim coming out of their capsule, and boarding once their quest is accepted; one shrinking away uncollected. Every capsule looks alike, so the collecting sound is what tells the player what was inside.
- **A returning passenger.** Someone who rated a five-star ride boarding again, and the castaway coming back.
- **Research.** The screen opening, a research completing, the badge nudging for a new upgrade.
- **Hints and the tutorial.** A feature hint's card appearing, Got it, a tutorial step finishing, the way-home waypoint being set.
- **Levels.** A level's loading screen, its bar filling, the Start button dropping in and being pressed, a level completed, a scene fade.

### Trouble

- **Heat.** The bus getting too hot (above 32°), overheating and coasting to a stop, the smoke.
- **Fuel.** The tank running low, and empty.
- **The tow.** The tow ship frameshifting in, the cable hitching and twanging taut, the beacon, it reeling in and leaving.
- **The asteroid field.** Rocks slowing the bus, and every knock that shakes the passengers.
- **Passengers.** One leaving the line after 60 s, one losing a lot of happiness at once (a shock), and the mood changing to furious.

### Passenger life

- **Amenities.** The Food Dispenser, Waiter Droids, In-Flight Movies, Karaoke, Space Invaders, Pillows and Sleeping pods, a passenger dozing off. The Honk and the Door chime are sounds by their own name, which the player buys.
- **Drive upgrades.** Quick charge and the Warm drive (a faster charge), a Slingshot, the Reserve tank starting up, Solar fuel, Faster pumps and Pit crew (a faster, bigger pump), the Warp gate opening.

### Music and ambience

- **Menu music.** `menu_music.ogg` is in the project and unused, and left out of the itch.io build. The menus play the game's track. Take it off the Web preset's `exclude_filter` when something plays it.
- **A track for Level 3** (Sol), which plays Level 1's for now, and one for the tutorial and the joined systems at the end.
- **A level-complete jingle.**
- **Space ambience** under the map, and the heat zone.

### Voices and the rest

- **The Boss needs a voice.** The Boss is a shadowy figure in the dark, and every one of their calls is in Orange's voice (`BOSS_RACE` in `transmission.gd`), so they sound like any Orange passenger. A voice set of their own would set them apart and make their calls (the first shift, the promotion, the trial, the end) land. It is a full set like a race's: blips, long, question, exclaim, annoyed, happy and scared stingers (no kicked), and a stern, slower, lower delivery. It needs a letter of its own in the voice README's table, a `boss.tres`, and a way for a transmission to name a voice other than a race's.
- **The mechanic** (Rusty) speaks in Blue's voice (`MECHANIC_RACE`) and may want a voice of their own too.

### Placeholders to replace before release

`dock_bell.ogg`, `key_click.ogg` and `ui_click.ogg`.
