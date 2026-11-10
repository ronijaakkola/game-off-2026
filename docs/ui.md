# UI and look

What the player sees and hears: the art direction, what each part of the screen shows, its texts, and how it moves. The rules behind it are in `DESIGN.md`. Read this before work on the look, the HUD, a panel or an animation.

Keeping it that way:

- **What goes here:** what a thing shows, where, in which words and colours, how it moves, and what Reduce motion does to it. A reason, where the obvious alternative was tried and failed.
- **What doesn't:** game rules and their numbers (`DESIGN.md`), web limits (`docs/web-constraints.md`), and what the scene or script already says (node layout, file paths, tween code).
- **Change, don't append.** Rewrite the bullet when the thing changes. No history. One fact per bullet, so two changes don't collide on a line.

## Look

Flat and cartoony, like a picture book of the solar system: solid colours with crisp edges, no textures, no realistic light. Everything is generated from shaders and meshes, so there are no image assets to make.

Anything new follows the same rules: flat colour, hard edges, a two-tone shade at most, no textures. No post-processing so far: each effect adds a full-screen pass on the web.

- **Camera.** Looks down at the orbit plane at an angle, with a narrow field of view (30°), so the system reads almost like a map but the planets still look round.
- **Planets.** A sphere with up to three colour bands with hard edges: noise blobs for rocky planets, wobbly horizontal stripes for gas giants, optional polar caps. The pattern turns with the planet's spin.
- **Light is two tones only:** a lit side in the planet's own colours, and a night side tinted by the same purple multiply on every planet, split by a line about a pixel wide at any zoom. The star's distance and the ambient light don't change a planet's colours.
- **Colours.** Soft, warm and saturated, never dark: sandy orange, leaf green, a pale lilac moon, an orange-striped gas giant with lilac rings, a pink ice planet with white caps. Planets are told apart by colour first, so each new one needs its own hue.
- **Star.** An unlit yellow sphere with a flat halo of a few see-through discs that always face the camera. No bloom.
- **Rings and orbits.** Unlit, flat bands with hard edges. Every orbit is a thin, faint lilac line, so the player sees where each planet is going.
- **Sky.** A deep navy-violet background with faint coloured fog and two layers of small stars, dim on purpose so the planets stand out. Its layers drift slightly as the camera moves.
- **Names.** Each planet has its name just under it: small off-white text with the sky's lilac, a little see-through, with a thin navy outline. It faces the camera and keeps its size on screen at any zoom; the bus passes in front of it.
- **Planet icons.** The UI shows a planet as a flat disc in its one icon colour, with the same purple night side, lit from the upper left. Rings show as a line at their tilt, behind the disc at the top and in front at the bottom. Each icon colour is set by hand to the colour the planet reads as from the camera.
- **A destination** reads the same everywhere: an arrow, the planet's icon and its name.
- **Icons.** Lucide. The fonts are under UI style.

### UI style

- **One surface:** frosted navy glass (`#1F1A47` at 72 % over the blurred screen) with a 1 px faint white border and 12 px corners. Rows inside it are a faint white tint.
- **Colour only carries game meaning** (mood, race, fuel, route, credits, gain and loss); controls stay neutral.
- **Buttons.** Each panel has one primary button, light with dark text; the rest are quiet tinted buttons.
- Hover lightens a control one step and pressing dips it below its default, and nothing changes size.
- **Fonts.** Baloo 2 is the UI font, for names, labels, buttons, headings and numbers (tabular); Figtree is only for sentences, such as status lines, notices and what a passenger is doing.
- **Placement.** Panels hug a screen corner 12 px from the edges and leave the solar system clear: On board top left, the resource bar top centre, the station (dock panel) top right, and the route and bus bars on the bottom edge, centred, with notices above them.
- Spacing is on a 4 px scale.
- The Frameshift key is the one control that isn't flat: a physical key that sinks when pressed.

### Races

A race shows in two ways, so it reads without colour: its skin colour, and the build both its head shapes share.

| Race | Skin | Photo background | Build | Heads |
|---|---|---|---|---|
| Blue | `#6699ff` | `#2e3d8c` | Long: tall, smooth, eyes in the face | The Dome; the Bean, with antennae |
| Orange | `#fa8033` | `#9e401a` | Short: low mounds with no neck | The Blob, with one big eye; the Mound, wider, with two eyes and two nubs |
| Green | `#99e673` | `#296138` | Middle: a thin neck, eyes out on the ends of things | Stalks; the Hammer, eyes on the ends of a bar |

- With red-green colour blindness, orange and green both turn yellowish. They stay apart because the orange is darker and the green lighter, and their builds are the most different pair.
- A race's colour marks whatever belongs to that passenger or that race's points: their trip arc, their row's border, a tree's accent.
- The planets' hues aren't final: the Giant and Terra come close to the races' colours.

### Reduce motion

The setting holds everywhere. As a rule: a slide becomes a fade in place, and nothing shakes, pops, drifts, tumbles or pulses. Each part below says where it differs.

## The bus

- **Model.** A flat yellow space bus with faceted edges, shaped to read when small: a short tapered nose in front of a taller cabin, a thruster pod out past each side at the back, a sloped windscreen, a door and three large side windows over a white band, a white roof with a wide stripe, a hull underneath (no wheels).
- Windows, stripe, hull and nozzles are a mid lilac, lighter than the sky, so they don't vanish into it.
- **Thrusters** are dark while docked. As the drive charges, a pale cyan exhaust cone grows out of each, full length in flight, and shrinks back after docking. They stay dark under tow.
- **Trail.** In flight, a flat pale cyan trail on the orbit plane that narrows and fades over 2.5 s.
- **Docked,** it floats beside its planet with a barely visible bob and sway.
- **Charging,** a white ring round the bus fills clockwise (temporary), and the bus shakes slightly. It pulls out a little from the planet as it turns, so its tail clears it.
- **Docking** rings a bell.
- **Hover.** A white border as wide on screen as a planet's, only past its silhouette. Not while the bus is open.

### The tow ship

- A stubby coral-red tug, so it never reads as the bus: a cab at the bow, a push bumper, a winch and an A-frame tow boom over the stern, an oversized engine on a stub wing each side so the exhaust passes either side of the cable, a blinking orange beacon on its roof.
- It frameshifts in just off the edge of the nearest planet and flies out to the bus, stopping just ahead of it.
- **Hitching** takes about a second: it swings its stern round and shoots a pale cable from its boom to the bus's nose, with a small clamp at the end. The tow starts when it latches.
- The cable starts slack, in a bow. The ship pulls ahead over half a second until it is taut, the cable twangs, and from then on its middle swings a little behind the ship's turns. Under Reduce motion it only bows.
- The ship leans into its turns, as the bus does. Near the planet it moves round to the bus's side, never closer than where it shifted in.
- Once the bus starts to park, the ship reels the cable in over a third of a second, veers off and frameshifts out.
- **A frameshift jump** takes 0.3 s and 2.5 units: the ship stretches long and thin along its heading, and a thin white-cyan streak fades over half a second.

## The map

- **Hover.** The pointer over a planet shows a white border round it, over its orange route border. Where the bus and a planet overlap, only the one a left click would open shows it. Over the HUD, the pointer picks nothing.
- **Route.** A flat orange line from the bus through each stop, with a diamond at each point in space. It runs to a planet's surface, and every planet on the route has an orange border.
- Under the pointer, the last stop's diamond turns white, as a planet's border does. Diamonds earlier on the route stay orange.
- **Course hint.** Until the player first sets a course, a line at the bottom of the screen: "Right-click planets or space to add stops. Backspace clears the route."
- **Waiting markers** (a trait). Under the name of each planet where someone waits, a small person and a number.
- **Fuel forecast** (a trait). Just above the route's last stop, "-22% fuel" in the names' off-white, or in low fuel's red when the bus hasn't that much left. Hidden with no course and during a tow.
- **Trip arc.** A waiting passenger's trip, shown from their row in the dock panel: an arc from the planet to their destination in their race's skin colour.
  - It rises off the orbit plane like a hop, so it never reads as part of the flat route, and bows sideways where the trip points along the view.
  - A line of rounded dashes with a thin dark outline, as wide on screen at any zoom, from the planet's edge to a ring round the destination.
  - It grows out in half a second, the ring closing in as it arrives; then the dashes flow toward the destination and the ring sends out a slow pulse. Under Reduce motion it fades in whole and holds still.
- **While a planet or the bus is open,** the names, waiting markers, fuel forecast and trip arc fade out, and the course hint hides.

## The HUD

| Where | What |
|---|---|
| Top left | On board panel |
| Top centre | Resource bar |
| Top right | Dock panel (the planet's station), while docked or charging |
| Bottom edge, centred | Bus status: the route bar over the bus bar |
| Above the bus bars | Tow offer, when out of fuel |
| Right side | The open planet's or bus's panel, over the dock panel |
| Bottom left | Debug panel (F2) |

- **While a planet's or the bus's panel is open,** the bus bars and the course hint hide, and the resource bar moves to stay centred between the On board panel and the open panel.

### Resource bar

A frosted-glass pill: what is behind it shows blurred under a translucent fill. It holds the credits, the three research counts and the recent rating, split by thin dividers.

- **Credits:** beside a gold dollar sign, with a comma between thousands (12,480).
- **Research:** for each race a flask in its skin colour and its count, on a chip tinted in the race's colour.
- **Rating:** the recent rating to one decimal beside a yellow star, or a dash before the first. The pointer over it shows a tooltip: who that rating attracts, and from how many stars the next band starts.
- **Gains and losses** float under the pill, taking no room in it: green "+15", red "-12". Each new payment at a stop pops the gain bigger and shows the new sum.
- Once the stop is over, after a short delay the total counts to its new value one credit at a time while the gain fades out drifting upward.
- The rating does the same: each one pops a gain with how far the average moved ("+0.2", "-0.3", "±0.0"). The very first just appears with a pop.
- A research count pops as it goes up.
- **The pill never wobbles.** Every digit is the same width. Each number has room for what it shows early on (credits three digits, research two, the rating "0.0"), so it starts at 284 px and first changes at 1,000 credits or 100 points.
- When a number gains or loses a digit, the pill stays centred and glides to the new width in 0.3 s, easing out. A count makes room for its widest number before it starts, so the pill changes width once per count.
- Under Reduce motion nothing pops or drifts, and the width changes at once.

### Bus status

Two bars on the bottom edge of the screen, centred: the route bar on top, the bus bar under it.

- **The route bar** shows what the bus is doing, or the track while it is on a leg. With no course it reads "No course".
- **What the bus is doing:** "Docked", "Charging frameshift", "Travelling to Terra", "Docking to Terra", "Heading to a point in space", "Stopping", "Holding in space", "Out of fuel", "Out of fuel: refuel here", "Towed to Terra".
- **A track** from the planet it left (or "Space") to the next planet on the route, with the time left. The track never moves back: a planet that moves away slows it instead.
- **The bus bar** holds the fuel gauge and the bus's keys, the Frameshift key among them.
- **Fuel gauge:** a pale cyan bar and the percentage, both red at a quarter of a tank or less.
- **The Frameshift key** is a physical key: its cap sits proud in a dark well and sinks while pressed.
- While the drive charges, the key latches down, its lamp lights and the bus's yellow fills it as the charge does. Pressing it then cancels the course and keeps the bus docked.
- While the bus flies under its own power it is the red Stop key, which slows the bus to a stop in space.
- Otherwise it is dim, its lamp off. Out of fuel, it is off.
- Pressing the Frameshift key while it charges or as Stop clears the route, as Backspace does.
- Pressing a bus key down plays a click.

### Dock panel

The planet's station: it hangs from the top right corner while the bus is docked or charging. It stays in one place on screen, so its buttons never move under the pointer.

- Title: the planet's icon and name with "Station".
- Who waits there, longest waiting first: portrait, name, destination and a Board button. Or "Nobody waiting."
- A Business passenger's name has their type before it, here, in the open planet's rows and on their card on board: "Business · Vontti". A Commuter's has nothing. Where the row is narrow the name is cut short, not the type.
- After a row's destination, fainter, how many on board or picked up are going there too ("· 2 aboard"), so the player can group passengers.
- Under the rows, a Board all button. While every seat is taken or promised it reads "Bus full 4/4" and is off, as are the Board buttons.
- Then a faint line and Services, each with its icon on a small tile:
  - The fuel button, where the planet sells fuel.
  - A Research button, where the planet has a tree. It opens the planet on its Research tab.
- **A row's trip.** The pointer over a row shows its trip arc. A click on the row pins it until the row is clicked again, the passenger boards or the bus leaves. The row whose trip shows has a border in their race's colour.
- It slides in from the right when the bus docks and out when it leaves. A passenger picked up slides out of it to the right, and it grows and shrinks smoothly to fit, so it shrinks as rows leave.

### Fuel button

In the dock panel: "Hold to fuel (51 cr)", with what filling the tank costs there.

- It is the tank's gauge too: a faint fill behind the label, as wide as the share of a full tank the bus holds, in the fuel's colour.
- Held, the label morphs into the fuel's percentage, counting up, and morphs back when let go.
- Off, it reads why: "Tank full" or "Not enough credits".
- The bill shows as a loss under the credits when the pump stops.

### Tow offer

A red warning notice above the bus bars: "You ran out of fuel" and a "Request a tow (100 credits)" button, with what the tow costs now. It stays until pressed.

### On board panel

In the top left corner: how many seats are taken ("3/4") and, under it, a card for each passenger on board, a 48 px row.

- **A card shows:** portrait, their name with their destination beside it, a short activity line ("Sleeping...", "Counting stars"), and along the bottom a happiness bar in their mood's colour. The line starts with "Finding their seat..." for a few seconds after boarding.
- **The mood has no name on the card:** the bar's colour says it. When the mood changes, the bar blends into the new colour, Reduce motion or not.
- **The bar.** A big drop leaves a dark red trail that holds for half a second, then shrinks to the bar.
- **Trend chevrons** on the bar show where happiness is heading, as the motive arrows on The Sims' bars do: `>` while it climbs, `<` while it falls.
  - One to three, by how much it will change over the next 10 s at its speed, no further than its target: 1.5 or more shows one, 8 two, 20 three. A chevron stays until the change drops 1 under its step, so it doesn't flicker.
  - They sit inside the fill at its end, dark so they read on every mood's colour. Once the fill is too short, they sit just past its end in the mood's colour.
  - Nothing shows while happiness holds or has reached its target. They fade over 0.2 s.
- **The activity line morphs** when it changes: a wave sweeps left to right, the old letters drift up and blur away and the new ones rise into focus, in about half a second. Under Reduce motion the lines crossfade.
- **A request.** A serve button takes the place of the activity line, with the need's icon and label: "Hand a snack" with a sandwich, "Pour a drink" with a cup. A faint cyan fill sweeps across the button as it is held, or as an amenity serves.
  - Served: "Munching a snack".
  - Amenities have their own lines: "Getting a snack from the replicator", "Waiting for the replicator", "A droid brings a snack", "Waiting for a droid".
  - A request on hold at a stop shows them idling.
- **Options.** The pointer over a card fades its options in to the right of the On board panel, with no slide; Reduce motion keeps the fade. There is one: Kick, with a kicking shoe icon. A card showing a rating has none.
- **Getting off.** When the bus docks, everyone going there shows their rating at once.
  - The middle row sinks a few pixels and fades out while five empty stars drop in from just above. Then the stars fill to the rating one after another, each swelling as it turns yellow. The line morphs to "Getting off".
  - The card lingers for 2.2 s from when the stop starts, long enough for five stars to fill and be read. Only then, and at their turn, does it slide out past the left edge.
  - Under Reduce motion the row crossfades and the stars only change colour.
- **Cards slide** in at the bottom from past the left edge and out the same way, and the cards below move up into a gap, the panel shrinking with them.

### Portraits

A small photo on the left of a card or a waiting row: the passenger's head and shoulders over a blurred background in a deep shade of their race's colour, in a thin white frame tilted very slightly at random.

- Each passenger has one of their race's two heads and one of two eye styles (Googly, Bead). Eye style is variety only, not a sign of race.
- **Alive:** the head sways and breathes, the eyes blink and glance around, stalks wobble.
- **Mood shows on the face, never the skin.** Annoyed, the lids slant down toward the middle like a frown over smaller pupils. Furious, more so, a red cartoon anger mark grows in at the upper right and pulses, and the head trembles.
- **Happy,** they beam now and then for a second or two: lower lids rise so the eyes smile into crescents, the pupils look up, the head bobs. A beam rather than a constant half-smile, which reads as a squint at a card's size.
- **A single eye** (the Blob) shows both off the eye, since a curve cut into one eye reads as a mouth: angry, a thick dark brow comes down, flat when annoyed and a sharp V when furious; beaming, its shine turns into a four-pointed star and pink blush shows on its cheeks.
- **Asleep,** the eyes drift shut to a curved line, and the head nods forward and to one side and breathes slower.
- **Eating and drinking.** The aliens have no mouths, so the food is held up just below the eyes, running off the bottom of the photo so it never floats.
  - A snack is a bar in a pink wrapper: every 1.5 s it rises to the face, the head dips to bite, then munches.
  - A drink is a tall white cup with a blue band and a yellow straw: every couple of seconds the head dips to sip.
- **Watching a show,** a screen's light falls on the face from below, so the chin and cheeks glow and the top of the head stays in the skin's own colour. The light is strongly coloured: blue and white mostly, with cyan, yellow, pink and red shots between, so the whole face changes colour at a cut, which is what shows at a card's size. It only ever adds to the skin's colour, and the top of the head and the photo's background keep the race's colour. It never sits still, as from a moving picture: it cuts softly to the next shot about every half second to a second, each a different colour and brightness, and within a shot it swells and dims and pans from one side of the face toward the other. Every few seconds they laugh: the joyful face, head tipped back and bouncing. Not while angry.
  - Cuts stay well under three a second, for photosensitive players. Under Reduce motion the light holds one colour, from straight ahead.
- **Leaning.** While they ride, the bust leans with the push on board: back as the bus speeds up, forward as it brakes, toward the outside of a turn. Waiting at a planet, they don't lean.
- Under Reduce motion only the eyes move, and food comes up and stays still.

### A kicked passenger

- Out of the bus's door, a small, soft human figure in a star jump, all in their skin colour, is thrown out and up. It slows and tumbles as if weightless, and shrinks away after 4 s.
- It lets out a quiet Wilhelm scream that fades fast, as if it flew away from the bus.

## Opening a planet or the bus

- The camera blends in from the same angle and follows the thing, framed in the middle of the space left of the panel. The panel slides in down the right side in step, arriving as the zoom completes.
- A bigger planet fills more of the screen's height, from about a third for the Moon to half for the Giant, so sizes still compare. The camera stays far enough back that rings fit beside the panel.
- The open planet's hover border fades out and stays off, so nothing sits on the close-up.
- Closing blends the camera back to where it was while the panel slides out.
- A panel that another replaces leaves fast, in 0.2 s, so the two don't cross.
- Both panels are 480 px wide, so switching never changes the width. The resource bar moves to stay centred between the On board panel and the open panel, so the credits and research points stay in view while the player researches.
- Under Reduce motion the camera cuts and the panel fades.

### Planet panel

The planet's icon and name, and a Close button. A planet with a research tree has two tabs, Services and Research; one without has no tab bar.

- It opens on Services. Opening another planet from an open one keeps the Research tab when the new planet has one.
- **Services:** a row for each passenger waiting there, longest waiting first (portrait, name over destination, fare), then the Fuel section. Anything else a planet offers goes here.
- A passenger who turns up while it is open slides in from the right.
- **Fuel section:** "Full tank 10 credits", the bus's fuel as a bar and a percentage, a "Hold to refuel" button ("Refuelling..." while held), and a note.
- The note shows the player's credits, or why the button is off: "Dock here to refuel.", "Tank full.", "Not enough credits.", "No fuel sold here.".

### Research tab

- The tree draws top to bottom: a row for each tier, each upgrade a square tile showing only its icon.
- A line runs from each upgrade up to each one it needs, faint until that one is researched, then in the race's skin colour.
- **The accent** is the skin colour of the race whose points the upgrade costs most; cyan when it costs none.

| Tile | Look |
|---|---|
| Available (whether or not the player can pay) | Dark, with an accent border and a white icon |
| Researched | Filled with the accent, the icon in the race's photo-background colour |
| Locked or hidden | Flat and dim; a hidden one shows "?" |

- **The card.** The pointer over an upgrade shows its card just under it, or above where there's no room: name, a line on what it does, and its cost with the resource bar's icons, what the player lacks in red.
- A hidden one shows "???" and no cost. A researched one shows no cost. One that isn't implemented reads "NOT IMPLEMENTED".
- A click on an available upgrade researches it at once: the credits come off as a loss under the bar and the points come off their counts.
- Away from that planet, the tree draws at half strength, the cards still show, and "Dock here to research." reads over it.

### Bus panel

Titled "Frameshift Bus".

- One row per stat: its name, its value, and once upgrades change it, how much they add in green ("Top speed 1.44 +20%") or take away in red ("Fuel tank 80 -20%").
- Seats show whole ("Seats 5 +1"). Portion size shows as "1.5x".
- A Traits section names each trait the bus has, or reads "None yet.".

## Menus

- **Main menu:** title, Play, Settings, Quit (hidden on web). On web a title card (the game's title, "Click to start") comes first.
- **Pause menu:** Resume, Settings, Main menu.
- **Loading.** A scene change fades to a black card with "Loading…" over a bar that fills in real steps, then fades back in.

## Debug panel

F2 opens it. Its buttons are whatever the running scene adds (`_debug_*` handlers in its script), so the list is in the code, not here. View research tree opens every tree side by side with smaller tiles, and researches from anywhere.

## Open questions

- **Fuel and time on the map.** Each planet is meant to show the fuel cost and travel time to it *(not built)*. Whether a point in space and a checkpoint show them too.
- **Passenger cards while a planet is open.** The On board panel stays in the top left corner and can cover part of the open planet. Hide it, shrink it, or leave it?
- **Boarding with the docked planet open.** The planet panel covers the dock panel, and its rows have no Board button, so the player closes it to pick anyone up.
- **The charge ring** is temporary.
