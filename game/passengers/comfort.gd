class_name Comfort
extends RefCounted
## What the bus's comfort upgrades give everyone on board: a bonus on the happiness they
## settle at, how fast their ride's clock runs while awake, and whether and how long they
## sleep, with how fast the clock runs then. A bare bus gives nothing, and nobody sleeps.
## [method from_traits] reads it off the bus's traits, which the upgrades give.

## Gamepads: a little fun. Its bonus and awake clock speed.
const GAMEPADS_BONUS := 8.0
const GAMEPADS_CLOCK := 0.95
## The entertainment system: more fun, on top of the gamepads'.
const ENTERTAINMENT_BONUS := 12.0
const ENTERTAINMENT_CLOCK := 0.9
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
## How fast a passenger's ride clock runs while awake, as a multiple of real time.
var clock := 1.0
## How long each sleep lasts, a random while between these, in seconds. Nobody sleeps
## while the longest is 0.
var sleep_min := 0.0
var sleep_max := 0.0
## How fast a passenger's ride clock runs while asleep.
var sleep_clock := 1.0


## The comfort the bus's [param traits] give.
static func from_traits(traits: BusTraits) -> Comfort:
	var comfort := Comfort.new()
	if traits.has(BusTraits.Type.GAMEPADS):
		comfort.bonus += GAMEPADS_BONUS
		comfort.clock *= GAMEPADS_CLOCK
	if traits.has(BusTraits.Type.ENTERTAINMENT_SYSTEM):
		comfort.bonus += ENTERTAINMENT_BONUS
		comfort.clock *= ENTERTAINMENT_CLOCK
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
