class_name Race
extends RefCounted
## A passenger's race, which shows as their skin colour and sets which kind of research
## point delivering them earns. For now each passenger's is picked at random.

enum Type { TEAL, CORAL, MUSTARD }

## Each race's skin colour, hues the planets don't use. Their research points show in it.
const SKIN_COLORS: Dictionary[Type, Color] = {
	Type.TEAL: Color(0.3, 0.8, 0.7),
	Type.CORAL: Color(0.98, 0.52, 0.47),
	Type.MUSTARD: Color(0.95, 0.76, 0.3),
}


## A race picked by [param rng].
static func random(rng: RandomNumberGenerator) -> Type:
	var types := Type.values()
	return types[rng.randi_range(0, types.size() - 1)] as Type
