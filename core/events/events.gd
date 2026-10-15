extends Node
## The signal bus: every bus event, a past-tense fact that parts of the game which
## don't know each other react to. Add an event only when something listens.

# Bus events are emitted by other scripts, never here.
@warning_ignore_start("unused_signal")

## A piece was placed on the board at [param position] (world space).
signal piece_placed(position: Vector3)
