class_name ForestPlaces
extends RefCounted
## The forest's places on the theme place hooks (ForestTheme.place_kind / plan_places / plan_place /
## place_steps): which chain set pieces and landmarks its own kinds stand in for.

const KINDS := {}


static func plan(_isl, _kind: String, _rng: RandomNumberGenerator, _avoid: Array) -> Dictionary:
	return {}


static func steps(_isl, _ctx, _pl: Dictionary) -> Array:
	return []
