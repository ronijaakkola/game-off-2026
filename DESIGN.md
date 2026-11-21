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
3. **Charge.** The player holds the Frameshift key to charge the drive, and the bus leaves once it is charged. Just after docking the drive is still warm for a while, and the charge starts from the warmth left and builds faster. Until then the route can still change.
4. **Fly.** The bus flies the route stop by stop. The player can reroute at any time.
5. **Arrive.** At a planet, passengers going there get off, pay by their mood, rate the ride and earn a research point.
6. **Refuel and research.** Docked, the player buys fuel, and at a planet with a lab researches upgrades from every open tree.

## The solar system

- A star and four planets on circular orbits, one with a moon and one with rings. The Moon counts as a planet for passengers, fuel and docking.
- Planets orbit at 0.34 (Frost) to 0.47 (Ember) units a second; the Moon moves at up to about 0.87 as it circles Terra. Every planet moves at under 40 % of the bus's speed, so the bus catches one without a long chase.
- Ember and Frost are 12 to 23 units apart as they orbit.
- **The game runs at 0.9 of real time:** the bus, the planets, the passengers and everything on screen alike, so a ride plays out the same and only takes a tenth longer to play. Every number here is in the game's own seconds.

### Star systems

- **Three star systems,** in the order the player reaches them: Sol (the solar system above), Lyra and Draco. Each is a star with four planets and a moon, and every planet in each moves at under 40 % of the bus's speed. More can be added; the last one in the order is the one whose promotion joins them.
- **They all share one space,** 43 to 47 units apart from star to star, so the bus can fly between them once they are joined: the gap between the outer orbits of two systems is 13 to 14 units, well inside a tank's 40.
- **One system at a time.** Until they are joined, the bus works in one system. Only its planets show and have lines, and the camera can't pan past its edge (18 units from Sol's star, 15 from Lyra's, 16 from Draco's).
- **A promotion opens the next system** (Goals). The dock panel then offers to jump there, from any planet, only with nobody on board and no stop under way, so no passenger is left going to a planet behind them. There is no going back.
- **The jump plays as a scene change,** so the player never sees two systems at once and finding out at the end that they share one space is a surprise. The bus turns toward the next system and winds up for 1.3 s, then frameshifts out as the tow ship does; the screen goes black, and the bus frameshifts in 2 units off the new system's home planet (Verdance, Hollow) and flies in to dock there. Its course is gone and it keeps its fuel. Lines start at the new system's planets, empty but for the starting passengers, and the new system's goals are given.
- **The promotion in the last system joins them all.** Every system shows, the camera may roam over all of them and zoom out to 110, lines start at every planet that had none, and a passenger may want any planet in any system.
- Each system's planets are lit by its own star, and the bus by the star nearest it.
- **Time slows unless the bus frameshifts.** The planets orbit at full speed only while the bus flies a course, towed or not. They slow to half of it once it starts parking at a planet, comes to rest in space, or starts coasting to a stop after the course is cleared or the tank runs dry, and stay that slow while it waits or charges. A trip takes far longer than it looks, and the time spent stopped is wound back. Half speed keeps the system moving while docked, so a long stop still costs some of a route's shape. They take about 0.6 s to slow and 0.6 s to get going again, so nothing jumps. Their spin and the passengers' clocks keep running.

## Route and flight

- **Stops.** A route is an ordered list of stops, each a planet or a point in space. The bus docks at every planet on the route and passes through points in space. It holds still at a point in space that ends the route.
- **A planet stop** is the planet's near side, so the bus chases a moving planet.
- **Setting a course** works as in a real-time strategy game: a right click sets the route to the one stop under the pointer, and with the queue key held adds it to the end, so the stops come in the order clicked. The planet the route already ends at isn't added again straight after itself.
- **Steering by hand.** A point in space set with the right button follows the pointer for as long as the button stays down, every frame, so the bus chases it. Where the bus reaches it, as when the pointer rests, it stops; moving the pointer 0.3 units on sets a new point, which leaves at once while the drive is still warm from stopping (1 s) and otherwise waits for a charge.
- **Round trips.** A planet earlier on the route can be added again, and so can the planet the bus is docked at once the route has a stop.
- **The queue key** is Shift or Q, both in every browser. Firefox opens its own context menu on Shift + right-click and a page can't stop it, so in Firefox the hints name Q. Not Ctrl: a page can't block Ctrl+W, and W pans the camera.
- **Speed.** The bus flies at a top speed of 1.2 units a second, speeding up as it leaves and slowing as it nears a planet.
- **Charge.** Setting a course never leaves a planet by itself, so planning a route and leaving are separate decisions. With the drive cold, the player charges it by holding the Frameshift key for 3 s. The bus turns toward its next stop meanwhile.
- **Warm at a planet.** Docking at a planet, the drive is warm, with a route still ahead or not, so the player can reroute and still leave warm. It holds while the passengers getting off get off, then cools over 4 s (6 s with Warmer drive), which picking someone up and refuelling spend; research pauses the game and the cooling with it, but researching an upgrade makes the drive cold at once, so a stop spent on research is no quick stop. Opening the research screen and closing it costs nothing. Holding the Frameshift key while warm starts the charge from the warmth left, building 1.5 times as fast, so a quick stop takes a short hold. Letting go of it drains the charge four times as fast as it builds (0.75 s from full), and the drive is cold from then on: held again, it charges at the normal speed. The bus never leaves by itself. Towed in, the drive is cold.
- The reward is for leaving quickly; a queued route only makes that easier. A cold drive costs the passengers riding on (Happiness).
- **Letting go** drains the charge twice as fast as it built and keeps the course; holding again charges from what is left. Cancelling keeps the bus docked.
- **Rerouting in flight is free:** no charge and no extra fuel beyond the distance it adds.
- **Short stops in space.** A course set from a stop in space within 1 s of coming to rest leaves at once, so a short stop costs nothing. After that the drive is cold and the bus waits for a charge, as at a planet; cancelling leaves it holding in space.
- **Parking.** Near a planet the bus glides the last half unit in and swings side-on, door toward the planet. It has docked only once it is parked, and only then can the drive charge.
- **Clearing the route** stops a charging drive, and makes a flying bus coast to a stop.

## Fuel

- **Tank.** A full tank holds 100 fuel. The bus burns 2.5 per unit flown, so a tank flies 40 units: about one trip from Ember to Frost and back.
- **Only flying burns fuel.** Charging, parking and floating while docked don't.
- **Prices.** For now every planet sells fuel, each at its own price per unit. A full tank from empty costs 6 credits at Giant, 8 at Frost, 10 at Ember, 12 at Terra and 15 at the Moon. A planet can be set to sell none; none is yet.
- **Refuelling is a hold.** While the bus is docked or charging at the planet, holding the button pumps fuel from 5.1 a second, speeding up to 25.5 a second over 1.5 s, so a full tank takes about 4.7 s; Faster pumps makes both twice as fast. It stops when the player lets go, the tank is full or the credits run out, and it doesn't run while the frameshift is held: charging and refuelling take turns, since a player with only a mouse can hold one button at a time.
- **The bill** is paid when the pump stops, not as fuel flows: the whole credits it adds up to come off at once, and what is left under a credit carries over to the next refuel.
- **Fuel is cheap next to fares** for now: about 0.25 credits of fuel per unit flown, against fares of 3 per unit.
- **An empty tank at a planet** (only the debug panel causes it) keeps the bus docked: a charge under way stops and no course can be set until it refuels.

### Running dry and the tow

- The moment the tank runs dry in flight, the route is cleared, the bus coasts to a stop, and everyone on board takes a −15 shock.
- Nothing comes by itself: the player requests a tow, and pays for it then.
- **The tow costs 100 credits.** With fewer, the credits go below zero and the player owes the rest. A full tank costs 6 to 15, so a tow is many times the price of refuelling in time.
- A tow ship flies out from the nearest planet, hitches on and leads the bus there. It flies 0.4 units a second faster than that planet moves, up to the bus's top speed, so the tow always catches its planet.
- A tow is slow, so happiness suffers on the way.
- The player can't set, change or cancel a course from running dry until the bus has docked.
- The bus docks as usual (a stop, with passengers getting off) **with a full tank**, so a tow never leaves the player stuck at a planet without fuel or the credits for it.

## Temperature

The star is something to steer around: flying near it heats the bus, and too near for too long overheats it, which stops it. How close and how long is a skill the player learns.

- **Degrees.** The bus rests at 21° and overheats at 60°. A new run and a continued one start at 21°; it isn't saved, since a run saves only at a planet and of those only Ember is in the heat zone.
- **The heat zone** is everything within 6.3 units of the star's centre. It reaches past Ember's orbit (5.2), so every trip to Ember costs a little, and stays inside 6.6, the closest the Moon comes, so Terra and the Moon are clear of it.
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
- **Too hot is uncomfortable.** Above 32°, the top of the gauge's green band, everyone on board slowly loses happiness: what the bus can lift them to drops 0.25 a second, down to 3 below at most, and once the temperature is back in the band it comes back 1 a second. It is a nudge the player can undo, not a cost that stays with the ride: a clean ride on a bare bus (76) keeps its four stars at the worst of it. It counts through a cooldown, since the bus is hot then (about 6 s above 32°): with the −5 scare, an overheat takes a clean bare ride under four stars for about 2 s, and all of it is gone about 9 s after. Not while the temperature is exempt. Frustration's floor of 50 still holds.
- **Overheating scares everyone on board, −5,** and costs no credits. The time is most of the cost: the cooldown and the charge are about 11 s on a ride of about 20 s, which takes a passenger's on-time bonus and more.
- **Exempt.** The temperature holds, and can't overheat, during the tutorial until the zoom out is over (the zoomed map scales distances to the star), and during a tow, whose route the player has no say in.
- **Balance runs steer round it.** The scripted player decides only at docks, so whenever the straight way to the planet ahead passes within 0.5 of the hot zone, now or as the planet moves, it puts a checkpoint beyond the heat zone's edge. Going round just outside the hot zone overheats: half a circle at 5.0 units adds about 25°. After an overheat it sets the same course again once it has cooled.

## Passengers

### Waiting

- Each planet gets a new passenger every 12 to 30 s, up to 3 waiting there and 7 at all the planets together, or 30 once the star systems are joined, about 2 to a planet, so the end game is busier; 30 is a guess, not measured yet. Lines build slowly and some are short: the scripted player finds nobody waiting at about a quarter of its stops and 1.4 on average, so where to go next is worth looking up. Who they are is under Who turns up.
- Nobody new turns up at the planet the bus is docked at: its clock holds until the bus leaves, so waiting there gains nothing.
- Happiness holds while they wait.
- **Station waiting lounge.** Someone picked up gets +1 on their target for every 10 s they waited, up to +5 at 50 s, for their whole ride. A wait counts while the planet's clock runs, so waiting docked there builds none. +5 at most keeps In-Flight Movies alone short of 5 stars (84 + 5 = 89).
- **The start.** A new run starts with the tutorial (Tutorial) while the player hasn't been through it, and its lines start after it. Once they start, the bus is empty, with 2 passengers waiting at the planet it is docked at and 1 at every other planet, so the first stop has someone to pick up and the first route somewhere to go. A New game after the tutorial starts docked at Terra, where the tutorial does, and the run after the tutorial at the Moon, where it ends; a scene run on its own starts docked at Ember.

### Who turns up

- **Decided when first seen.** A waiting passenger is only a count until the player first sees the line, by docking at the planet or opening it. Then each undecided passenger in it gets a destination, a race and a type, one after another, and keeps them. Lines fill about 40 s before the bus arrives, so deciding late is what lets a line answer the bus as it is now.
- Anything that shows a line from afar counts as seeing it. The waiting markers show only a count, so they don't; the station cameras show who waits, so pointing at a planet with them does.
- **Destination** is a roll among the other planets, each as likely as the next. Only Timetables makes a match likelier: with it, a planet someone already in the line is going to is 3× as likely.
- **No more than two** in a line go to the same planet, so a line always holds a choice.
- Who is on board doesn't count, with Timetables or without: passengers going the same way are something the player researches for, not a given.
- Destinations aren't dealt from a bag: dealing without repeats makes two going the same way rarer than chance does.
- **Race** is dealt from one shuffled bag of six, two of each race, so no race stays away for long.
- **Type** goes by the band the recent rating is in (Rating). Upgrades aren't read: a bare bus sits between 3 and 4 stars, by how clean its rides are, and only comfort upgrades take it past 4.

| Recent rating | Commuter | Business |
|---|---|---|
| Under 3.5 | 97 % | 3 % |
| 3.5 to 4.25 | 92 % | 8 % |
| 4.25 and up | 55 % | 45 % |

- **No Business passenger turns up until the player has delivered 10 passengers.** As the tenth gets off, the first one joins the line at that planet, whatever the limit on everyone waiting, so the player meets them there; were that line full, the next passenger decided anywhere is the one. After that they are rare through the first stage: one more in about half of all runs before 30 are delivered.
- **A full line has a Commuter:** at most one Business passenger in a line in the lowest band, two above it.
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
- **Fare** is 3 credits per unit times the type's multiplier.
- Both are set when the passenger is decided (Who turns up), from where the planets are then.
- A faster bus gets passengers there before they expect it. Speed upgrades make passengers happier rather than more demanding.
- **Payment** on getting off goes by mood: happy pays 1.2× the fare, okay 1×, annoyed 0.5×, furious nothing. With the Tip jar, happy pays 1.2× that again.

### Happiness

Happiness replaced patience, so a long ride isn't the only thing that matters: what a passenger needs, and how well the bus gives it, does too.

- Each passenger on board has a happiness from 0 to 100.
- **It starts at the target,** the most the bus can give them: set as they take their seat, and again as the bus leaves, so comfort researched at that stop counts. A quick ride keeps them there. Starting lower and climbing made a short ride end before they got there, so delivering quickly scored worse than taking long.
- A shock before the bus leaves stays: they start that much under the target.
- Every frame it slides toward the **target**, falling at 3 a second and climbing at 1. It never jumps, and bad moments take a while to wear off.
- **Mood:** happy from 70, okay from 50, annoyed from 25, furious below.
- **Rating** on getting off: happiness ÷ 20, to the nearest whole star.
- **It holds** until the bus leaves the planet they boarded at, and while the bus parks.
- **Docked,** it falls at a tenth of its speed while the drive is warm, so a quick stop (boarding, refuelling) barely costs anyone. Once the drive goes cold it falls at half its speed, and their clock runs at half speed, until the bus leaves: a stop that drags on costs those riding on. Those who boarded there hold anyway.
- **A quick stop is admired.** When the bus leaves a planet on a charge started warm and never let go, everyone on board gains 3 happiness at once, and as much more of what they can reach for the rest of their ride, up to 6 in all. It rewards the player who makes them: over 8 seeds a player who always does rates 3.84 against 3.69 without it, one who misses 40 % of them 3.62 against 3.53, and one who never does gains nothing. For the first it also brings the first 5-star rides of the first stage, about one in twenty.

**The target** is worked out fresh every frame:

- 64 for a bus that does its job, plus the comfort bonuses and the lounge's (no higher than 100 together), less the heat's discomfort (Temperature), plus timing, less frustration.
- While a request is open, the target is 0, from 1.5 s of flying after it opened: serving it at once costs nothing. Ignoring a request must always cost more than serving it.
- While anything is serving the request, happiness holds rather than falling, since they can see it coming.

**Timing** is one line along the ride:

- +12 if they arrive in the direct trip time, falling to 0 at the expected time, and no lower: past it, frustration takes over.
- It runs on the passenger's own **clock**: real time in flight, a tenth of it while docked (half once the drive is cold), and slower while they sleep or watch a show.
- **Leeway.** While happiness is 80 or more, every second of their clock adds half a second to the time they expect, up to half a trip time.
- Getting there sooner (routing, speed, never needing a tow) is the main way to beat timing. Comfort only buys a little.

**Frustration** takes happiness off the most the bus can lift them to. It never drains them to 0: the bus can still lift them up to what is left, with food and comfort, so serving a frustrated passenger always pays.

- **Stops.** Every planet the bus docks at on their ride before theirs is a stop on the way; the planet they boarded at counts only once the bus has left it. Each type tolerates a number of them calmly, and each stop past that costs 15. Delivering the demanding ones first is the routing puzzle.
- **A late ride** costs 1 a second of their clock past the expected time, with their leeway: steady, never faster, so a late ride never runs away from the player.
- **The floor.** Frustration never takes them under 50 (okay, three stars, the full fare). A request open still heads for 0.
- *(playtest)* Every stop counts for now. Counting only detours, a stop where going there and on is more than 1.25 times the straight way from where the bus last left, is one switch away (`RideProgress.ONLY_DETOURS`), for if serving several passengers on one route feels punished.
- They say why: a stop past their tolerance shows one of their type's lines about it at once (“Another stop?!”), and so does the moment the ride runs late (“I’m late for a meeting”), unless a request, a sleep, a show or a meal holds their line. While frustrated, their idle lines are those, for whichever costs them more.

**Shocks** change happiness at once and leave the target alone, so it climbs back at 1 a second:

| Shock | Amount | Why |
|---|---|---|
| Someone is kicked | −25 to everyone else | Otherwise kicking the angriest passenger would raise the average for free |
| The bus runs out of fuel | −15 to everyone | Less than a kick, since the wait and the tow cost time on top |
| The bus overheats | −5 to everyone | Small, since the cooldown and the charge cost time on top, and there is no tow to pay |
| Arriving unserved | −10 to them, before they rate | A request open for 5 s or more, not counting parking, and counting time docked at a stop on the way. One asked just before arriving, or during parking, is forgiven |
| Woken by a shock | a further −10 | Every shock wakes anyone asleep, so a kick or a tow is worse on a bus that sleeps |

There are no good shocks: one would fall away at 3 a second, gone in seconds.

**What a bus can reach.** A bare bus gives 4 stars for a clean ride and 3 otherwise: a direct trip with every request served at once ends where it started, at 64 + 12 = 76, and 4 stars takes 70, so it takes about two seconds of an open request near the end, or arriving a fair bit late, to cost the star. At 60 a single second did, and the rating turned on slips too small to see. Over many rides a bare bus averages about 3.7: 3.8 with quick hands, 3.3 with slow ones and a full bus. Five stars takes about 90, which only the comfort upgrades reach. A fully upgraded bus sits at about 100 before timing.

### Needs and serving

- Each passenger type has a few needs. The Commuter's are a snack and a drink, both food.
- A need asks again a random while after the last one's served activity ends: 8 to 20 s for a snack, 10 to 25 s for a drink. An open one is a **request**. The times are short because rides are (about 20 s): half of all rides should hold a request, or serving decides nothing and the food upgrades answer nothing.
- **One request at a time.** The other needs' timers wait while one is open, so serving one doesn't set off the rest.
- **Not everyone asks at once.** The bus holds two fewer open requests than it has seats, and at least one: 2 with 4 seats, 3 with 5. A need that comes up past that waits until one is served.
- **A request never expires.** One that did would make ignoring a passenger cheaper than serving them.
- **Serving is a hold,** like refuelling: holding the button serves the request over 1.2 s (0.8 s with Quick hands), and letting go keeps what was served so far.
- **Stops are quiet.** No request opens while the bus is docked or parking, and the needs' timers run as slowly as the clock while docked. A request already open when the bus stops stays open, and the player or an amenity can serve it there; one going with a passenger who gets off goes with them.
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

- The player can kick a passenger off the bus at once, wherever it is.
- Their seat frees up, they pay nothing, rate nothing and earn no research point, and everyone left on board takes the kick's shock.
- A passenger who is getting off can't be kicked.

### Passenger types

- A type is data: fare multiplier, slack, needs, and the lines and names it uses.
- There are two, the Commuter and Business.
- **Business** pays more and is harder to please, through tighter slack and more frequent requests, never a lower starting happiness. On a bare bus a near-direct trip with requests served within a few seconds gets three stars and the full fare; four stars takes a direct trip with every request served at once, or upgrades.
- Business pays 1.6× with a slack of 1.2, tolerates 2 stops on the way, and asks for the Commuter's snack and drink at 0.6 of the time between requests.
- The Commuter's slack stays loose (1.5) and it tolerates 4 stops: it is the passenger that makes a route with several stops work.
- The player can tell a Business passenger from a Commuter wherever they pick passengers and on board.
- Race and type are independent: any race can be any type.

### Races and research points

- Every passenger is one of three races, picked at random: blue, orange or green.
- Getting off at their destination earns one **research point,** whatever their race or rating.
- **Research points are one kind.** Every tree takes them, so race never decides what the player can research, and the player keeps track of one count, not three against three trees.
- A race must read without colour too, by the build of its head (`docs/ui.md`): with red-green colour blindness, orange and green come close.
- Skin colour never changes with mood, since it is what shows the race.

### Rating

- The player's **average rating** is the mean of every rating so far.
- It changes nothing yet.
- The **recent rating** is the mean of the last 10 ratings. It sets which types turn up (Who turns up), it is what a rating goal reads (Goals), and it is the rating the player is shown, so the stars, the goal and what they explain are one number.
- The star rating says only that a higher rating brings more Business passengers: no bands, no odds.
- *(not built)* The player is told the first time the recent rating reaches a new band, and not again on coming back to it.

## Research

Upgrades for the bus, bought with credits and research points.

- **Research trees aren't tied to planets.** Each is the upgrades for one part of the bus, linked by what each needs first.
- **Researching happens only while the bus is docked or charging at a planet with a lab,** as refuelling does, and there the player researches from every tree.
- **Research opens a part at a time,** so the first research screen isn't a wall of upgrades. Each tree splits into three stages by row: rows 1 and 2, rows 3 and 4, and the rest. An upgrade is open once its tree and its stage both are, and the research screen shows nothing that isn't.
- **The mechanic opens it, with a call** as a passenger calls: a transmission that only says something, with two answers that mean the same; left ringing for 10 s of play, it opens by itself. What it brings opens once the player closes it.
  - **In Sol the trees open one at a time,** on their first stage: Performance once the player can pay for one of its top upgrades (120 credits and 2 points, about one delivery after the tutorial), Planets at 7 deliveries in the run and Comfort at 14. Until Performance opens there is nothing to research: no lab badges and no Research button. Over 8 seeds the scripted player earns 258 credits a minute and rates 3.98 against 265 and 4.02 with every tree open from the start, and has as many upgrades by minute 10; at 4 and 9 deliveries it is no better.
  - **Each system after Sol opens the next stage in every tree,** with a call once the bus works there, so the second opens on arriving in Lyra and the third in Draco. A promotion opens no research, and nor does joining the systems.
  - **Nobody else calls over it.** It rings only when no other transmission is open or ringing, and not during a stop or a jump; passengers' calls wait while it rings.
- **The research guide.** After the mechanic's first call, guide cards show the player how to research, the game running: beside the badge of the nearest planet with a lab until the bus docks at one; on the station's Research button until the research screen opens (back to the badge if the bus leaves first); in the screen, beside its title with a Got it button, beside Fuel tank 1, or the first upgrade the player can research, until one is researched, and on the close button until it closes. Closing the screen early ends it. It shows once, as a feature hint does (Feature hints), and only in a run the main menu started.
- **Every other call that opens research leaves a reminder,** so the player goes to the lab: a guide card saying what is new (a tree's upgrades, or new ones in every tree) beside the nearest lab's badge, and on the station's Research button once the bus docks at a lab, with a Got it button. It goes as the research screen opens or on Got it, and shows in every run, every time; a call while one shows replaces it. While the research guide shows, a call leaves none.
- **The game is paused** while the player researches.
- **An upgrade** has a cost in credits and research points.
- It needs *one* of the upgrades it lists, from the same tree, and its stage open: each is a path to it. One that lists none needs only its stage.
- Each is researched once. A bigger step of the same thing is its own upgrade after it (Tank I, then Tank II).
- Once researched it puts modifiers on the bus's stats, gives it traits, or both.

An upgrade is in one of six states:

| State | When |
|---|---|
| Shut | Its tree or its stage isn't open. The research screen leaves it out |
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
| Serving speed | 1 | 0.1 | How fast the player serves by hand, as a multiple of the 1.2 s hold |

- A continued run researches its saved upgrades again on load, so their modifiers and traits come from the same place as in play (Save game).

### Traits

- A **trait** is a feature the bus either has or doesn't. The feature shows or works only while it does.
- Two upgrades can give the same trait; it stays until both take it back.
- **Waiting markers:** how many wait at each planet shows on the map. Without them, the player finds out by opening a planet.
- **Station cameras:** with the waiting markers, pointing at a planet shows who waits there and where each is going.
- **Fuel forecast:** how much of the tank the whole course burns, and each leg of it, shows on the route. It counts the straight legs as everything is now, short of each planet by where the bus starts to park, so it is an estimate.
- The comfort and food traits: Pillows, Sleeping pods, In-Flight Movies, Space Invaders, Food Dispenser, Waiter Droids.
- The station traits: Station waiting lounge (Waiting), Timetables (Who turns up), Tip jar (Payment) and Free station coffee: someone picked up waits 1.5× as long for the first request of each need.

### The trees

There are three trees, all paid for with the same research points. Frost, Terra and Giant have a lab; the rest have none.

- They branch and join like talent trees: an early upgrade opens more than one, and the last rows hold upgrades that either of two branches reaches. An upgrade can need nothing even below the top row, open once its stage is. Only a tree or a stage that isn't open hides an upgrade; none is marked hidden.
- **Costs come in levels,** the same in every tree. The first stage has two: 120 credits and 2 points on its first row, 240 and 4 on its second. After it come 300 and 4, 550 and 7, 800 and 10, and 1,100 and 14. Each upgrade has its own level, which usually rises down the tree but needn't match its row: Express service on row 5 costs 800 and 10, Station cameras on row 3 costs 300 and 4. Credits come in at about 200 a minute and research points at about 3.9, so in the first stage credits are what the player waits for. At 150 and 300 the scripted player had 8 of the stage's upgrades by minute 10, against 10 now. Much cheaper in credits, and fares, moods and Business passengers stop mattering.
- An upgrade that isn't implemented says so on its card and changes nothing when researched.

"A ← B" means A needs B; "A ← B or C" means either one opens it.

- **Blue** (performance). Speed 1 and Fuel tank 1 at the top. Warmer drive and Speed 2 ← Speed 1; Speed 3 ← Speed 2. Fuel forecast, Faster pumps and Fuel tank 2 ← Fuel tank 1. Pit crew ← Faster pumps. How is my driving? ← Warmer drive or Speed 2. Efficient burn ← Fuel forecast or Fuel tank 2. Tow loyalty card ← Pit crew or Fuel tank 2. Slingshot ← Warmer drive. Solar fuel ← Fuel tank 2 or Efficient burn. Last row: Warp gate ← Efficient burn, Solar fuel or Slingshot.
  - Speed is +10 % top speed a step, Fuel tank +25 % a step, Fuel forecast gives its trait, Warmer drive +50 % warm time, Faster pumps +100 % pump speed.
  - *(not built)* Pit crew, How is my driving?, Efficient burn, Tow loyalty card, Solar fuel, Slingshot, Warp gate.
- **Green** (the planets). Door chime and Station waiting lounge at the top. Tip jar and Station cameras ← Door chime; Honk ← Tip jar; Passenger happiness survey ← Honk. Free station coffee, Timetables and Business lounge ← Station waiting lounge. Destination sign ← Timetables; Passenger loyalty program ← Destination sign. Remote terminal ← Station cameras or Business lounge; Research grant ← Remote terminal, alone on the last row. Bottomless complaints box ← Station cameras or Passenger happiness survey; Express service ← Passenger loyalty program or Business lounge.
  - Door chime gives the waiting markers, Station cameras the station cameras; Station waiting lounge, Tip jar, Free station coffee and Timetables their traits.
  - *(not built)* The other nine.
- **Orange** (comfort). Extra seat I, Pillows and Bigger portions I at the top. Extra seat II ← Extra seat I; Extra seats III ← Extra seat II (+1, +1, then +2 seats). In-Flight Movies ← Pillows or Bigger portions I; Space Invaders ← In-Flight Movies. Sleeping pods ← Pillows. Quick hands and Bigger portions II ← Bigger portions I. Airlock ← Space Invaders or Bigger portions II. Food Dispenser ← Quick hands or Bigger portions II; Waiter Droids ← Food Dispenser. Karaoke ← Space Invaders. Last row: Time dilation cabin ← Sleeping pods or Extra seats III. Bigger portions I and II are +50 % portion size each, 2× in all; Quick hands is +50 % serving speed.
  - *(not built)* Airlock, Karaoke, Time dilation cabin. The rest is implemented.

## Goals

- **Several at once.** The player can have any number of goals; each counts from when it is given, not from the start of the run.
- **A milestone** is done once and stays done: deliver 50 passengers. Kicked passengers don't count.
- **A standing goal** is met or not as things stand, and is never done: keep a 4.0 rating. It isn't met until a set number of rides are rated (at least 1), so one lucky first ride doesn't meet it. Dropping below makes it unmet, not failed.
- **A rating goal reads the recent rating,** not the all-time average. On the average the first rides on a bare bus weigh on it for the whole run: a player who takes everyone and serves slowly then met a 3.5 goal in 3 runs of 8 within 15 minutes, with every first-stage upgrade researched. On the recent rating every kind of player meets it.
- **A quest** is something one passenger asks for mid-ride, for a reward. It is tracked apart from the goals a promotion takes, so a quest under way or failed never stands in the way of all met.
- **The call.** While the bus flies, a passenger on board calls: the first once the player has delivered 15 passengers and no sooner than 30 s into a run, the next 75 to 120 s after the last call or quest ended. Quests are an event, not a constant: the pausing transmission wears thin if it comes all the time. The scripted player gets one call before both starting goals are met, and a second only when the rating goal takes long.
- **Anyone on board can call,** whatever their type.
- **One at a time.** Nobody calls while a call rings or a quest is under way, and the wait until the next call starts only once that one has ended. Nobody calls in the first 2 s of a flight, while asleep, or within 6 s of getting off.
- **Answering** opens their transmission, with what they ask and the reward. The quest is worked out then, from where everything is.
- **Declining costs the caller 5 happiness,** as a shock, and so does leaving the call unanswered until the bus reaches a planet or is towed, so ignoring a call is never better than saying no. A call whose caller leaves the bus first just ends.
- **A done quest pays** 30 credits and 2 research points, on top of the delivery.
- **A failed quest costs the caller 15 happiness,** as a shock, if they still ride: more than declining, or accepting and ignoring it would beat saying no. When a kick fails it, the kick's shock is the cost.
- **Express.** The caller changes their mind and wants another planet to be the bus's next stop: one that isn't where they were going, where they boarded, or on the route, so it is always a detour for everyone else. Accepting changes their destination. Their timing starts again from there, with the direct trip from where the bus is and the type's slack, and their fare is the new trip's when that is more.
  - It is done when they get off there, and fails when the bus docks at any other planet first, by a tow as much as by a course, or when they are kicked. Points in space are no stop.
  - There is no clock: a time limit didn't feel good in play, and the passenger's own timing already rewards getting there soon.
- *(not built)* **Photo stop:** hold still in space near a planet. **Pick up my friend:** fetch a named passenger at another planet and deliver both.
- Two older quest goals are built but nothing gives them: deliver one passenger, and fly one past a planet (the bus comes within 3 units of its surface in flight, having been out of reach since they boarded).
- **Balance runs answer calls** by the scripted player's policy: they take every quest unless told to decline, ignore or switch off calls, or to decline a detour past a set length, and fly straight to an express quest's planet.
- **All met** means every milestone done and every standing goal holding.
- **A promotion** comes once every goal it takes is met and still is 1.5 s later, so the player sees them ticked. The goals go, and the next star system opens (Star systems); its research comes with the mechanic once the bus is there (Research). The debug panel's Promote gives one at once, and its Complete system also jumps to the next system at once. Balance runs are never promoted, so they play on the first stage throughout, with every tree open unless told to have the mechanic open them.
- **Each star system gives its own two goals** when the bus arrives: deliver 20 and keep 3.5 in Sol, 40 and 3.8 in Lyra, 50 and 4.0 in Draco, and 60 and 4.0 once the systems are joined. Lyra's and Draco's numbers are guesses, not measured yet.
- **A run starts with Sol's two goals:** deliver 20 passengers, and keep a 3.5 rating. 3.5 is under what a bare bus averages (3.7), so it is met about when the deliveries are: the scripted player has both after about 5 minutes, and one who takes everyone and serves slowly after about 7. A higher target shuts that player out: they end a run near 3.6.
- **The run ends** once all the goals have been met for 5 s of play, still met then: The Boss calls with the next job, in another star system. Left unanswered for 10 s of play while the call notice shows, the call opens by itself, and The Boss opens annoyed, telling the player to pick up. Both answers mean the same, and either shows that the next level isn't there yet; the run goes on. While a passenger's call rings The Boss waits for it, and nobody calls while The Boss's call rings. Once a session: a continued run calls again.
- *(not built)* A temporary lose while the loop is tuned. **Lose:** the happiness score, the average happiness of everyone on board, stays at 0 for 20 s; the countdown pauses while the bus is empty.

## Controls

| Input | Action |
|---|---|
| Left click a planet or the bus | Open it. One thing is open at a time. Where the bus and a planet overlap, whichever centre is nearer the pointer opens |
| Left click the open thing, or empty space | Close it |
| Right click a planet or empty space | Set the route to it: the planet, or a point in space (Route and flight) |
| Shift or Q + right click | Add it to the end of the route |
| Hold the right button on empty space | The point in space follows the pointer until let go, to steer by hand |
| Backspace or Delete | Take the last stop off the route |
| The X on a stop in the route bar | Take that stop off the route |
| W A S D, arrow keys, or the pointer at a window edge | Pan the camera. A pointer that reaches the edge within 0.3 s of being over a panel waits 0.4 s there before it pans, so overshooting a panel's button doesn't. A setting turns edge pan off |
| Hold the middle mouse button and move | Drag the camera: the point under the pointer when the button went down stays under it. The drag goes on past the window edge, and edge pan stays out of it |
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
main menu ──Play / Continue / New game──▶ solar system ──Esc / pause button──▶ pause menu ──Main menu──▶ main menu
    │                                          │
    └──Settings──▶ settings panel ◀──────────Settings
```

- The game is one scene, the solar system, which holds every star system. A new run opens on the tutorial's zoomed map (Tutorial) until the player has been through it.
- Pausing stops the game; music keeps playing. The pause menu also opens when the player leaves browser fullscreen.
- **The pause button** opens the pause menu as Esc does, wherever Esc would, so a player in browser fullscreen, where Esc never reaches the game, can still pause.
- **A transmission** pauses the game until the player answers it. Closing the pause menu over one leaves the game paused.
- **A caller's voice:** each race has its own set of short recorded clips (`game/transmissions/voice/`), strung together while the text types out. A race with no clips yet is silent. Every caller of a race has a pitch of their own, fixed by their name. The voice lab, from the debug panel on the main menu, is where the delivery is tuned.
- **Settings:** Master, Music and SFX volume, Reduce motion, and Edge pan (on by default). They are saved across sessions.
- On the web a title card comes before the main menu, and its click starts the music (`docs/web-constraints.md`, Audio).

## Tutorial

- **A new run starts with it until the player has been through it once,** done or skipped; after that New game starts without it, as does a continued run. Whether they have is kept beside the save and outlives the run; deleting the save data, from the main menu's settings or the debug panel's Delete save, forgets it, so the next run has it again. The pause menu's Skip tutorial skips it, as does the debug panel: what shows closes, and it goes straight to the zoom out it ends with. A passenger still waiting at Terra leaves the line while the HUD is out, unseen.
- **The zoomed map.** Only Terra and the Moon, the map zoomed in 6.5× on Terra, so the Moon orbits 13 units out, about as far as a trip across the whole map. The bus keeps its size, speed and fuel burn, so the ride costs the time, fuel and fare a trip across the whole map does.
- **Nothing orbits.** Terra and the Moon hold still on their orbits, still spinning, so the bus always finds them where they were and stays in view.
- **A clear way out.** The bus starts docked on the side of Terra facing the Moon, so the straight flight there never crosses Terra.
- **One ride.** One passenger waits at Terra, going to the Moon, always a blue one, so every tutorial looks the same. Nobody else turns up, and nobody leaves a line. Research isn't in it: the mechanic brings it once the run has started (Research).
- **The trip burns half the tank,** more than the bus burns outside the tutorial, so refuelling has a reason. Fuel is free at Terra and the Moon. Done or skipped, the run starts on a full tank.
- **The passenger pays 120 credits** whatever their mood, so the first upgrade is one delivery away once it is over.
- **It opens on a call from their boss,** who tells them they are on a trial period. Until the player answers it and closes the transmission, the call notice's Answer is the one thing they can do: no clicks on the map or the bus bars, no pan or zoom.
- **Each step is a guide card** (placeholder titles; what each says is in `tutorial_cards.gd`, the calls' words in `tutorial_call.gd`), most waiting for the player to do something in the game; a card that only tells them something has a Got it button, offered on purpose and rarely.
  - **The bus**, beside it. Got it moves on. Until then, still no clicks but on the card, and no pan or zoom.
  - **The pick-up**, on the waiting passenger's row once the station panel is in. It goes once they board.
  - **On board**, beside the On board panel, once it has come in and the passenger's card has slid into it. Got it moves on.
  - **Happiness**, beside the happiness bar on the passenger's card. Got it moves on.
  - **The course**, beside the Moon. It goes once the Moon is on the route.
  - **The charge**, above the Frameshift key. It goes once the bus leaves.
  - **The snack.** Halfway to the Moon the passenger asks for a snack, and the game pauses, all but serving and the portraits, with a card beside their serve button. The game runs again once it is served.
  - **The rating.** Getting off at the Moon, once their card has filled its stars, the game pauses, all but the portraits, with a card beside them. Got it moves on.
  - **The fare.** Once their card has left the On board panel, the resource bar comes in, then a card under it. Got it moves on.
  - **Refuelling**, beside the Moon's fuel button. It goes once the tank is full.
- **It ends on another call from their boss,** a second after the tank is full: the player passed their trial period, and the boss unlocks the frameshift planet lock for the whole star system. The call notice's Answer is again the one thing the player can do. Both calls offer two answers that mean the same, for flavour, and either one goes on. Answering the last ends the tutorial.
- **Only what a step brings in shows.** After the call, only the bus bars; the station panel comes in with the pick-up, the On board panel once the passenger boards, and the resource bar with the fare. The station's fuel button shows from the flight to the Moon on, off until the refuelling card opens; the lab badges and the station's Research and Board all buttons stay hidden.
- **The course holds in flight.** From the flight's start until the bus docks, the player can't change the route: no Stop, no stop taken off the route bar, no new course.
- **No planet opens** on a click through it.
- **Courses only when asked for.** Right clicks set a course only in the steps about setting one, and only to the planet the step names: no points in space, no other planet, and nothing more once it is set. A stop short of where the bus is headed asks for the course again.
- **No other needs.** The snack is the only thing the passenger asks for.
- **No route changes in flight.** From leaving until the bus docks, each way, clicks on the map, Backspace and the Frameshift key do nothing, and the key never turns into Stop.
- **No kicks.** The passenger can't be kicked off until it is over.
- **The zoom out.** Done or skipped, the HUD goes, then the map zooms out to the whole solar system, the planets starting to orbit as it goes, and holds there for 4 s before the HUD comes back. The screen takes no clicks, and the route controls, pan and zoom do nothing, until then.
- Then the lines start at every planet (The start), the run's goals are given, and a notice says the whole solar system is open.

## Feature hints

- **The first time the player meets a feature in play,** the game pauses with a feature hint pointing at it, until the player presses Got it; the pause menu can open over it, and closing that leaves the game paused. Each hint shows once across every run, kept beside the save; deleting the save data, from the main menu's settings or the debug panel's Delete save, forgets them, so they show again.
- **Never during the tutorial,** which has its own cards, and never on a hidden target: a hint passed over that way isn't kept as seen, so the next meeting offers it again. Two at once show one after the other.
- **The heat zone:** the first time the passengers become uncomfortable (past 32°, where the gauge leaves green), a hint above the gauge says the star heats the bus, that passengers are getting uncomfortable and it will soon overheat, and to move away from the star to cool it (the words are in `feature_hints.gd`).
- **Business passengers:** the first time a Business passenger waits in the dock panel, once the panel is in and their row has slid in, a hint beside their row says they ask more but pay better.

## Save game

- **One run is saved.** With a save, the main menu offers Continue, and New game in place of Play. New game replaces the save once the tutorial is over, so it is held to confirm, like refuelling, and a stray click can't lose a run. The main menu's settings can delete the save, held the same way; the pause menu's can't, since the run in play would save it again at the next planet.
- **Nothing saves during the tutorial.** Quitting in it keeps the save from before, and the next New game starts the tutorial again. Once it has ended, done or skipped, it is kept as done, even if the player quits in the zoom out.
- **Checkpoints at planets.** The run saves whenever something it keeps has changed while the bus waits at a planet with no stop under way: after a stop, a pick-up, a kick, research, refuelling. Never in flight, so quitting in flight loses only the flight, and a continued run always starts docked.
- **What's kept:** where each planet is on its orbit (its progress in full-speed seconds, since orbit speed changes with the bus), the bus's planet and fuel, credits, research points and ratings, researched upgrades and which trees and stages are open, the passengers on board with their happiness, ride clock and needs, every line (who was seen, and how many not yet), the goals' progress, the quest under way, and how many star systems are open and whether they are joined. The system the bus works in is the one its planet is in, so a run continued after a promotion still offers the jump.
- **Nothing saves through a jump.** Quitting mid-jump keeps the save from before it.
- **What starts afresh:** the course, the charge, the wait until the next call, what each passenger was doing (an open request opens again at once), and the lines' clocks.
- **Continuing builds a new run first, then applies the save,** so a continued run starts from the same code as a new one.
- Only a run started from the main menu is saved, so tests and a scene run on its own never touch the save.

## Scope

- **Out for now:** more than one save slot, dialogue, positional or adaptive audio.
- **Not in temperature:** cold (nothing lies beyond Frost, so it would be an unavoidable tax on Frost trips or never felt; it waits for a system where it is a choice), a player action that cools the bus, and upgrades that change any of it.

## Not designed yet

Features we will very probably build, but that need more design work first.

- **Business passengers' own needs.** Types can also differ in what they need on board, so a Business passenger might want a sleeping pod where a Commuter wants only snacks.
- **VIPs.** Rare passengers who turn up as announced events once the recent rating is in the top band, outside the rules for who turns up, with requests of another kind, such as visiting planets.
- **Environment.** How space affects the bus and passengers beyond the star's heat (Temperature): a big planet's gravity slows the bus down near it.
- **Depots.** Whether fuel stays on sale at every planet.

## Open questions

- **The first stage runs out.** Its 15 upgrades, all built, cost 2,760 credits in all; the scripted player has 10 by minute 10 and 13 by minute 15, one with quick hands 12 and 14, measured with no promotion, so points (41 % unspent at minute 15) pile up with nothing to buy. A promotion at Sol's goals (minute 5 to 7) may fix it; unmeasured.
- **Lyra, Draco and the joined systems are untuned.** Their goals, fuel prices and layouts are first guesses, and the balance tool plays only Sol. Trips between joined systems run from 13 to about 75 units, nearly two tanks at the far end, so where to refuel starts to matter there, and fuel tanks may stop doing nothing.
- **What the joined systems are for.** Their goals promote to nothing; whether meeting them wins the game, or there is no end.
- **Who wants another system.** Once joined, a passenger's destination is any other planet, so most trips cross to another system. Whether to weigh their own system's planets higher.
- **The top band is in reach in the first stage.** In-Flight Movies and a full lounge bonus reach 89, and a quick stop takes that past 90, so about one ride in six gets 5 stars once Movies is researched. The scripted player ends a run at a recent rating of 4.1 to 4.3, and one who researches Movies first crosses 4.25 and gets about 14 % Business passengers. Whether that band should wait for a promotion. With every stage open, half of all rides get 5 stars and the recent rating ends near 4.9.
- **Serving speed barely shows once research starts.** Over a run a hand that reacts in 4 s rates within 0.05 stars of one that reacts in 0.7 s and earns the same; on a bare bus it is 0.1 stars. In-Flight Movies does most of it: its +8 is almost three seconds of an open request for free.
- **In-Flight Movies is the best upgrade by far,** at the second-lowest price: alone on a bare bus it adds 0.2 stars and 15 credits a minute, where no other first-stage upgrade adds more than 0.1 stars. Researching it first rather than last is worth 0.15 stars over a run. At +12 that was 0.26, and with the base at 64 it put a clean ride on the 5-star line, so half of all rides got 5 stars.
- **Business passengers are no trade-off.** They pay 1.6× and rate 0.1 stars lower than Commuters, 0.3 lower on a bare bus; leaving them behind loses 30 % of the credits and gains no rating.
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
