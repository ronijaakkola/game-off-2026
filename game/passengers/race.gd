class_name Race
extends RefCounted
## A passenger's race, which shows as their skin colour and their head's build, and sets
## which kind of research point delivering them earns. For now each passenger's is picked
## at random.

enum Type { BLUE, ORANGE, GREEN }

## Each race's skin colour. Their research points show in it. Orange is darker and green
## lighter, so the two stay apart for red-green colour blindness, where both turn yellow.
const SKIN_COLORS: Dictionary[Type, Color] = {
	Type.BLUE: Color(0.4, 0.6, 1.0),
	Type.ORANGE: Color(0.98, 0.5, 0.2),
	Type.GREEN: Color(0.6, 0.9, 0.45),
}

## Each race's portrait background: a deep shade of its skin colour, so the photo as a
## whole shows the race and the skin stands out from it by lightness.
const BACKDROP_COLORS: Dictionary[Type, Color] = {
	Type.BLUE: Color(0.18, 0.24, 0.55),
	Type.ORANGE: Color(0.62, 0.25, 0.1),
	Type.GREEN: Color(0.16, 0.38, 0.22),
}


## A race picked by [param rng].
static func random(rng: RandomNumberGenerator) -> Type:
	var types := Type.values()
	return types[rng.randi_range(0, types.size() - 1)] as Type
