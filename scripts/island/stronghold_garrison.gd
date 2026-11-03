class_name StrongholdGarrison
extends RefCounted
## The stronghold's garrison (1.30 rework, docs/v1_30_plan.md round 3: "placed garrisons (sentries, posts, barracks)
## that react; a raised alarm brings visible reinforcements; a cleared district stays clear"). Each district holds its
## own men, placed once (POSTS) and never respawned: sentries watching its ways in, posts of men sat or stood round a
## spot, a patrol, riflemen and a sergeant. Most are fodder (FodderMarine: 2-4 blows); the riflemen and the sergeant are
## full marines (PirateGrunt, +30%, co-op scaling). Its reinforcements (StrongholdReinforce: SOURCES) come only when
## StrongholdAlarm raises the district's alarm. Then the sealed fight rooms (StrongholdEncounter), the bosses, the keep's
## gate, the officers and the Scouring. Built on every machine (camps are net spawners: the host runs them).

## How many may swing at one captain at once in a district (its reinforcements share the turns).
const ATTACKERS := 4
const FODDER := "res://scripts/enemies/fodder_marine.gd"
## Each district's men (frame xz): ["sentry", at, facing] / ["post", at, men, "sit" | "stand"] / ["patrol", loop, men] /
## ["rifle", at, facing] / ["sergeant", at, facing].
const POSTS := {
	"landing": [
		["sentry", Vector2(-8, 38), Vector2(0, 1)], ["sentry", Vector2(8, 38), Vector2(0, 1)],
		["sentry", Vector2(-36, 60), Vector2(0, 1)], ["sentry", Vector2(42, 60), Vector2(0, 1)],
		["post", Vector2(-16, 45), 3, "sit"], ["post", Vector2(26, 46), 3, "stand"],
		["patrol", [Vector2(-50, 57), Vector2(50, 57)], 2],
		["rifle", Vector2(-2, 55), Vector2(0, 1)],
	],
	"ward": [
		["sentry", Vector2(-7, 18), Vector2(0, 1)], ["sentry", Vector2(7, 18), Vector2(0, 1)],
		["sentry", Vector2(-40, -12), Vector2(-1, 0)], ["sentry", Vector2(40, -12), Vector2(1, 0)],
		["post", Vector2(0, 4), 4, "sit"], ["post", Vector2(-9, -7), 3, "stand"], ["post", Vector2(10, 11), 3, "stand"],
		["patrol", [Vector2(-14, 15), Vector2(14, 15), Vector2(14, -10), Vector2(-14, -10)], 2],
		["rifle", Vector2(-15, 13), Vector2(0, 1)], ["rifle", Vector2(15, 13), Vector2(0, 1)],
		["sergeant", Vector2(0, -9), Vector2(0, 1)],
	],
	"arsenal": [
		["sentry", Vector2(57, -1), Vector2(-1, 0)], ["sentry", Vector2(65.5, -28), Vector2(-1, 0)],
		["post", Vector2(82, 6), 4, "sit"], ["post", Vector2(104, -20), 3, "stand"],
		["patrol", [Vector2(58, 10), Vector2(106, 10)], 2],
		["rifle", Vector2(60, -40), Vector2(0, 1)], ["rifle", Vector2(106, 10), Vector2(-1, 0)],
		["sergeant", Vector2(75, -2), Vector2(-1, 0)],
	],
	"prison": [
		["sentry", Vector2(-57, -1), Vector2(1, 0)], ["sentry", Vector2(-103, -14), Vector2(1, 0)],
		["post", Vector2(-62, -38), 4, "sit"], ["post", Vector2(-100, 8), 3, "stand"],
		["patrol", [Vector2(-64, -20), Vector2(-82, -36), Vector2(-100, -20), Vector2(-82, -1)], 3],
		["rifle", Vector2(-61, -41), Vector2(-1, 0)], ["rifle", Vector2(-108, -40), Vector2(1, 0)],
		["sergeant", Vector2(-66, -8), Vector2(1, 0)],
	],
	"keep": [
		["sentry", Vector2(-5, -51), Vector2(0, 1)], ["sentry", Vector2(5, -51), Vector2(0, 1)],
		["sentry", Vector2(-7, -60), Vector2(0, 1)], ["sentry", Vector2(7, -60), Vector2(0, 1)],
		["post", Vector2(19, -55), 4, "stand"], ["post", Vector2(-36, -80), 3, "sit"],
		["patrol", [Vector2(-30, -52), Vector2(30, -52)], 2],
		["rifle", Vector2(-34, -55), Vector2(0, 1)], ["rifle", Vector2(34, -55), Vector2(0, 1)],
		["sergeant", Vector2(0, -56), Vector2(0, 1)],
	],
}
## Where each district's reinforcements come from (StrongholdReinforce): [kind, frame xz, the way out].
const SOURCES := {
	"landing": [["boat", Vector2(-30, 66), Vector2(0, 1)], ["boat", Vector2(52, 66), Vector2(0, 1)]],
	"ward": [["door", Vector2(22, 1), Vector2(-1, 0)], ["door", Vector2(-22, 1), Vector2(1, 0)]],
	"arsenal": [["door", Vector2(72, -23), Vector2(-1, 0)]],
	"prison": [["gate", Vector2(-66.5, -18), Vector2(1, 0)]],
	"keep": [["door", Vector2(0, -66), Vector2(0, 1)]],
}
## The rooms that are sealed fights (StrongholdPlan.ROOMS keys).
const SEALED := ["mess"]


## The districts' garrisons, their reinforcements and the alarm, the sealed rooms, the bosses and the rest; and their
## nav zones (the island's NavBaker).
static func build(isl: Node3D) -> Array:
	var out: Array = []
	var baker: Node = isl.get_parent().get_node_or_null("NavBaker")
	var squads := {}
	var sources := {}
	for d in StrongholdPlan.DISTRICTS:
		var key := str(d[0])
		var camp := _squad(isl, key, d[1], float(d[2]))
		isl.city.add_child(camp)
		out.append(camp)
		squads[key] = camp
		if baker:
			baker.add_zone(camp, 70.0, false, isl.nav_faces)
		for i in range((StrongholdBell.BELLS[key] as Array).size()):
			isl.city.add_child(StrongholdBell.build(isl, key, i))
		sources[key] = []
		var srcs: Array = SOURCES[key]
		for i in range(srcs.size()):
			var s: Array = srcs[i]
			var r := StrongholdReinforce.new().setup(isl, key, str(s[0]), s[1], s[2], i)
			r.squad = camp
			isl.city.add_child(r)
			out.append(r)
			sources[key].append(r)
	# the acts' pieces: the Landing's gate, the Verdict's roof and its hoist, grapple ledges, the supply chest
	out.append_array(StrongholdActs.build(isl))
	var alarm := StrongholdAlarm.new().setup(isl, squads, sources)
	isl.city.add_child(alarm)
	out.append(alarm)
	for rm in StrongholdPlan.ROOMS:
		if not str(rm[0]) in SEALED:
			continue
		var enc := StrongholdEncounter.new().setup(isl, rm)
		isl.city.add_child(enc)
		out.append(enc)
		if baker:
			baker.add_zone(enc, 24.0, false, isl.nav_faces)
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
	# the broadcast and the Scouring once the Commodore falls (StrongholdScouring)
	var sc := StrongholdScouring.new().setup(isl, out.duplicate())
	isl.city.add_child(sc)
	out.append(sc)
	return out


## Every man a district's POSTS place, as camp specs round `mid` (its middle): [frame xz, spec].
static func men(key: String) -> Array:
	var out: Array = []
	var n := 0
	for e: Array in POSTS[key]:
		match str(e[0]):
			"sentry":
				out.append([e[1], _man(key, n, e[1], e[2], "fodder", {"sentry": true})])
				n += 1
			"post":
				var c: Vector2 = e[1]
				var k: int = e[2]
				for i in range(k):
					var a := TAU * float(i) / float(k) + 0.4
					var q := c + Vector2(cos(a), sin(a)) * 1.7
					out.append([q, _man(key, n, q, c - q, "fodder", {"mode": str(e[3]), "seat_y": 0.2})])
					n += 1
			"patrol":
				var loop: Array = e[1]
				for i in range(int(e[2])):
					var q: Vector2 = loop[i % loop.size()]
					out.append([q, _man(key, n, q, Vector2(0, 1), "fodder", {"mode": "patrol", "loop": loop, "start": i})])
					n += 1
			"rifle":
				out.append([e[1], _man(key, n, e[1], e[2], "rifle", {})])
				n += 1
			"sergeant":
				out.append([e[1], _man(key, n, e[1], e[2], "sergeant", {})])
				n += 1
	return out


static func _man(key: String, i: int, _at: Vector2, f: Vector2, tier: String, extra: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["garrison", key, i])
	var lk := PirateGrunt.crew_look(rng)
	EnemyShip.marine_look(lk, rng, tier == "sergeant")
	var c := {"yaw": atan2(-f.x, -f.y), "mode": str(extra.get("mode", "stand")), "look": lk, "seed": hash(["garrison", key, i]),
		"title": "Admiralty sergeant" if tier == "sergeant" else "Admiralty marine", "role": "rifle" if tier == "rifle" else "sword"}
	if tier == "fodder":
		c["script"] = FODDER
		c["sentry"] = bool(extra.get("sentry", false))
	if tier == "sergeant":
		c["elite"] = true
	for k in extra:
		if k not in ["mode", "sentry", "loop", "start"]:
			c[k] = extra[k]
	if extra.has("loop"):
		c["loop"] = extra["loop"]
		c["start"] = extra["start"]
	return c


## A district's garrison: one camp at its middle holding every man POSTS places, never respawned.
static func _squad(isl: Node3D, key: String, rect: Rect2, y: float) -> GruntCamp:
	var mid := rect.get_center()
	var camp := GruntCamp.new()
	camp.name = "Garrison_" + key
	camp.warm_start = true
	camp.respawn_time = 1.0e9
	camp.max_attackers = ATTACKERS
	camp.level = int(isl.node["level"]) + (1 if key == "keep" else 0)
	camp.position = Vector3(mid.x, y, mid.y)
	for m: Array in men(key):
		var q: Vector2 = m[0]
		var c: Dictionary = m[1]
		var g := StrongholdPlan.ground(q)
		var ly := (g if g > -INF else y) - y
		c["post"] = Vector3(q.x - mid.x, ly, q.y - mid.y)
		if c.has("loop"):
			var loop: Array = c["loop"]
			var pts: Array = []
			for k in range(loop.size()):
				var p: Vector2 = loop[(k + int(c["start"])) % loop.size()]
				pts.append(Vector3(p.x - mid.x, ly, p.y - mid.y))
			c["patrol"] = pts
			c["post"] = pts[0]
			c.erase("loop")
			c.erase("start")
		camp.add_grunt(c)
	return camp
