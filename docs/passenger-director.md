# Who waits where: spawn experiments

Experiments on the rules that decide which passengers wait at which planet, and when: the hidden logic that should make the loop feel dealt rather than random, the way Tetris deals pieces from a bag. None of it is built. The model and every number below come from `tools/passenger_sim.py` (`python3 tools/passenger_sim.py all`, about a minute).

## Method

The simulator is a 2D model of the solar system with the numbers in the game today: the five bodies' orbits from `solar_system.tscn`, the bus's 1.2 top speed, 1.6 acceleration and 3 s charge, 0.6 s per passenger on or off, 4 seats, patience at 1.5 × the trip estimate, the mood thresholds and pay, half drain while docked, and needs asking every 15 to 45 s at 3× drain until served. Fuel only costs credits, since a full tank covers the longest leg.

Three bots play each rule set for 10 minutes, on the same 40 or 80 seeds:

- **Casual**: presses Board all, then flies to whoever is least patient. The floor.
- **Nearest**: Board all, then the nearest destination on board. A typical player.
- **Planner**: tries every choice of who to board and every order of stops, with the planets' future positions, and takes the best credits and stars per second. It leaves people behind. The ceiling.

What a good rule set should do, as numbers the bots can measure:

| Feel | Measure |
|---|---|
| Fair to a normal player | Casual and nearest bots' average stars, and the share of annoyed or furious deliveries |
| Skill pays | Skill gap: the planner's credits over the casual bot's |
| Outcomes come from play, not luck | Luck: the spread of the casual bot's credits across seeds (coefficient of variation) |
| No dead time | Flying empty, and "dry" stops: free seats and nobody waiting |
| No droughts | The longest stretch without a delivery |
| Real decisions | Stops where the line offers two or more destinations |
| Satisfying moments | Stops where two or more get off at once |
| The map matters | How often the lines are nearly full, 80 % of every place taken (then where people wait tells the player nothing) |

Bots aren't players. They can't tell whether something feels rigged, readable or annoying; those are for playtests (Open questions, below).

## What the game does today

Each planet gets a passenger every 8 to 20 s, up to 3 waiting, each going to another planet at random. Waiting passengers never leave.

| Bot | Delivered | Credits | Stars | Annoyed or furious | Lines nearly full | Waited over 60 s |
|---|---|---|---|---|---|---|
| Casual | 62 | 1,202 | 1.79 | 67 % | 80 % of the time | 66 % |
| Nearest | 73 | 1,901 | 2.91 | 43 % | 74 % | 59 % |
| Planner | 61 | 2,567 | 4.20 | 13 % | 86 % | 54 % |

Four things stand out:

1. **Supply swamps the bus.** The planets try to produce about 21 passengers a minute; one bus delivers 6 or 7. The lines sit full, so spawn timing barely matters, the waiting markers trait would tell the player nothing, and the typical passenger has waited two minutes.
2. **Fare and patience are set at spawn, not boarding.** `WaitingPassengers.create()` prices them when they turn up, and DESIGN.md says "at boarding". After two minutes of orbiting, 49 to 53 % of the passengers boarded had a patience more than 20 % off what the trip now takes: some generous, some impossible, by luck. The planner profits from it, picking the ones priced from a longer distance. This is a bug either way.
3. **A direct trip can't make anyone happy past 4.5 units.** Patience is 1.5 × (charge + distance at top speed + speeding up and slowing down), but the charge doesn't drain it, so a perfect direct trip keeps 60 % or more only on short hops. Most planet pairs are 10 to 23 units apart: those arrive Okay at best, and one request on the way (+4 s of drain) makes even a 4-unit hop Annoyed. DESIGN.md says "a straight trip keeps them happy"; with these numbers it can't. This is patience tuning, not spawning, but it caps every spawn rule's ratings.

   | Distance | Patience left on a direct trip | Mood |
   |---|---|---|
   | 2 | 70 % | Happy |
   | 4.5 | 60 % | Happy |
   | 8 | 53 % | Okay |
   | 16 | 45 % | Okay |
   | 30 | 40 % | Okay |
4. **Board all is a trap.** Random destinations in every line mean pressing Board all fills the bus with four ways to go, and two thirds of the casual bot's passengers arrive annoyed or furious.

## What didn't work

- **A Tetris bag for destinations.** Each planet dealing every other planet once per bag made the casual bot worse (annoyed or furious 47 % → 56 %). A bag guarantees variety, but a bus wants the opposite: the "piece you need" is someone going where you're already going. Variety in a line is what makes Board all hurt.
- **Weighting destinations toward near planets.** More happy passengers, but short trips pay less: the planner's credits fell 13 to 22 %, and the bus flew empty more.
- **Waves (rush hours) and an adaptive rate** that eases off while riders are unhappy. Neither moved the bots' numbers much. Rush hours may still feel good to a person (a playtest question). Rubber-banding is the kind of secret help players notice and resent, and here it buys nothing.
- **Choosing the emptiest planet as the origin.** Barely different from uniform.
- **A fourth place in each line.** With give-ups on, the cap is almost never reached.

## What worked

Each was tested on top of the others; the ablation table below takes each out alone.

- **One stream for the whole system, a little slower, ramping up.** One clock deals passengers to any planet that isn't full and isn't where the bus is docked. Gaps are jittered ±50 % around the mean rather than random, so there are no long droughts. The rate ramps from 6 to 14 a minute over 10 minutes. The rate is a skill knob: more supply tempts Board all players into worse loads, while a planner turns it into credits (from 8 to 16 a minute, the casual bot's stars fall 2.97 → 2.02 and the planner's credits rise 1,810 → 2,632). Starting sparse gives a learning curve: the casual bot averages 3.33 stars in the first 3 minutes with the ramp, against 2.87 without it.
- **Waiting passengers give up after 60 to 100 s.** Lines refresh, the map changes, and where people wait starts to matter: the lines are nearly full 20 % of the time instead of 75 to 85 %. Shorter (45 to 75 s) costs the planner 4 deliveries in 10 minutes; longer (90 to 150 s) brings the stale lines back.
- **Price fare and patience at boarding** (the bug fix above).
- **Lines cluster.** Each new passenger has a 40 % chance of going where someone already waiting there goes. This is the real analogue of Tetris's bag: it deals what the bus wants, a group heading the same way. Board all becomes a reasonable play, two-at-once drops go up, and nothing about it looks rigged. In the game it could read as friends or a family travelling together.
- **The arrival guarantee.** When the bus sets off for a planet with nobody waiting there, and it will have a free seat once its passengers get off, someone turns up there partway through the flight. It looks like an ordinary arrival. For the casual bot, dry stops fall from 15 % to 3 %, flying empty from 9 % to 2 %, and the longest stretch without a delivery from 42 s to 30 s.

## The recommendation

A **dispatcher** with those five rules: one jittered stream ramping from 6 to 14 a minute, give-ups after 60 to 100 s, pricing at boarding, 40 % clustering, and the arrival guarantee. Against the game today, on 80 seeds:

| Rules | Bot | Delivered | Credits | Stars | Annoyed or furious | Real choice at a stop | Two or more off at once | Longest gap without a delivery |
|---|---|---|---|---|---|---|---|---|
| Today | Casual | 62 | 1,202 | 1.79 | 67 % | 88 % | 56 % | 36 s |
| | Nearest | 73 | 1,901 | 2.91 | 43 % | 83 % | 40 % | 35 s |
| | Planner | 61 | 2,567 | 4.20 | 13 % | 87 % | 44 % | 37 s |
| Dispatcher | Casual | 60 | 1,422 | 2.40 | 52 % | 45 % | 48 % | 30 s |
| | Nearest | 67 | 1,855 | 3.34 | 30 % | 41 % | 41 % | 29 s |
| | Planner | 59 | 2,393 | 4.21 | 7 % | 42 % | 47 % | 31 s |
| Dispatcher, slack 1.75 | Casual | 60 | 1,649 | 2.70 | 44 % | 45 % | 48 % | 30 s |
| | Nearest | 67 | 2,071 | 3.64 | 24 % | 41 % | 41 % | 29 s |
| | Planner | 60 | 2,553 | 4.44 | 3 % | 44 % | 47 % | 31 s |

| Rules | Skill gap | Luck (casual) | Lines nearly full (casual) | Waited over 60 s (casual) |
|---|---|---|---|---|
| Today | 2.14× | 0.22 | 80 % | 66 % |
| Dispatcher | 1.68× | 0.22 | 23 % | 21 % |
| Dispatcher, slack 1.75 | 1.55× | 0.20 | 23 % | 21 % |

What it costs, honestly:

- **Fewer passengers.** About 3 % fewer deliveries for the casual bot, 8 % for the typical one and 3 % for the planner, and the 30th delivery (the temporary win) comes 25 to 47 s later, mostly from the slow start.
- **Fewer choices at a stop.** Two or more destinations on offer at 41 to 45 % of stops, against 83 to 88 %. Today's 88 % is mostly noise (three random destinations in a full line), but the number is worth watching: stronger clustering pushes it lower.
- **A smaller skill gap,** 2.14× to 1.68×. A planner still earns two thirds more than Board all, so skill clearly pays.
- **Luck doesn't change.** The seed-to-seed spread of the casual bot's credits stays at about 0.22. Where the passengers are isn't what decides a run; how they're picked up is.

Taking each part out alone (60 seeds; nearest bot unless noted):

| Without | What happens |
|---|---|
| Clustering | Stars 3.35 → 3.14; casual bot's annoyed or furious 52 % → 60 %; real choices up to 59 % |
| Arrival guarantee | Dry stops 3 % → 17 %, longest gap 30 s → 42 s, 5 fewer deliveries |
| Give-ups | 5 more deliveries, but the lines are nearly full 52 % of the time and 46 % of passengers waited over a minute |
| Ramp | More deliveries; the casual bot's first 3 minutes fall from 3.33 to 2.87 stars |

**Slack** is the biggest single lever on how it feels, bigger than any spawn rule: 1.5 → 1.75 takes the typical bot from 3.34 to 3.64 stars and the planner's bad deliveries from 7 % to 3 %. It belongs with the mood thresholds rather than the dispatcher: decide what a direct trip should feel like first (finding 3), then tune slack or the thresholds to match.

## Open questions

Only a playtest answers these:

- **Does giving up feel fair?** It's a new mechanic: the player needs to see it coming (a patience ring on the waiting marker?) and see it happen (they walk off, or a ship leaves without them). Does it cost anything, or is the lost fare enough?
- **Does clustering read as groups?** Showing them as a party (a family, a tour) would turn a hidden rule into something the player can plan around.
- **Does anyone notice the arrival guarantee?** If players start to expect someone wherever they go, it's working; if they say the game is "giving" them passengers, it's too strong.
- **Rush hours.** The bots couldn't tell; a person might like the rhythm.
- **Is 6 to 14 a minute right once there are upgrades?** More seats or speed raise what one bus can carry. The rate should probably follow the bus's capacity rather than the clock.

## Limits of the model

- Bots replan only at planets; nobody reroutes in flight, which a good player does.
- The planner sees the future perfectly and plays for credits and stars per second, with no notion of research points or the win condition.
- Requests are served after 2 s. A busy player serves slower, which makes everything harsher.
- One passenger type, no upgrades, no research. Ten-minute runs.
- Flight is a straight chase of the planet at top speed; the bus's turning and the charge pull-out aren't modelled.
