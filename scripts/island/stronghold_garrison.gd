class_name StrongholdGarrison
extends RefCounted
## The stronghold's garrison (1.27, preview v2 "Spawns: the fortress refills"): a squad of Admiralty marines patrolling
## each district's open ground (PATROLS), a rifleman among them; a squad wiped out comes back RESPAWN s later once no
## captain is within CLEARANCE of it (GruntCamp's own respawn). And the sealed fight rooms (StrongholdEncounter): the
## Mess Hall first. Built on every machine (camps are net spawners: the host runs them), under the island's City node.

const RESPAWN := 90.0
const CLEARANCE := 30.0
## Each district's squad: [size, its patrol loop (frame points, round the open ground clear of its buildings)].
const PATROLS := {
	"landing": [4, [Vector2(-40, 48), Vector2(40, 48), Vector2(40, 40), Vector2(-40, 40)]],
	"ward": [5, [Vector2(-10, 16), Vector2(10, 16), Vector2(10, -12), Vector2(-10, -12)]],
	"arsenal": [4, [Vector2(60, 8), Vector2(104, 8), Vector2(104, -42), Vector2(60, -42)]],
	"prison": [4, [Vector2(-60, 8), Vector2(-104, 8), Vector2(-104, -42), Vector2(-60, -42)]],
	"keep": [4, [Vector2(-34, -54), Vector2(34, -54), Vector2(34, -58), Vector2(-34, -58)]],
}
## The rooms that are sealed fights (StrongholdPlan.ROOMS keys).
const SEALED := ["mess"]


## The squads and the sealed rooms, and their nav zones (the island's NavBaker).
static func build(isl: Node3D) -> Array:
	var out: Array = []
	var baker: Node = isl.get_parent().get_node_or_null("NavBaker")
	for d in StrongholdPlan.DISTRICTS:
		var key := str(d[0])
		if not PATROLS.has(key):
			continue
		var camp := _squad(isl, key, float(d[2]))
		isl.city.add_child(camp)
		out.append(camp)
		if baker:
			baker.add_zone(camp, 70.0, false, isl.nav_faces)
	for rm in StrongholdPlan.ROOMS:
		if not str(rm[0]) in SEALED:
			continue
		var enc := StrongholdEncounter.new().setup(isl, rm)
		isl.city.add_child(enc)
		out.append(enc)
		if baker:
			baker.add_zone(enc, 24.0, false, isl.nav_faces)
	# the bosses in their arenas (StrongholdBoss): Lieutenant Kesh in the Casting Hall so far
	for bkey in StrongholdBoss.BOSSES:
		var boss := StrongholdBoss.new().setup(isl, str(bkey))
		isl.city.add_child(boss)
		out.append(boss)
	# the keep's gate, shut until both seals are taken
	var sg := StrongholdBoss.SealGate.new()
	isl.city.add_child(sg)
	out.append(sg)
	# the officers sprinkled in: one per district as you reach it, then a chance with each new wave (StrongholdOfficers)
	var off := StrongholdOfficers.new().setup(isl, out.filter(func(c): return c is GruntCamp))
	isl.city.add_child(off)
	out.append(off)
	return out


## A district's squad: marines patrolling its loop (each starting at its own corner), the last a rifleman.
static func _squad(isl: Node3D, key: String, y: float) -> GruntCamp:
	var p: Array = PATROLS[key]
	var n: int = p[0]
	var loop: Array = p[1]
	var mid := Vector2.ZERO
	for q: Vector2 in loop:
		mid += q / loop.size()
	var camp := GruntCamp.new()
	camp.name = "Garrison_" + key
	camp.warm_start = true
	camp.respawn_time = RESPAWN
	camp.respawn_clearance = CLEARANCE
	camp.level = int(isl.node["level"]) + (1 if key == "keep" else 0)
	camp.position = Vector3(mid.x, y, mid.y)
	for i in range(n):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(["garrison", key, i])
		var lk := PirateGrunt.crew_look(rng)
		EnemyShip.marine_look(lk, rng, false)
		var pts: Array = []
		for k in range(loop.size()):
			var q: Vector2 = loop[(k + i) % loop.size()] - mid
			pts.append(Vector3(q.x, 0.0, q.y))
		camp.add_grunt({"post": pts[0], "yaw": 0.0, "mode": "patrol", "patrol": pts, "look": lk, "title": "Admiralty marine",
			"seed": hash(["garrison", key, i]), "role": "rifle" if i == n - 1 else "sword"})
	return camp
