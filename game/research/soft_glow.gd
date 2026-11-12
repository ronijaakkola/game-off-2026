class_name SoftGlow
extends RefCounted
## Soft shadows and glows as a design tool's blur draws them: a shape blurred by a Gaussian,
## full strength well inside, half at its edge and fading out about the blur past it. Each
## mask is worked out once, from the shape's signed distance, and kept; a caller draws it
## tinted with the shadow's colour. A box's own shadow fades straight from full strength at
## the edge instead, which reads as a ring.

# The masks made so far, by their shape and blur.
static var _masks: Dictionary[String, ImageTexture] = {}


## How far past a shape's edge a mask of [param blur] reaches, in pixels.
static func get_reach(blur: float) -> float:
	return ceilf(blur * 1.5) + 1.0


## A white mask of a rounded rectangle of [param size] and [param radius] blurred by
## [param blur], the CSS blur radius (twice the Gaussian's spread). It covers the shape and
## [method get_reach] round it.
static func box(size: Vector2, radius: float, blur: float) -> ImageTexture:
	var key := "box %s %s %s" % [size, radius, blur]
	if _masks.has(key):
		return _masks[key]
	var reach := get_reach(blur)
	var full := size + Vector2.ONE * reach * 2.0
	# Half the pixels: the mask is smooth, and drawn filtered it looks the same.
	var width := ceili(full.x * 0.5)
	var height := ceili(full.y * 0.5)
	var image := Image.create_empty(width, height, false, Image.FORMAT_LA8)
	var half := size * 0.5
	var spread := maxf(blur * 0.5, 0.01) * sqrt(2.0)
	for y: int in height:
		for x: int in width:
			var at := Vector2(x + 0.5, y + 0.5) * full / Vector2(width, height)
			var from_centre := (at - full * 0.5).abs() - (half - Vector2.ONE * radius)
			var outside := from_centre.max(Vector2.ZERO).length()
			var distance := outside + minf(maxf(from_centre.x, from_centre.y), 0.0) - radius
			image.set_pixel(x, y, Color(1, 1, 1, 0.5 * _erfc(distance / spread)))
	_masks[key] = ImageTexture.create_from_image(image)
	return _masks[key]


## A white mask across a line [param width] pixels wide blurred by [param blur]: one
## column, to stretch along the line. It covers the line and [method get_reach] each side.
static func line(width: float, blur: float) -> ImageTexture:
	var key := "line %s %s" % [width, blur]
	if _masks.has(key):
		return _masks[key]
	var reach := get_reach(blur)
	var across := ceili(width + reach * 2.0)
	var image := Image.create_empty(1, across, false, Image.FORMAT_LA8)
	var spread := maxf(blur * 0.5, 0.01) * sqrt(2.0)
	for x: int in across:
		var from_centre := x + 0.5 - across * 0.5
		var strength := (
			0.5
			* (
				_erfc((from_centre - width * 0.5) / spread)
				- _erfc((from_centre + width * 0.5) / spread)
			)
		)
		image.set_pixel(0, x, Color(1, 1, 1, strength))
	_masks[key] = ImageTexture.create_from_image(image)
	return _masks[key]


# The complementary error function, to about 1e-7 (Abramowitz and Stegun, 7.1.26).
static func _erfc(x: float) -> float:
	var t := 1.0 / (1.0 + 0.3275911 * absf(x))
	var poly := (
		t
		* (
			0.254829592
			+ t * (-0.284496736 + t * (1.421413741 + t * (-1.453152027 + t * 1.061405429)))
		)
	)
	var tail := poly * exp(-x * x)
	return tail if x >= 0.0 else 2.0 - tail
