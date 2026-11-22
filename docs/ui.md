# UI and look

What the player sees and hears: the art direction, what each part of the screen shows, its texts, and how it moves. The rules behind it are in `DESIGN.md`. Read this before work on the look, the HUD, a panel or an animation.

Keeping it that way:

- **What goes here:** what a thing shows, where, in which words and colours, how it moves, and what Reduce motion does to it. A reason, where the obvious alternative was tried and failed.
- **What doesn't:** game rules and their numbers (`DESIGN.md`), web limits (`docs/web-constraints.md`), and what the scene or script already says (node layout, file paths, tween code).
- **Change, don't append.** Rewrite the bullet when the thing changes. No history. One fact per bullet, so two changes don't collide on a line.

## Look

Flat and cartoony, like a picture book of the solar system: solid colours with crisp edges, no textures, no realistic light. Everything is generated from shaders and meshes, so there are no image assets to make. The one exception is the research upgrades' rendered icons: small models rendered in Blender in the same two-tone light and saved as pictures (Research screen).

Anything new follows the same rules: flat colour, hard edges, a two-tone shade at most, no textures. No post-processing so far: each effect adds a full-screen pass on the web.

- **Camera.** Looks down at the orbit plane at an angle, with a narrow field of view (30°), so the system reads almost like a map but the planets still look round.
- **Planets.** A sphere with up to three colour bands with hard edges: noise blobs for rocky planets, wobbly horizontal stripes for gas giants, optional polar caps. The pattern turns with the planet's spin.
- **Orbits slowing.** As the bus swings side-on to dock, or its frameshift ends in space, the planets slow to half speed with a soft ease-out, and ease back in as it heads off. Their spin never stops, so the system still looks alive while it waits.
- **Light is two tones only:** a lit side in the planet's own colours, and a night side tinted by the same purple multiply on every planet, split by a line about a pixel wide at any zoom. The star's distance and the ambient light don't change a planet's colours.
- **Colours.** Soft, warm and saturated, never dark: sandy orange, leaf green, a pale lilac moon, an orange-striped gas giant with lilac rings, a pink ice planet with white caps. Planets are told apart by colour first, so each new one needs its own hue.
- **Star.** An unlit yellow sphere with a flat halo of a few see-through discs that always face the camera. No bloom.
- **Heat zone.** A faint warm glow on the orbit plane round the star, out to the heat zone's edge, with no edge lines: it fades out softly over its outer rim, and deepens to red-orange where the hot zone starts, blended rather than cut. Very faint orange smoke churns through it: two layers of soft wisps slowly turning round the star opposite ways. While the bus is inside, flying, docked at Ember or holding in space, it pulses brighter about once every 1.7 s, more in the hot zone, easing in and out over a second as the bus enters and leaves; under Reduce motion it brightens without pulsing, and the smoke holds still. Hidden on the zoomed map; once the zoom out is over and the run's goals and notices come, it fades in over 0.8 s, easing out.
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
- Hover lightens a control one step and pressing dips it below its default.
- **A press is felt.** A held button shrinks to 96 % about the point it was pressed at, and springs back when let go, ending a touch over its size before it settles. Toggles, sliders, research tiles, the bus keys and the buttons held down to fill (refuel, serve, hold to confirm) don't. Under Reduce motion nothing changes size.
- **Fonts.** Baloo 2 is the UI font, for names, labels, buttons, headings and numbers (tabular); Figtree is only for sentences, such as status lines, notices and what a passenger is doing.
- **Placement.** Panels hug a screen corner 12 px from the edges and leave the solar system clear: On board top left, the resource bar top centre, the goal panel top right with the station (dock panel) under it, and the route and bus bars on the bottom edge, centred, with notices above them, and the pause button bottom left.
- Spacing is on a 4 px scale.
- **Tooltips** name a counter or an icon-only key: a solid dark card (`#0B0920`) with the surface's border and 8 px corners, no shadow, so it reads over the map and over glass. A name and, when it helps, one sentence in fainter running text, at most 200 px wide.
  - It sits 8 px from its target's panel, centred on the target: below the resource bar, above the bus bar. A research tile's sits above the tile. Near a side edge of the screen it stays 8 px inside it, and still grows from the target's centre.
  - It opens once the pointer has rested on the target for 0.3 s, and closes when the pointer leaves. On a research tile it opens as the pointer arrives: the trees are read tile after tile, and a wait would feel sluggish.
  - Under the sentence it can hold one more row, such as a cost.
  - Going from one tooltip to the next, within 0.3 s of the last one closing, another target shows its tooltip at once with no motion, and the one closing goes at once.
  - It comes from its target: opening, it slides 6 px out from the target into place while fading in and growing from 94 % out of the edge facing it, in 0.15 s, easing out. Closing, it only fades and shrinks back, in 0.1 s. A pointer that leaves while it opens, or comes back while it closes, turns it round from where it is. Under Reduce motion it only fades. When the game pauses it closes at once.
- **Guide cards** point at one thing and say what to do with it: the tooltip's solid dark card, 256 px wide with 12 px padding, growing downward to at most three lines. A title in Baloo 2 14 px and the text in Figtree 12 px.
  - A notch 14 px wide and 7 px long, part of the card's outline, sits on the edge facing the target and points at its middle, its tip 12 px from the target, room for the target's ring.
  - The owner picks the side that covers least: below a top panel, above the bus bars, beside the dock panel. The card follows its target, stays 12 px inside the screen, and its notch slides along its edge to stay on the target, no closer than 16 px to a corner.
  - A tutorial step can have step dots at the bottom, 4 px apart: the current one 8 px and white, those done 6 px and dim, those to come 6 px and faint. The tutorial shows none for now. Only a step that just tells the player something has the Got it button, at the bottom right.
  - A feature hint has a "Game paused" tag with a pause icon at the right of the title, and a small primary Got it button at the bottom right. No step dots. While one shows, the music is muffled as under a transmission, easing in over 0.4 s and clearing over 0.6 s once the last hint goes; the tutorial's steps leave the music alone.
  - A feature hint rings its target, so the eye finds it, as a trip's ring does its destination: a white 2 px line with a 1 px dark outline, 3 px out from the target, with 9 px corners (a target too small for them gets a round ring). As the card opens it closes in from 14 px farther out while fading in, over 0.35 s easing out; then every 1.6 s a pulse spreads 18 px out from it and fades, under the card. It fades out as the card closes. Under Reduce motion it fades in in place and holds still. Tutorial steps have none for now; the mechanic's reminders have it.
  - While a feature hint shows, the rest of the screen is dimmed: the outline's navy (`#141230`) at 60 % over the map and the HUD, under the card and the ring, but for a rounded hole round the target whose edge sits under the ring's line. It fades in over 0.4 s, easing out, with the first hint, holds from one hint to the next while the hole glides to the next target over 0.35 s, easing in and out, and fades out over 0.6 s, easing in and out, once the last hint goes. Under Reduce motion it still fades and the hole moves at once. It takes no clicks. Tutorial steps and the mechanic's reminders, which don't pause the game, have none.
  - It opens and closes as a tooltip does: opening, it slides 6 px out from the target into place while fading in and growing from 94 % out of its notch, in 0.15 s, easing out; closing, it only fades and shrinks back, in 0.1 s. Either turns round from where it is. It stays open while the game is paused. Under Reduce motion it only fades.
  - **The step dots move on** a beat after the card is in (0.1 s): the current dot's size and white glide to the next dot over 0.3 s, easing in and out, the one it leaves shrinking and dimming to done. A card that opens on a later step for the first time moves on from the step before. Under Reduce motion the dots change at once.
  - **From one feature hint to the next,** as from one tutorial step to the next. The heat zone's shows above the temperature gauge, the goals' left of the goal panel, the business passenger's left of their row in the dock panel, 0.9 s after the row is in.
  - **From one tutorial step to the next,** the card closes where it is, and the next step's opens on its own target 0.25 s after it has gone, never moving between the two.
  - The tutorial's steps show them: right of the bus; left of the waiting passenger's row, once the station card has come in; right of the On board panel, once it has come in and the passenger's card has slid into it, 0.5 s after that card starts; left of the Moon; above the Frameshift key; right of the passenger's serve button; right of their rating stars; under the resource bar once it has come in, while the credits breathe (growing to 115 % and back every 1.2 s, easing both ways; still under Reduce motion); and left of the station's fuel button.
  - The research guide's steps show them on the same card, the same way: under the resource bar's research points, 0.75 s after the mechanic's call closes, once they have grown in, as a feature hint with its "Game paused" tag, its ring and the muffled music; left of the station's Research row, its icon included, rung the same way and the music still muffled; and in the research screen, once its sheet has grown in, above its "Game paused" tag, over the dimmed map, so it covers none of the screen. The mechanic's reminder of new upgrades shows on the badge and the Research button the same way, with a Got it button and its target rung as a feature hint's is.
- The Frameshift key is the one control that isn't flat: a physical key that sinks when pressed.

### Pointer

A faceted dart, off-white on its lit side and lilac on its night side, with a 2 px navy outline: a 32 px system cursor, so it never lags. One shape for every state, with no hands and no change over a control, which lights up itself.

- **Pressed.** While the left button is down, anywhere, the dart shrinks to 85 % toward its tip, and stays so for as long as the button is held.
- **Add stop.** Over the map while the queue key is held, a navy badge with a plus in the route's orange sits at the dart's upper right. While the right button is down the dart shrinks as Pressed does, and it stays in place of Steer for as long as the key is held.
- **Locked.** Over the map while it takes no clicks (the tutorial's flights, the zoom out), a red no-entry badge at the dart's upper right.
- **Edge pan.** A two-tone arrowhead pointing the way the camera pans, in 8 directions, its night side always the lower half, as on the dart.
- **Steer.** While a point in space follows the pointer, four off-white corners frame it, leaving the route's diamond clear.
- **Drag camera.** A four-point star in the dart's two tones while the camera is dragged.
- When two apply, the later in this list wins. A paused game shows the plain dart.

### Races

A race shows in two ways, so it reads without colour: its skin colour, and the build both its head shapes share.

| Race | Skin | Photo background | Build | Heads |
|---|---|---|---|---|
| Blue | `#6699ff` | `#2e3d8c` | Long: tall, smooth, eyes in the face | The Dome; the Bean, with antennae |
| Orange | `#fa8033` | `#9e401a` | Short: low mounds with no neck | The Blob, with one big eye; the Mound, wider, with two eyes and two nubs |
| Green | `#99e673` | `#296138` | Middle: a thin neck, eyes out on the ends of things | Stalks; the Hammer, eyes on the ends of a bar |

- With red-green colour blindness, orange and green both turn yellowish. They stay apart because the orange is darker and the green lighter, and their builds are the most different pair.
- A race's colour marks whatever belongs to that passenger: their trip arc, their row's border. Each research tree is drawn in one race's colours too, only to tell the trees apart: Performance blue, Planets green, Comfort orange.
- **Research points** are a light violet (`c3a6ff`), wherever they show: their flask, the chip tinted behind them, a gain of them. No race has it, since points are one kind.
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
- **Heating up.** From 40°, thin pale lilac-grey wisps puff up off the bus's roof, thicker and more opaque as it nears 60°: small faceted puffs that rise, grow to about three times their size and fade in under 2 s, left behind as the bus moves.
- **Overheated.** A burst of smoke goes out all at once, wider and faster than the wisps. For the length of the cooldown the whole bus pulses red, 2.5 times a second, the red fading as it cools, and the smoke stays thick; it stops a little before the cooldown ends. Under Reduce motion the red holds steady rather than pulsing.
- **Hover.** A white border as wide on screen as a planet's, only past its silhouette. Not while the bus is open.

### Quick text

A stamp of a few words with an icon that lands over the bus when something about the driving is worth a nod, then goes.

- **Quick stop.** Leaving a planet on a charge started warm and never let go: "Quick stop!" with a clock, as a remark.
- **Quest completed.** A quest done: "Quest completed!" with a circled check, as a gain.
- **Quest failed.** A quest failed: "Quest failed!" with a circled cross, as a loss.

- **Look.** A Lucide icon (15 px) 3 px before the text (Baloo 2 ExtraBold, 14 px), in one colour with a 2 px navy outline (`#141230`) and a hard shadow (`#0B0920`, 1 px right, 2 px down), tilted 5° counter-clockwise so the text climbs to the right. The icon's lines are thickened to read as 2 px beside the heavy text.
- **Kinds.** A remark in the bus's yellow (`#F5C74A`), a gain in green (`#8CD966`), a loss in red (`#F24D66`). Three words at most, sentence case.
- **Placement.** Centred over the bus, its lowest corner 6 px above the bus on screen, following it at the same size at any zoom; over the map's labels, under the HUD panels. One at a time: a new one replaces the one showing at once. While a planet's or the bus's panel is open it hides, and one that would show is dropped.
- **Motion.** 1.5 s in all, about its centre, never drifting: it slams from 160 % to 92 % easing in over 0.14 s, fading in over the first 0.08 s, springs back to 100 % easing out by 0.25 s, holds until 1.3 s, then shrinks to 80 % while fading out, easing in. Under Reduce motion it fades in over 0.15 s at full size, holds until 1.3 s, and fades out over 0.2 s; the tilt stays.

### The tow ship

- A stubby coral-red tug, so it never reads as the bus: a cab at the bow, a push bumper, a winch and an A-frame tow boom over the stern, an oversized engine on a stub wing each side so the exhaust passes either side of the cable, a blinking orange beacon on its roof.
- It frameshifts in just off the edge of the nearest planet and flies out to the bus, stopping just ahead of it.
- **Hitching** takes about a second: it swings its stern round and shoots a pale cable from its boom to the bus's nose, with a small clamp at the end. The tow starts when it latches.
- The cable starts slack, in a bow. The ship pulls ahead over half a second until it is taut, the cable twangs, and from then on its middle swings a little behind the ship's turns. Under Reduce motion it only bows.
- The ship leans into its turns, as the bus does. Near the planet it moves round to the bus's side, never closer than where it shifted in.
- Once the bus starts to park, the ship reels the cable in over a third of a second, veers off and frameshifts out.
- **A frameshift jump** takes 0.3 s and 2.5 units: the ship stretches long and thin along its heading, and a thin white-cyan streak fades over half a second.

### The jump to the next star system

- It reads as a scene change: the two systems never show together.
- The open planet or bus closes, the HUD leaves as at the tutorial's end, and nothing can be clicked until the bus is out of the jump. The camera closes in on the bus, centred on screen and far enough back for the shift out to stay in view.
- The bus swings round to face the next system over 0.6 s, easing in and out and banking into the turn, its thrusters lighting. Then it winds up for 0.7 s: it draws back 0.2 units, easing in and out, as a smooth rumble builds to 0.02 units, a few waves that don't line up rather than the charge's random shake, which jitters up close.
- It frameshifts out as the tow ship does: stretched long and thin along its heading, leaving the same streak. Meanwhile black closes in on a circle round where it was, over 0.9 s, easing in, until the screen is black.
- The screen stays black for 0.4 s while the old system hides and the camera cuts to the new one.
- A circle opens from where the bus will come out, over 0.9 s, easing out, a little way off the new system's home planet. 0.35 s in, the bus frameshifts in there.
- It flies in, parks and docks with the bell, while the camera eases back out to the map over the new system and the HUD comes back. A notice says "Welcome to Lyra. Deliver passengers to get promotion." for 8 s.
- Under Reduce motion the camera cuts, the bus doesn't turn or shift, and the screen fades to black and back over 0.5 s each way.
- **The join**, in the last system, is the first time two systems show at once: every system appears, and the camera pulls back over 5 s, easing in and out, from where it is to over the middle of them all at its farthest zoom, zooming by the same factor every step so it reads as a steady rise. Pan and zoom wait until it ends. Under Reduce motion it cuts there.
- Under Reduce motion the camera and the bus cut straight there, and the bus flies in from where it comes out.
- **Joining the systems,** the camera eases out toward the farthest zoom, and a notice says every star system is open for 8 s.

## The map

- **Hover.** The pointer over a planet shows a white border round it, over its orange route border. Where the bus and a planet overlap, only the one a left click would open shows it. Over the HUD, the pointer picks nothing.
- **Route.** A flat orange line from the bus through each stop, with a diamond at each point in space. It runs to a planet's surface, and every planet on the route has an orange border.
- **Lab badge.** Once the mechanic has opened research, on the upper right of the rim of each planet with a lab, a 14 px badge drawn as a photo's are: a dark disc with a faint light rim and a white flask. It grows a quarter as fast as the planets do on the zoomed map, so it is about 2.4 times as big there. The pointer resting on the planet opens a tooltip above the badge, "Research planet" in the tooltips' running text with no name over it, the same card and motion as every tooltip. It follows the badge smoothly as the planet moves, off whole pixels. As the mechanic's first call opens research, every badge fades in growing from 40 % with a slight overshoot over 0.35 s; under Reduce motion it only fades.
- **Waiting markers** (a trait). 7 px under each planet's name, a 5 px dot for each place in its line, 3 px apart: filled off-white for someone waiting, a faint ring for a free place. A dot that fills grows out of its ring from 40 % while fading in, in 0.25 s easing out; one that empties shrinks back. Under Reduce motion it only fades. Without the station cameras, the pointer resting on the planet opens a tooltip under the dots, "3 waiting passengers" in the tooltips' running text, following them as the lab badge's does.
- **Station cameras** (a trait). The pointer over a planet turns its dots into who waits there, on a small dark card like a tooltip's: each one's 24 px photo over their destination's full 14 px icon, rings and all, with no text. Nobody waiting keeps the dots. The card grows out of the name, from 95 % at the middle of its top edge while fading in, in 0.18 s easing out, as the dots fade out; leaving, it fades and shrinks to 97 % in 0.12 s as the dots come back. It fades as one piece, photos and icons with the card. Under Reduce motion it only fades.
- **Fuel forecast** (a trait). Just above the route's last stop, "-22% fuel" in the names' off-white, or in low fuel's red when the bus hasn't that much left. With more than one leg, each leg's own cost ("-9%", smaller) sits beside its middle, on its upper side. Hidden with no course and during a tow.
- **Trip arc.** A waiting passenger's trip, shown from their row in the dock panel: an arc from the planet to their destination in their race's skin colour.
  - It rises off the orbit plane like a hop, so it never reads as part of the flat route, and bows sideways where the trip points along the view.
  - A line of rounded dashes with a thin dark outline, as wide on screen at any zoom, from the planet's edge to a ring round the destination.
  - It grows out in half a second, the ring closing in as it arrives; then the dashes flow toward the destination and the ring sends out a slow pulse. Under Reduce motion it fades in whole and holds still.
- **While a planet or the bus is open,** the names, lab badges, waiting markers, fuel forecast and trip arc fade out.

### The zoomed map

- **Zoomed in** for the tutorial, Terra fills the middle of the screen and the Moon sits still on a thin orbit line around it, with the camera looking at Terra and kept near it. The star's body, the other planets and every other orbit line are hidden; the starlight still falls from where the star is.
- Orbit lines and names keep their size on screen, so only the bodies look zoomed. The bus keeps its size too.
- **The zoom out** starts once the HUD has gone: every panel, the bus bars, the notices and the pause button fade out one after another, 0.08 s apart over 0.35 s each, easing in, the top panels rising 12 px and the bus bars sinking 12 px; the lab badges go with them. It takes 7 s, easing in and out. The world shrinks by the same factor in every equal step, so it reads as a steady pull back, while the camera glides to frame the whole map: out to its outermost orbit it takes 94 % of the screen's height, centred top to bottom, so the star sits a little above the middle; the zoom eases with the rest. The camera is locked from the tutorial's call until The Boss's first-shift call closes: no pan, edge pan, drag or zoom. The star and the other planets keep their whole-map size as the world shrinks around them, so they glide in from past the screen's edges, and the other orbit lines fade in. The planets start orbiting with it, their speed rising from nothing as the square of how far it has got. Then it holds for 4 s before the bus bars, the notices and the pause button come back, the bars rising 12 px as they fade in, for The Boss's first-shift call; the other panels and the camera wait for it to end. Under Reduce motion it cuts, still holds, and the HUD only fades.
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
| Bottom left | Pause button; the debug panel (F2) over it |

- **While a planet's or the bus's panel is open,** the bus bars and the notices hide, the goal panel fades out over 0.2 s (and back in when the panel closes), and the resource bar moves to stay centred between the On board panel and the open panel.

### Resource bar

A frosted-glass pill with a thin border and no shadow: what is behind it shows blurred under a translucent fill. It holds the credits, the three research counts and the recent rating, split by thin dividers.

- **Credits:** beside a gold dollar sign, with a comma between thousands (12,480). The pointer over it shows a tooltip: "Credits", "Fares you have earned. Fuel and tows cost credits."
- **Research:** a flask and the count, on a chip tinted in the research points' violet. It isn't in the HUD's bar, nor the divider before it, until the mechanic's first call closes: then the pill glides open to make room in 0.3 s, the divider fading in with it, and from 0.15 s in the count grows from 60 % with a slight overshoot over 0.4 s while fading in over 0.2 s. Under Reduce motion the width changes at once and they fade in over 0.2 s. The research screen's bar always has it. The pointer over it shows a tooltip: "Research points", "One for each passenger you deliver. Planets trade them for upgrades."
- **Rating:** the recent rating to one decimal beside a yellow star, or a dash before the first. The pointer over it shows a tooltip: "Recent rating", "Your last 10 rides. A higher rating brings more Business passengers."
- **Gains and losses** show on chips hanging 4 px under the pill, centred under their number and taking no room in it: a solid dark chip (the tooltip's fill) 18 px tall with 8 px corners, a thin border in the change's colour and 12 px digits. Green "+15", red "-12", grouped as the totals are ("+1,000").
- A chip slides 6 px down from the pill's edge while fading in, in 0.15 s, easing out, and leaves the same way back, easing in. When its number changes it dips 2 px and comes back in 0.12 s. It sits on whole pixels and nothing scales. Under Reduce motion it only fades.
- **Credits.** Each payment at a stop adds to the gain, which shows the new sum. Once the stop is over, every chip it left stays 0.6 s more and then they leave together, the credits', the points' and the rating's. As it leaves, the total counts to its new value one credit at a time, in 0.6 s at most, in green; then it turns white again over 0.2 s.
- Spending shows at once and goes in the way a gain does: 0.6 s after the last of it, the loss leaves while the total counts down in red, together with the chips of any points spent with it. More spent meanwhile adds to it. While a gain waits, the loss sits left of it, so the gain stays put and neither reaches under the research counts.
- The total never jumps. A count starts from what the total shows, so a change that comes during one carries on from there, and a stop ending while a loss waits takes both in at once, counting to what is left.
- **The rating** does the same: each one shows how far the average moved ("+0.2", "-0.3", "±0.0" in grey), and the average moves in that colour. The very first just appears with a pop.
- **Research.** A point shows as "+1" in the points' violet under the count until the stop's chips leave. Another change the same way meanwhile adds to it ("+2"). Points spent show the same way, in red, for 0.6 s.
- **The pill never wobbles.** Every digit is the same width. Each number has room for what it shows early on (credits three digits, research two, the rating "0.0"), so with the research points it starts at 176 px and first changes at 1,000 credits or 100 points.
- When a number gains or loses a digit, the pill stays centred and glides to the new width in 0.3 s, easing out. A count makes room for its widest number before it starts, so the pill changes width once per count.
- Under Reduce motion nothing pops or drifts, and the width changes at once.

### Bus status

Two bars on the bottom edge of the screen, centred: the route bar on top, the bus bar under it.

- **The route bar** says what the bus is doing in a header, and with a route, draws it under the header as a line. With a route it is 50 px tall; with none it is one 28 px row with an icon before the text. The notices above ride its height.
- **What the bus is doing:** "No route", "Hold Frameshift to leave", "Charging frameshift", "Travelling to Terra", "Docking to Terra", "Heading to a point in space", "Stopping", "Holding in space", "Out of fuel", "Out of fuel: refuel here", "Overheated: cooling down" while it cools down, with or without a route, "Towed to Terra", and "Route complete" for 4 s after docking at the route's last planet. In one row it is dim with a dim route icon, except "Out of fuel" in low fuel's red with the fuel icon and "Route complete" with a green tick (`#8CD966`).
- **Totals.** At the header's right, a timer and the time the whole route takes ("18 s", "1:38"); with the fuel forecast, the fuel the whole route burns too ("22%"), red when that is more than is left. They tick, with no motion.
- **The line** runs to scale from where the bus set off or waits, through each planet ahead, to the point in space the route ends at, if it does: a long leg is a long link. A planet is its 16 px icon, a point in space a small diamond. A point in space on the way to a planet isn't drawn. Links are white and faint, orange (the route's colour) up to the bus.
- Past seven stops the rest fold into a "+N" pill as tall as a planet's disc. The links shrink to fit, none under 14 px, and the first, where the bus is, stays at least 40 px.
- **The bus** sits on the line with room round it: the line and any planet under it are cut away there, so the glass shows through, and no sliver of line is left beside it. It waits just past the start, flies along its link, and stops with its nose at a planet it docks at on the way. Docking there, the flown part folds away to the left and the bus drives over the planet, which becomes the start. At the last stop it stops short, never covering it.
- The pointer over a stop rings it and opens a tooltip above it with the planet's name, or "Point in space". The bus has none.
- **Remove.** The pointer over a stop that can come off (Route and flight) also shows a 12 px round X on its top right corner: dark with a faint light rim and a white X, red under the pointer. It stays while the pointer moves from the icon onto it. Over it, a tooltip above it reads "Remove from route", at the same gap as the stop's name, which gives way to it. A click takes the stop off, and its icon leaves as any stop taken off does. The start of the line never shows one, nor does any stop during a tow.
- **Motion.** Opening to two rows eases out over 0.3 s while the line fades in, and closing back over 0.2 s; the line is in place as it opens, so its stops don't come in one by one. In the open bar a new stop slides in from 8 px past its place, growing from half size and fading in, in 0.25 s; one taken off fades and shrinks where it is in 0.15 s; the rest glide to their new places from wherever they are, so quick clicks never jump. The header's text morphs as a passenger's activity line does.
- Under Reduce motion the height changes at once and only the fade is left, stops fade in and out where they stand, and the fold and the drive over are a cut.
- **The bus bar** holds the fuel gauge, the temperature gauge and the bus's keys, the Frameshift key among them, with a faint divider between each.
- **Fuel gauge:** a pale cyan bar and the percentage, both red at a quarter of a tank or less.
- **Temperature gauge:** a green thermometer, "Temperature" and the degrees ("21°") over a faint track from −20° to 60°, with a green comfortable band from 8° to 32° and a white marker, standing proud of the track, at the temperature. From 45° the thermometer and the degrees turn amber, and red while it cools down after overheating.
- **The Frameshift key** is a physical key: its cap sits proud in a dark well and sinks while pressed.
- Space works the Frameshift key as the pointer does, without clicking it first, while the bus bar shows. The bus keys never take keyboard focus.
- With a course set and the bus waiting, the key is up and ready: its cap pulses slightly lighter once every two seconds, and a hard 2 px outline in the bus's yellow round the cap fades between 35 % and full strength in step. Under Reduce motion both hold still, the outline at full strength. Held, the drive charges: the pulse and outline go, the key stays down and the bus's yellow fills it as the charge does. Let go, the fill drains back and the key stays down until it is empty. Charged, the key pops up by itself as the bus leaves, even with the button still held.
- Docked with the drive warm, the key is up and ready and the bus's yellow fills it by the warmth left, emptying as the drive cools. The ring round the bus on the map shows the same. Held, the key goes down and fills from there, faster than a cold charge; let go, the fill drains back fast and the drive is cold.
- While the bus flies under its own power it is the red Stop key, which slows the bus to a stop in space. Not while it brakes in to dock: then it is dim.
- Otherwise it is dim. Out of fuel, or while the bus cools down after overheating, it is off.
- Pressing the Frameshift key as Stop clears the whole route; Backspace takes off only the last stop. Stop acts on the press, not the release, so a key still held as the bus leaves doesn't stop it.
- Pressing a bus key down plays a click.

### Goal panel

In the top right corner, 264 px wide, with the dock panel 8 px under it: "To get promoted" and a row for each goal, in the order given. Under a thin faint line, a dim flag and "Quests", and a row for each quest. Each part shows only while it has rows, the line only between the two, and the panel only while there are any.

- **A goal's row:** an icon, the goal's text and, at the right, how far along it is, over a 3 px bar.
- **The icon** is an empty circle in faint white until the goal is met, then a green tick (`#8CD966`). The bar's fill is white, and green while met.
- **Deliver 50 passengers:** the count ("12/50"), and the bar fills with it.
- **Maintain 3.5 rating:** the recent rating ("3.7", or a dash before the first rating) on a bar of five stars, with a white mark at the target.
- **A quest's row** has two lines. On top, the circle, what it asks and its planet's icon and name ("Go straight to", Frost). Under it, indented, the passenger who asked as a 16 px flat portrait without badges and their name, dim, and at the right the reward: the credits by a gold dollar sign and the research points by a violet flask.
- **A done quest:** the green tick.
- **A failed quest:** a red cross (`#F24D66`), the top line at half strength, no reward, and why it failed in the name's place ("Stopped at Moon first", "Reizhis was kicked", "Reizhis left the bus").
- A finished quest's row stays 8 s, then goes.
- **Coming in and going,** the quests move as the notices do. The panel grows to make room over 0.25 s, easing in and out, while the part rises 8 px into place and fades in over 0.3 s with a strong ease-out. Going, it fades out in 0.18 s, sinking 6 px, then the panel closes over it in 0.25 s. The first quest brings the whole part in, line and heading too, and the last takes it out; the dock panel under the goal panel glides with it. What is already there when the panel first shows doesn't move. Under Reduce motion the part only fades, and the panel changes height at once.

### Dock panel

The planet's station: it hangs under the goal panel in the top right corner while the bus is docked or charging. It stays in one place on screen. The services and Board all sit above the passengers, so they never move when a passenger boards and the list shrinks.

- Title: the planet's icon and name with "Station".
- Under the title, the services, each with its icon on a small tile:
  - The fuel button, where the planet sells fuel.
  - A Research button, where the planet has a lab and the mechanic has opened research, in the same shape as the fuel button: a quiet tinted button of the same height, corners and font, its label centred and a chevron at its right edge, inset like the button's padding. It opens the research screen. As the mechanic's first call opens research with the panel showing a lab, the row grows in under the fuel row over 0.3 s, easing out, while fading in, the card and what is under it gliding down with it; under Reduce motion it only fades. While the player can pay for an upgrade they couldn't pay for when they last closed the research screen, it has a nudge, quieter than the Frameshift key's: a 1 px outline in the bus's yellow on its own edge, fading between 15 % and 60 % once every two seconds in step with the key, and holding at 60 % under Reduce motion. With nothing affordable, or only the same upgrades as then or fewer of them, no outline; a run continued from a save has seen none yet.
  - After a promotion, at every planet until the bus jumps, a Jump button in the primary style with an arrow on its tile: "Jump to Lyra". While anyone is on board it reads "Drop everyone off to jump" and is off; it is off during a stop too. A notice says where to jump until the bus does: "Promoted! The Lyra system is open. Drop off your passengers, then jump there from a station."
- Then a faint line and "Waiting passengers", with a Board all button under it. While every seat is taken or promised it reads "Bus full 4/4" and is off, as are the Board buttons; a click on an off Board button brings the bus full notice.
- Under that, who waits there, longest waiting first: portrait, name, destination and a Board button. Or "Nobody waiting."
- A Business passenger's portrait has a briefcase badge, here, in the open planet's rows and on their card on board (Portraits). A Commuter's has none.
- After a row's destination, fainter, how many on board or picked up are going there too ("· 2 aboard"), so the player can group passengers.
- **A row's trip.** The pointer over a row shows its trip arc. A click on the row pins it until the row is clicked again, the passenger boards or the bus leaves. The row whose trip shows has a border in their race's colour.
- It slides in from the right when the bus docks and out when it leaves.
- **Rows come and go** as the cards on board do, from the right: a passenger who turns up while it shows opens a place over 0.25 s while their row slides in from past the panel's right edge over 0.35 s; one picked up slides out past it in 0.25 s, then their place closes over 0.25 s. A row never fades as it moves. The panel grows and shrinks with the places. Those waiting when the bus docks are there already. "Nobody waiting." fades in once the last row has gone, and out under the first to come. Under Reduce motion a row only fades, and its place opens and closes at once.
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
- **The tutorial's last call** comes 1 s after the tank is full at the Moon, with nothing hidden; until it is answered the screen takes no clicks but on the notice, and the camera holds still.
- **The tutorial's call.** A new run fades in from black over 2.5 s, easing in and out, once the loading card has gone, with only the bus bars showing. 0.8 s later The Boss's call notice comes in. After the transmission, the HUD's other panels come in as the tutorial's steps bring them in, the station card with the pick-up step, the On board panel as the passenger boards, their card sliding in only once the panel is in, and the resource bar once their card has slid out of it: each fades in while dropping 12 px into place over 0.5 s, easing out, several 0.08 s apart. Under Reduce motion they only fade.
- **The first-shift call.** Once the zoom out has held and the bus bars, the notices and the pause button have come back, or once a new run without the tutorial has faded in with the other panels hidden, The Boss's call notice comes in 0.8 s later. Until the transmission closes the screen takes no clicks but on the notice and the pause button, and the camera holds still. Then the HUD's other panels come in as the tutorial's do, and the goal panel's feature hint opens once they are in.
- **Next level.** After The Boss's call at the end of the run, a closable info notice: "The next level is not available yet." It stays until closed.
- **Low fuel.** Once the fuel falls to a quarter of a tank, where the gauge turns red, a closable warning: "Fuel is running low." It clears by itself once the fuel is back above a quarter, or the tank runs dry. Refuelling up from empty shows none.
- **Overheating.** Once the temperature climbs to 45°, where the gauge turns amber, a closable warning: "The bus is overheating. Steer away from the star." It clears by itself once it is back under 45°, or the bus overheats.
- **Overheated.** An error notice for the length of the cooldown: "The bus overheated. Cooling down..."
- **Cooled down.** Once the cooldown is over, an info notice for 6 s: "The bus has now cooled down. You can charge your frameshift drive again."
- **Bus full.** A click on a Board button while every seat is taken: an info notice for 2.5 s, "The bus is already full!". Another click while it shows starts its 2.5 s over rather than adding a second.
- **Out of fuel.** An error notice: "You ran out of fuel" and a "Tow (100 credits)" button, with what the tow costs now.
- **Incoming transmission.** A call, 44 px tall: on the left the caller's 36 px photo, inset 4 px as the Answer button is on the right; beside it their name in the guide cards' 14 px bold title, and under it the phone, 11 px, and "Incoming transmission..." in the dim 11 px label; then an Answer button. The photo is a rounded square of their portrait, dressed and backed as on the transmission screen, in a 1 px frame of their skin colour. A caller the player doesn't know yet is "Unknown caller": their real outline in the dark, as The Boss sits in the dark room, with a pale lilac question mark over it (`#CFBEFF`, 22 px, dark outline). A passenger's call has a decline button left of Answer: a 24 px square in a soft red tint with a hung-up phone. Every 1.6 s the phone rattles: it tips side to side, wide first then dying out, for about 0.4 s. Its ringtone, two beats long at the music's 88 bpm, plays on a loop while it shows at its mixed level, starting on the music's next beat so the two keep time, and fades out in 0.15 s as the call is answered or goes; it is silent while the notices are hidden or the game is paused, then starts again on a beat, and plays under Reduce motion too. A passenger with a quest calls this way; it goes unanswered when its caller leaves the bus or the bus reaches a planet.
- **A quest ending.** "Quest done: Take Sufoi straight to Moon" as info, or "Quest failed: Take Sufoi straight to Moon" as a warning, each closing by itself after 4 s.
- **Coming in,** a card rises 8 px into place, growing from 96 % and fading in, over 0.3 s with a strong ease-out. A new one goes on top of the cards staying, so they never move, but under any still leaving, so one that replaces another (each tutorial step) comes in where it rests and never drops as the old one's gap closes.
- **Leaving,** it fades out in 0.18 s, sinking 6 px toward the bus bars and shrinking to 97 %, the way it came in. Then the cards above it glide down into its place over 0.25 s, easing in and out. A card can leave while still coming in, from wherever it got to.
- Under Reduce motion cards only fade in and out, the cards above close the gap at once, and the phone holds still.

### On board panel

In the top left corner: how many seats are taken ("3/4") and, under it, a card for each passenger on board, a 48 px row, grouped by destination.

- **Groups.** Each destination has a header: the planet's icon, its name, a faint rule and how many on board are going there. Groups run top to bottom in the order their planet first came up among those on board, and the cards in a group from the first to board to the last. 12 px above a header, 8 px under it and between cards.
- **A card shows:** portrait, their name, a short activity line ("Sleeping...", "Counting stars"), and along the bottom a happiness bar in their mood's colour. The line starts with "Finding their seat..." for a few seconds after boarding. A line says what they are doing; one they say out loud is in quotation marks, as “Another stop?” is.
- **When the bus overheats,** everyone on board who is only idling shows one of their type's overheat lines for the length of the cooldown ("Fanning themselves", "Asking for a refund"). A request, a sleep, a show or a meal keeps its own line.
- **The mood has no name on the card:** the bar's colour says it. When the mood changes, the bar blends into the new colour, Reduce motion or not.
- **The bar.** A big drop leaves a dark red trail that holds for half a second, then shrinks to the bar.
- **Frustration** shows as the track's right end striped: fainter than the rest, with grey stripes leaning right, as wide as what frustration has taken off the most they can reach, so the part they can no longer fill reads at a glance. No red, which already means falling.
  - It is one track with no gap. The stripes run right up to the fill, round its rounded end too.
  - The fill stops where the stripes start. Happiness still above that shows faded under the stripes until it has drained.
  - It grows or shrinks to a new width over 0.4 s. Nothing shows while nothing is lost.
  - The pointer on the striped end, or within 3 px above or below it, opens a tooltip to its right: "This passenger is getting frustrated which limits their happiness."
- **Trend chevrons** on the bar show which way happiness is moving and how fast, as the motive arrows on The Sims' bars do: `>` while it climbs, `<` while it falls.
  - One to three, by how much it changes in 10 s at the speed it is moving now, whatever moves it (a request, a late ride, recovering): 1.5 or more shows one, 8 two, 20 three. A chevron stays until the change drops 1 under its step, so it doesn't flicker.
  - They sit inside the fill at its end, dark so they read on every mood's colour. Once the fill is too short, they sit just past its end in the mood's colour.
  - Nothing shows while happiness holds still. They fade over 0.2 s.
- **The activity line morphs** when it changes: a wave sweeps left to right, the old letters drift up and blur away and the new ones rise into focus, in about half a second. Under Reduce motion the lines crossfade.
- **A request.** A serve button takes the place of the activity line, with the need's icon and label: "Hand a snack" with a sandwich, "Pour a drink" with a cup. A faint cyan fill sweeps across the button as it is held, or as an amenity serves.
  - Served: "Munching a snack".
  - Amenities have their own lines: "Getting a snack from the dispenser", "Waiting for the dispenser", "A droid brings a snack", "Waiting for a droid".
  - A request on hold at a stop shows them idling.
- **Options.** The pointer over a card fades its options in to the right of the On board panel, with no slide; Reduce motion keeps the fade. There is one: Kick, with a kicking shoe icon. A card showing a rating has none, nor does any during the tutorial.
- **A change of destination,** as when the player accepts an express quest: the card slides out of its group as a kicked one does, and only then slides back in at the bottom of the new destination's group, which opens at the bottom when there is none yet. Its new place opens as its old one folds, and a new group's header as an emptied group's, so the panel keeps its height and the cards between move up one place. Both counts update at once, but an emptied group keeps its last count as it folds.
- **A group's header folds** with its last card's place, not after it, whether that card was rerouted, kicked or got off.
- **Getting off.** When the bus docks, everyone going there shows their rating at once.
  - The middle row sinks a few pixels and fades out while five empty stars drop in from just above. Then the stars fill to the rating one after another, each swelling as it turns yellow. The line morphs to "Getting off".
  - The card lingers for 2.2 s from when the stop starts, long enough for five stars to fill and be read. Only then, and at their turn, does it leave.
  - Under Reduce motion the row crossfades and the stars only change colour.
- **Cards come and go** over the left edge of the screen. Boarding, a card's place opens at the bottom of its group over 0.25 s, easing in and out, while the card slides in from past the edge over 0.35 s with a strong ease-out, cut off at the bottom by its place until that is open. Leaving, it slides all the way out past the edge in 0.25 s, easing out, then its place folds away over 0.25 s and the cards below move up, the panel growing and shrinking with them. A card never fades as it moves, since a see-through portrait flashes white. Under Reduce motion a card only fades, and its place opens and closes at once.
- **A group's header** opens and fades in with its first card. Once its last card has gone, it fades out and folds away with its gap over 0.25 s, and the groups below move up.

### Portraits

A small photo on the left of a card or a waiting row: the passenger's head and shoulders over a blurred background in a deep shade of their race's colour, in a thin white frame tilted very slightly at random, over a hard dark navy shadow 2 px to its right and below.

- Each passenger has one of their race's two heads and one of two eye styles (Googly, Bead). Eye style is variety only, not a sign of race.
- **Badges.** A passenger's type can put badges on the photo: dark discs with a faint light rim and a white icon, in a row that starts on the top left corner, reaching a little past it, and runs right, tilted with the photo. A disc is 15 px on a 32 px photo, reaching 4 px past the corner, and both grow half as fast as the photo: 19 px on a card's 48 px one. A type can have several. Business has one, a briefcase. A Commuter has none. The pointer over a badge shows a tooltip with the type's name and a line about it: "Business", "These passengers are more demanding but pay more." While a quest is about a passenger, a flag badge joins the row after their type's, and its tooltip says "Quest" and what it asks ("Take Sufoi straight to Moon").
- **Bow tie.** A Business passenger wears a near-black bow tie with a slightly lighter knot, under the chin: on the neck, or on the body of a shape that has none. It shows wherever their portrait does, the transmission screen included. A Commuter wears none.
- **Alive:** the head sways and breathes, the eyes blink and glance around, stalks wobble.
- **Mood shows on the face, never the skin.** Annoyed, the lids slant down toward the middle like a frown over smaller pupils. Furious, more so, a red cartoon anger mark grows in at the upper right and pulses, and the head trembles.
- **Happy,** they beam now and then for a second or two: lower lids rise so the eyes smile into crescents, the pupils look up, the head bobs. A beam rather than a constant half-smile, which reads as a squint at a card's size.
- **A single eye** (the Blob) shows both off the eye, since a curve cut into one eye reads as a mouth: angry, a thick dark brow comes down, flat when annoyed and a sharp V when furious; beaming, its shine turns into a four-pointed star and pink blush shows on its cheeks.
- **Sweating.** While the bus is above its comfortable temperature, cartoon sweat drops (pale blue, dark outline, a white shine) well up on the head over whatever face they make, slide down a little and shrink away, each on its own timing: one on the left side at first, a second on the brow from about 40°, a third on the right from about 50°. They ride on the head, so they lean, nod and tremble with it. A drop that would hang off a narrow part of the head, as under the Hammer's bar, sits on it instead. Only passengers on board sweat. Under Reduce motion the drops sit still.
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
- **Beside it:** a phone icon and "Incoming transmission", faint; the caller's name, large; a passenger's destination at the right (arrow, planet icon, name); what they say, in Figtree 13 px. The text starts 4 px down, level with the coloured frame rather than the bezel. Money in what they say (a `[money]` tag) is in the dollar sign's gold, its letters bobbing 1.5 px one after another, with a pale glint running along it every 2.4 s; under Reduce motion it is only gold. A shouted word (a `[shout]` tag) shakes, each letter jumping up to 1.2 px on its own 18 times a second; under Reduce motion it holds still.
- **A quest** adds a faint row under the text: a flag, its line ("Stop the bus near") and a planet. Over the buttons sits the reward, right-aligned: "Reward", the credits in the gain's green by a gold dollar sign, and the research points on a violet chip.
- **Buttons:** a message has one primary button ("Got it"); a quest has a quiet "No" and a primary "Yes". A message can also offer two answers that mean the same, as the boss's calls in the tutorial and the mechanic's calls do: two primary buttons sharing the row equally.
- **The mechanic** is a brown alien, a colour no race has, with the Bean's shape and bead eyes, smiling: "Rusty, the Mechanic". They hold a steel wrench up at the photo's right, its handle running off the bottom, over the photo backdrop in a steel blue-green rather than a race's shade. They talk in the blue race's voice.
- **Opening.** The scrim and modal fade in as the modal grows from 96 % in 0.4 s while the tube turns on. A beat after the picture is up, the caller says their text a letter at a time at a speaking pace, about 25 a second for most races (each race's voice can run faster or slower) and never quite even, with a beat between words, a pause at a comma and a longer one at a full stop. Their head bobs as if with each word, stilling in the pauses, and their eyes stay on the player. After a 0.4 s pause to finish reading, the quest, the reward and the buttons fade in and rise into place one after another, 0.18 s apart over 0.5 s each, the quest rising most (8 px) and the buttons least (4 px). The buttons take clicks only once they start to show. A click on the modal before that shows the text whole and brings the rest in at once, with a tight stagger and no pause.
- **Voice.** As the text types, the caller's race's clips play, tied to the words: each word of three or more letters gets a blip as it starts, picked to fit the time before the next word, and a long word gets a second one halfway. The word before a question or exclamation mark gets that mark's clip instead, timed to end as the mark shows. A long clip sometimes opens the line or sits at a comma or full stop, and holds the blips off until it is over. A clip never plays twice running, and its pitch varies a little. Each race has several voices, evenly spaced in pitch, and each caller's name picks one, so callers of a race sound clearly different. A clip may start a little before the last one ends, so two stack for a moment; a blip that would stack more is skipped, and an ending or a long clip fades out what it would stack on. Every clip fades in and out over a few milliseconds. A happy or annoyed caller opens with a stinger.
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

- **Header:** the name, and under it the planet's tagline, dim.
- **Services:** a row for each passenger waiting there, longest waiting first (portrait, name over destination, fare). Anything else a planet offers goes here.
- A passenger who turns up while it is open slides in from the right.
- **Lore** sits at the foot, over the Close button, under a rule: a few sentences about the planet in dim body text, about 40 words, so it fits under three rows. It keeps room for four lines, with space above and below, so its rule stays put from planet to planet. A planet without lore shows neither.

### Research screen

A modal over the whole screen, the game paused and dimmed under it: one frosted sheet 24 px in from the sides, as tall as what it shows and centred top to bottom.

- **Header:** a flask and "Research", a "Game paused" tag with a pause icon, the resource bar in the middle, and a Close button with an ✕. Esc closes it too, unless the pause menu is open over it. Until the first upgrade is researched, the Close button is off, and the pointer resting on it opens a tooltip under it: "Rusty wants you to research something before you move on."
- **Opening** fades it in over 0.2 s while the sheet grows from 97 % to full size in 0.25 s. **Closing** lets the game run at once and fades it out in 0.15 s. Under Reduce motion it only fades.
- While it is open, the HUD's resource bar hides; the header has its own.
- **The trees** stand side by side, centred, each on a faint card with its icon and name (a rocket and "Performance", a globe and "Planets", a heart and "Comfort") and a chip in its colour counting what is researched of all it has ("3/15"). The icon is 14 px in the tree's colour, 6 px before the name, its middle level with the middle of the name's capitals. Before research opens no tree is there, and the rows of a stage that isn't open never are: the cards end 16 px under the last open row.
- Each upgrade is a 52 px tile with 12 px corners showing its icon, in rows 64 px apart. Where its name ends in a step ("Speed 2", "Bigger portions II"), the step shows as a Roman numeral on a chip centred on the tile's bottom edge, half over it: 14 px tall, fully rounded, its border in the tree's colour, the numeral's capitals centred in it. On one stacked above the next step it sits where their line leaves the tile.
- **The icons.** Each upgrade shows a rendered icon: a small model in the game's two-tone light, every one under the same camera and light from the upper left, with a white sticker edge round it, 36 px and centred on the tile. Steps of one upgrade share theirs. It keeps its own colours and avoids its tree's, so it reads on a filled tile. It is saved at several sizes, and a tile shows the one nearest its size on screen, so it stays crisp in any window. Upgrades without an icon of their own yet, from row 3 down, show a placeholder: a lilac gift box with a white bow.
- **Stages.** The rows of every tree line up, with more room between two open stages and a faint line across all the trees there. While a stage is still to open, the same line runs under the last open stage, 34 px above the cards' bottom edge, broken in the middle by a tag 8 px from the line either side: 20 px tall and fully rounded, in a solid dark violet (#2A2450) with the line's faint border, holding a 10 px lock and "Requires promotion" in small strong text, both dim. The cards end 26 px under the line, and each tree's lines to that stage's upgrades run on faintly from their tiles, across the line, to the cards' bottom edges.
- **What opened** shows the next time the screen is open, once it has faded in: as research opens, every tree's card fades in over 0.2 s, and its tiles, or a stage's tiles, fade in over 0.3 s, each row 40 ms after the one above.
- A line runs from each upgrade to each one it needs, centre to centre: lit in the tree's colour once that one is researched, a little brighter while it can be researched, faint otherwise.
- **The colours** are the tree's: one race's, Performance blue, Planets green, Comfort orange.

Every tile is flat, with no gradient, glow or shadow, and each state has its own fill.

| Tile | Look |
|---|---|
| Researched | A solid fill in the tree's colour; the icon in its own colours; the step chip in the deep shade |
| Available | Dark, tinted toward the tree's colour, with a 2 px border in it; the icon in its own colours |
| Can't afford | Dark with a faint border in the tree's colour, a dim icon, and a red badge on its corner with a flask (points lacking) or a dollar sign (only credits) |
| Locked | Dark and dim, with a thin grey outline; a dimmer icon |
| Hidden | Near-black with no border, and a faint silhouette of its icon; no step chip |

- **The tooltip.** The pointer over an upgrade opens its tooltip above it, so it covers neither the rows under it, which the upgrade opens, nor the tiles beside it: name, a line on what it does, then, 4 px further apart than the lines above it, its cost with the resource bar's icons, what the player lacks in red. Under the cost, one the player can't afford reads "Insufficient funds" in red.
- A hidden one shows "???" and no cost. A researched one shows no cost. One that isn't implemented reads "NOT IMPLEMENTED".
- **Researching.** Holding an available tile sweeps the hold buttons' faint cyan fill up from its bottom, evenly; at the top, 0.6 s on, it is researched: the credits come off as a loss and the points come off their counts. The tile turns lit and pops (to 106 % and back), while the fill fades off it in 0.15 s. Letting go or leaving first drains the fill in 0.2 s, fast at first.
- **A press on a tile that can't be researched** flashes its border for 0.3 s; on one the player can't afford, the red badge pulses too.
- **Sound.** A click as a hold completes, and a different click for a press on a tile that can't be researched. Both are placeholders.
- Under Reduce motion nothing pops or pulses; the fills, fades and flashes stay.

### Bus panel

Titled "Frameshift Bus".

- One row per stat: its name, its value, and once upgrades change it, how much they add in green ("Top speed 1.44 +20%") or take away in red ("Fuel tank 80 -20%").
- Each row's value right-aligns on one vertical line, and the delta has a fixed 44 px slot to its right (right-aligned, tabular figures, kept when empty), so the deltas form their own column.
- Seats show whole ("Seats 5 +1"). Portion size, pump speed and serving speed show as "1.5x", warm time in seconds ("6.0 s").
- Sections: 8 px between a section's title and its first row and between rows, 16 px between the end of one section and the next section's title.
- A Traits section names each trait the bus has, or reads "None yet.".

## Menus

- **Main menu:** title, Play, Settings, Quit (hidden on web). With a save game, Continue comes first as the primary button and has focus, and a plain "New game" button takes Play's place, with no hint that it has to be held: held for 1.2 s, a faint fill growing across it, it starts over; let go early, the fill drains back twice as fast. On web a title card (the game's title, "Click to start") comes first. The debug panel's "Delete save" deletes the save, and the menu turns back to Play; its "Reset settings" puts every setting back to its default.
- **Show FPS** (settings, off by default): one line in the top right corner, over every scene, the HUD included: the frame rate, the size the game renders at in real pixels, the MSAA, and any rendering switch turned off ("40 FPS · 2560×1440 · MSAA 4x · no glass"). Small off-white text with a navy outline on a dark backing (`#0B0920` at 85 %, 4 px corners), 4 px from the corner.
- **Pause button:** a 48 px glass square in the HUD's bottom left corner, 12 px from the edges, holding a quiet 40 px button with Lucide's menu icon, three lines, at 16 px. Its tooltip, to its right: "Menu", "Esc opens it too." It leaves and comes back with the bus bars around the zoom out, sinking and rising 12 px as they do. It takes clicks while the screen is covered, as through the tutorial's calls, when nothing else but the notices and guide cards does, even under the black the new run fades in from.
- **Pause menu:** Resume, Settings, Main menu. Through the tutorial, a Skip tutorial button sits above them, 12 px further apart than the rest; it closes the menu. It fades in over 0.2 s and closes at once, as the game picks up at once.
- **Settings:** three volume sliders, a rule, then the Reduce motion, Edge pan and Show FPS toggles, and Back as the primary button. Every row is 38 px high with its label and control centred, so the six rows have one pitch; the rule sits 16 px from the rows above and below. Opened from the main menu with a save game, a rule and a plain "Hold to delete save data" button sit above Back, held like New game; once full it reads "Save data deleted", greyed out, focus moves to Back, and the menu under it turns back to Play. The pause menu's settings have no Delete save.
- **Loading.** A scene change fades to a black card with "Loading…" over a bar that fills in real steps, then fades back in.

## Debug panel

F2 opens it. Its buttons are whatever the running scene adds (`_debug_*` handlers in its script), so the list is in the code, not here. The Rendering group is there in every scene: MSAA off, 2x or 4x, and toggles for the glass blur and the stencil, each for this session only, so a slow frame can be traced on the machine where it is slow, with Show FPS on. Open research opens the research screen from anywhere. The Star systems card has Promote, which promotes at once, and Complete system, which also jumps the bus to the next system at once, from wherever it is, kicking anyone on board, or joins every system in the last one.

## Mixer

Debug panel (F2) › Mixer, on the main menu: one scrolling card for setting how loud each sound is.

- **Music, Sound effects.** One row for each audio file in the project outside the alien voices' folder, found by scanning, so a new clip is in it with no code. A clip 30 seconds or longer is a track, under Music. A row has its file name (the path on hover), a Play button, a slider from 0 to 2 with a − and a + beside it that move it 0.05, and the number. A track plays as the music and loops, so it can run while the others are tried; a clip that loops starts on the music's next beat and plays until Stop; any other plays once. A row says "edited" when it is off the table's level and "unset" when the table has no entry for it, so it plays as recorded.
- **Voices.** A level for each race's voice (its volume), and buttons that say a line as a transmission would, with the caller's stinger and the words typing out: Plain, Question, Exclaim, Annoyed, Happy, Scared, and the Plain line in the lowest and in the highest of the race's voices. "Every voice in turn" has each race say a few lines one after another, to hear them against each other.
- **Header.** Stop the music, Stop sounds (a loop, a voice line), Copy values, Reset all and Back to menu. Copy puts the table for `core/audio/clip_levels.gd` and each voice's volume on the clipboard, to set by hand: the mixer writes no file. A level set here is heard in the game too, until it closes.

## Open questions

- **Fuel and time on the map.** Each planet is meant to show the fuel cost and travel time to it *(not built)*. Whether a point in space shows them too.
- **Passenger cards while a planet is open.** The On board panel stays in the top left corner and can cover part of the open planet. Hide it, shrink it, or leave it?
- **Boarding with the docked planet open.** The planet panel covers the dock panel, and its rows have no Board button and it has no fuel button, so the player closes it to pick anyone up or refuel.
- **The charge ring** is temporary.
- **The goal panel once the systems are joined** still says "To get promoted", though there is nothing left to be promoted to.
- **The jump** has no sound of its own yet.
