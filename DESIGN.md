# Design

The design decisions the game logic follows: the rules, the numbers that are decisions, and why. Read it before gameplay work.

Keeping it that way:

- **What goes here:** a rule or a number someone needs to write the game logic, and couldn't guess. One rule per bullet.
- **What doesn't:** how it looks, sounds or animates (`docs/ui.md`), and anything the code already says (file paths, class names, node layout).
- **Change, don't append.** When a rule changes, rewrite its bullet. No history: git has it. A reason stays only while it still stops someone undoing the decision.
- **Status.** Everything here is built unless it says *(not built)*. All numbers are starting points for playtests.

## Pitch

You drive a bus around a small solar system. Pick up passengers, plot a route through space and get them to their planet before the ride wears them out. The planets orbit while the bus flies, so a route that looks short at the dock may not be short by the time the bus gets there.

## Core loop

1. **Docked.** The bus starts docked at a planet. Passengers wait at planets, each with a destination, a fare and an expected trip time. While docked or charging, the player picks passengers up into the bus's seats.
2. **Set course.** The player adds planets and points in space to the route.
3. **Charge.** The player holds the Frameshift key to charge the drive, and the bus leaves once it is charged. Until then the route can still change.
4. **Fly.** The bus flies the route stop by stop. The player can reroute at any time.
5. **Arrive.** At a planet, passengers going there get off, pay by their mood, rate the ride and earn a research point.
6. **Refuel and research.** Docked, the player buys fuel, and at a planet with a lab researches upgrades from every tree.

## The solar system

- A star and four planets on circular orbits, one with a moon and one with rings. The Moon counts as a planet for passengers, fuel and docking.
- Planets orbit at 0.34 (Frost) to 0.47 (Ember) units a second; the Moon moves at up to about 0.87 as it circles Terra. Every planet moves at under 40 % of the bus's speed, so the bus catches one without a long chase.
- Ember and Frost are 12 to 23 units apart as they orbit.
- **Time slows unless the bus frameshifts.** The planets orbit at full speed only while the bus flies a course, towed or not. They slow to half of it once it starts parking at a planet, comes to rest in space, or starts coasting to a stop after the course is cleared or the tank runs dry, and stay that slow while it waits or charges. A trip takes far longer than it looks, and the time spent stopped is wound back. Half speed keeps the system moving while docked, so a long stop still costs some of a route's shape. They take about 0.6 s to slow and 0.6 s to get going again, so nothing jumps. Their spin and the passengers' clocks keep running.

## Route and flight

- **Stops.** A route is an ordered list of stops, each a planet or a point in space. The bus docks at every planet on the route and passes through points in space. It holds still at a point in space that ends the route.
- **A planet stop** is the planet's near side, so the bus chases a moving planet.
- **Checkpoint.** With a planet on the route, a point in space goes in just before the first planet on the route, so it bends the way there rather than going on after it. There is one checkpoint before that planet: a new one replaces it.
- **Open space.** With no planet on the route, a point in space replaces the one the bus is flying to, so a route in open space is one point. Adding a planet then replaces that point.
- **Round trips.** A planet earlier on the route can be added again. The planet the bus is docked at can be added as the last stop when the route already has a planet.
- **No modifier keys** in the route controls: Firefox opens its own context menu on Shift + right-click, and a page can't stop it.
- **Speed.** The bus flies at a top speed of 1.2 units a second, speeding up as it leaves and slowing as it nears a planet.
- **Charge.** Setting a course never leaves a planet by itself, so planning a route and leaving are separate decisions. The player charges the drive by holding the Frameshift key for 3 s, at every planet the bus leaves. The bus turns toward its next stop meanwhile.
- **Letting go** drains the charge twice as fast as it built and keeps the course; holding again charges from what is left. Cancelling keeps the bus docked.
- **Rerouting in flight is free:** no charge and no extra fuel beyond the distance it adds.
- **Warm drive.** A course set from a stop in space within 1 s of coming to rest leaves at once, so a short stop costs nothing. After that the drive is cold and the bus waits for a charge, as at a planet; cancelling leaves it holding in space.
- **Parking.** Near a planet the bus glides the last half unit in and swings side-on, door toward the planet. It has docked only once it is parked, and only then can the drive charge.
- **Clearing the route** stops a charging drive, and makes a flying bus coast to a stop.

## Fuel

- **Tank.** A full tank holds 100 fuel. The bus burns 2.5 per unit flown, so a tank flies 40 units: about one trip from Ember to Frost and back.
- **Only flying burns fuel.** Charging, parking and floating while docked don't.
- **Prices.** For now every planet sells fuel, each at its own price per unit. A full tank from empty costs 6 credits at Giant, 8 at Frost, 10 at Ember, 12 at Terra and 15 at the Moon. A planet can be set to sell none; none is yet.
- **Refuelling is a hold.** While the bus is docked or charging at the planet, holding the button pumps fuel from 12 a second, speeding up to 60 a second over 1.5 s. It stops when the player lets go, the tank is full or the credits run out.
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

## Passengers

### Waiting

- Each planet gets a new passenger every 8 to 20 s, up to 3 waiting. Who they are is under Who turns up.
- Nobody new turns up at the planet the bus is docked at: its clock holds until the bus leaves, so waiting there gains nothing.
- Happiness holds while they wait.
- **The start.** The bus is empty and docked at Ember, with 2 passengers waiting there and 1 at every other planet, so the first stop has someone to pick up and the first route somewhere to go.

### Who turns up

- **Decided when first seen.** A waiting passenger is only a count until the player first sees the line, by docking at the planet or opening it. Then each undecided passenger in it gets a destination, a race and a type, one after another, and keeps them. Lines fill about 40 s before the bus arrives, so deciding late is what lets a line answer the bus as it is now.
- Anything that shows a line from afar counts as seeing it. The waiting markers show only a count, so they don't.
- **Destination** is a weighted roll among the other planets, each at weight 1: ×2.5 if someone on board is going there, ×1.5 if someone already in the line is.
- **No more than two** in a line go to the same planet, so a line always holds a choice.
- A match with who is on board is likely, never certain. A certain one stops being a reward, and turns the bus into a shuttle between two planets.
- Destinations aren't dealt from a bag: dealing without repeats makes two going the same way rarer than chance does.
- **Race** is dealt from one shuffled bag of six, two of each race, so no race stays away for long.
- **Type** goes by the band the recent rating is in (Rating). Upgrades aren't read: a bare bus sits between 3 and 4 stars, by how clean its rides are, and only comfort upgrades take it past 4.

| Recent rating | Commuter | Business |
|---|---|---|
| Under 3.5 | 95 % | 5 % |
| 3.5 to 4.25 | 75 % | 25 % |
| 4.25 and up | 55 % | 45 % |

- **A full line has a Commuter:** at most one Business passenger in a line in the lowest band, two above it.
- *(not built)* A type whose needs take an amenity doesn't turn up until the bus has it. No need takes one yet.
- **Leaving.** Once a line has been seen, its longest-waiting passenger leaves after 60 s without being picked up, then the next after 60 s more, so a line the player passes over doesn't stay the same for good. Nobody leaves while the bus is docked there.
- Leaving costs the player nothing. The place fills again on the planet's clock, with someone undecided.

### Stops and boarding

- Whenever the bus docks at a planet it makes a **stop**: the passengers going there get off one at a time.
- **Nobody boards by themselves.** While the bus is docked or charging, the player picks waiting passengers up one by one, or all that fit at once, longest waiting first.
- **Seats.** The bus has 4. No one can be picked up while every seat is taken or promised to someone picked up.
- Getting off or on takes 0.6 s each, in order: those getting off first, then those picked up, in the order picked.
- **The drive can't charge until the stop is over.** Holding the key during it charges nothing until the last passenger is on. Picking someone up while it charges holds the charge where it is until they are on.
- The bus waits at every planet until the player charges the drive, so picking passengers up takes as long as the player likes.

### Trip time, fare and payment

- Both come from the straight distance at boarding. Planets move, so they are estimates.
- **Trip time** is the charge plus that distance at the bus's *base* top speed. **Expected time** is the trip time times the type's slack.
- **Fare** is 3 credits per unit times the type's multiplier.
- Both are set when the passenger is decided (Who turns up), from where the planets are then.
- A faster bus gets passengers there before they expect it. Speed upgrades make passengers happier rather than more demanding.
- **Payment** on getting off goes by mood: happy pays 1.2× the fare, okay 1×, annoyed 0.5×, furious nothing.

### Happiness

Happiness replaced patience, so a long ride isn't the only thing that matters: what a passenger needs, and how well the bus gives it, does too.

- Each passenger on board has a happiness from 0 to 100.
- **It starts at the target,** the most the bus can give them: set as they take their seat, and again as the bus leaves, so comfort researched at that stop counts. A quick ride keeps them there. Starting lower and climbing made a short ride end before they got there, so delivering quickly scored worse than taking long.
- A shock before the bus leaves stays: they start that much under the target.
- Every frame it slides toward the **target**, falling at 3 a second and climbing at 1. It never jumps, and bad moments take a while to wear off.
- **Mood:** happy from 70, okay from 50, annoyed from 25, furious below.
- **Rating** on getting off: happiness ÷ 20, to the nearest whole star.
- **It holds** until the bus leaves the planet they boarded at, and while the bus parks.
- **Docked,** it falls at a tenth of its speed, so a stop (boarding, refuelling, charging) barely costs anyone.

**The target** is worked out fresh every frame:

- 60 for a bus that does its job, plus the comfort bonuses (no higher than 100 together), plus timing.
- While a request is open, the target is 0. Ignoring a request must always cost more than serving it.
- While anything is serving the request, happiness holds rather than falling, since they can see it coming.

**Timing** is one line along the ride:

- +12 if they arrive in the direct trip time, 0 at the expected time, then down to −100 one more trip time after that.
- It runs on the passenger's own **clock**: real time in flight, a tenth of it while docked, and slower while they sleep or watch a show.
- **Leeway.** While happiness is 80 or more, every second of their clock adds half a second to the time they expect, up to half a trip time. It never grows past that, so a long enough ride still wears out anyone.
- Getting there sooner (routing, speed, never needing a tow) is the main way to beat timing. Comfort only buys a little.

**Shocks** change happiness at once and leave the target alone, so it climbs back at 1 a second:

| Shock | Amount | Why |
|---|---|---|
| Someone is kicked | −25 to everyone else | Otherwise kicking the angriest passenger would raise the average for free |
| The bus runs out of fuel | −15 to everyone | Less than a kick, since the wait and the tow cost time on top |
| Arriving unserved | −10 to them, before they rate | A request open or on hold for 5 s of flying or more. One asked just before arriving, or during parking, is forgiven |
| Woken by a shock | a further −10 | Every shock wakes anyone asleep, so a kick or a tow is worse on a bus that sleeps |

There are no good shocks: one would fall away at 3 a second, gone in seconds.

**What a bus can reach.** A bare bus gives 4 stars for a clean ride and 3 otherwise: a direct trip with every request served at once ends where it started, at 60 + 12 = 72, and 4 stars takes 70, so a second of an open request near the end, or arriving a little late, costs the star. Over many rides a bare bus averages about 3.5: 3.6 with quick hands, 3.0 with slow ones and a full bus. Five stars takes about 90, which only the comfort upgrades reach. A fully upgraded bus sits at about 100 before timing.

### Needs and serving

- Each passenger type has a few needs. The Commuter's are a snack and a drink, both food.
- A need asks again a random while after the last one's served activity ends: 8 to 20 s for a snack, 10 to 25 s for a drink. An open one is a **request**. The times are short because rides are (about 20 s): half of all rides should hold a request, or serving decides nothing and the food upgrades answer nothing.
- **One request at a time.** The other needs' timers wait while one is open, so serving one doesn't set off the rest.
- **A request never expires.** One that did would make ignoring a passenger cheaper than serving them.
- **Serving is a hold,** like refuelling: holding the button serves the request over 1.2 s, and letting go keeps what was served so far.
- **Stops are quiet.** No request opens while the bus is docked or parking, and the needs' timers run at a tenth of their speed while docked. A request open when the bus stops goes on hold and opens again once it flies on.
- Fun and sleep aren't needs that ask: upgrades give them.
- *(not built)* **Food and drink become one need,** so the player isn't asked to tell them apart: one request, served as a snack or a drink at random.

### Amenities

An amenity serves food by itself. Automation shortens a request rather than removing it, so needs stay on the cards on a fully upgraded bus, and more seats need more delivery.

- The moment someone asks for food, an amenity with room starts serving them. Anyone else asking waits, and their happiness heads for 0 meanwhile.
- The player can still hold the button: the hand's speed adds to the amenity's.
- **Food Replicator:** one passenger at a time, 4 s each.
- **Waiter Droids:** three at a time, 2.5 s each.
- With both, the droids are tried first, then the replicator, so four can be served at once.

### Comfort

What the comfort upgrades give everyone on board. Each line has one main job:

| Line | What it does |
|---|---|
| Food delivery | Shortens requests: the amenities above |
| Portions | A served snack or drink lasts longer, by hand or by machine, so the next request comes later. Helps before any replicator |
| Fun | Raises the target all ride long: In-Flight Movies +12, Space Invaders +8. Passengers also watch shows, and their clock runs at 70 % while they do |
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
- Business pays 1.6× with a slack of 1.2, and asks for the Commuter's snack and drink at 0.6 of the time between requests.
- The Commuter's slack stays loose (1.5): it is the passenger that makes a route with several stops work.
- The player can tell a Business passenger from a Commuter wherever they pick passengers and on board.
- Race and type are independent: any race can be any type.

### Races and research points

- Every passenger is one of three races, picked at random: blue, orange or green.
- Getting off at their destination earns one **research point** of their race, whatever their rating.
- Each race's points are meant for one part of the bus: blue for its performance, orange for comfort on board, green for the stops.
- A race must read without colour too, by the build of its head (`docs/ui.md`): with red-green colour blindness, orange and green come close.
- Skin colour never changes with mood, since it is what shows the race.

### Rating

- The player's **average rating** is the mean of every rating so far.
- It changes nothing yet.
- The **recent rating** is the mean of the last 10 ratings. It sets which types turn up (Who turns up), and it is the rating the player is shown, so the stars and what they explain are one number.
- The star rating says only that a higher rating brings more Business passengers: no bands, no odds.
- *(not built)* The player is told the first time the recent rating reaches a new band, and not again on coming back to it.

## Research

Upgrades for the bus, bought with credits and research points.

- **Research trees aren't tied to planets.** Each is the upgrades for one part of the bus, linked by what each needs first.
- **Researching happens only while the bus is docked or charging at a planet with a lab,** as refuelling does, and there the player researches from every tree.
- **Each tree splits into three stages** by row: rows 1 and 2, rows 3 and 4, and the rest. The first stage is open from the start, and each **promotion** opens the next. *(not built)* What earns a promotion; for now only the debug panel gives one.
- **The game is paused** while the player researches.
- **An upgrade** has a cost in credits and research points, usually of the one race whose points are for the part of the bus it improves, so a tree can send the player looking for that race.
- It needs *all* the upgrades it lists, from the same tree, and its stage open.
- Each is researched once. A bigger step of the same thing is its own upgrade after it (Tank I, then Tank II).
- Once researched it puts modifiers on the bus's stats, gives it traits, or both.

An upgrade is in one of five states:

| State | When |
|---|---|
| Needs promotion | Its stage isn't open. Its name, description and cost don't show |
| Hidden | Marked hidden, and not everything it needs is researched. Its name, description and cost don't show |
| Locked | Something it needs isn't researched |
| Available | Everything it needs is researched and the player can pay |
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

- A continued run researches its saved upgrades again on load, so their modifiers and traits come from the same place as in play (Save game).

### Traits

- A **trait** is a feature the bus either has or doesn't. The feature shows or works only while it does.
- Two upgrades can give the same trait; it stays until both take it back.
- **Waiting markers:** how many wait at each planet shows on the map. Without them, the player finds out by opening a planet.
- **Fuel forecast:** how much of the tank the whole course burns shows on the route. It counts the straight legs as everything is now, short of each planet by where the bus starts to park, so it is an estimate.
- The comfort and food traits: Pillows, Sleeping pods, In-Flight Movies, Space Invaders, Food Replicator, Waiter Droids.

### The trees

There are three trees, each paid for with one race's points. Frost, Terra and Giant have a lab; the rest have none.

- They branch and join like talent trees: an early upgrade opens more than one, some need upgrades from two branches, and each ends in a capstone that needs two branches. Only a stage that isn't open hides an upgrade; none is marked hidden.
- **Costs go by row,** the same in every tree for now: 150 credits and 2 points in the top row, then 300 and 4, 550 and 7, 800 and 10, and 1,100 and 14. Credits come in at about 400 a minute and points of one race at 2.5, so in the first stage either can be what the player waits for. Much cheaper in credits, and fares, moods and Business passengers stop mattering.
- An upgrade that isn't implemented says so on its card and changes nothing when researched.

"A ← B" means A needs B.

- **Blue** (performance). Speed 1 and Fuel tank 1 at the top. Speed 2 ← Speed 1; Frameshift 1 ← Speed 1 and Fuel tank 1; Fuel forecast ← Fuel tank 1; Fuel tank 2 ← Fuel tank 1. Speed 3, Frameshift 2 and Fuel tank 3 each ← the one above. Extra insulation ← Frameshift 2 and Fuel tank 3. Capstone: Sunscreen ← Speed 3 and Extra insulation.
  - Speed is +10 % top speed a step, Fuel tank +25 % a step, Fuel forecast gives its trait.
  - *(not built)* Frameshift (a shorter charge), Extra insulation, Sunscreen.
- **Green** (the stops). Door chime; Station cameras and Station waiting lounge ← Door chime; capstone Mind reading machine ← both.
  - Door chime gives the waiting markers.
  - *(not built)* The other three.
- **Orange** (comfort). Extra seat, Food Replicator, Bigger portions I and In-Flight Movies at the top. Four Extra seats in a chain (+1 seat each). Pillows ← the first Extra seat and the Food Replicator; Sleeping pods ← the second Extra seat and Pillows. Bigger portions II and III in a chain (+50 %, +50 % and +100 % portion size, 3× in all). Space Invaders ← In-Flight Movies. Capstone: Waiter Droids ← the Food Replicator and Bigger portions II.
  - Every upgrade in it is implemented.

## Goals

- **Several at once.** The player can have any number of goals; each counts from when it is given, not from the start of the run.
- **A milestone** is done once and stays done: deliver 50 passengers. Kicked passengers don't count.
- **A standing goal** is met or not as things stand, and is never done: keep a 4.0 average rating. It isn't met until a set number of rides are rated (at least 1), so one lucky first ride doesn't meet it. Dropping below makes it unmet, not failed.
- **A quest** is a goal about one passenger, and fails if they are kicked:
  - Deliver them to their destination.
  - Fly them past a planet: while they ride, the bus comes within 3 units of its surface in flight, having been out of reach since they boarded. Leaving the planet they boarded at isn't a flyby, coming back to it is, and flying in to dock there counts. It fails if they leave the bus first, however they leave.
- **All met** means every milestone done and every standing goal holding.
- **A run starts with two goals:** deliver 30 passengers, and keep a 3.5 average rating. 3.5 is what a bare bus averages, so quick serving and direct routes meet it without research, and anyone else needs a first upgrade or two. Both are met after about 5 to 7 minutes, with half of the first stage researched.
- *(not built)* Quests turning up.
- *(not built)* A temporary win and lose while the loop is tuned. **Win:** every goal met at once. **Lose:** the happiness score, the average happiness of everyone on board, stays at 0 for 20 s; the countdown pauses while the bus is empty.

## Controls

| Input | Action |
|---|---|
| Left click a planet or the bus | Open it. One thing is open at a time. Where the bus and a planet overlap, whichever centre is nearer the pointer opens |
| Left click the open thing, or empty space | Close it |
| Right click a planet | Add it to the end of the route |
| Right click empty space | Add a point in space (Route and flight) |
| Right click a point in space on the route | Remove it |
| Right click the last planet on the route | Remove it, along with the checkpoint before it |
| Backspace or Delete | Clear the route |
| W A S D, arrow keys, or the pointer at a window edge | Pan the camera. A setting turns edge pan off |
| Hold the middle mouse button and move | Drag the camera: the point under the pointer when the button went down stays under it. The drag goes on past the window edge, and edge pan stays out of it |
| Mouse wheel | Zoom toward the point under the pointer |
| Esc | Pause |
| F2 | The debug panel |

- **Left click selects, right click routes.**
- **Esc stays pause only.** In browser fullscreen the browser takes Esc and the game never sees it, so Esc can't close a panel the same way in a window and in fullscreen.
- Removing the last stop cancels the course.
- WASD reads physical key positions, so it sits in the same place on every keyboard layout.
- Pan and zoom do nothing while a planet or the bus is open. Right click still sets the course.
- Each panel's own buttons are in `docs/ui.md`.

## Scenes and flow

```
main menu ──Play / Continue / New game──▶ solar system ──Esc──▶ pause menu ──Main menu──▶ main menu
    │                                          │
    └──Settings──▶ settings panel ◀──────────Settings
```

- The game is one scene, the solar system.
- Pausing stops the game; music keeps playing. The pause menu also opens when the player leaves browser fullscreen.
- **A transmission** pauses the game until the player answers it. Closing the pause menu over one leaves the game paused.
- **Settings:** Master, Music and SFX volume, Reduce motion, and Edge pan (on by default). They are saved across sessions.
- On the web a title card comes before the main menu, and its click starts the music (`docs/web-constraints.md`, Audio).

## Save game

- **One run is saved.** With a save, the main menu offers Continue, and New game in place of Play. New game replaces the save at once, so it is held to confirm, like refuelling, and a stray click can't lose a run.
- **Checkpoints at planets.** The run saves whenever something it keeps has changed while the bus waits at a planet with no stop under way: after a stop, a pick-up, a kick, research, refuelling. Never in flight, so quitting in flight loses only the flight, and a continued run always starts docked.
- **What's kept:** where each planet is on its orbit (its progress in full-speed seconds, since orbit speed changes with the bus), the bus's planet and fuel, credits, research points and ratings, researched upgrades, the passengers on board with their happiness, ride clock and needs, every line (who was seen, and how many not yet), and the goals' progress.
- **What starts afresh:** the course, the charge, what each passenger was doing (a request comes back on hold, as at a stop), and the lines' clocks.
- **Continuing builds a new run first, then applies the save,** so a continued run starts from the same code as a new one.
- Only a run started from the main menu is saved, so tests and a scene run on its own never touch the save.

## Scope

- **Out for now:** more than one save slot, dialogue, positional or adaptive audio.

## Not designed yet

Features we will very probably build, but that need more design work first.

- **Business passengers' own needs.** Types can also differ in what they need on board, so a Business passenger might want a sleeping pod where a Commuter wants only snacks.
- **VIPs.** Rare passengers who turn up as announced events once the recent rating is in the top band, outside the rules for who turns up, with requests of another kind, such as visiting planets.
- **Environment.** How space affects the bus and passengers. A hot star makes passengers on a route near it hot; a big planet's gravity slows the bus down near it.
- **Depots.** Whether fuel stays on sale at every planet.

## Open questions

- **Fun in the first stage.** In-Flight Movies and Space Invaders are both in the first two rows, so the first stage alone takes the recent rating to about 4.7 and half of all rides to 5 stars. A later stage's rating goal has little room above that unless Space Invaders moves down a row or the bonuses shrink.
- **Orange points.** Past the first stage the orange tree is what the player waits for: it holds most of the built upgrades, while green points pile up unspent (the green tree has one built upgrade) and credits pass 2,000 by minute 20.
- **The rating goal reads the all-time average,** so the first rides on a bare bus weigh on it for the whole run, while the resource bar shows the recent rating.
- **Food quality.** Bigger portions took the tiles a quality line (a happiness bonus per tier, +8 to +12) would have had. Whether one still comes, or portions are enough.
- **Fun is mostly a flat bonus.** The +12 and +8 apply whether or not anyone watches; only the clock depends on watching. A bonus only while watching barely shows, since happiness falls three times as fast as it climbs. Whether watching should matter more.
- **How often passengers sleep.** Too short between sleeps and a long route costs nothing, too long and the pods hardly show. Also the pods' price, since costs go by row.
- **What else the rating does.** Besides setting which types turn up: whether it gates upgrades, or is the leaderboard score.
- **The tow's price and speed.** 100 credits, which can take the credits below zero, and 0.4 units a second over the planet's speed.
- **Fuel and fare balance.** Fuel is about a twelfth of a fare per unit.
- **Research points and rating.** A furious passenger is worth as much research as a happy one. Whether the rating should scale it (say, a point only from 3 stars up).
- **Race and planets.** Whether a race leans toward some planets, so the player can hunt for one kind of point. Leaning no: it gets confusing quickly.
- **Seats and waiting passengers.** 4 seats and up to 3 waiting per planet, from the prototype. With 6 seats or more a bus that keeps to two destinations leaves with one or two seats empty; 4 waiting delivers about a tenth more, and fills a bus that takes everyone with more destinations than it can serve well.
- **Softening shocks.** An upgrade could soften the kick's shock, or what a stop costs.

UI questions are in `docs/ui.md`.

## Online

Online services run on Talo (`docs/online.md`), picked over Firestore in issue #5: analytics events, stats and play sessions now, leaderboards once there's a score. Nothing is tracked yet. Uploaded replays (ghosts of other players' runs) don't fit Talo; a player's own ghost can stay in `user://`.
