class_name GadgetVeil
extends RefCounted
## The smoke clouds alive on this machine (GadgetZone registers them) and whether a captain stands in one: Stealth
## and the grunts' target check ask. No autoloads here (Stealth is named by scripts that compile before them).

static var clouds: Array = []


static func veiled(p: Node3D) -> bool:
	for z in clouds:
		if z.inside(p.global_position):
			return true
	return false
