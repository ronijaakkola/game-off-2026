extends Node
## Which bus events become analytics: Talo events (Online.track) and stats (Online.add_stat).
## The one place that says what the game tracks, so wire new bus events here. Online adds it.
## Name an event after its bus event; create a stat in the Talo dashboard before adding to it.
## Nothing is tracked yet: connect each bus event in _ready(), as docs/online.md shows.
