extends Node
## The signal bus: every bus event, a past-tense fact that parts of the game which
## don't know each other react to. Add an event only when something listens.
##
## There are none yet. Declare one like this, with its ## comment right above it:
## [codeblock]
## ## A passenger got off at their destination with [param rating] stars.
## signal passenger_delivered(rating: int)
## [/codeblock]

# Bus events are emitted by other scripts, never here.
@warning_ignore_start("unused_signal")
