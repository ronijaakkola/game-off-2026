# Design

The design decisions the game logic follows: the rules, the numbers that are decisions, and why. Read it before gameplay work.

Keeping it that way:

- **What goes here:** a rule or a number someone needs to write the game logic, and couldn't guess. One rule per bullet.
- **What doesn't:** how it looks, sounds or animates (`docs/ui.md`), and anything the code already says (file paths, class names, node layout).
- **Change, don't append.** When a rule changes, rewrite its bullet. No history: git has it. A reason stays only while it still stops someone undoing the decision.
- **Status.** Everything here is built unless it says *(not built)*. All numbers are starting points for playtests.

## Pitch

You drive a bus around a small solar system. Pick up passengers, plot a route through space and get them to their planet before the ride wears them out. The planets orbit while the bus flies, so a route that looks short at the dock may not be short by the time the bus gets there. Each promotion sends the bus on to the next star system, and in the end every system is one route map.

## Core loop

1. **Docked.** The bus starts docked at a planet. Passengers wait at planets, each with a destination, a fare and an expected trip time. While docked or charging, the player picks passengers up into the bus's seats.
2. **Set course.** The player adds planets and points in space to the route.
3. **Charge.** The player holds the Frameshift key to charge the drive, and the bus leaves once it is charged. Leaving soon after docking is a quick stop; with the Warm drive the drive stays warm meanwhile, and a charge from warm takes a moment. Until then the route can still change.
4. **Fly.** The bus flies the route stop by stop. The player can reroute at any time.
5. **Arrive.** At a planet, passengers going there get off, pay their fare, rate the ride and earn research points.
6. **Refuel and research.** Docked, the player buys fuel, and at a planet with a lab researches upgrades from every tree once the mechanic has opened research.

## The solar system

- A star and four planets on circular orbits, one with a moon and one with rings. The Moon counts as a planet for passengers, fuel and docking.
- Planets orbit at 0.34 (Frost) to 0.47 (Ember) units a second; the Moon moves at up to about 0.87 as it circles Terra. Every planet moves at under 40 % of the bus's speed, so the bus catches one without a long chase.
- Ember and Frost are 12 to 23 units apart as they orbit.
- **The game runs at 0.9 of real time:** the bus, the planets, the passengers and everything on screen alike, so a ride plays out the same and only takes a tenth longer to play. Every number here is in the game's own seconds.

### Star systems

- **Three star systems,** in the order the player reaches them: Vela (the solar system above), Lyra and Sol. Vela is a star with four planets and a moon, Lyra a star with four planets, a moon and an asteroid field, Sol a star with six planets and two thin asteroid fields, and every planet in each moves at under 40 % of the bus's speed. More can be added; the last one in the order is the one whose promotion joins them.
- **They all share one space,** 46 to 55 units apart from star to star, so the bus can fly between them once they are joined: the gap between the outer orbits of two systems is 10 to 14 units, well inside a tank's 40.
- **One system at a time.** Until they are joined, the bus works in one system. Only its planets show and have lines, and the camera can't pan past its edge (18 units from Vela's star, 22.5 from Lyra's, 22 from Sol's) or zoom out past 55 units, 63 in Lyra and 62 in Sol, so the whole system fits.
- **A promotion opens the next system** (Goals), and the bus jumps there when the player takes the jump: at once, from wherever it is, after any stop under way. The player may stay in the system for now, and jump later from the goal panel. Whoever is still on board stays behind, paying and rating nothing, with no shock, and a quest about them fails; The Boss's call says so. There is no going back until the stargate is built (Goals, Travel between stars).
- **The jump plays as a scene change,** so the player never sees two systems at once and finding out at the end that they share one space is a surprise. The bus turns toward the next system and winds up for 1.3 s, then frameshifts out as the tow ship does; the screen goes black, the next level's loading screen shows until the player starts it (Scenes and flow), and the bus frameshifts in 1 unit off a planet, on its side away from the star, about where a stargate floats, and flies in to dock there, burning no fuel: Cinder in Lyra, the home planet Mars in Sol. The starting passengers wait at the home planet either way (Hither in Lyra). Its course is gone and its tank is full, so a new system never starts on a low tank. The system's planets start where its layout puts them, however long the last system took, and the bus comes out beside where its planet is then. While it flies in, the player can't change its route. Lines start at the new system's planets, empty but for the starting passengers, and the new system's goals are given. Once the bus has docked, The Boss calls about the system, as on the first shift (The first shift): only the bus bars show, the call notice's Answer is the one thing the player can do, it opens by itself after 5 s of play with The Boss annoyed, and the other panels come in once it closes. In Lyra The Boss says it is the second shift, that the planets are full of picky Business passengers with money they want, and not to fail. Nothing saves until it closes.
- **The promotion in the last system joins them all,** though nothing in play gives it yet (Goals, The Boss's pick-up): only the debug panel's Complete system does. Every system shows, the camera may roam over all of them and zoom out to 110, lines start at every planet that had none, and a passenger may want any planet in any system.
- Each system's planets are lit by its own star, and the bus by the star nearest it.
- **Each system has its own heat zone,** round its own star, and the one nearest the bus heats it once they are joined (Temperature). A system can have none, and its star still stops the bus.
- **Lyra is a blue giant,** with a bigger star and a wider heat zone than Vela's: its star's radius is 2.9, its hot zone reaches 6.6 and its heat zone 8.8. From the star out:
  - **Cinder** orbits on the heat zone's edge (8.8). Its moon **Janus** circles it 4.0 out, once every 50 s, so it swings from 4.8 from the star's centre, 1.9 off the star's surface, to 12.8, well outside the heat zone: when to go there matters. Janus moves at up to just under 1.0 units a second, the fastest body in any system, still under the bus's top speed.
  - **Brume,** with a lab, at 15.0, its rings clear of Janus at its widest.
  - **The asteroid field,** a band from 17.2 to 19.2 with five gaps, one of them wide, that turns once in 680 s. Among its rocks the bus flies at no more than 0.4, a third of its top speed, and every 0.8 s a rock knocks it, a shock of −1 to everyone on board. Its gaps are free. With Shock absorbers the bus flies among the rocks at up to 0.6 and each knock is −0.5. Numbers and open questions are in `docs/asteroid-field.md`.
  - **The twins, Hither and Yon,** outside the field on one orbit at 21, always on opposite sides of the star. Hither is the home planet, with a lab; Yon sells the cheapest fuel in Lyra. The bus crosses the field, or threads a gap, to reach the inner planets.
  - **A warp gate beside each twin** leads to the other's. Docked at either, the player can warp to the other for half a full tank of fuel (a quarter with Gate tuning), not credits, taken as the bus comes out of the far gate so the Pit crew fills it there rather than before it leaves, so a player short of credits can still go; with less than that in the tank they can't. The bus comes out of the far gate, its course gone, and flies the short way in to dock, with whoever is on board. Nobody waiting at one twin is going to the other, or the gate would deliver them at once for a fare and a rating set by the trip round the star. So the gate is for going on: from Hither to the inner planets on Yon's side, or back. A first try: the fuel price isn't measured, and whether the drive comes out warm and whether the gate counts as a stop for a passenger isn't decided.
- **Sol is our own solar system, far in the future,** its sun red and near the end of its life: its star's radius is 2.6, its hot zone reaches 4.8 and its heat zone 6.6 at rest.
- **Sol's sun is unstable: its heat zone swells.** Over and over, it rests for 40 s, swells over 20 s (easing in and out) until its edge reaches Jupiter's orbit (14.9), holds there for 15 s and shrinks back over 15 s, the hot zone growing to 9.0, so Earth and Mars are in the heat zone at its widest, Jupiter on its edge, Earth in the hot zone, and Venus is all but closed. It swells at no more than 0.62 units a second, half a bare bus's top speed, so a bus that charges cold at any planet as it starts and flies straight out gets clear, rocks and all. It holds at rest from the bus's arrival in Sol until the mechanic's call there (3 deliveries in, Research), where Rusty warns of it; once the player closes it, the star's pulse quickens and the first swell comes 6 s later. The cycle isn't saved: a run continued after that call starts it the same way, with the warning. As it swells it also heats faster, up to 1.5 times as fast at its widest, so its far reaches still count: at its widest, a bare bus flying in a straight line gains about 19° from Mars to Jupiter 45° round and 47° at 90°, 16° from Mars to Saturn 45° round, 26° from Earth to Jupiter 45° round. Standing still in it heats up to 4 times as fast at its widest, 1.6° a second, so waiting a swell out costs more than flying out ahead of it: a bus parked at Mars through one gains about 47° and overheats near the end of the hold, at Earth about 53°, and at Jupiter, on the edge, about 31°. Growing the hot zone in step with it, to 10.8, would take it right up to Mars, so every trip out of Mars would start in it. Unmeasured: balance runs never leave Vela. The star's pulse quickens over the 6 s before each swell (`docs/ui.md`). From the star out: **Venus** (6.0), inside the heat zone; **Earth** (8.6), abandoned, with no lab and no fuel; **Mars** (11.0), the home planet, with a lab; **the asteroid field,** a band from 12.4 to 13.4 with four gaps, half as wide as Lyra's and with a third of its rocks, that turns once in 700 s and rides as Lyra's does; **Jupiter** (14.9); **Saturn** (17.4), with rings and a lab; **the outer asteroid field,** a band from 19.0 to 19.8 with five gaps that turns once in 950 s, so every trip to Pluto crosses it; and **Pluto** (20.9), with the cheapest fuel. **A warp gate beside Venus and one beside Pluto** lead to each other, as Lyra's twins' do (above): the far ends of the system, so the gate skips the outer asteroid field and the heat zone, and a bus docked at Venus as the zone swells can warp out instead of flying through it. Nobody waiting at either is going to the other. A first layout: nothing in it is measured, and no rock ride is asked for there yet.
- **Time slows unless the bus frameshifts.** The planets orbit at full speed only while the bus flies a course, towed or not. They slow to half of it once it starts parking at a planet, comes to rest in space, or starts coasting to a stop after the course is cleared or the tank runs dry, and stay that slow while it waits or charges. A trip takes far longer than it looks, and the time spent stopped is wound back. Half speed keeps the system moving while docked, so a long stop still costs some of a route's shape. They take about 0.6 s to slow and 0.6 s to get going again, so nothing jumps. Their spin keeps running, and so do the passengers' clocks, except while docked (Happiness).

## Route and flight

- **Stops.** A route is an ordered list of stops, each a planet or a point in space. The bus docks at every planet on the route and passes through points in space. It holds still at a point in space that ends the route.
- **A planet stop** is the planet's near side, so the bus chases a moving planet.
- **Setting a course** works as in a real-time strategy game: a right click sets the route to the one stop under the pointer, and with the queue key held adds it to the end, so the stops come in the order clicked. The planet the route already ends at isn't added again straight after itself.
- **Steering by hand.** A point in space set with the right button follows the pointer for as long as the button stays down, every frame, so the bus chases it. Where the bus reaches it, as when the pointer rests, it stops; moving the pointer 0.3 units on sets a new point, which leaves at once while the drive is still warm from stopping (1 s) and otherwise waits for a charge.
- **Round trips.** A planet earlier on the route can be added again, and so can the planet the bus is docked at once the route has a stop.
- **The queue key** is Shift or Q, both in every browser. Firefox opens its own context menu on Shift + right-click and a page can't stop it, so the hints name Shift, and Q only in Firefox, never both. That menu also swallows the release of Shift, so a click or a move of the pointer that says Shift is up counts over a Shift still read as held. Not Ctrl: a page can't block Ctrl+W, and W pans the camera.
- **Speed.** The bus flies at a top speed of 1.2 units a second, speeding up as it leaves and slowing as it nears a planet.
- **Charge.** Setting a course never leaves a planet by itself, so planning a route and leaving are separate decisions. With the drive cold, the player charges it by holding the Frameshift key for 1.5 s, 1 s with Quick charge. The bus turns toward its next stop meanwhile.
- **Quick stop.** Leaving a planet within 5.5 s of the passengers getting off being off is a quick stop, with a route still ahead or not, so the player can reroute and still make it. The time counts the charge, so on a cold drive the player has 4 s to pick someone up and refuel before holding the key. Research pauses the game and the time with it, but researching an upgrade ends the quick stop at once, so a stop spent on research is no quick stop. Opening the research screen and closing it costs nothing. Towed in, there is none.
- **Warm drive.** With the upgrade, the drive is warm from docking for as long as the quick stop lasts, holding while the passengers get off. Holding the key while warm starts the charge from the warmth left, building as if a whole charge took 0.5 s, so it takes half a second at most, and leaving on it is a quick stop however late it started. Letting go of it drains the charge four times as fast as a cold one builds (0.75 s from full), and the drive is cold from then on: held again, it charges at the normal speed. It makes quick stops easier, not possible: the time a cold charge spends is the player's. The scripted player, which leaves 3 s after a stop, already makes every quick stop it doesn't spend on research, so to it the upgrade is worth nothing: researched right after Speed 1 it rates 3.99 against 4.04, with 72 % quick stops against 73 %. Its worth to a person who takes longer at a stop is untested.
- The reward is for leaving quickly; a queued route only makes that easier. A stop that drags on costs the passengers nothing (Happiness): it only loses the quick stop. The bus never leaves by itself.
- **Letting go** drains the charge twice as fast as it built and keeps the course; holding again charges from what is left. Cancelling keeps the bus docked.
- **Rerouting in flight is free:** no charge and no extra fuel beyond the distance it adds.
- **Short stops in space.** A course set from a stop in space within 1 s of coming to rest leaves at once, so a short stop costs nothing. After that the drive is cold and the bus waits for a charge, as at a planet; cancelling leaves it holding in space.
- **Parking.** Near a planet the bus glides the last half unit in and swings side-on, door toward the planet. It has docked only once it is parked, and only then can the drive charge.
- **Clearing the route** stops a charging drive, and makes a flying bus coast to a stop.

## Fuel

- **Tank.** A full tank holds 100 fuel. The bus burns 2.5 per unit flown, so a tank flies 40 units: about one trip from Ember to Frost and back. Efficient burn makes it 2.0, so a tank flies 50.
- **Only flying burns fuel.** Charging, parking and floating while docked don't.
- **Prices.** For now every planet sells fuel, each at its own price per unit. A full tank from empty costs 6 credits at Giant, 8 at Frost, 10 at Ember, 12 at Terra and 15 at the Moon. A planet can be set to sell none; none is yet.
- **Refuelling is a hold.** While the bus is docked or charging at the planet, holding the button pumps fuel from 5.1 a second, speeding up to 25.5 a second over 1.5 s, so a full tank takes about 4.7 s; Faster pumps makes both twice as fast. It stops when the player lets go, the tank is full or the credits run out, and it doesn't run while the frameshift is held: charging and refuelling take turns, since a player with only a mouse can hold one button at a time. With the Pit crew the pump runs as if held whenever the bus is docked at a planet that sells fuel and the drive isn't held, until the tank is full or the credits run out.
- **The bill** is paid when the pump stops, not as fuel flows: the whole credits it adds up to come off at once, and what is left under a credit carries over to the next refuel.
- **Fuel is cheap next to fares** for now: about 0.25 credits of fuel per unit flown, against fares of 3 per unit.
- **An empty tank at a planet** (only the debug panel causes it) keeps the bus docked: a charge under way stops and no course can be set until it refuels.

### Running dry and the tow

- The moment the tank runs dry in flight, the route is cleared, the bus coasts to a stop, and everyone on board takes a −15 shock.
- **Reserve tank.** With it, running dry in flight instead opens 20 fuel, 8 units of flight, with no shock and the route kept, and "Reserve tank!" shows over the bus. It opens once until the tank is next full, by the pump or a tow.
- Nothing comes by itself: the player requests a tow, and pays for it then.
- **The tow costs 100 credits.** With fewer, the credits go below zero and the player owes the rest. A full tank costs 6 to 15, so a tow is many times the price of refuelling in time.
- A tow ship flies out from the nearest planet, hitches on and leads the bus there. It flies 0.4 units a second faster than that planet moves, up to the bus's top speed, so the tow always catches its planet.
- A tow is slow, so happiness suffers on the way.
- The player can't set, change or cancel a course from running dry until the bus has docked.
- The bus docks as usual (a stop, with passengers getting off) **with a full tank**, so a tow never leaves the player stuck at a planet without fuel or the credits for it.

## Temperature

The star is something to steer around: flying near it heats the bus, and too near for too long overheats it, which stops it. How close and how long is a skill the player learns.

- **Degrees.** The bus rests at 21° and overheats at 60°. A new run and a continued one start at 21°; it isn't saved, since a run saves only at a planet, and few are ever in a heat zone.
- **The heat zone** is everything within 6.3 units of Vela's star's centre (Lyra's: Star systems). It reaches past Ember's orbit (5.2), so every trip to Ember costs a little, and stays inside 6.6, the closest the Moon comes, so Terra and the Moon are clear of it.
- **The hot zone** is its inner part, within 4.5 units. The rise steepens sharply there.

| Where | Flying | Standing still: docked, charging, parking, holding in space |
|---|---|---|
| Outside the heat zone | Falls 3.9° a second, to 21° | Falls the same |
| Heat zone | Rises 0.78° a second at its edge, up to 2.34° at the hot zone's edge | Rises 0.4° a second |
| Hot zone | Rises 2.34° a second at its edge, up to 46.8° at the star's surface (2.4) | Rises 0.4° a second |

- **Standing still in the zone warms it slowly,** docked at Ember or holding in space alike, so a stop there keeps what the trip cost and a long one costs a little more: from a trip's 25° or so, about a minute and a half to overheat, and parking in the zone is never free. Research pauses the game, so the clock stops there too.
- Coasting to a stop after the course is cleared counts as flying until the bus is at rest.
- **Never into the star.** While the straight line the bus heads along would touch the star, it brakes so it comes to rest on that line 0.1 short of touching (2.95 units from the star's centre when heading straight at it), and there it soon overheats. A line that clears the star isn't slowed, however near it passes. Not during a tow, which can't overheat, so stopping there would hold it for good.
- **Overheating.** At 60° the bus lets go of the Frameshift key and coasts to a stop, keeping its route. The route can be changed meanwhile, but the drive can't charge until the **cooldown** is over: 8 s that bring it back to 21° wherever the bus stands. Then it waits in space with a cold drive, warming slowly again, so going on along the same route, or a new one, takes a charge.
- **A clear way out.** After a cooldown, until the bus leaves the heat zone, flying anywhere but into the star heats it at a tenth of the usual rate, so the player can keep the course they had or turn away, and get out without overheating again. Only a heading whose line would touch the star heats as usual. Stopped against the star, that leaves courses 75° or more off straight at its centre.
- **Too hot is uncomfortable.** Above 32°, the top of the gauge's green band, everyone on board but a sauna quest's caller slowly loses happiness: what the bus can lift them to drops 0.25 a second, down to 3 below at most, and once the temperature is back in the band it comes back 1 a second. It is a nudge the player can undo, not a cost that stays with the ride: a clean ride on a bare bus (76) keeps its four stars at the worst of it. It counts through a cooldown, since the bus is hot then (about 6 s above 32°): with the −5 scare, an overheat takes a clean bare ride under four stars for about 2 s, and all of it is gone about 9 s after. Not while the temperature is exempt. Frustration's floor of 50 still holds.
- **Overheating scares everyone on board, −5,** and costs no credits. The time is most of the cost: the cooldown and the charge are about 9.5 s on a ride of about 20 s, which takes a passenger's on-time bonus and more.
- **Exempt.** The temperature holds, and can't overheat, during the tutorial until the zoom out is over (the zoomed map scales distances to the star), and during a tow, whose route the player has no say in.
- **Balance runs steer round it.** The scripted player decides only at docks, so whenever the straight way to the planet ahead passes within 0.5 of the hot zone, now or as the planet moves, it puts a waypoint beyond the heat zone's edge. Going round just outside the hot zone overheats: half a circle at 5.0 units adds about 25°. After an overheat it sets the same course again once it has cooled.

## Passengers

### Waiting

- Each planet gets a new passenger every 12 to 30 s, up to 3 waiting there and 7 at all the planets together, or 30 once the star systems are joined, about 2 to a planet, so the end game is busier; 30 is a guess, not measured yet. Lines build slowly and some are short: the scripted player finds nobody waiting at about a quarter of its stops and 1.4 on average, so where to go next is worth looking up. Who they are is under Who turns up.
- Nobody new turns up at the planet the bus is docked at: its clock holds until the bus leaves, so waiting there gains nothing.
- **Nobody waits at an abandoned planet,** which Earth is: none at the start and none later, nobody rides there, and no quest sends the bus there or past it. Its station sells no fuel either. The player finds out by first seeing its empty line, which docking there does, and the run keeps that they have.
- Happiness holds while they wait.
- **Station waiting lounge.** Someone picked up gets +1 on their target for every 10 s they waited, up to +5 at 50 s, for their whole ride. A wait counts while the planet's clock runs, so waiting docked there builds none. +5 at most keeps In-Flight Movies alone short of 5 stars (84 + 5 = 89).
- **The start.** A new run starts with the tutorial (Tutorial) while the player hasn't been through it, and its lines start after it. Once they start, the bus is empty, with 2 passengers waiting at the planet it is docked at and 1 at every other planet, so the first stop has someone to pick up and the first route somewhere to go. A New game after the tutorial starts docked at Terra, where the tutorial does, and the run after the tutorial at the Moon, where it ends; a scene run on its own starts docked at Ember.
- **The first shift.** A new run opens on a call from The Boss, once the tutorial's zoom out is over or, without the tutorial, once the scene is in, with only the bus bars showing: a welcome to the first shift, and that good employees are rewarded with a promotion. Until the player closes the transmission, the call notice's Answer is the one thing they can do: no clicks on the map or the bus bars, no route changes, no pan or zoom; Esc and the pause button still pause. Left unanswered for 5 s of play, it opens by itself, and The Boss opens annoyed, telling the player to answer. Both answers mean the same. Then the other panels come in, and a feature hint points at the goal panel (Feature hints). A continued run has none.

### Who turns up

- **Decided when first seen.** A waiting passenger is only a count until the player first sees the line, by docking at the planet or opening it. Then each undecided passenger in it gets a destination, a race and a type, one after another, and keeps them. Lines fill about 40 s before the bus arrives, so deciding late is what lets a line answer the bus as it is now.
- Anything that shows a line from afar counts as seeing it. The waiting markers show only a count, so they don't; the station cameras show who waits, so pointing at a planet with them does.
- **Destination** is a roll among the other planets, each as likely as the next. Only upgrades make a match likelier: with Timetables a planet someone already in the line is going to is 3× as likely, and with the Destination sign a planet someone on board is going to is 3× as likely. With both they multiply.
- **No more than two** in a line go to the same planet, so a line always holds a choice.
- Who is on board counts only with the Destination sign: passengers going the same way are something the player researches for, not a given.
- Destinations aren't dealt from a bag: dealing without repeats makes two going the same way rarer than chance does.
- **Race** is dealt from one shuffled bag of six, two of each race, so no race stays away for long.
- **Type** goes by the band the recent rating is in (Rating). Upgrades aren't read, though they lift the rating: a bare bus sits between 3 and 4 stars, by how clean its rides are, and the bus quality and the comfort upgrades take it past 4.

| Recent rating | Commuter | Business |
|---|---|---|
| Under 3.5 | 97 % | 3 % |
| 3.5 to 4.25 | 92 % | 8 % |
| 4.25 and up | 55 % | 45 % |

- **No Business passenger turns up in Vela,** the first star system, so the player learns the ride on Commuters alone. Past it, the first passenger decided in a line at the planet the bus is docked at or heading for is Business, so the player meets one at their first stop in Lyra; a line seen from afar doesn't use it up. After that they turn up by the system's share, or by the band where it has none. Balance runs play in Vela, so they see none: over 8 seeds the scripted player earns 241 credits a minute against 265 with them, and rates 4.05 against 4.02.
- **Half of Lyra's passengers are Business,** whatever the rating: Lyra is where the player learns them. Sol and the joined systems go by the band.
- **A full line has a Commuter:** at most one Business passenger in a line in the lowest band, two above it, and two where the system sets the share.
- **Returning passengers.** Someone who rates a ride 5 stars comes back later, half of the time: the same name, race, look and type, in a line again no sooner than 60 s after getting off, at any planet, and in a later star system as well. While one is due, each passenger decided is them 1 time in 4, with at most one in a line, and a Business one only where the line still keeps a place for a Commuter. They pay more (Payment), ride happier (the target) and are likelier to call with a quest (Goals). Up to 6 are remembered, and one more takes the place of the one away longest. Coming back again takes another 5-star ride, and one who leaves a line unpicked is gone. They are a reward that shows more than it pays: over 12 seeds of 15 minutes left in Vela they are 1 % of rides in the first 5 minutes, 14 % in the next 5 and 20 % in the last, and the rating, the credits and the quests taken move no more than they do between seeds.
- *(not built)* A type whose needs take an amenity doesn't turn up until the bus has it. No need takes one yet.
- **Leaving.** Once a line has been seen, its longest-waiting passenger leaves after 60 s without being picked up, then the next after 60 s more, so a line the player passes over doesn't stay the same for good. Nobody leaves while the bus is docked there.
- Leaving costs the player nothing. The place fills again on the planet's clock, with someone undecided.

### Stops and boarding

- Whenever the bus docks at a planet it makes a **stop**: the passengers going there get off one at a time.
- **Nobody boards by themselves.** While the bus is docked or charging, the player picks waiting passengers up one by one, or all that fit at once, longest waiting first.
- **Seats.** The bus has 4. No one can be picked up while every seat is taken or promised to someone picked up.
- Getting off or on takes 0.6 s each, in order: those getting off first, then those picked up, in the order picked.
- **The bus can't leave until the stop is over.** The drive charges during it as at any time, so the key answers at once, but a charge that fills before the last passenger is on waits, full, and the bus leaves as they sit down. Holding back the charge felt sluggish when picking passengers up quickly.
- The bus waits at every planet until the player charges the drive, so picking passengers up takes as long as the player likes.

### Trip time, fare and payment

- Both come from the straight distance at boarding. Planets move, so they are estimates.
- **Trip time** is the charge plus that distance at the bus's *base* top speed. **Expected time** is the trip time times the type's slack.
- **Fare** is 3 credits per unit times the type's multiplier and the star system's: 1.5 in Lyra, 1 elsewhere for now. Lyra's second stage costs about 10,700 credits against the first stage's 2,760, and at 1 the scripted player there took in about 235 credits a minute and still had no row-4 upgrade 10 minutes in, with the credits gone each time it docked. At 1.5 it takes in about 385 and holds about 600 credits 5 minutes in and 1,400 at 10, so from there research points are what it waits for (Races and research points); at 2 the credits only pile up. Measured over 16 seeds promoted into Lyra, with the same ratings at each. Express quests' fares follow it.
- Both are set when the passenger is decided (Who turns up), from where the planets are then.
- A faster bus gets passengers there before they expect it. Speed upgrades make passengers happier rather than more demanding.
- **Payment** on getting off: everyone pays the fare, a 4-star ride (happy) 1.1× and a 5-star ride 1.2×. With the Tip jar those are 1.2× and 1.3×. A returning passenger pays 1.1× all of it, whatever they rate. The steps are an even 0.1 so they are easy to balance. A poor ride costs the rating and never the fare, so one bad ride isn't punished twice and a player who struggles can still pay for the upgrades that help: over 12 seeds one who takes everyone and answers requests in about 8 s earns 229 credits a minute against 219 when annoyed paid half and furious nothing. The tips are small, so credits no longer reward good service: the scripted player earns 227 (259 when happy paid 1.2×, 1.44× with the Tip jar), and one who takes everyone and answers in about 12 s earns 251, since a full bus now pays more than a careful one.

### Happiness

Happiness replaced patience, so a long ride isn't the only thing that matters: what a passenger needs, and how well the bus gives it, does too.

- Each passenger on board has a happiness from 0 to 100.
- **It starts at the target,** the most the bus can give them: set as they take their seat, and again as the bus leaves, so comfort researched at that stop counts. A clean ride keeps them there. Starting lower and climbing made a short ride end before they got there, so delivering quickly scored worse than taking long.
- A shock before the bus leaves stays: they start that much under the target.
- Every frame it slides toward the **target**, falling at 3 a second and climbing at 1. It never jumps, and bad moments take a while to wear off.
- **Mood:** happy from 70, okay from 50, annoyed from 25, furious below.
- **Rating** on getting off: happiness ÷ 20, to the nearest whole star.
- **Docked is safe.** It holds, falling or climbing, while the bus is docked or parks, and their clock holds with it: the ride wears them out only while it flies, so a stop to refuel, research or think costs nobody anything. A shock still lands there. The falling version (a tenth of the speed while the drive was warm, half once cold) made players hurry through every stop and never research, and nothing on screen could teach it.
- **A quick stop is admired.** When the bus leaves a planet on a quick stop (Route and flight), everyone on board gains 3 happiness at once, and as much more of what they can reach for the rest of their ride, up to 6 in all. It rewards the player who makes them, and it is all a slow stop loses, since docked is safe: over 8 seeds a bare bus that makes nearly all of them (94 %) rates 3.79 against 3.75 for one that makes none, and a bus that researches, making 73 %, 4.06 against 3.80. With the 1.5 s charge, a 5.5 s window keeps the researching bus at 73 %, as 7 s did with the 3 s charge: the slack after the charge is what counts.

**The target** is worked out fresh every frame:

- 64 for a bus that does its job, plus the bus quality, the comfort bonuses, the lounge's and 3 for a returning passenger (no higher than 100 together), less the heat's discomfort (Temperature), less frustration. Timing isn't in it.
- While a request is open, the target is 0, from 1.5 s of flying after it opened, and happiness falls toward it at 4.5 a second, faster than for anything else: serving it at once costs nothing, and leaving it costs a star in under 2 s. Requests are rarer than they were at 3 a second (Needs and serving), so each one weighs more and a ride's rating comes out the same: over 12 seeds the scripted player rates 3.99 and one who takes everyone and answers in about 8 s 3.31, as before both changes (4.00 and 3.27). Ignoring a request must always cost more than serving it.
- While anything is serving the request, happiness holds rather than falling, since they can see it coming.

**Timing** is paid on arrival:

- As they get off, +12 at once if they arrive in the direct trip time, falling to 0 at the expected time, and no lower: past it, frustration takes over. It comes after any disappointment at a request left unserved, and before they rate.
- It isn't in the target, so the bar holds on a clean ride and only falls for a reason the card can show. In the target, it drained the bar on most rides with a stop on the way while nothing was wrong, and players couldn't tell why. The bar no longer predicts the rating exactly: an early arrival can add a star, which shows only in the stars they give.
- It runs on the passenger's own **clock**: real time in flight, stopped while docked, and slower while they sleep or watch a show.
- **Leeway.** While happiness is 80 or more, every second of their clock adds half a second to the time they expect, up to half a trip time.
- Getting there sooner (routing, speed, never needing a tow) is the main way to beat timing. Comfort only buys a little.

**Frustration** takes happiness off the most the bus can lift them to. It never drains them to 0: the bus can still lift them up to what is left, with food and comfort, so serving a frustrated passenger always pays.

- **Stops.** Every planet the bus docks at on their ride before theirs is a stop on the way; the planet they boarded at counts only once the bus has left it. Each type tolerates a number of them calmly, and each stop past that costs 15. Delivering the demanding ones first is the routing puzzle.
- **A late ride** costs 1 a second of their clock past the expected time, with their leeway: steady, never faster, so a late ride never runs away from the player.
- **The floor.** Frustration never takes them under 50 (okay, three stars). A request open still heads for 0.
- *(playtest)* Every stop counts for now. Counting only detours, a stop where going there and on is more than 1.25 times the straight way from where the bus last left, is one switch away (`RideProgress.ONLY_DETOURS`), for if serving several passengers on one route feels punished.
- They say why: a stop past their tolerance shows one of their type's lines about it at once (“Another stop?!”), and so does the moment the ride runs late (“I’m late for a meeting”), unless a request, a sleep, a show or a meal holds their line. While frustrated, their idle lines are those, for whichever costs them more.
- **Docked, they say they are calm:** their idle lines are their type's docked lines instead (“Calmly waiting at the station”), frustrated or not, since docked is safe. An idle line changes as the bus docks and leaves; a complaint, sleep, show or meal runs out first.
- **The card says what moves it:** on the happiness bar, what lifts them (what they were just served, getting over something, each comfort upgrade, coming back, the station lounge, a quick stop, a quest done) and what costs them (a request nobody serves, stops past their tolerance, a late ride, the heat, and for 15 s a quest declined or failed). The other shocks aren't listed yet.

**Shocks** change happiness at once and leave the target alone, so it climbs back at 1 a second:

| Shock | Amount | Why |
|---|---|---|
| Someone is kicked | −25 to everyone else | Otherwise kicking the angriest passenger would raise the average for free |
| The bus runs out of fuel | −15 to everyone | Less than a kick, since the wait and the tow cost time on top |
| The bus overheats | −5 to everyone | Small, since the cooldown and the charge cost time on top, and there is no tow to pay |
| Arriving unserved | −10 to them, before they rate | A request open for 5 s or more of flying. One asked just before arriving, or during parking, is forgiven, and a stop on the way serves it (Needs and serving) |
| Woken by a shock | a further −10 | Every shock wakes anyone asleep, so a kick or a tow is worse on a bus that sleeps |

There are no good shocks: one would fall away at 3 a second, gone in seconds.

**What a bus can reach.** A bare bus gives 4 stars for a clean ride and 3 otherwise: a direct trip with every request served at once rides at 64 and gets off at 64 + 12 = 76, and 4 stars takes 70, so it takes a little over a second of an open request past its leeway near the end, or arriving a fair bit late, to cost the star. At 60 a single second did, and the rating turned on slips too small to see. Over many rides a bare bus averages about 3.7 (3.71 over 12 seeds), 3.3 with slow hands and a full bus. Five stars takes about 90, which only a quest done (Goals), the comfort upgrades or a well-upgraded bus (Bus quality) reach. A fully upgraded bus sits at about 100 before timing.
- **Bus quality.** Every upgrade researched that does anything adds 1 to the target of everyone on board, up to 10: a better bus is a nicer ride, so any upgrade makes high ratings easier. It is what makes Lyra's 4.0 as hard as Vela's 3.5: the bus comes to Lyra with about 8 upgrades and Business passengers who ask more, and has the full 10 a few rides in. Measured over 24 seeds promoted into Lyra with the mechanic opening research, from the first ride to the promotion in Vela and from arriving to the goals being met in Lyra, the recent rating stands this far above the goal on average, for the scripted player and one who takes everyone and answers requests in about 8 s: Vela +0.37 and −0.01 (+0.33 and −0.07 with none), Lyra +0.34 and −0.30 (−0.14 and −0.67 with none, when the scripted player held 4.0 36 % of the time, against 89 %). At 0.5 an upgrade Lyra stays at +0.07, and at 1 up to 8 at +0.26. The slow player gains least, since an open request sends the target to 0 whatever the bus gives; they still meet Lyra's goals in 23 runs of 24, the one miss a run of tows. Vela's goals come no sooner for the scripted player, whom the deliveries hold back, but a bus left in Vela gets 5 stars on 57 % of rides by minute 15, against 21 %.

### Needs and serving

- Each passenger type has a few needs. The Commuter's are a snack and a drink, both food.
- A need asks again a random while after the last one's served activity ends: 20 to 40 s for a snack, 26 to 50 s for a drink. An open one is a **request**. Rides are short (about 20 s), so about a third of them hold a request, 0.55 a ride: few enough that each is noticed, and enough that the food upgrades answer something. At 8 to 20 s and 10 to 25 s it was 0.82 a ride, and serving was a chore that ran all flight.
- **Everyone comes on board with a hunger of their own:** the first wait of each need is a random part of one of its waits, from a quarter of it to all of it. With a whole wait for everyone, those picked up together asked together: of three, two asked within 3 s of each other on 68 % of flights, against 40 % now.
- **One request at a time.** The other needs' timers wait while one is open, so serving one doesn't set off the rest.
- **Not everyone asks at once.** The bus holds two fewer open requests than it has seats, and at least one: 2 with 4 seats, 3 with 5. A need that comes up past that waits until one is served.
- **A request never expires.** One that did would make ignoring a passenger cheaper than serving them.
- **Serving is a hold,** like refuelling: holding the button serves the request over 1.2 s (0.8 s with the Pneumatic galley), and letting go keeps what was served so far.
- **Stops are quiet.** No request opens while the bus is docked or parking, and the needs' timers stop with the clock while docked.
- **The station serves.** A request open when the bus docks is served by the station, by itself, over 1.2 s, whatever it asks for, since players missed requests while they looked at the station. The player's hold adds to it. One going with a passenger who gets off goes with them, unserved.
- Fun and sleep aren't needs that ask: upgrades give them.
- *(not built)* **Food and drink become one need,** so the player isn't asked to tell them apart: one request, served as a snack or a drink at random.

### Amenities

An amenity serves food by itself. Automation shortens a request rather than removing it, so needs stay on the cards on a fully upgraded bus, and more seats need more delivery.

- The moment someone asks for food, an amenity with room starts serving them. Anyone else asking waits, and their happiness heads for 0 meanwhile.
- The player can still hold the button: the hand's speed adds to the amenity's.
- **Food Dispenser:** one passenger at a time, 4 s each.
- **Waiter Droids:** three at a time, 2.5 s each.
- With both, the droids are tried first, then the dispenser, so four can be served at once.

### Comfort

What the comfort upgrades give everyone on board. Each line has one main job:

| Line | What it does |
|---|---|
| Food delivery | Shortens requests: the amenities above |
| Portions | A served snack or drink lasts longer, by hand or by machine, so the next request comes later. Helps before any dispenser |
| Fun | Raises the target all ride long: In-Flight Movies +8, Space Invaders +8. Passengers also watch shows, and their clock runs at 70 % while they do |
| Sleep | The clock runs a lot slower while asleep, and nothing is asked for |

- **Shows.** With In-Flight Movies, a passenger now and then watches a show instead of idling, for 8 to 12 s. Space Invaders makes each a binge of 15 to 25 s. A request stops the show.
- **Sleep.** Now and then, with nothing asked for, a passenger dozes off. Pillows allow naps of 4 to 8 s with the clock at 60 %; Sleeping pods give sleeps of 15 to 25 s at 40 %. The ranges never overlap, so a pod always beats a pillow. Without either, nobody sleeps.
- Hunger waits while they sleep, so a sleep is cut short only by a shock.
- Sleep is strong, so pods are priced well above the rest of their row and naps stay short. Staying awake a while between sleeps is what keeps a long route costing something.

### Kicking

- *(off for now)* No card offers the kick until it has a place on screen that isn't the happiness breakdown's. The rule stands for when it does.
- The player can kick a passenger off the bus at once, wherever it is.
- Their seat frees up, they pay nothing, rate nothing and earn no research point, and everyone left on board takes the kick's shock. Passengers kicked to make room for a VIP (Goals, VIP tour) cost no shock.
- A passenger who is getting off can't be kicked.

### Passenger types

- A type is data: fare multiplier, slack, needs, and the lines and names it uses.
- There are three: the Commuter, Business and the VIP.
- **Business** pays more and is harder to please, through tighter slack and more frequent requests, never a lower starting happiness. On a bare bus a near-direct trip with requests served within a few seconds gets three stars and the full fare; four stars takes a direct trip with every request served at once, or upgrades.
- Business pays 1.6× with a slack of 1.2, tolerates 2 stops on the way, and asks for the Commuter's snack and drink at 0.6 of the time between requests.
- The Commuter's slack stays loose (1.5) and it tolerates 4 stops: it is the passenger that makes a route with several stops work.
- The player can tell a Business passenger from a Commuter wherever they pick passengers and on board.
- **A VIP** never waits in a line: they call the bus to pick them up (Goals, VIP tour). They pay 1.6× with a slack of 1.5, tolerate 4 stops on the way, earn 3 research points and ask as often as Business does. They are gold, a colour no race has, in any race's shape and voice, and go by one of thirty titles before an ordinary name ("Baron Vontti", "Influencer Jen'na"). A five-star ride never brings one back.
- Race and type are independent: any race can be any type.

### Races and research points

- Every passenger is one of three races, picked at random: blue, orange or green.
- Getting off at their destination earns **research points,** whatever their race or rating: one for a Commuter, three for a Business passenger, and with the Passenger happiness survey one more for a 5-star ride, so the systems with Business passengers pay for their dearer research and serving Business pays in points as well as credits. Lyra's rows 3 and 4 cost 4 to 10 points each, and at one for everyone the scripted player there, with its credits to spare, had 3.3 of the second stage's upgrades 10 minutes in and none from row 4, waiting on points. With Business at three, half of Lyra's deliveries, it has 5.8 and 0.7 from row 4, with credits and points running out together, meets Lyra's goals in 6.8 minutes rather than 7.4, and rates the same; one who takes everyone and answers requests in about 8 s has 6.2 and 0.9. That is the pace of two points for every delivery in Lyra alone, measured too. Measured over 16 seeds promoted into Lyra.
- **Research points are one kind.** Every tree takes them, so race never decides what the player can research, and the player keeps track of one count, not three against three trees.
- A race must read without colour too, by the build of its head (`docs/ui.md`): with red-green colour blindness, orange and green come close.
- Skin colour never changes with mood, since it is what shows the race.

### Rating

- The player's **average rating** is the mean of every rating so far.
- It changes nothing yet.
- The **recent rating** is the mean of the last 10 ratings. It sets which types turn up (Who turns up), it is what a rating goal reads (Goals), and it is the rating the player is shown, so the stars, the goal and what they explain are one number.
- The star rating says only that a higher rating brings more Business passengers: no bands, no odds.
- *(not built)* The player is told the first time the recent rating reaches a new band, and not again on coming back to it.

## Capsules

Capsules adrift in space are something worth a detour: a small reward for flying into one, now and then a passenger with a quest.

- **Where and when.** From when the run proper starts (after the tutorial's zoom out; the tutorial puts out its own one, Tutorial), a capsule appears every 25 to 45 s while fewer than 2 drift (3 in Lyra and Sol), in the star system the bus works in (once joined, the one nearest the bus): between 1.5 units past its heat zone's edge and 1 unit inside the edge the camera stops at, 1.5 clear of any planet's surface and 5 from the bus. It drifts in a straight line at 0.05 units a second, barely moving next to the planets, and is gone after 90 s. None appear during a jump, and a new system starts with none.
- **What it holds** is rolled as the bus collects it, and every capsule looks alike, so nothing gives it away: the castaway, otherwise credits, research points or fuel, as likely one as another. Research points turn up only once research is open (Research), so the player earns none before they can see them, and fuel only while the tank is neither full nor dry, so it is never wasted and a bus that ran dry still needs its tow.
- **A pity counter** makes the castaway certain in the end: they are 10 % likely, and 15 points likelier for every capsule collected since they were last in one, so the 7th at the latest holds them. The count is saved with the run.
- **Never the first capsule.** At least one capsule holds something else since they were last in one, before or after quests are taught, so the player meets a capsule's other rewards first and the castaway feels like luck rather than a script. So the first capsule of a run, and the first in a system after one they turned up in, never holds them, and the second holds them 25 % of the time.
- **Certain in Vela.** In the first star system, once a capsule has held something else, the first capsule they can turn up in holds them. Quests are taught there only after 13 deliveries, the promotion comes at about 20, and a quest under way holds them back, so at 10 % most players would leave Vela without meeting them.
- **Once in a star system.** The castaway turns up once in each star system; after that its capsules hold only the rest, and count nothing, until the bus works in another (once joined, crosses into another). Whether they have turned up is saved with the run. A player who collects few capsules may not meet them there at all.
- **Only once quests are taught, and when they can board and call.** What a capsule holds is decided as the bus collects it. The castaway turns up only once the player has closed the quests feature hint (Feature hints), so their rescue is never the first quest the player meets. That hint comes with the first quest taken on, so a player who declines every quest never meets the castaway, in any system; a run that shows no hints, as a test or a balance run, doesn't wait for it. In Sol only once VIPs call there (VIP tour), since their bump takes one, so never once the systems are joined. Then only with a seat free, while they aren't on board already, and while their transmission can open at once: with no call ringing, no quest on offer or under way and no transmission open. Otherwise the roll is among the rest, and still counts toward the castaway, so a player who collected several capsules before the hint meets them soon after it.
- **The debug panel's capsules** hold what they say, without a roll or a count, or credits when what they say can't turn up: the castaway's when they can't board or call (it ignores that they turn up once in a system and wait for the quests hint), research points before research is open, fuel with the tank full or dry. Its Fill capsules tops the star system up to as many as can drift there, each rolled as it is collected.
- **Collecting** is flying into it: the bus within its own radius plus the capsule's, in any state, towed too. Credits and research points go to the player at once: 50, 115 and 230 credits, or 1, 2 and 3 points, in Vela, Lyra and Sol (as Sol once joined), about half a fly past's pay, so a capsule is worth a short detour and never a long one. Fuel is a tenth of a full tank in every system, up to full. Unmeasured: the scripted player decides only at docks and goes for none.
- **Not a stop.** A right click on a capsule sets a point in space where it is, as on empty space: the route doesn't follow it as it drifts.
- **The castaway** is always the same person, Major Tim: a Commuter no race claims, silver in a white helmet, with the green race's voice, who keeps drifting off in space and doesn't much mind, so the player gets to know them. Out of their capsule they ask for a quest (Goals) before they board: a hop in Vela, a hop near Janus in Lyra, a bump in Sol. Accepted, they take a seat; declined, they stay adrift and nothing is lost, and they don't turn up again in that system. On a hop or a bump they go nowhere: no destination, no fare and no time they expect, so no stop and no wait frustrates them, and they rate nothing; the quest's reward is all they pay. They don't much mind anything: their happiness is full all ride, no shock, heat or wait moves it, and they ask for no food or drink.
- **The castaway comes back.** The first ride in a run is an ordinary one; from the second on they are a returning passenger (Who turns up): the badge, 1.1× the pay and +3 on the target, and their call says they are back. Unlike other returning passengers this takes no five-star ride, and they never wait in a line, however they rate a ride. Whether the player has taken them on board before is saved with the run, and a new run meets them afresh.
- **Not saved.** A continued run starts with none adrift; a rescued passenger is saved as anyone on board.

## Research

Upgrades for the bus, bought with credits and research points.

- **Research trees aren't tied to planets.** Each is the upgrades for one part of the bus, linked by what each needs first.
- **Researching happens only while the bus is docked or charging at a planet with a lab,** as refuelling does, and there the player researches from every tree. With the Remote terminal (The trees), any planet will do.
- **Research opens a part at a time,** so the first research screen isn't a wall of upgrades. Each tree splits into three stages by row: rows 1 and 2, rows 3 and 4, and the rest. An upgrade is open once research and its stage both are, and the research screen shows nothing that isn't.
- **The mechanic opens it, with a call** as a passenger calls: a transmission that only says something, with two answers that mean the same; left ringing for 10 s of play, it opens by itself. What it brings opens once the player closes it.
  - **In Vela the first call opens research,** every tree on its first stage, once the player has delivered 10 passengers, the tutorial's one counted, and the bus is docked at a planet with a lab, so the player learns to research where they can do it. From the call ringing until it closes, the bus can't leave. Until then there is nothing to research: no lab badges, no Research button and no research points in the resource bar, though deliveries still earn them, so the player comes to the first lab with points to spend. It is no worse than research open from the start: over 24 seeds the scripted player, whose count leaves out the tutorial's ride, researches its first upgrade 2.7 minutes in rather than 0.6, and earns 242 credits a minute against 240, rates 4.00 against 3.98 and has 12 upgrades by minute 10 either way.
  - **Each system after Vela opens the next stage in every tree,** with a call once the player has delivered 3 passengers there, wherever the bus is, so Lyra opens on the first stage alone and its second comes a few rides in, and the third likewise in Sol, where the call also warns of its sun's swell (Star systems). Research is open from the start in every system after Vela: a player promoted before the first call gets it on the first stage with no call and no research guide, as the bus jumps. A promotion opens no other research, and nor does joining the systems.
  - **Nobody else calls over it.** It rings only when no other transmission is open or ringing, and not during a stop or a jump; passengers' calls wait while it rings.
- **The research guide.** After the mechanic's first call, guide cards show the player how to research: on the resource bar's research points, saying each delivery earns one and some passengers more, until they press Got it; on the station's Research button until the research screen opens, the game paused from the first card on, so only that button takes a click; and in the screen beside its "Game paused" tag, saying the game is paused while the lab is open and that research points are only for research, until one is researched. That ends it, and the player goes on researching by themselves. The bus can't leave until the research screen opens, though the player can still set a route. It shows once, as a feature hint does (Feature hints), and only in a run the main menu started.
- **Every other call that opens research leaves a reminder,** so the player goes to the lab: a guide card saying every tree has new upgrades beside the nearest lab's badge, or on the station's Research button while the bus is docked at a lab, with a Got it button. It goes as the research screen opens or on Got it, and shows in every run, every time; a call while one shows replaces it. While the research guide shows, a call leaves none.
- **The game is paused** while the player researches.
- **The first visit ends with an upgrade.** Until the player has researched their first upgrade, the research screen doesn't close while they can pay for one. So they always can, a screen opened with nothing researched and nothing they can pay for quietly raises their credits to the cheapest upgrade's among those they have the research points for, with no gain shown.
- **An upgrade** has a cost in credits and research points.
- It needs *one* of the upgrades it lists, from the same tree, and its stage open: each is a path to it. One that lists none needs only its stage.
- Each is researched once. A bigger step of the same thing is its own upgrade after it (Tank I, then Tank II).
- Once researched it puts modifiers on the bus's stats, gives it traits, or both.

An upgrade is in one of six states:

| State | When |
|---|---|
| Shut | Research or its stage isn't open. The research screen leaves it out |
| Hidden | Marked hidden, and nothing it needs is researched. Its name, description and cost don't show |
| Locked | Nothing it needs is researched |
| Available | Something it needs is researched and the player can pay |
| Can't afford | Available but for the cost |
| Researched | Its effects are on the bus |

### Stats and modifiers

- A **stat** is a base value with modifiers on top, each flat or a percent. The flat ones add to the base, then the percents add together and scale the sum: a base of 8 with +5, +10 % and +20 % is (8 + 5) × 1.3, in any order.
- Each stat has a floor however much modifiers take away, so the bus always moves, holds fuel and has a seat.

| Stat | Base | Floor | Notes |
|---|---|---|---|
| Top speed | 1.2 | 0.1 | Trip times and fares still use the base |
| Fuel tank | 100 | 1 | A bigger tank's new room starts empty; a smaller one spills what no longer fits |
| Seats | 4 | 1 | Rounded to the nearest whole seat. Fewer seats than passengers leaves everyone on board, and nobody else boards until enough have got off |
| Portion size | 1 | 0.1 | How long a served snack or drink lasts, as a multiple of its need's time |
| Warm time | 4 | 0.1 | Seconds the drive stays warm at a planet (Warm at a planet) |
| Pump speed | 1 | 0.1 | How fast the pump fills the tank, as a multiple of its rates |
| Charge time | 1.5 | 0.1 | Seconds a cold charge takes. Trip times still use the base |
| Heating | 1 | 0.1 | How fast the heat zone heats the bus, as a multiple of its rates, flying or standing |
| Fuel burn | 1 | 0.1 | Fuel burnt per unit flown, as a multiple of 2.5 |
| Serving speed | 1 | 0.1 | How fast the player serves by hand, as a multiple of the 1.2 s hold |

- A continued run researches its saved upgrades again on load, so their modifiers and traits come from the same place as in play (Save game).

### Traits

- A **trait** is a feature the bus either has or doesn't. The feature shows or works only while it does.
- Two upgrades can give the same trait; it stays until both take it back.
- **Waiting markers:** how many wait at each planet shows on the map. Without them, the player finds out by opening a planet.
- **Station cameras:** with the waiting markers, pointing at a planet shows who waits there and where each is going.
- *(off for now: no upgrade gives it)* **Fuel forecast:** how much of the tank the whole course burns, and each leg of it, shows on the route. It counts the straight legs as everything is now, short of each planet by where the bus starts to park, so it is an estimate.
- The comfort and food traits: Pillows, Sleeping pods, In-Flight Movies, Space Invaders, Food Dispenser, Waiter Droids.
- The station traits: Station waiting lounge (Waiting), Timetables and Destination sign (Who turns up), Tip jar (Payment), Passenger happiness survey (Races and research points), Gate tuning (Star systems) and Free station coffee: someone picked up waits 1.5× as long for the first request of each need.
- The fuel traits: Pit crew (Fuel) and Reserve tank (Running dry and the tow).
- **Business class:** a Business passenger puts up with 3 stops on the way, not 2, from when they board; whoever is on board when it is researched gets it at once.
- **Shock absorbers:** the asteroid field's knocks and its pull on the bus's speed are softer (Star systems).

### The trees

There are three trees, all paid for with the same research points. In Vela, Frost, Terra and Giant have a lab; in Lyra, Hither and Brume; the rest have none.

- They branch and join like talent trees: an early upgrade opens more than one, and the last rows hold upgrades that either of two branches reaches. An upgrade can need nothing even below the top row, open once its stage is. Only a tree or a stage that isn't open hides an upgrade; none is marked hidden.
- **Costs come in levels,** the same in every tree. The first stage has two: 120 credits and 2 points on its first row, 240 and 4 on its second. After it come 300 and 4, 550 and 7, 800 and 10, and 1,100 and 14. Each upgrade has its own level, which usually rises down the tree but needn't match its row: Express service on row 5 costs 800 and 10, Station cameras on row 3 costs 300 and 4. Credits come in at about 240 a minute and research points at about 5, so in the first stage credits are what the player waits for. The scripted player has 7 of the stage's upgrades by minute 5, about when Vela's goals are met, and 12 by minute 10. Dearer shuts out the player who struggles: at 140 and 280 the scripted player has 10 by minute 10 and 5-star rides fall from 15 % to 5 %, and one who takes everyone and answers requests in about 8 s misses Vela's rating goal in 2 runs of 12 (3 of 12 at 150 and 300, none now), since the comfort upgrades are what lift them over it. Much cheaper in credits, and fares, moods and Business passengers stop mattering.
- An upgrade that isn't implemented says so on its card and changes nothing when researched.

"A ← B" means A needs B; "A ← B or C" means either one opens it.

- **Blue** (performance). Speed 1 and Fuel tank 1 at the top. Warm drive, Quick charge and Speed 2 ← Speed 1; Speed 3 ← Speed 2. Faster pumps and Fuel tank 2 ← Fuel tank 1. Pit crew ← Faster pumps. Heat shielding ← Warm drive. Efficient burn ← Speed 2 or Quick charge. Reserve tank ← Pit crew or Fuel tank 2. Slingshot ← Efficient burn or Heat shielding. Solar fuel ← Fuel tank 2 or Reserve tank. Last row: Warp gate ← Solar fuel, Slingshot or Speed 3.
  - Speed is +10 % top speed a step, Fuel tank +25 % a step, Quick charge −0.5 s charge time, Faster pumps +100 % pump speed, Heat shielding −30 % heating, Efficient burn −20 % fuel burn; Warm drive (Route and flight), Pit crew and Reserve tank give their traits.
  - *(not built)* Solar fuel, Slingshot, Warp gate: the third stage isn't designed yet.
- **Green** (the planets). Door chime and Station waiting lounge at the top. Tip jar and Station cameras ← Door chime; Honk ← Tip jar. Free station coffee, Timetables and Business class ← Station waiting lounge. Gate tuning ← Free station coffee. Destination sign ← Timetables. Passenger happiness survey ← Honk or Station cameras. Bottomless complaints box ← Station cameras or Passenger happiness survey; Remote terminal ← Station cameras, Business class or Gate tuning; Express service ← Destination sign or Business class. Last row: Research grant ← Remote terminal, Express service or Bottomless complaints box.
  - Door chime gives the waiting markers, Station cameras the station cameras; the rest of the first two stages give their own traits.
  - **Bottomless complaints box:** from when it is researched, a ride rated under 3 stars counts for nothing: not in the recent rating, the average or the rides rated, so neither a rating goal nor who turns up sees it. It still pays its fare and earns its research points.
  - **Remote terminal:** the player researches at any planet the bus is docked or charging at, lab or not (Research), so the lab badges, which say where to research, go.
  - **Research grant:** the research screen trades credits and research points both ways at 200 credits a point, one a press, so whichever the player is short of, the other pays for it. At one price both ways, a trade there and back gains nothing. Unmeasured, like all of the third stage: balance runs don't reach Sol.
  - *(not built)* Honk, which needs a honk button, and Express service.
- **Orange** (comfort). Pillows, Extra seat I and Bigger portions I at the top. In-Flight Movies ← Pillows or Extra seat I; Space Invaders ← In-Flight Movies. Extra seat II ← Extra seat I; Extra seats III ← Extra seat II (+1, +1, then +2 seats). Pneumatic galley and Bigger portions II ← Bigger portions I. Sleeping pods ← Pillows. Shock absorbers ← Space Invaders or Extra seat II. Food Dispenser ← Pneumatic galley or Bigger portions II; Waiter Droids ← Food Dispenser. Karaoke ← Shock absorbers or Sleeping pods. Last row: Time dilation cabin ← Extra seats III, Karaoke or Waiter Droids. Bigger portions I and II are +50 % portion size each, 2× in all; the Pneumatic galley is +50 % serving speed.
  - *(not built)* Karaoke, Time dilation cabin. The rest is implemented.

## Goals

- **Several at once.** The player can have any number of goals; each counts from when it is given, not from the start of the run.
- **A milestone** is done once and stays done: deliver 50 passengers. Kicked passengers don't count.
- **Earning credits** counts every credit that comes in from when the goal is given (fares, quest rewards, capsules); spending them takes nothing off. In Sol, a scripted player promoted there earns about 350 credits a minute in fares and 200 in quests, and a VIP tour adds about 1,050, so 10,000 comes about 12 to 15 minutes in for a player who takes the tours, near when the VIP goal does, and after the 25 deliveries at 7 to 9 minutes.
- **A standing goal** is met or not as things stand, and is never done: keep a 4.0 rating. It isn't met until a set number of rides are rated (at least 1), so one lucky first ride doesn't meet it. Dropping below makes it unmet, not failed.
- **A rating goal reads the recent rating,** not the all-time average. On the average the first rides on a bare bus weigh on it for the whole run: a player who takes everyone and serves slowly then met a 3.5 goal in 3 runs of 8 within 15 minutes, with every first-stage upgrade researched. On the recent rating every kind of player meets it.
- **A quest** is something one passenger asks for mid-ride, for a reward. It is tracked apart from the goals a promotion takes, so a quest under way or failed never stands in the way of all met.
- **The call.** While the bus flies, a passenger on board calls: the first once the player has delivered 13 passengers and no sooner than 30 s into a run. The next comes 35 to 50 s after the last call or quest ended until 20 are delivered, and 75 to 120 s after that; in Sol, where VIPs call, each wait is 1.5 times as long, so a passenger's quest comes less often beside the tours. Sol's 1.5 is a guess, unmeasured. Quests are an event, not a constant: the pausing transmission wears thin if it comes all the time, so only a new player gets them close together, to meet two before Vela's 20 deliveries. Over 24 seeds the scripted player gets 1.9 calls before its 20th delivery (1 to 3); a wait of 20 to 35 s gave about 0.6 more, 40 to 60 s about 0.2 fewer.
- **Anyone on board can call,** whatever their type, but in Lyra only Business passengers call. Of those who can, a returning passenger is 3× as likely to be the one who does as anyone else; how often a call comes stays the same. So in Lyra a returning Commuter never calls.
- **What they ask goes by who calls and where.** A fly past or an errand, as likely one as the other, and the one that suits when only one does. From Lyra on, a Business passenger asks for an errand, a photo stop or a warp, as likely one as another, or now and then a rock ride or a sauna (each a fifth as likely as each of the others), and never a fly past. Each kind is only asked where it suits: a warp where the system has gates, a rock ride where it has an asteroid field, a sauna where its star has a heat zone and the bus isn't hot already. The rock ride and the sauna are rare because they cost everyone else on board.
- **One at a time.** Nobody calls while a call rings or a quest is under way, and the wait until the next call starts only once that one has ended. A VIP's tour is apart from that: one passenger's quest and one tour can be under way at once, and a tour ending doesn't start the wait over. The VIP on a tour never calls with another quest. Nobody calls in the first 2 s of a flight, while asleep, or within 6 s of getting off.
- **Answering** opens their transmission, with what they ask and the reward. The quest is worked out then, from where everything is.
- **Declining costs the caller 5 happiness,** as a shock, whether in the transmission or from the call notice before hearing the quest, and so does leaving the call unanswered until the bus reaches a planet or is towed, so ignoring a call is never better than saying no. A call whose caller leaves the bus first just ends.
- **A done quest pays** on top of the delivery, by the star system the bus works in, and as in Sol once they are joined:

  | | Vela | Lyra | Sol |
  |---|---|---|---|
  | Fly past | 100 credits, 2 points | 230, 3 | 460, 7 |
  | Errand, photo stop, warp, rock ride, sauna, rescue, hop | 140, 2 | 320, 4 | 640, 7 |

  - **Two quests pay for one upgrade at the higher cost level of the stage that system opens** (240 and 4, 550 and 7, 1,100 and 14): a fly past and an errand together, the fly past less because it costs no stop. In Vela those are the two a new player meets before 20 deliveries.
  - Over 24 seeds in Vela the scripted player, who docks at a fly past's planet too, takes 4.0 quests in 10 minutes and finishes 3.8 for 464 credits and 7.6 points: 237 credits a minute against 200 declining them all, with the same rating and 12.7 upgrades against 11. Lyra's and Sol's amounts follow the rule and aren't measured, as balance runs never leave Vela, and nor are the Business quests.
- **A done quest lifts the caller 20 happiness** at once, and as much more of what they can reach for the rest of their ride, and they dance for a moment (`docs/ui.md`). It is how a bare bus gives five stars: a clean ride sits at 84 and needs only half the timing bonus to reach 90. At 15 it needed nearly all of it. Over 16 seeds on a bare bus 70 % of rides with a quest done rate five stars (58 % at 15), and no other ride does; with research it is 80 % (77 % at 15), against 16 % of all rides. The rating moves little, 3.74 to 3.82 on a bare bus, since only about 4 rides in 10 minutes have one.
- **A failed quest costs the caller 15 happiness,** as a shock, if they still ride: more than declining, or accepting and ignoring it would beat saying no. When a kick fails it, the kick's shock is the cost.
- **The planet a quest names is a detour:** never where the caller is going, where they boarded, where the bus is docked, or on the route.
- **The caller's own detour costs them nothing.** Accepting a fly past or an errand adds the detour to their trip time (by the planet and on to their destination, against straight there from where the bus is), with the type's slack, and an errand's stop doesn't count against the stops they tolerate; a later stop at that planet does. Everyone else on board takes it as any detour.
- **Fly past.** The caller wants to see a planet from the window. It is done when the bus comes within 3 units of the planet's surface in flight with them on board; flying in to dock there counts.
  - It fails when the bus docks at their destination first, or when they are kicked.
  - Never a planet the bus is within reach of already, nor one that orbits inside the heat zone (Ember), so it never sends a beginner into the heat.
  - The zone shows on the map while the quest is under way (`docs/ui.md`), and is the same 3 units the rule counts.
- **Errand.** The caller has something to do at another planet. It is done when the bus docks there with them on board, in any order with its other stops, by a tow as much as by a course. They stay on and ride on to their destination.
  - It fails when the bus docks at their destination first, or when they are kicked.
- **Errand for Business.** The same errand, with their own reasons: contract documents left behind, papers to sign, a client waiting.
- **Photo stop.** The caller wants a photo of a planet, so the bus has to come to rest in space within the fly past's 3 units of its surface with them on board. Flying through the zone doesn't count, and nor does docking there. The planet is picked as a fly past's, the zone shows the same, and accepting adds the detour with the time to stop and charge again. It fails as a fly past does.
- **Warp.** The caller has never been through a warp gate. It is done when the bus comes out of the far gate with them on board, through either gate, and fails when the bus docks at their destination first, or when they are kicked. Accepting adds the detour to the nearest gate's planet and the far dock. Docking at the gate's planet still counts against the stops they tolerate.
- **Rock ride.** The caller wants a thrill: the bus flies among the asteroid field's rocks for 3 s in all with them on board, not all at once. From accepting it for the rest of their ride, every knock lifts them by as much as it costs the rest (+1), at once and in what they can reach, as a quest done does, so it stays where a shock wears off, and they dance for a moment. Accepting adds the time to the band's middle and back, and the 3 s. It fails when the bus docks at their destination first, or when they are kicked.
- **Sauna.** The caller misses a proper sauna. It is done when the bus runs past its comfortable temperature, out of the gauge's green band (32°), with them on board, so they dance sweating. From accepting it for the rest of their ride, the heat lifts them as much as it costs everyone else (up to +3 against −3, Temperature), and their card lists it as "Sauna". Accepting adds the time to the hot zone's edge and back, and to heat up there. It fails when the bus docks at their destination first, or when they are kicked.
- **The castaway's quests.** The castaway, out of a capsule the bus collected (Capsules), asks for theirs 1.5 s after, in a transmission that opens by itself with no call notice (they only turn up when nothing is in its way), whatever the wait since the last call and however few have been delivered, in Sol; should the bus be in a stop by then, it opens as the stop ends. Accepting boards them, or counts as a no should the last seat have gone meanwhile; declining costs nothing, since they aren't a passenger yet.
- **Rescue.** Take the castaway to their destination in time, with their fare and trip time from the capsule, flown without a charge; they ride and pay like anyone else. Nothing gives it any more, since the castaway asks for a bump in Sol; a save with one under way still loads it. It is done when the bus docks there with them on board, and fails the moment their ride runs late (past their expected time and leeway) or when they are kicked. Accepting changes nothing else about their ride.
- **Hop.** In Vela the castaway asks for this instead of a rescue, the same way: they are going nowhere and want out at a nice spot in open space, the hop location. It is across the star from where the bus was when they asked, 1.3 units inside the outermost orbit (16.2 from Vela's star, between Giant's rings and Frost), so the straight way there crosses the star and the player routes round it. It is done when the bus comes to rest in space within 0.8 units of the spot with them on board; flying through doesn't count. Then they hop out of the bus at once, with no shock to anyone, no rating and no delivery counted. Nothing fails it but their leaving the bus first (a kick, or the jump to the next system), so until then they hold a seat, which is all they cost. A first try: the spot's place and the zone's size are untested.
- **Hop near Janus.** In Lyra the castaway's hop has a moving hop location that is only open at times: they want out beside Janus when it is hot enough, inside the hot zone (within 6.6 of the star).
  - **The hop location** follows Janus, 1.8 units round its centre, so at Janus's closest (4.8) its outer rim is on the hot zone's edge and a bus that stops there has barely entered it; deeper in, a flying bus gains up to 24° a second.
  - **The window** is open for the quarter of Janus's turn round Cinder that faces the star: about 21 s of every 86 s with the bus in flight, and twice as long on the clock with it stopped, as the orbits slow then. Janus all but stands still at its closest, 0.04 units a second, so the zone is easy to stop in when it counts.
  - **It is done** when the bus is at rest there while the window is open: holding still in space in the zone, or at Janus, from the moment it starts parking. A bus that stopped early is done the moment the window opens, if Janus hasn't carried the zone off it. Then they hop out as in Vela.
  - **Nothing fails it** but their leaving the bus first. A halt outside the window does nothing, and the next window comes round.
  - A first try: the zone's size and the window's length are untested, and nobody but the castaway is asked to go this deep.
- **Bump.** In Sol the castaway asks to be bumped off the bus by a VIP. A VIP picked up with fewer seats free than the two they take kicks passengers off to make room (VIP tour), the castaway first, and being thrown off by someone famous is what they want.
  - **It is done** the moment a VIP kicks them off, or The Boss boarding does (The Boss's pick-up): they fly out of the door as anyone kicked does. A VIP picked up with room to spare changes nothing, and the next VIP gets another go.
  - **Nothing fails it** but their leaving the bus another way, as when left behind at the jump. While the player's own kick is off, a kick is only ever a VIP's or The Boss's.
  - **Saying what to do.** A player rarely knows a VIP kicks anyone until it happens, so the castaway says so as they ask, the ask reads "Board a VIP with the bus full", and while it is under way the quest's row says whether a VIP would fit now (`docs/ui.md`).
  - It pays as a hop. A first try: with one seat free the player can fill the bus at the VIP's own planet before picking them up, so it may rarely be a routing problem, and on a bus with more seats it takes more passengers on board.
- **VIP tour.** In Sol, a VIP (Passenger types) waiting at a planet calls the bus: pick them up there and take them to three stops in order. All of its numbers are first guesses, unmeasured.
  - **The call** comes first once the player has delivered 6 passengers in Sol, three after the mechanic's call starts the swell, so each new thing has room; no sooner than 20 s after arriving, and then 30 to 60 s after the last VIP call or tour ended. Never once the systems are joined. One VIP at a time: none calls while another's call rings, or while one waits or rides. A passenger's quest under way is no bar, but nobody else may be on the line: no call ringing, no quest on offer, no transmission open, no stop under way. It rings for 20 s, from "Someone very important" the player can't see: who it is shows once they answer. Declining it, in the notice or the transmission, or letting it ring out costs nothing, since they aren't a passenger yet. While it rings or its transmission shows, no passenger calls.
  - **The tour** is rolled as they call: a planet to wait at that the bus isn't docked at, then three stops, each any planet but that one and the stop before it, never an abandoned one. Their trip time is every leg flown straight from where the planets are then, with 8 s for each stop on the way, and their fare the whole distance's.
  - **Accepted, they wait** at their planet, first in its line, never leaving, and take one of its 3 places: nobody new turns up there past them, and a line already full loses its newest passenger as they accept. They take two seats, as they always want the next seat empty. They can always be picked up on a bus with two seats or more: with fewer free, the castaway (Bump) and then passengers on board picked at random are kicked off to make room, one, then 1.2 s later the next, so their screams don't overlap, and the VIP gets on after the last. Those kicked pay and rate nothing and a quest about them fails, as with any kick, but nobody left on board takes the kick's shock: the player didn't kick them. Board all never makes room for a VIP; only the VIP's own button does. They wait 60 s and twice the flight to them from where the bus is as their transmission opens, 90 s at the most, so the player can finish what they are doing first; the transmission says how long. Not on board by then, they give up and the tour fails, which costs nothing more.
  - **On board, they stay in their seat** at each stop of the tour but the last, where they get off, pay and rate as anyone. Only the stop they are on counts: docking at a later one first is a stop on the way like any other planet. Their own stops never count against the stops they tolerate. Their one trip time covers the whole tour and the player sees it count down. They don't want to wait: unlike anyone else's, their clock runs on while the bus is docked or parks, from when it leaves the planet they boarded at, though their happiness holds there as everyone's does. Sleep and shows still slow it. past it they are late as any passenger is, and the tour goes on.
  - **It is done** when the bus docks at the last stop with them on board, and pays 900 credits and 10 research points on top of their fare, with the lift of any quest done. It fails when they give up waiting or are kicked.
  - **A hand-written VIP** has a set title, name and call text, each optional, for easter eggs; their looks, where they wait and their stops are rolled as any VIP's. While there are some, each VIP call has a 25 % chance to be one of them, picked at random, until the player has accepted one: only one rides per star system, and Sol is the only one VIPs call in. One that is declined or rings out can call again. The debug panel can have a chosen one call at any time.
  - **Not saved while they wait.** A continued run has no VIP waiting and no quest for them; one on board is saved with their quest, beside any passenger's quest under way. How many passengers have been delivered in Sol is saved, so VIPs unlock on the same delivery in a continued run.
  - **Balance runs meet none,** as they never leave Vela.
- **Express** is built but nothing gives it any more: it annoyed more than it paid. A save with one under way still loads it.
- **Failing by reaching their destination costs the caller the 15** before they rate, so accepting a quest and flying straight on is never better than declining.
- *(not built)* **Pick up my friend:** fetch a named passenger at another planet and deliver both.
- One older quest goal is built but nothing gives it: deliver one passenger.
- **Balance runs answer calls** by the scripted player's policy: they take every quest unless told to decline, ignore or switch off calls, or to decline a detour past a set length, and fly straight to the quest's planet, docking there for a fly past too. Unless told to be promoted, they meet no Business quest; they decline a quest whose planet is too far for the fuel left.
- **All met** means every milestone done and every standing goal holding.
- **A promotion** comes once the player answers The Boss's call with it (below), and the next star system opens. Taking the jump, the goals stay on the goal panel as they stand, ticked and no longer counting, until the bus jumps there (Star systems) and the next system's replace them. Staying, the goals go, and in their place the goal panel offers the jump to the next system until the player takes it, but only while the bus is at a planet, docked or charging, as the dock panel shows; the rest of the system plays on as before, and a run continued while staying offers it again; its research comes with the mechanic a few deliveries after the bus is there (Research). The debug panel's Promotion call has The Boss call at once, and its Complete system promotes and jumps at once, as answering does. Balance runs are never promoted unless told which system to be promoted to (`promote_to`), so by default they play on the first stage in Vela throughout, with no Business passengers and research open from the start unless told to have the mechanic open it.
- **Each star system gives its own goals** when the bus arrives: deliver 20 and keep 3.5 in Vela; deliver 15, 10 of them Business, and keep 4.0 in Lyra; 25 and earn 10,000 credits in Sol, with no rating goal, and once VIPs call there (VIP tour), deliver 5 VIPs on time too, a VIP counting only if they weren't late as they got off at their last stop; and 60 and 4.0 once the systems are joined. Lyra's are measured (Bus quality): the scripted player meets them about 7 minutes after arriving. Sol's are guesses.
- **A run starts with Vela's two goals:** deliver 20 passengers, and keep a 3.5 rating. 3.5 is under what a bare bus averages (3.7), so it is met about when the deliveries are: the scripted player has both after about 5 minutes, and one who takes everyone and serves slowly after about 7. A higher target shuts that player out: they end a run near 3.6.
- **The Boss's call.** Once all the goals of a system have held for 5 s of play, The Boss calls with the promotion, or in Sol, the last system, once, with someone to pick up (The Boss's pick-up); a goal dropping back starts the 5 s over. Left unanswered for 10 s of play while the call notice shows, the call opens by itself, and The Boss opens annoyed, telling the player to pick up. A system can give The Boss its own words for its promotion: in Lyra, The Boss is rich and wants the player in Sol for something very important. Its answers are "Jump to new system", which jumps at once, and "Stay for now", which keeps the bus in the system with the jump on the goal panel; in the last system its one answer is "Sure boss", which starts The Boss's pick-up. While a passenger's call rings The Boss waits for it, and nobody calls while The Boss's call rings. A run continued from before the jump is over gets the call again. Once the systems are joined nobody calls.
- **The Boss's pick-up.** In Sol, The Boss's call says a very important passenger waits on Earth. Answered, it gives a quest to pick them up there, with no timer and no reward, and the goals stay as they are. They wait at Earth for as long as it takes, nobody the player knows: "???". Once the bus is docked at Earth, with no stop under way and nobody else on the line, the meeting plays by itself, and until it is over the player can't plot a course, leave, or move the camera, nobody calls, and nothing saves, so a run continued from the middle of it has it again:
  - They show first in Earth's line, and the quest is done.
  - 1.4 s later The Boss's transmission opens with no call notice: "Well, we finally meet." in the dark, then the lights come on over them, and they say they are invited to a board meeting. Answered ("Congratulations!" or "Sure, boss!", which mean the same), they introduce the stargate, which lets the bus go between stars, and say the player will take them to the board after some errands ("Sure, boss!" or "Ok, I guess").
  - The stargate appears beside Earth as the camera watches, and stays for the rest of the run.
  - Everyone on board is kicked off as for a VIP (Kicking), one at a time, and The Boss boards. As a passenger The Boss takes every seat the bus has, so nobody else boards while they ride; they are going nowhere, pay and rate nothing, ask for nothing, never sleep, and are never kicked off. From the meeting on nobody calls: no passenger with a quest, no VIP.
  - The station at Earth gets a service, "Travel between stars", and the game pauses until the player presses it.
  - The map draws back to the star chart and stays there. 1 s later The Boss's transmission opens by itself, with no call notice: "As I said, I need a few things before I'm ready to receive my promotion. I forgot my briefcase at my side office on Brume, and my bowtie at my mansion on Giant. WHY AREN'T YOU DRIVING ALREADY, RESOURCE? MY PROMOTION AWAITS!" ("Right away, boss!").
  - The HUD comes back over the chart, Sol's goals go, and The Boss's take their place, "To get The Boss promoted": get the briefcase from Brume, and the bowtie from Giant, each done once the bus docks there. As each is fetched The Boss's portrait has it for the rest of the run: the briefcase held up beside them, the bowtie on. Meeting both does nothing yet. The chart stays open for the player to jump to another star or close it (Travel between stars), with the route and the bus held until it closes; then the player has the bus again. A run continued from here starts on the map, at Earth.
- **Travel between stars** shows at the planet a stargate floats beside, once the stargate is built: Earth in Sol, Cinder in Lyra, Terra in Vela. The other two stargates are there from the moment Earth's is. Pressing it opens the star chart, which stays open until the player jumps or closes it.
  - **The stars sit in one line** in the order the player opened them, and the bus jumps one link at a time: from Sol to Lyra, from Lyra to Vela or back. A star further away can't be jumped to.
  - **A jump costs no fuel.** The star's system becomes the one the bus works in, its lines start empty, and the bus comes out 2 units off the planet its stargate floats beside, on the stargate's side, and flies in to dock. The way in burns no fuel either, so an almost empty tank still gets there. Nothing saves from the jump until the chart has closed.
  - There the bus flies as in any system, and The Boss's goals stay. It is all still Sol's level: a run continued from another star shows Sol's loading screen, and Restart level starts Sol over.
- *(not built)* A temporary lose while the loop is tuned. **Lose:** the happiness score, the average happiness of everyone on board, stays at 0 for 20 s; the countdown pauses while the bus is empty.

## Controls

| Input | Action |
|---|---|
| Left click the bus or a planet | Opens nothing for now: the bus and the planets act as empty space, and the bus shows no hover border. Where the bus overlaps a planet, the planet is what the pointer is over |
| Left click the open thing, or empty space | Close it |
| Right click a planet or empty space | Set the route to it: the planet, or a point in space (Route and flight) |
| Shift or Q + right click | Add it to the end of the route |
| Hold the right button on empty space | The point in space follows the pointer until let go, to steer by hand |
| Backspace or Delete | Take the last stop off the route |
| The X on a stop in the route bar | Take that stop off the route |
| W A S D, arrow keys, or the pointer at a window edge | Pan the camera. A pointer that reaches the edge within 0.3 s of being over a panel waits 0.4 s there before it pans, so overshooting a panel's button doesn't. A setting turns edge scrolling off |
| Hold the middle mouse button and move | Drag the camera: the point under the pointer when the button went down stays under it. The drag goes on past the window edge, and edge scrolling stays out of it |
| Hold the left button on the map and move | Drag the camera as the middle button does, once the pointer has moved 4 px, so a left click still clicks. A press on a panel never drags |
| Mouse wheel | Zoom toward the point under the pointer |
| Esc, or the pause button | Pause |
| F2 | The debug panel |

- **Left click selects, right click routes.**
- **Esc stays pause only.** In browser fullscreen the browser takes Esc and the game never sees it, so Esc can't close a panel the same way in a window and in fullscreen.
- **Removing a stop.** Any planet ahead on the route comes off, from the middle too, and the route joins up round it. A planet takes the points in space just before it along: they were the way there, and the route bar doesn't show them. A point in space comes off alone, and only when it ends the route. Two of the same planet left side by side become one, as does a first stop at the planet the bus waits at. Not during a tow.
- Removing the last stop cancels the course. The Stop key clears the whole route.
- While the bus brakes in to dock, the Frameshift key does nothing, so a press meant to leave from there doesn't stop the bus.
- WASD reads physical key positions, so it sits in the same place on every keyboard layout.
- Pan and zoom do nothing while a planet or the bus is open. Right click still sets the course.
- Each panel's own buttons are in `docs/ui.md`.

## Scenes and flow

```
main menu ──Play / Levels──▶ campaign ──Play / Continue / Play again / Restart──▶ level's loading screen ──▶ solar system
    │  └──Continue──────────────────────────────────────────────────────────────▲                       │
    │                                                                                              Esc / pause button
    └──Settings / Controls──▶ settings, controls ◀──Settings / Controls── pause menu ◀──────────────────┘
                                                                           └──Main menu──▶ main menu
```

- **Levels are stages of the one run,** each in its own star system: Level 1 in Vela, Level 2 in Lyra, Level 3 in Sol (placeholder names: "Your first shift", "Rough ride", "Return to home"). A level is done once a promotion there opens the next system, and the next level is open once the one before is done; how far the player has got outlives the run. The run as it entered each level after the first is kept, so restarting a level puts the run back to how it began, with everything earned before it.
- **The main menu** offers Play with no run in progress, which opens the campaign screen; with one, Continue plays it at once and Levels opens the campaign screen.
- **The campaign screen** opens with the level in progress picked, or else the next one not done. The level in progress offers Continue and Restart level; a done one offers Play again, which starts the run over from where that level began; another open one offers Play. A locked one can't be picked. Restarting, and playing a done level again while a run is in progress, ask first: the run in play is lost, and what was earned in the levels before carries over. Until the player has been through the tutorial, Level 1 always opens on it and its card has no Play tutorial box, so a first run can't leave it out; after, the card has the box, cleared, and starting Level 1 opens on the tutorial if it is ticked. Ticking the box picks Level 1's card, since the player who ticks it means to play it.
- **The pause menu** can restart the level it is in, with the same question, through the tutorial again if it is under way.
- **Loading:** entering a level shows that level's loading screen: its picture, its name and a tip, and once loaded it waits for the player to press Start. The jump into the next level shows it too, in the jump's black, with nothing to load. Start shows no sooner than 2 s after the screen has faded in, its bar filling meanwhile, so a level that loads at once still reads as loading. Every other scene change, and a level with no picture (Level 3 for now), load on the black card, and the jump into such a level stays black.
- **Tips:** one picked at random each time, never the one shown last. A tip may belong to one level; the rest show on any.

- The game is one scene, the solar system, which holds every star system. A new run opens on the tutorial's zoomed map (Tutorial) until the player has been through it.
- Pausing stops the game; music keeps playing. The pause menu also opens when the player leaves browser fullscreen.
- **The pause button** opens the pause menu as Esc does, wherever Esc would, so a player in browser fullscreen, where Esc never reaches the game, can still pause.
- **A transmission** pauses the game until the player answers it. Closing the pause menu over one leaves the game paused.
- **The call shows who calls, once the player knows them:** The Boss always, a passenger on board always, and the mechanic from their second call in a run on, so a new run's first call from them, where they introduce themselves, comes from an unknown caller. Of the passengers, only those on board call.
- **A caller's voice:** each race has its own set of short recorded clips (`game/transmissions/voice/`), strung together while the text types out. A race with no clips yet is silent. Every caller of a race has a pitch of their own, fixed by their name. The voice lab, from the debug panel on the main menu, is where the delivery is tuned.
- **Settings:** Master, Music and SFX volume, Reduce motion, and Edge scrolling (on by default). They are saved across sessions.
- On the web a title card comes before the main menu, and its click starts the music (`docs/web-constraints.md`, Audio).

## Tutorial

- **A new run starts with it until the player has been through it once,** done or skipped; after that Level 1 starts without it, as does a continued run, unless the player ticks Play tutorial on Level 1's card, which shows, cleared, only from then. Whether they have is kept beside the save and outlives the run; resetting the campaign, from the main menu's settings or the debug panel's Delete save, forgets it, so the next run has it again. The pause menu's Skip tutorial skips it, as does the debug panel: what shows closes, and it goes straight to the zoom out it ends with. A passenger still waiting at Terra leaves the line while the HUD is out, unseen.
- **The zoomed map.** Only Terra and the Moon, the map zoomed in 6.5× on Terra, so the Moon orbits 13 units out, about as far as a trip across the whole map. The bus keeps its size, speed and fuel burn, so the ride costs the time, fuel and fare a trip across the whole map does.
- **Nothing orbits.** Terra and the Moon hold still on their orbits, still spinning, so the bus always finds them where they were and stays in view.
- **A clear way out.** The bus starts docked on the side of Terra facing the Moon, so the straight flight there never crosses Terra.
- **One ride.** One passenger waits at Terra, going to the Moon, always a blue one, so every tutorial looks the same. Nobody else turns up, and nobody leaves a line. Research isn't in it: the mechanic brings it once the run has started (Research).
- **The trip burns half the tank,** more than the bus burns outside the tutorial, so refuelling has a reason. The way home, through the capsule, burns three quarters of it, so the gauge drops as a trip's would and the tank never runs dry. Fuel is free at Terra and the Moon. Done or skipped, the run starts on a full tank.
- **It pays 120 credits in all,** whatever the passenger's mood: 70 from their fare and 50 from the capsule on the way home, so the first upgrade is one delivery away once it is over.
- **It opens on a call from their boss,** who tells them they are on a trial period. Until the player answers it and closes the transmission, the call notice's Answer is the one thing they can do: no clicks on the map or the bus bars, no pan or zoom.
- **Each step is a guide card** (placeholder titles; what each says is in `tutorial_cards.gd`, the calls' words in `tutorial_call.gd`), most waiting for the player to do something in the game; a card that only tells them something has a Got it button, offered on purpose and rarely.
  - **The bus**, beside it. Got it moves on. Until then, still no clicks but on the card, and no pan or zoom.
  - **The camera**, beside the bus: how to pan, by dragging with the left button or with WASD, and zoom. From here the screen takes clicks and the camera is the player's. It goes 0.8 s after the player has both panned it 8 units in all (about a quarter of a second of panning) and zoomed it by a tenth (one wheel notch), so they try each and a pointer passing the window's edge doesn't count.
  - **The pick-up**, on the waiting passenger's row once the station panel is in. It goes once they board.
  - **On board**, beside the passenger's card in the On board panel, once the panel has come in and the card has slid into it: they are on board, and their bar shows how happy they are, which makes them pay more and rate better. Got it moves on.
  - **The course**, beside the Moon. It goes once the Moon is on the route.
  - **The charge**, above the Frameshift key. It goes once the bus leaves.
  - **The snack.** Halfway to the Moon the passenger asks for a snack, and the game pauses, all but serving and the portraits, with a card beside their serve button. The game runs again once it is served.
  - **The rating.** Getting off at the Moon, once their card has filled its stars, the game pauses, all but the portraits, with a card beside them. Got it moves on.
  - **The fare.** Once their card has left the On board panel, the resource bar comes in, then a card under it. Got it moves on.
  - **Refuelling**, beside the Moon's fuel row. It goes once the tank is full.
  - **The way home**, by way of a capsule: once the tank is full, a capsule of 50 credits appears above Terra on the side of the Moon (6 units toward the Moon and 5 up the screen), holding still and staying until collected, and a card beside it says capsules sometimes drift in space and can hold all kinds of valuables, and to right click it. It goes once the waypoint is set; the player leaves on their own, collects the capsule, and the bus holds where it was. Then a card beside Terra says to right click it, and goes once the bus leaves for it. Skipped before then, the capsule goes with the HUD.
  - **Chaining stops**, above the route bar once the bus docks at Terra: holding Shift (Q in Firefox) while right clicking adds each stop to the end of the route. Got it moves on.
- **It ends on another call from their boss,** a second after the card on chaining stops goes: the player passed their trial period, and the boss unlocks the frameshift planet lock for the whole star system. The call notice's Answer is again the one thing the player can do. Both calls offer two answers that mean the same, for flavour, and either one goes on. Answering the last ends the tutorial.
- **Only what a step brings in shows.** After the call, only the bus bars; the station panel comes in with the pick-up, the On board panel once the passenger boards, and the resource bar with the fare. The station's fuel button shows from the flight to the Moon on, off until the refuelling card opens; the lab badges, the station's Research and Board all buttons and the resource bar's research points stay hidden.
- **The course holds in flight.** From the flight's start until the bus docks, the player can't change the route: no Stop, no stop taken off the route bar, no new course.
- **No planet opens** on a click through it.
- **Courses only when asked for.** Right clicks set a course only in the steps about setting one, and only to the planet the step names: no points in space, no other planet, and nothing more once it is set. On the way home, first only a waypoint, from a click within 1.5 units of the capsule, set in its very middle; then, held there, only Terra, and the drive stays warm while it waits, so Terra's course leaves at once. Once either is set it can't change, by click, Backspace or the route bar's X, so the one thing left is the Frameshift key. Through the tutorial a held right button never steers a waypoint. A stop short of where the bus is headed asks for the course again.
- **No other needs.** The snack is the only thing the passenger asks for.
- **No route changes in flight.** From leaving until the bus docks, each way, clicks on the map, Backspace and the Frameshift key do nothing, and the key never turns into Stop.
- **The zoom out.** Done or skipped, the HUD goes, then the map zooms out to the whole solar system, the planets starting to orbit as it goes, and holds there for 4 s before the bus bars come back for The Boss's first-shift call (The start), and the rest of the HUD after it. The screen takes no clicks, and the route controls, pan and zoom do nothing, until that call closes.
- Then the lines start at every planet (The start), the run's goals are given, and The Boss's first-shift call comes (The start).

## Feature hints

- **The first time the player meets a feature in play,** the game pauses with a feature hint pointing at it, until the player presses Got it; the pause menu can open over it, and closing that leaves the game paused. Each hint shows once across every run, kept beside the save; resetting the campaign, from the main menu's settings or the debug panel's Delete save, forgets them, so they show again.
- **Never during the tutorial,** which has its own cards, and never on a hidden target: a hint passed over that way isn't kept as seen, so the next meeting offers it again. Two at once show one after the other.
- **The heat zone:** the first time the passengers become uncomfortable (past 32°, where the gauge leaves green), a hint above the gauge says the star heats the bus, that passengers are getting uncomfortable and it will soon overheat, and to move away from the star to cool it (the words are in `feature_hints.gd`).
- **The goals:** after The Boss's first-shift call (The start), a hint beside the goal panel says it shows the goals that reach the promotion.
- **The jump:** the first time the player stays after a promotion, once the goal panel's jump button has shown for 1 s of play, a hint beside it says they can keep working the system as long as they like, and move to the next level from there when ready (The Boss's call has already said who stays behind). A run continued while staying offers it too, until it has been closed.
- **Quests:** the first time the player takes on a quest, once its row has slid into the goal panel, a hint beside the panel's quests says the active quests show up there.
- **The asteroid field:** the first time the bus flies into the rocks, a hint beside the bus says the rocks slow it to a crawl and every knock shakes the passengers, and to fly through a gap or go round the field.
- **Business passengers:** the first time a Business passenger waits in the dock panel, once the panel is in and their row has slid in, a hint beside their row says they ask more but pay better.
- **Returning passengers:** the first time a returning passenger waits in the dock panel, once the panel is in and their row has slid in, a hint beside their row says they gave 5 stars last time, are back happier, and will tip at the end of the trip.
- **VIP passengers:** the first time a VIP waits in the dock panel, once the panel is in and their row has slid in, a hint beside their row says they want several planets visited in order, don't wait even while the bus is docked, and take 2 seats.
- **Warp drives:** the first time the bus docks at a planet with a warp gate, once the dock panel is in, a hint beside its warp row says the planet has a warp drive, which can be used to travel quickly to other planets with one.

## Save game

- **One run is saved,** with the campaign's record beside it (Scenes and flow): how many levels are done and the run as it entered each level. Starting a level over replaces the run, after asking. The main menu's settings can reset the campaign, held to confirm like refuelling, which deletes both, the tutorial and the feature hints seen; with nothing to reset it is off. The pause menu's settings can't, since the run in play would save it again at the next planet.
- **A save from an older version of the game counts as none,** run and campaign record both, since the levels' star systems have changed names since. The tutorial and the feature hints seen are kept.
- **Nothing saves during the tutorial.** Quitting in it keeps the save from before, and the next start of Level 1 offers the tutorial again. Once it has ended, done or skipped, it is kept as done, even if the player quits in the zoom out.
- **Checkpoints at planets.** The run saves whenever something it keeps has changed while the bus waits at a planet with no stop under way: after a stop, a pick-up, a kick, research, refuelling. Never in flight, so quitting in flight loses only the flight, and a continued run always starts docked.
- **What's kept:** where each planet is on its orbit (its progress in full-speed seconds, since orbit speed changes with the bus), the bus's planet and fuel and whether its reserve tank has opened, credits, research points and ratings, researched upgrades (each by its tree and its place in it, with which layout of the trees the save was made in, so a save from before a layout changed finds its upgrades where they sit now), whether research and which stages are open, the passengers on board with their happiness, ride clock and needs, every line (who was seen, and how many not yet), who may come back, the goals' progress, the quest under way, and how many star systems are open and whether they are joined. The system the bus works in is the one its planet is in, so a run continued after a promotion still offers the jump.
- **Nothing saves through a jump.** Quitting mid-jump keeps the save from before it.
- **The Boss's pick-up** (Goals) is kept as how far it has got: not begun, the quest given, or the stargate built with The Boss on board, and then which of The Boss's goals are done. Nothing saves through the meeting at Earth, so quitting in it keeps the quest, and the meeting plays again as the run continues docked there.
- **What starts afresh:** the course, the charge, the wait until the next call, the capsules adrift, what each passenger was doing (an open request opens again at once), and the lines' clocks.
- **Continuing builds a new run first, then applies the save,** so a continued run starts from the same code as a new one.
- Only a run started from the main menu is saved, so tests and a scene run on its own never touch the save.

## Scope

- **Out for now:** more than one save slot, dialogue, positional or adaptive audio.
- **Not in temperature:** cold (nothing lies beyond Frost, so it would be an unavoidable tax on Frost trips or never felt; it waits for a system where it is a choice), a player action that cools the bus, and upgrades that change any of it.

## Not designed yet

Features we will very probably build, but that need more design work first.

- **Business passengers' own needs.** Types can also differ in what they need on board, so a Business passenger might want a sleeping pod where a Commuter wants only snacks.
- **Environment.** How space affects the bus and passengers beyond the star's heat (Temperature): a big planet's gravity slows the bus down near it.
- **Depots.** Whether fuel stays on sale at every planet.

## Open questions

- **The first stage runs out.** Its 15 upgrades, all built, cost 2,760 credits in all; the scripted player has 10 by minute 10 and 13 by minute 15, one with quick hands 12 and 14, measured with no promotion, so points (41 % unspent at minute 15) pile up with nothing to buy. A promotion at Vela's goals (minute 5 to 7) may fix it; unmeasured.
- **Lyra, Sol and the joined systems are untuned.** Their goals, fuel prices, fare multipliers and layouts are first guesses, except Lyra's goals and fares. Balance runs promoted into Lyra are towed about 1.4 times every 10 minutes, against 0.2 in Vela, and a tenth of Lyra's rides have a tow in them: a trip across the star and round its heat zone takes most of a tank, and the scripted player chases the moons round the star. Whether players run dry there too. Trips between joined systems run from 13 to about 75 units, nearly two tanks at the far end, so where to refuel starts to matter there, and fuel tanks may stop doing nothing.
- **What the joined systems are for.** Their goals promote to nothing; whether meeting them wins the game, or there is no end.
- **Who wants another system.** Once joined, a passenger's destination is any other planet, so most trips cross to another system. Whether to weigh their own system's planets higher.
- **The top band is in reach in the first stage.** In-Flight Movies, a full lounge bonus and the bus quality of the upgrades on the way pass 90 before a quick stop. The scripted player left in Vela ends a 15-minute run at a recent rating of 4.85, and promoted into Lyra it leaves at about 4.7, so the bus reaches Sol in the 4.25 band, where 45 % of passengers are Business. Whether that band should wait for a promotion. With every stage open, half of all rides get 5 stars and the recent rating ends near 4.9.
- **Serving speed barely shows once research starts.** Over a run a hand that reacts in 4 s rates within 0.05 stars of one that reacts in 0.7 s and earns the same; on a bare bus it is 0.1 stars. In-Flight Movies does most of it: its +8 is almost three seconds of an open request for free.
- **In-Flight Movies is the best upgrade by far,** at the second-lowest price: alone on a bare bus it adds 0.2 stars and 15 credits a minute, where no other first-stage upgrade adds more than 0.1 stars. Researching it first rather than last is worth 0.15 stars over a run. At +12 that was 0.26, and with the base at 64 it put a clean ride on the 5-star line, so half of all rides got 5 stars.
- **Business passengers are no trade-off,** as measured when they still turned up in Vela. They pay 1.6× and rate 0.1 stars lower than Commuters, 0.3 lower on a bare bus; leaving them behind loses 30 % of the credits and gains no rating.
- **Fuel tanks do nothing.** With fuel on sale everywhere a tank never runs low, so Fuel tank 1 and 2 change no number in a run. They matter only if some planets stop selling fuel (Not designed yet, Depots).
- **Food quality.** Bigger portions took the tiles a quality line (a happiness bonus per tier, +8 to +12) would have had. Whether one still comes, or portions are enough.
- **Fun is mostly a flat bonus.** The +8 of each applies whether or not anyone watches; only the clock depends on watching. A bonus only while watching barely shows, since happiness falls three times as fast as it climbs. Whether watching should matter more.
- **How often passengers sleep.** Too short between sleeps and a long route costs nothing, too long and the pods hardly show. Also the pods' price, since costs go by row.
- **What else the rating does.** Besides setting which types turn up: whether it gates upgrades, or is the leaderboard score.
- **The tow's price and speed.** 100 credits, which can take the credits below zero, and 0.4 units a second over the planet's speed.
- **Fuel and fare balance.** Fuel is about a twelfth of a fare per unit, and under 2 % of what a run earns, so where to refuel is no decision. At five times the price it is 10 % of earnings and slows research by about one upgrade in ten minutes; the tow's price would have to rise with it.
- **Research points and rating.** A furious passenger is worth as much research as a happy one. Whether the rating should scale it (say, a point only from 3 stars up).
- **Seats and waiting passengers.** 4 seats and up to 3 waiting per planet, from the prototype. With 6 seats or more a bus that keeps to two destinations leaves with one or two seats empty; 4 waiting delivers about a tenth more, and fills a bus that takes everyone with more destinations than it can serve well.
- **Temperature's numbers** are guesses, tuned by hand. Unmeasured: how much a pass clipping the hot zone adds, and what a trip into Ember and out costs (meant to be 4 to 6°).
- **Temperature's cost.** Over 8 seeds of 10 minutes it costs the scripted player about 8 % of deliveries and a fifth of the credits, and 3.64 stars become 3.46, with no overheats. Part of that is tows, about once in 16 minutes: going to Ember on the far side of the star, it circles just outside the heat zone chasing Ember, which takes about 40 units, and its fuel margin counts only the straight distance.
- **Softening shocks.** An upgrade could soften the kick's shock, or what a stop costs.

UI questions are in `docs/ui.md`.

## Online

Online services run on Talo (`docs/online.md`), picked over Firestore in issue #5: analytics events, stats and play sessions now, leaderboards once there's a score. Nothing is tracked yet. Uploaded replays (ghosts of other players' runs) don't fit Talo; a player's own ghost can stay in `user://`.
