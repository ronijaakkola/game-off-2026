class_name TowOffer
extends Control
## A warning notice above the bus bars once the bus has run out of fuel in space: "You
## ran out of fuel" and a button to request a tow, with its price. [method offer] shows it
## and [method close] hides it; the button emits [signal requested] and nothing else, so the
## owner sends the tow and closes the notice.

## The player pressed the button.
signal requested


func _ready() -> void:
	hide()
	(%RequestButton as Button).pressed.connect(requested.emit)


## Shows the bar, with a tow costing [param fee] credits.
func offer(fee: int) -> void:
	(%RequestButton as Button).text = "Request a tow (%d credits)" % fee
	show()


func close() -> void:
	hide()
