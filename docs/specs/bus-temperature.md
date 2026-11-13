# Spec: bus temperature

A spec for work not yet built. When it is built, its rules move into `DESIGN.md` and `docs/ui.md`, its words into `CONTEXT.md`, and this file is deleted.

## Why

The bus flies straight through the star today: 11 to 25 % of straight planet-to-planet trips cross its body (radius 2.4), and 20 to 50 % pass within 4.5 units of its centre. Nothing makes the player route around it, and a checkpoint rarely has a use.

Temperature makes the star something to steer around. Flying near it heats the bus, and flying too near for too long overheats it, which stops it. How close and how long is a skill the player learns.

## Scope

In:

- One temperature on the bus, driven by its distance from the star.
- Overheating: a forced stop and a cooldown.
- A temperature gauge, and the heat zone shown on the map.

Out, on purpose:

- **Cold.** Nothing lies beyond Frost, so cold would be either an unavoidable tax on Frost trips or never felt. It waits for a system where it is a choice.
- **Passengers feeling the temperature.** No comfortable range, no happiness effect below overheating. The stop is the cost.
- **A player action that cools the bus** (windows, vents). The bus cools by flying away.
- Upgrades that change any of this.

## Rules

Temperature runs from 0 % (cool) to 100 % (overheated). A new run, and a continued one, starts at 0 %.

**The heat zone** is everything within the zone's edge of the star's centre. It has two parts:

- **The outer zone,** from the edge down to the core's edge. It reaches past Ember's orbit (5.2), so every trip to Ember costs a little. The edge stays inside 6.6, the closest the Moon comes to the star, so Terra and the Moon are clear of it.
- **The core,** from the core's edge down to the star. The rise steepens sharply here, so a bus heading straight at the star overheats at about its surface.

**How temperature changes,** by where the bus is and whether it is flying:

| Where | Flying | Stopped (docked, charging, parking, holding in space) |
|---|---|---|
| Outside the heat zone | Falls | Falls |
| Outer zone | Rises slowly, faster the nearer the star | Holds |
| Core | Rises fast, much faster the nearer the star | Holds |

- Stopped inside the zone it holds: it neither rises nor falls. Docking at Ember keeps what the trip there cost, and waiting there gains nothing.
- Coasting to a stop after the course is cleared counts as flying until the bus is at rest.

**Overheating.** At 100 %:

- The route is cleared and the bus coasts to a stop, as when the tank runs dry.
- No course can be set, and the drive can't charge, until the cooldown is over.
- **The cooldown** takes a fixed time and brings the temperature to 0 %, wherever the bus stands. It must: the bus has stopped inside the heat zone, where it would otherwise only hold.
- Then the bus holds in space with a cold drive, so leaving takes a charge, and it has its whole range to get out with.
- No shock and no credits. The time lost is the cost: the cooldown and the charge are about 11 s on a ride of about 20 s, which takes a passenger's on-time bonus and more. A full detour around the core costs at most about 4 s.

**Exempt.** Temperature holds at what it is, and can't overheat:

- **During the tutorial,** until the zoom out is over. The zoomed map scales distances to the star.
- **During a tow.** A tow flies straight to the nearest planet, and the player has no say in its route.

**Save game.** Temperature isn't saved. A run saves only at a planet; of those only Ember is in the heat zone, and a continued run starting cool there is harmless.

## Starting numbers

Guesses to tune by hand, not measured. Each is an exported value.

| Number | Start |
|---|---|
| Heat zone edge, from the star's centre | 6.3 units |
| Core edge | 4.0 units |
| Fall outside the zone | 10 % a second |
| Rise in the outer zone, edge to core edge | 2 % rising to 6 % a second |
| Rise in the core, core edge to the star's surface (2.4) | 6 % rising to 120 % a second |
| Cooldown | 8 s |

What they should give, to check in play:

- A plain trip into Ember and out again costs 10 to 15 %.
- A pass that clips the core's outer half unit is survivable from cool.
- A run straight at the star overheats at about the surface, not deep inside the disc. If it can't without making the core a wall, the star's disc shrinks; that is a look decision for the human.
- From 0 % and at rest, the bus escapes the zone from wherever it overheated.
- The Speed upgrades let the bus cut closer, with no rule of their own.

## What the player sees

The design is in the design file, node `Vs75z`. Read it before building any of this; where it and this section differ, the design wins, and the result goes in `docs/ui.md`.

- **A temperature gauge** on the bus bar with the fuel gauge.
- **The heat zone on the map:** where it starts, and where the core starts. The star's halo already reaches about 3.85 units, close to the core's edge.
- **A warning notice** as the temperature gets high, in the manner of the low fuel warning, and an **overheated notice** for the length of the cooldown.
- **The debug panel:** a temperature readout, and buttons to set it and to overheat.

Not in this spec, but the natural next step: the route line showing where a course crosses the core.

## Building it

- **Its own node on the bus,** beside the fuel tank, which it mirrors: it owns the number and emits a signal at 100 %. `bus.gd` is at 559 lines of a 600 limit, so the bus gains only the lock on setting a course and charging while it cools.
- **The star's position** comes from the scene. The star is a plain node under `World` today, with nothing in code that names it.
- **Words.** "Warm" and "cold" already describe the frameshift drive (`DESIGN.md`, Warm drive). Temperature needs glossary entries that don't reuse them for the bus: suggested are **temperature**, **heat zone**, **core**, **overheated** and **cooldown**.
- **Balance runs.** The scripted player flies straight and decides only at docks, so it would overheat on about a fifth of its trips. Before any balance number is trusted again, it must put a checkpoint around the core when a straight leg crosses it.
- **Tests** come once the rules settle, per the `gdunit-tests` skill.

## Open questions

- Whether overheating should also shock everyone on board (running dry is −15), if the lost time alone proves too soft.
- Whether the star's disc shrinks (see Starting numbers).
- Whether holding in space inside the zone should really hold. It follows from the Ember rule and keeps one rule for every stop, but it lets a bus park beside the core for free.
