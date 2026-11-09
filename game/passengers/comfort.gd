class_name Comfort
extends RefCounted
## What the bus's comfort upgrades give everyone on board: a bonus on the happiness they
## settle at, whether and how long they sleep, with how fast their ride's clock runs then,
## and whether and how long they watch shows, with how fast the clock runs while they do. A
## bare bus gives nothing: nobody sleeps or watches. [method from_traits] reads it off the
## bus's traits, which the upgrades give.

## The entertainment system: fun, and shows to watch now and then, in seconds, with the
## clock speed while watching.
const ENTERTAINMENT_BONUS := 12.0
const SHOW_MIN := 8.0
const SHOW_MAX := 12.0
const WATCH_CLOCK := 0.7
## The gaming system: more fun on top, and with the entertainment system, longer shows.
const GAMING_BONUS := 8.0
const BINGE_MIN := 15.0
const BINGE_MAX := 25.0
## Pillows: short naps, in seconds, and the clock speed while napping.
const PILLOW_NAP_MIN := 4.0
const PILLOW_NAP_MAX := 8.0
const PILLOW_CLOCK := 0.6
## Sleeping pods: long sleeps, and a slower clock while asleep. They beat pillows.
const POD_SLEEP_MIN := 15.0
const POD_SLEEP_MAX := 25.0
const POD_CLOCK := 0.4

## Added to the happiness every passenger settles at.
var bonus := 0.0
## How long each sleep lasts, a random while between these, in seconds. Nobody sleeps
## while the longest is 0.
var sleep_min := 0.0
var sleep_max := 0.0
## How fast a passenger's ride clock runs while asleep, as a multiple of real time.
var sleep_clock := 1.0
## How long each show lasts, a random while between these, in seconds. Nobody watches
## while the longest is 0.
var watch_min := 0.0
var watch_max := 0.0
## How fast a passenger's ride clock runs while they watch a show.
var watch_clock := 1.0


## The comfort the bus's [param traits] give.
static func from_traits(traits: BusTraits) -> Comfort:
	var comfort := Comfort.new()
	if traits.has(BusTraits.Type.ENTERTAINMENT_SYSTEM):
		comfort.bonus += ENTERTAINMENT_BONUS
		comfort.watch_clock = WATCH_CLOCK
		comfort.watch_min = SHOW_MIN
		comfort.watch_max = SHOW_MAX
	if traits.has(BusTraits.Type.GAMING_SYSTEM):
		comfort.bonus += GAMING_BONUS
		if comfort.can_watch():
			comfort.watch_min = BINGE_MIN
			comfort.watch_max = BINGE_MAX
	if traits.has(BusTraits.Type.SLEEPING_PODS):
		comfort.sleep_min = POD_SLEEP_MIN
		comfort.sleep_max = POD_SLEEP_MAX
		comfort.sleep_clock = POD_CLOCK
	elif traits.has(BusTraits.Type.PILLOWS):
		comfort.sleep_min = PILLOW_NAP_MIN
		comfort.sleep_max = PILLOW_NAP_MAX
		comfort.sleep_clock = PILLOW_CLOCK
	return comfort


## Whether passengers sleep at all.
func can_sleep() -> bool:
	return sleep_max > 0.0


## Whether passengers watch shows at all.
func can_watch() -> bool:
	return watch_max > 0.0
