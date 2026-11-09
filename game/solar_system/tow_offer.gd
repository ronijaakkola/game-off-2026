class_name TowOffer
extends Control
## The bar across the lower half of the screen once the bus has run out of fuel in space:
## "You ran out of fuel" at one end and a button to request a tow, with its price, at the
## other. [method offer] shows it and [method close] hides it; the button emits
## [signal requested] and nothing else, so the owner sends the tow and closes the bar.

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
