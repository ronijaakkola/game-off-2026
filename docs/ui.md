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
- **Orbits slowing.** As the bus swings side-on to dock, or its frameshift ends in space, the planets slow to half speed with a soft ease-out, and ease back in as it heads off. Their spin never stops, so the system still looks alive while it waits.
- **Light is two tones only:** a lit side in the planet's own colours, and a night side tinted by the same purple multiply on every planet, split by a line about a pixel wide at any zoom. The star's distance and the ambient light don't change a planet's colours.
- **Colours.** Soft, warm and saturated, never dark: sandy orange, leaf green, a pale lilac moon, an orange-striped gas giant with lilac rings, a pink ice planet with white caps. Planets are told apart by colour first, so each new one needs its own hue.
- **Star.** An unlit yellow sphere with a flat halo of a few see-through discs that always face the camera. No bloom.
- **Rings and orbits.** Unlit, flat bands with hard edges. Every orbit is a thin, faint lilac line, so the player sees where each planet is going.
- **Sky.** A deep navy-violet background with faint coloured fog and two layers of small stars, dim on purpose so the planets stand out. Its layers drift slightly as the camera moves.
- **Names.** Each planet has its name just under it: small off-white text in Baloo 2 semibold with the sky's lilac, a little see-through, with a thin navy outline. It faces the camera and keeps its size on screen at any zoom; the bus passes in front of it.
- **Planet icons.** The UI shows a planet as a flat disc in its one icon colour, with the same purple night side, lit from the upper left. Rings show as a line at their tilt, behind the disc at the top and in front at the bottom. Each icon colour is set by hand to the colour the planet reads as from the camera.
- **A destination** reads the same everywhere: an arrow, the planet's icon and its name.
- **Icons.** Lucide. The fonts are under UI style.

### UI style

- **One surface:** frosted navy glass (`#1F1A47` at 72 % over the blurred screen) with a 1 px faint white border and 12 px corners. Rows inside it are a faint white tint.
- **Colour only carries game meaning** (mood, race, fuel, route, credits, gain and loss); controls stay neutral.
- **Buttons.** Each panel has one primary button, light with dark text; the rest are quiet tinted buttons.
- Hover lightens a control one step and pressing dips it below its default, and nothing changes size.
- **Fonts.** Baloo 2 is the UI font, for names, labels, buttons, headings and numbers (tabular); Figtree is only for sentences, such as status lines, notices and what a passenger is doing.
- **Placement.** Panels hug a screen corner 12 px from the edges and leave the solar system clear: On board top left, the resource bar top centre, the goal panel top right with the station (dock panel) under it, and the route and bus bars on the bottom edge, centred, with notices above them.
- Spacing is on a 4 px scale.
- **Tooltips** name a counter or an icon-only key: a solid dark card (`#0B0920`) with the surface's border and 8 px corners, no shadow, so it reads over the map and over glass. A name and, when it helps, one sentence in fainter running text, at most 200 px wide.
  - It sits 8 px from its target's panel, centred on the target: below the resource bar, above the bus bar. A research tile's sits above the tile. Near a side edge of the screen it stays 8 px inside it, and still grows from the target's centre.
  - It opens once the pointer has rested on the target for 0.3 s, and closes when the pointer leaves. On a research tile it opens as the pointer arrives: the trees are read tile after tile, and a wait would feel sluggish.
  - Under the sentence it can hold one more row, such as a cost.
  - Going from one tooltip to the next, within 0.3 s of the last one closing, another target shows its tooltip at once with no motion, and the one closing goes at once.
  - It comes from its target: opening, it slides 6 px out from the target into place while fading in and growing from 94 % out of the edge facing it, in 0.15 s, easing out. Closing, it only fades and shrinks back, in 0.1 s. A pointer that leaves while it opens, or comes back while it closes, turns it round from where it is. Under Reduce motion it only fades. When the game pauses it closes at once.
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
- **Lab badge.** On the upper right of the rim of each planet with a lab, a 14 px badge drawn as a photo's are: a dark disc with a faint light rim and a white flask. It grows a quarter as fast as the planets do on the zoomed map, so it is about 2.4 times as big there. The pointer resting on the planet opens a tooltip above the badge, "Research planet" in the tooltips' running text with no name over it, the same card and motion as every tooltip. It follows the badge smoothly as the planet moves, off whole pixels.
- **Waiting markers** (a trait). 7 px under each planet's name, a 5 px dot for each place in its line, 3 px apart: filled off-white for someone waiting, a faint ring for a free place. A dot that fills grows out of its ring from 40 % while fading in, in 0.25 s easing out; one that empties shrinks back. Under Reduce motion it only fades. Without the station cameras, the pointer resting on the planet opens a tooltip under the dots, "3 waiting passengers" in the tooltips' running text, following them as the lab badge's does.
- **Station cameras** (a trait). The pointer over a planet turns its dots into who waits there, on a small dark card like a tooltip's: each one's 24 px photo over their destination's full 14 px icon, rings and all, with no text. Nobody waiting keeps the dots. The card grows out of the name, from 95 % at the middle of its top edge while fading in, in 0.18 s easing out, as the dots fade out; leaving, it fades and shrinks to 97 % in 0.12 s as the dots come back. It fades as one piece, photos and icons with the card. Under Reduce motion it only fades.
- **Fuel forecast** (a trait). Just above the route's last stop, "-22% fuel" in the names' off-white, or in low fuel's red when the bus hasn't that much left. With more than one leg, each leg's own cost ("-9%", smaller) sits beside its middle, on its upper side. Hidden with no course and during a tow.
- **Trip arc.** A waiting passenger's trip, shown from their row in the dock panel: an arc from the planet to their destination in their race's skin colour.
  - It rises off the orbit plane like a hop, so it never reads as part of the flat route, and bows sideways where the trip points along the view.
  - A line of rounded dashes with a thin dark outline, as wide on screen at any zoom, from the planet's edge to a ring round the destination.
  - It grows out in half a second, the ring closing in as it arrives; then the dashes flow toward the destination and the ring sends out a slow pulse. Under Reduce motion it fades in whole and holds still.
- **While a planet or the bus is open,** the names, lab badges, waiting markers, fuel forecast and trip arc fade out.

### The zoomed map

- **Zoomed in** for the tutorial, Terra fills the middle of the screen and the Moon circles it on a thin orbit line, with the camera looking at Terra and kept near it. The star's body, the other planets and every other orbit line are hidden; the starlight still falls from where the star is.
- Orbit lines and names keep their size on screen, so only the bodies look zoomed. The bus keeps its size too.
- **The zoom out** takes 4 s, easing in and out. The world shrinks by the same factor in every equal step, so it reads as a steady pull back, while the camera glides to where it starts on the whole map. The star and the other planets come in from past the screen's edges, and the other orbit lines fade in.
- Under Reduce motion it cuts to the whole map.

## The HUD

| Where | What |
|---|---|
| Top left | On board panel |
| Top centre | Resource bar |
| Top right | Goal panel, with the dock panel (the planet's station) under it while docked or charging |
| Bottom edge, centred | Bus status: the route bar over the bus bar |
| Above the bus bars | Notices |
| Right side | The open planet's or bus's panel, over the dock panel |
| Middle, over the paused game | Transmission |
| Bottom left | Debug panel (F2) |

- **While a planet's or the bus's panel is open,** the bus bars and the notices hide, the goal panel fades out over 0.2 s (and back in when the panel closes), and the resource bar moves to stay centred between the On board panel and the open panel.

### Resource bar

A frosted-glass pill: what is behind it shows blurred under a translucent fill. It holds the credits, the three research counts and the recent rating, split by thin dividers.

- **Credits:** beside a gold dollar sign, with a comma between thousands (12,480). The pointer over it shows a tooltip: "Credits", "Fares you have earned. Fuel and tows cost credits."
- **Research:** for each race a flask in its skin colour and its count, on a chip tinted in the race's colour. The pointer over them shows a tooltip: "Research points", "One for each passenger you deliver, in their colour. Planets trade them for upgrades."
- **Rating:** the recent rating to one decimal beside a yellow star, or a dash before the first. The pointer over it shows a tooltip: "Recent rating", "Your last 10 rides. A higher rating brings more Business passengers."
- **Gains and losses** float under the pill, taking no room in it: green "+15", red "-12". Each new payment at a stop pops the gain bigger and shows the new sum.
- Once the stop is over, after a short delay the total counts to its new value one credit at a time while the gain fades out drifting upward.
- The rating does the same: each one pops a gain with how far the average moved ("+0.2", "-0.3", "±0.0"). The very first just appears with a pop.
- A research count pops as it goes up.
- **The pill never wobbles.** Every digit is the same width. Each number has room for what it shows early on (credits three digits, research two, the rating "0.0"), so it starts at 264 px and first changes at 1,000 credits or 100 points.
- When a number gains or loses a digit, the pill stays centred and glides to the new width in 0.3 s, easing out. A count makes room for its widest number before it starts, so the pill changes width once per count.
- Under Reduce motion nothing pops or drifts, and the width changes at once.

### Bus status

Two bars on the bottom edge of the screen, centred: the route bar on top, the bus bar under it.

- **The route bar** says what the bus is doing in a header, and with a route, draws it under the header as a line. With a route it is 50 px tall; with none it is one 28 px row with an icon before the text. The notices above ride its height.
- **What the bus is doing:** "No route", "Hold Frameshift to leave", "Charging frameshift", "Travelling to Terra", "Docking to Terra", "Heading to a point in space", "Stopping", "Holding in space", "Out of fuel", "Out of fuel: refuel here", "Towed to Terra", and "Route complete" for 4 s after docking at the route's last planet. In one row it is dim with a dim route icon, except "Out of fuel" in low fuel's red with the fuel icon and "Route complete" with a green tick (`#8CD966`).
- **Totals.** At the header's right, a timer and the time the whole route takes ("18 s", "1:38"); with the fuel forecast, the fuel the whole route burns too ("22%"), red when that is more than is left. They tick, with no motion.
- **The line** runs to scale from where the bus set off or waits, through each planet ahead, to the point in space the route ends at, if it does: a long leg is a long link. A planet is its 16 px icon, a point in space a small diamond. A checkpoint on the way to a planet isn't drawn. Links are white and faint, orange (the route's colour) up to the bus.
- Past seven stops the rest fold into a "+N" pill as tall as a planet's disc. The links shrink to fit, none under 14 px, and the first, where the bus is, stays at least 40 px.
- **The bus** sits on the line with room round it: the line and any planet under it are cut away there, so the glass shows through, and no sliver of line is left beside it. It waits just past the start, flies along its link, and stops with its nose at a planet it docks at on the way. Docking there, the flown part folds away to the left and the bus drives over the planet, which becomes the start. At the last stop it stops short, never covering it.
- The pointer over a stop rings it and opens a tooltip above it with the planet's name, or "Point in space". The bus has none.
- **Motion.** Opening to two rows eases out over 0.3 s while the line fades in, and closing back over 0.2 s; the line is in place as it opens, so its stops don't come in one by one. In the open bar a new stop slides in from 8 px past its place, growing from half size and fading in, in 0.25 s; one taken off fades and shrinks where it is in 0.15 s; the rest glide to their new places from wherever they are, so quick clicks never jump. The header's text morphs as a passenger's activity line does.
- Under Reduce motion the height changes at once and only the fade is left, stops fade in and out where they stand, and the fold and the drive over are a cut.
- **The bus bar** holds the fuel gauge and the bus's keys, the Frameshift key among them.
- **Fuel gauge:** a pale cyan bar and the percentage, both red at a quarter of a tank or less.
- **The Frameshift key** is a physical key: its cap sits proud in a dark well and sinks while pressed.
- Space works the Frameshift key as the pointer does, without clicking it first, while the bus bar shows. The bus keys never take keyboard focus.
- With a course set and the bus waiting, the key is up and ready: its cap pulses slightly lighter once every two seconds, with a thin, faint glow in the bus's yellow round it. Under Reduce motion both hold still. Held, the drive charges: the pulse and glow go, the key stays down and the bus's yellow fills it as the charge does. Let go, the fill drains back and the key stays down until it is empty. Charged, the key pops up by itself as the bus leaves, even with the button still held.
- While the bus flies under its own power it is the red Stop key, which slows the bus to a stop in space.
- Otherwise it is dim. Out of fuel, it is off.
- Pressing the Frameshift key as Stop clears the route, as Backspace does. Stop acts on the press, not the release, so a key still held as the bus leaves doesn't stop it.
- Pressing a bus key down plays a click.

### Goal panel

In the top right corner, 264 px wide, with the dock panel 8 px under it: "To get promoted" and a row for each goal, in the order given. Under a thin faint line, a dim flag and "Quests", and a row for each quest. Each part shows only while it has rows, the line only between the two, and the panel only while there are any.

- **A goal's row:** an icon, the goal's text and, at the right, how far along it is, over a 3 px bar.
- **The icon** is an empty circle in faint white until the goal is met, then a green tick (`#8CD966`). The bar's fill is white, and green while met.
- **Deliver 50 passengers:** the count ("12/50"), and the bar fills with it.
- **Maintain 3.5 rating:** the average ("3.7", or a dash before the first rating) on a bar of five stars, with a white mark at the target.
- **A quest's row** has two lines. On top, the circle, what it asks and its planet's icon and name ("Go straight to", Frost). Under it, indented, the passenger who asked as a 16 px flat portrait without badges and their name, dim, and at the right the reward: the credits by a gold dollar sign and each race's research points by a flask in its colour.
- **A done quest:** the green tick.
- **A failed quest:** a red cross (`#F24D66`), the top line at half strength, no reward, and why it failed in the name's place ("Stopped at Moon first", "Reizhis was kicked", "Reizhis left the bus").
- A finished quest's row stays 8 s, then goes.
- **Coming in and going,** the quests move as the notices do. The panel grows to make room over 0.25 s, easing in and out, while the part rises 8 px into place and fades in over 0.3 s with a strong ease-out. Going, it fades out in 0.18 s, sinking 6 px, then the panel closes over it in 0.25 s. The first quest brings the whole part in, line and heading too, and the last takes it out; the dock panel under the goal panel glides with it. What is already there when the panel first shows doesn't move. Under Reduce motion the part only fades, and the panel changes height at once.

### Dock panel

The planet's station: it hangs under the goal panel in the top right corner while the bus is docked or charging. It stays in one place on screen. The services and Board all sit above the passengers, so they never move when a passenger boards and the list shrinks.

- Title: the planet's icon and name with "Station".
- Under the title, the services, each with its icon on a small tile:
  - The fuel button, where the planet sells fuel.
  - A Research button, where the planet has a lab, in the same shape as the fuel button: a quiet tinted button of the same height, corners and font, its label centred and a chevron at its right edge, inset like the button's padding. It opens the research screen. While the player can pay for any upgrade, it has the Frameshift key's thin, faint glow in the bus's yellow round it, pulsing once every two seconds, holding still under Reduce motion; with nothing affordable, no glow.
- Then a faint line and "Waiting passengers", with a Board all button under it. While every seat is taken or promised it reads "Bus full 4/4" and is off, as are the Board buttons.
- Under that, who waits there, longest waiting first: portrait, name, destination and a Board button. Or "Nobody waiting."
- A Business passenger's portrait has a briefcase badge, here, in the open planet's rows and on their card on board (Portraits). A Commuter's has none.
- After a row's destination, fainter, how many on board or picked up are going there too ("· 2 aboard"), so the player can group passengers.
- **A row's trip.** The pointer over a row shows its trip arc. A click on the row pins it until the row is clicked again, the passenger boards or the bus leaves. The row whose trip shows has a border in their race's colour.
- It slides in from the right when the bus docks and out when it leaves. A passenger picked up slides out of it to the right, and it grows and shrinks smoothly to fit, so it shrinks as rows leave.
- **Calling for a pick-up** (the tutorial's first step). No trip shows yet. The card gets a 2 px white border, and every row the highlight's border in their race's colour. In a pulse every 1.3 s both borders brighten, the rows' backgrounds lighten and the Board buttons swell to 110 % over 0.3 s, then all of it fades back over 1 s. Board buttons turn primary and Board all turns plain, so the row's Board is the one thing to press. Under Reduce motion the borders hold bright and nothing swells. Once the passenger boards, the card goes back to plain and their trip's arc to the Moon shows until the bus leaves.

### Fuel button

In the dock panel: "Hold to fuel (51 credits)", with what filling the tank costs there.

- It is the tank's gauge too: a faint fill behind the label, as wide as the share of a full tank the bus holds, in the fuel's colour. Off, the fill is about a third as strong and the label stays readable, so the button is quieter than an enabled one.
- Held, the label morphs into the fuel's percentage, counting up, and morphs back when let go.
- Off, it reads why: "Tank full" or "Not enough credits".
- The bill shows as a loss under the credits when the pump stops.

### Notices

Cards stacked above the bus bars, centred, 438 px wide, the width of the bus bars and 32 px tall, 8 px apart, the newest on top. Each has an icon and a line of text in Figtree, and can have an action button (small and quiet, so it never outweighs the card) and a close button (a dim ×) on the right.

| Kind | Icon | Card |
|---|---|---|
| Tutorial, how to do something | Question mark in a circle, dim | The navy glass |
| Info, something that happened | `i` in a circle, dim | The navy glass |
| Warning | Triangle, amber (`#FACC61`) | Dark amber glass |
| Error | `!` in a circle, red (`#F24D66`) | Dark red glass |
| Incoming call | Phone, pale lilac (`#CFBEFF`) with a soft glow of its own | Muted purple glass (`#3D2A80` at 85 %) with a 1 px lilac border (`#B9A0FF` at 50 %) and a faint lilac halo about 10 px wide |

- **While a planet's or the bus's panel is open** the notices hide with the bus bars. One that arrives meanwhile waits and comes in when the panel closes, and those already showing stop counting down to closing by themselves, so none goes unseen.
- A notice stays until its close or action button is pressed, unless it was given a time to close by itself, or until what it is about is over: a tutorial once the player does what it says, a warning once its cause is gone.
- **Tutorial.** One tutorial notice at a time, each saying what to do next and with a "Skip tutorial" button. The next comes in once the player has done it.
- **Map open.** Once the zoom out is over, an info notice for 8 s: "The whole solar system is open. Deliver passengers to get promotion."
- **Course hint.** In a run without the tutorial, until the player first sets a course, a tutorial notice: "Right-click planets or space to add stops. Backspace clears the route."
- **Low fuel.** Once the fuel falls to a quarter of a tank, where the gauge turns red, a closable warning: "Fuel is running low." It clears by itself once the fuel is back above a quarter, or the tank runs dry. Refuelling up from empty shows none.
- **Out of fuel.** An error notice: "You ran out of fuel" and a "Tow (100 credits)" button, with what the tow costs now.
- **Incoming transmission.** A call: "Incoming transmission..." and an Answer button. Every 1.6 s the phone rattles: it tips side to side, wide first then dying out, for about 0.4 s. Its ringtone plays on a loop while it shows, at 80 %, and fades out in 0.15 s as the call is answered or goes; it is silent while the notices are hidden or the game is paused, and plays under Reduce motion too. A passenger with a quest calls this way; it goes unanswered when its caller leaves the bus or the bus reaches a planet.
- **A quest ending.** "Quest done: Take Sufoi straight to Moon" as info, or "Quest failed: Take Sufoi straight to Moon" as a warning, each closing by itself after 4 s.
- **Coming in,** a card rises 8 px into place, growing from 96 % and fading in, over 0.3 s with a strong ease-out. A new one goes on top of the cards staying, so they never move, but under any still leaving, so one that replaces another (each tutorial step) comes in where it rests and never drops as the old one's gap closes.
- **Leaving,** it fades out in 0.18 s, sinking 6 px toward the bus bars and shrinking to 97 %, the way it came in. Then the cards above it glide down into its place over 0.25 s, easing in and out. A card can leave while still coming in, from wherever it got to.
- Under Reduce motion cards only fade in and out, the cards above close the gap at once, and the phone holds still.

### On board panel

In the top left corner: how many seats are taken ("3/4") and, under it, a card for each passenger on board, a 48 px row, grouped by destination.

- **Groups.** Each destination has a header: the planet's icon, its name, a faint rule and how many on board are going there. Groups run top to bottom in the order their planet first came up among those on board, and the cards in a group from the first to board to the last. 12 px above a header, 8 px under it and between cards.
- **A card shows:** portrait, their name, a short activity line ("Sleeping...", "Counting stars"), and along the bottom a happiness bar in their mood's colour. The line starts with "Finding their seat..." for a few seconds after boarding.
- **The mood has no name on the card:** the bar's colour says it. When the mood changes, the bar blends into the new colour, Reduce motion or not.
- **The bar.** A big drop leaves a dark red trail that holds for half a second, then shrinks to the bar.
- **Trend chevrons** on the bar show which way happiness is moving and how fast, as the motive arrows on The Sims' bars do: `>` while it climbs, `<` while it falls.
  - One to three, by how much it changes in 10 s at the speed it is moving now, whatever moves it (a request, a late ride, recovering): 1.5 or more shows one, 8 two, 20 three. A chevron stays until the change drops 1 under its step, so it doesn't flicker.
  - They sit inside the fill at its end, dark so they read on every mood's colour. Once the fill is too short, they sit just past its end in the mood's colour.
  - Nothing shows while happiness holds still. They fade over 0.2 s.
- **The activity line morphs** when it changes: a wave sweeps left to right, the old letters drift up and blur away and the new ones rise into focus, in about half a second. Under Reduce motion the lines crossfade.
- **A request.** A serve button takes the place of the activity line, with the need's icon and label: "Hand a snack" with a sandwich, "Pour a drink" with a cup. A faint cyan fill sweeps across the button as it is held, or as an amenity serves.
  - Served: "Munching a snack".
  - Amenities have their own lines: "Getting a snack from the dispenser", "Waiting for the dispenser", "A droid brings a snack", "Waiting for a droid".
  - A request on hold at a stop shows them idling.
- **Options.** The pointer over a card fades its options in to the right of the On board panel, with no slide; Reduce motion keeps the fade. There is one: Kick, with a kicking shoe icon. A card showing a rating has none.
- **Getting off.** When the bus docks, everyone going there shows their rating at once.
  - The middle row sinks a few pixels and fades out while five empty stars drop in from just above. Then the stars fill to the rating one after another, each swelling as it turns yellow. The line morphs to "Getting off".
  - The card lingers for 2.2 s from when the stop starts, long enough for five stars to fill and be read. Only then, and at their turn, does it slide out past the left edge.
  - Under Reduce motion the row crossfades and the stars only change colour.
- **Cards slide** in at the bottom of their group from past the left edge and out the same way, and the cards below move up into a gap, the panel shrinking with them.
- **A group's header** fades in with its first card. Once its last card has gone, it fades out and folds away with its gaps over 0.2 s, and the groups below move up.

### Portraits

A small photo on the left of a card or a waiting row: the passenger's head and shoulders over a blurred background in a deep shade of their race's colour, in a thin white frame tilted very slightly at random.

- Each passenger has one of their race's two heads and one of two eye styles (Googly, Bead). Eye style is variety only, not a sign of race.
- **Badges.** A passenger's type can put badges on the photo: dark discs with a faint light rim and a white icon, in a row that starts on the top left corner, reaching a little past it, and runs right, tilted with the photo. A disc is 15 px on a 32 px photo, reaching 4 px past the corner, and both grow half as fast as the photo: 19 px on a card's 48 px one. A type can have several. Business has one, a briefcase. A Commuter has none. The pointer over a badge shows a tooltip with the type's name and a line about it: "Business", "These passengers are more demanding but pay more." While a quest is about a passenger, a flag badge joins the row after their type's, and its tooltip says "Quest" and what it asks ("Take Sufoi straight to Moon").
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

### Transmission

A frosted-glass modal, 552 px wide, in the middle of the screen over a dark scrim, while the game is paused: the caller's screen on the left, what they say on the right.

- **The screen.** The caller's live portrait, 224 px, over a blurred backdrop in their race's deep shade, in a 2 px frame of their skin colour on a dark bezel. Their type's badges sit on its top left corner, 28 px discs, as on a portrait.
- It looks like an old tube at all times: fine dark scanlines, a dark rim, faint grey snow and a soft bright band rolling down.
- **Turning on.** It opens dark; a white line opens across the middle and the picture opens out from it in 0.9 s under a burst of static that settles to the faint snow. Answering closes the picture to a line and the line to nothing in 0.4 s; only once the screen is dark, after a short beat, does the modal fade and shrink a little (to 98 %) in 0.2 s.
- **Beside it:** a phone icon and "Incoming transmission", faint; the caller's name, large; a passenger's destination at the right (arrow, planet icon, name); what they say, in Figtree 13 px. The text starts 4 px down, level with the coloured frame rather than the bezel.
- **A quest** adds a faint row under the text: a flag, its line ("Stop the bus near") and a planet. Over the buttons sits the reward, right-aligned: "Reward", the credits in the gain's green by a gold dollar sign, and a chip per race's research points.
- **Buttons:** a message has one primary button ("Got it"); a quest has a quiet "No" and a primary "Yes".
- **Opening.** The scrim and modal fade in as the modal grows from 96 % in 0.4 s while the tube turns on. A beat after the picture is up, the caller says their text a letter at a time at a speaking pace, about 25 a second and never quite even, with a beat between words, a pause at a comma and a longer one at a full stop. Their head bobs as if with each word, stilling in the pauses, and their eyes stay on the player. After a 0.4 s pause to finish reading, the quest, the reward and the buttons fade in and rise into place one after another, 0.18 s apart over 0.5 s each, the quest rising most (8 px) and the buttons least (4 px). The buttons take clicks only once they start to show. A click on the modal before that shows the text whole and brings the rest in at once, with a tight stagger and no pause.
- The caller's face shows their mood as on a portrait; a happy caller beams now and then.
- **The boss** is a tall, lumpy tower of a blob that leans to one side, on a heap wider than the screen, with three eyes near the top: a big one in the middle and a smaller one a little lower on each side. For most of the game they call from a dark room: a near-black outline with no eyes, colour or mood, against a dim grey gloom, in a dim frame. It still bobs as it talks. Revealed, they are in the orange race's colours and glare whatever their mood: the eyes of full anger, with no anger mark and no tremble.
- **Music.** While it shows, the music is muffled, as if through a wall: a low-pass filter closes and the music dips to 60 %, easing in over 0.4 s as it opens and back out over 0.6 s as it is answered. On the web there are no audio filters, so only the dip is heard.
- Under Reduce motion the modal fades in and out without growing or shrinking, the rest fades in without rising, the tube fades in with no static burst and its snow and band hold still, the text shows whole and the head doesn't bob.

## Opening a planet or the bus

- The camera blends in from the same angle and follows the thing, framed in the middle of the space left of the panel. The panel slides in down the right side in step, arriving as the zoom completes.
- A bigger planet fills more of the screen's height, from about a third for the Moon to half for the Giant, so sizes still compare. The camera stays far enough back that rings fit beside the panel.
- The open planet's hover border fades out and stays off, so nothing sits on the close-up.
- Closing blends the camera back to where it was while the panel slides out.
- A panel that another replaces leaves fast, in 0.2 s, so the two don't cross.
- Both panels are 480 px wide, so switching never changes the width. The resource bar moves to stay centred between the On board panel and the open panel, so the credits stay in view.
- Under Reduce motion the camera cuts and the panel fades.

### Planet panel

The planet's icon and name, and a Close button.

- **Services:** a row for each passenger waiting there, longest waiting first (portrait, name over destination, fare), then the Fuel section. Anything else a planet offers goes here.
- A passenger who turns up while it is open slides in from the right.
- **Fuel section:** "Full tank 10 credits", the bus's fuel as a bar and a percentage, a "Hold to refuel" button ("Refuelling..." while held), and a note.
- The note shows the player's credits, or why the button is off: "Dock here to refuel.", "Tank full.", "Not enough credits.", "No fuel sold here.".

### Research screen

A modal over the whole screen, the game paused and dimmed under it: one frosted sheet 24 px in from the edges.

- **Header:** a flask and "Research", a "Game paused" tag with a pause icon, the resource bar in the middle, and a Close button with an ✕. Esc closes it too, unless the pause menu is open over it.
- **Opening** fades it in over 0.2 s while the sheet grows from 97 % to full size in 0.25 s. **Closing** lets the game run at once and fades it out in 0.15 s. Under Reduce motion it only fades.
- While it is open, the HUD's resource bar hides; the header has its own.
- **The trees** stand side by side, each on a faint card with its name ("Performance", "Stops", "Comfort") and a chip in its race's colour counting what is researched ("3/11").
- Each upgrade is a 52 px tile with 12 px corners showing its icon, in rows 64 px apart. Where its name ends in a step ("Speed 2", "Bigger portions II"), the step shows as a Roman numeral in its top left corner.
- **Stages.** The rows of every tree line up, with more room between two stages and a faint line across all the trees there. While the stage under it is shut, a "Requires promotion" tag with a lock sits in the middle of the line.
- **A stage opening** shows the next time the screen is open, once it has faded in: the tag fades off the line in 0.2 s and the line closes up, and the stage's tiles fade in from silhouettes over 0.3 s, each row 40 ms after the one above.
- A line runs from each upgrade to each one it needs, centre to centre: lit and glowing in the race's colour once that one is researched, a little brighter while it can be researched, faint otherwise.
- **The colours** are those of the race whose points the upgrade costs most.

| Tile | Look |
|---|---|
| Researched | A gradient in the race's colour, light at the top, glowing; the icon and numeral in its deep shade |
| Available | A dark gradient with a 2 px border in the race's colour and its glow; a white icon |
| Can't afford | Flat and dark with a faint border in the race's colour, a dim icon, and a red badge on its corner with a flask (points lacking) or a dollar sign (only credits) |
| Locked | Flat, darker and dim |
| Hidden, or its stage shut | A dark silhouette of its icon |

- **The tooltip.** The pointer over an upgrade opens its tooltip above it, so it covers neither the rows under it, which the upgrade opens, nor the tiles beside it: name, a line on what it does, then, 4 px further apart than the lines above it, its cost with the resource bar's icons, what the player lacks in red. Under the cost, one the player can't afford reads "Insufficient funds" in red.
- A hidden one shows "???" and no cost; one whose stage is shut shows "???" and "Requires promotion.". A researched one shows no cost. One that isn't implemented reads "NOT IMPLEMENTED".
- **Researching.** Holding an available tile sweeps the hold buttons' faint cyan fill up from its bottom, evenly; at the top, 0.6 s on, it is researched: the credits come off as a loss and the points come off their counts. The tile turns lit and pops as the research count does (to 106 % and back), while the fill fades off it in 0.15 s. Letting go or leaving first drains the fill in 0.2 s, fast at first.
- **A press on a tile that can't be researched** flashes its border for 0.3 s; on one the player can't afford, the red badge pulses too.
- **Sound.** A click as a hold completes, and a different click for a press on a tile that can't be researched. Both are placeholders.
- Under Reduce motion nothing pops or pulses; the fills, fades and flashes stay.

### Bus panel

Titled "Frameshift Bus".

- One row per stat: its name, its value, and once upgrades change it, how much they add in green ("Top speed 1.44 +20%") or take away in red ("Fuel tank 80 -20%").
- Each row's value right-aligns on one vertical line, and the delta has a fixed 44 px slot to its right (right-aligned, tabular figures, kept when empty), so the deltas form their own column.
- Seats show whole ("Seats 5 +1"). Portion size shows as "1.5x".
- Sections: 8 px between a section's title and its first row and between rows, 16 px between the end of one section and the next section's title.
- A Traits section names each trait the bus has, or reads "None yet.".

## Menus

- **Main menu:** title, Play, Settings, Quit (hidden on web). With a save game, Continue comes first as the primary button and has focus, and a plain "New game" button takes Play's place, with no hint that it has to be held: held for 1.2 s, a faint fill growing across it, it starts over; let go early, the fill drains back twice as fast. On web a title card (the game's title, "Click to start") comes first. The debug panel's "Delete save" deletes the save, and the menu turns back to Play; its "Reset settings" puts every setting back to its default.
- **Pause menu:** Resume, Settings, Main menu. It fades in over 0.2 s and closes at once, as the game picks up at once.
- **Settings:** three volume sliders, a rule, then the Reduce motion and Edge pan toggles, and Back as the primary button. Every row is 38 px high with its label and control centred, so the five rows have one pitch; the rule sits 16 px from the rows above and below.
- **Loading.** A scene change fades to a black card with "Loading…" over a bar that fills in real steps, then fades back in.

## Debug panel

F2 opens it. Its buttons are whatever the running scene adds (`_debug_*` handlers in its script), so the list is in the code, not here. Open research opens the research screen from anywhere, and Promote opens the next research stage.

## Open questions

- **Fuel and time on the map.** Each planet is meant to show the fuel cost and travel time to it *(not built)*. Whether a point in space and a checkpoint show them too.
- **Passenger cards while a planet is open.** The On board panel stays in the top left corner and can cover part of the open planet. Hide it, shrink it, or leave it?
- **Boarding with the docked planet open.** The planet panel covers the dock panel, and its rows have no Board button, so the player closes it to pick anyone up.
- **The charge ring** is temporary.
