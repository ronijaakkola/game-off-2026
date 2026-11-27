class_name FrameOrder
## Every process priority in the game, in the order they run each frame: lower runs
## first, and 0 is where a node runs when it sets none. A node sets its own with
## [code]process_priority = FrameOrder.<STAGE>[/code] in [method Node._ready], never a
## number, so moving a stage moves every node in it.

## Before the bus status panel and the HUD, which place themselves by its height: the
## route bar ([RouteBar]).
const BEFORE_HUD := -1
## After the [HeatZone] has set [member FrameshiftBus.speed_cap] for the frame, so a lower
## cap holds: the asteroid field ([AsteroidField]).
const AFTER_HEAT_ZONE := 1
## Phantom Camera's host, which sets this on itself to move the camera after everything it
## follows. It is the addon's number, not ours: a test fails if the two part.
const CAMERA_HOST := 300
## After the camera has moved: what is drawn or placed in the world where the camera now
## looks, such as the planets' names, the route line, the trip arc and the fuel forecast.
const AFTER_CAMERA := CAMERA_HOST + 1
## After the solar system has moved the planets and the camera has moved: what is placed
## on screen over a planet or the bus, such as the waiting markers, the lab badges, the
## bus's quick text and the pick-up markers. Placed any earlier, it trails them by a frame.
const SCREEN_MARKERS := AFTER_CAMERA + 1
## After the screen markers: a tooltip that follows one of them.
const MARKER_TOOLTIPS := SCREEN_MARKERS + 1
