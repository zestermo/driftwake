class_name GadgetVeil
extends RefCounted
## The smoke clouds alive on this machine (GadgetZone registers them) and whether a captain stands in one: Stealth
## and the grunts' target check ask. No autoloads here (Stealth is named by scripts that compile before them).

static var clouds: Array = []
## (GadgetZone.REACH_Y) how far over or under a cloud's ground it still hides.
const REACH_Y := 2.5


static func veiled(p: Node3D) -> bool:
	for z in clouds:
		if z.inside(p.global_position):
			return true
	return false


## (1.30) Does a smoke cloud stand between `from` and `to` (or round either end)? Seen flat, within the cloud's
## height: nobody sees or aims through it.
static func blocks(from: Vector3, to: Vector3) -> bool:
	for z in clouds:
		var c: Vector3 = z.global_position
		if minf(from.y, to.y) > c.y + REACH_Y or maxf(from.y, to.y) < c.y - REACH_Y:
			continue
		var a := Vector2(from.x - c.x, from.z - c.z)
		var b := Vector2(to.x - c.x, to.z - c.z)
		var ab := b - a
		var k := clampf(-a.dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		if (a + ab * k).length() < float(z.radius):
			return true
	return false
