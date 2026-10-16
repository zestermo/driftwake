extends SceneTree
## Jungle fauna (scripts/enemies/fauna/, FaunaSpawner): the first chain island
## rolls its pool and fills its zones (the same for the same seed, different
## seeds differ); far away it's all asleep and hidden, near it wakes; each
## creature, spawned beside the captain on Brinehollow, does its thing (boar
## charge, piglet flight, mantis leap, roller roll, mites, burrower eruption,
## bat and toucan swoops, monkey throw, snake strike with venom, crab pinch),
## flinches, dies with coins, XP and its drop; levels scale health; the cost of
## the island's fauna at a busy spot.
var t := 0.0
var step := 0
var wait := 0.0
var fails := 0
var p
var world
var isl
var fauna
var holder: Node3D
var c
var seen := {}
var queue: Array = []
var cur: Array = []
var start := Vector3.ZERO
var acc := {}
var frames := 0
## (loaded once the world is up, not named: a --script compiles before the autoloads Creature and FaunaSpawner use exist)
var FS
var CR
var PS

## [kind, args, offset from the captain (x along, y up for anchors), seconds, states wanted (any of), label]
const CASES := [
	["boar", {}, Vector3(3.0, 0, 0), 4.0, [4, 5], "boar paws and charges when crowded"],
	["boar", {"young": true}, Vector3(4.5, 0, 0), 2.0, [7], "piglet bolts"],
	["leaper", {}, Vector3(6.0, 0, 0), 4.0, [4, 5], "mantis crouches and leaps"],
	["roller", {}, Vector3(6.0, 0, 0), 4.0, [4, 5], "roller curls and rolls"],
	["mite", {}, Vector3(4.0, 0, 0), 3.0, [3, 5], "mite swarms in and nips"],
	["burrower", {}, Vector3(5.0, 0, 0), 7.0, [4, 5, 14], "burrower rumbles and erupts"],
	["bat", {"anchor": Vector3(2.0, 4.0, 0)}, Vector3(2.0, 0, 0), 7.0, [12, 5], "bat drops off its roost and swoops"],
	["toucan", {"anchor": Vector3(3.0, 7.0, 0)}, Vector3(3.0, 0, 0), 8.0, [12, 5], "toucan dives"],
	["monkey", {"anchor": Vector3(10.0, 6.0, 0)}, Vector3(10.0, 0, 0), 3.0, [4], "monkey throws fruit"],
	["snake", {}, Vector3(2.5, 0, 0), 3.0, [4, 5], "snake rears and strikes"],
	["crab", {}, Vector3(2.5, 0, 0), 4.0, [3, 4, 5], "crab clacks and pinches"],
]


func _initialize():
	load("res://tools/dev/test_kit.gd").seed_of(self)
	change_scene_to_file("res://scenes/world/world.tscn")


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		fails += 1


func finish() -> void:
	print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	quit()


func ground(at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 20.0, at + Vector3.DOWN * 40.0, 1)
	var hit: Dictionary = root.get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else at


func heal() -> void:
	p.health_component.max_health = 9000.0
	p.health_component.current_health = 9000.0
	for n in p.get_children():
		if is_instance_of(n, PS):
			n.queue_free()


func spawn(k: String, args: Dictionary, off: Vector3):
	var base: Vector3 = p.global_position
	var a := args.duplicate()
	if a.has("anchor"):
		a["anchor"] = ground(base + Vector3((a["anchor"] as Vector3).x, 0, 0)) + Vector3.UP * (a["anchor"] as Vector3).y
	var home := ground(base + Vector3(off.x, 0, off.z))
	var cr = FS.make("jungle", k)
	cr.setup(home, a)
	cr.name = "T_%s_%d" % [k, step]
	cr.position = holder.to_local(home) + Vector3.UP * 0.2
	holder.add_child(cr)
	return cr


func _process(d: float) -> bool:
	t += d
	if t > 300.0:
		check("timed out at step %d" % step, false)
		finish()
		return true
	if c and is_instance_valid(c):
		seen[int(c.state)] = true
	if wait > 0.0:
		wait -= d
		if step == 4:
			acc["frame"] = acc.get("frame", 0.0) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) + Performance.get_monitor(Performance.TIME_PROCESS)
			frames += 1
		return false
	match step:
		0:
			if t < 1.5:
				return false
			p = get_first_node_in_group("player")
			world = root.get_node("World/Islands")
			if not world.chain_ready():
				return false
			FS = load("res://scripts/island/fauna_spawner.gd")
			CR = load("res://scripts/enemies/fauna/creature.gd")
			PS = load("res://scripts/combat/poison_status.gd")
			isl = world.chain_islands[world.chain().start_next[0]]
			fauna = FS.of(isl)
			start = p.global_position
			check("the island has its fauna", fauna != null)
			var kinds: Array = fauna.pool.keys().filter(func(k): return k != "morph" and k != "ambient")
			var counts := {}
			for s in fauna.spots:
				counts[s["kind"]] = int(counts.get(s["kind"], 0)) + 1
			print("   %s (seed %d): %d creatures in %d groups %s, zones floor %d canopy %d shore %d, built in %d ms" % [isl.island_name, int(isl.node["seed"]),
				fauna.spots.size(), fauna.groups.size(), counts, fauna.zones["floor"].size(), fauna.zones["canopy"].size(), fauna.zones["shore"].size(), int(isl.build_ms.get("fauna", -1))])
			check("a pool of several kinds (%d)" % kinds.size(), kinds.size() >= FS.MIN_KINDS and kinds.size() <= FS.MAX_KINDS)
			check("a good number of creatures (%d)" % fauna.spots.size(), fauna.spots.size() >= 15 and fauna.spots.size() <= FS.CAP + 10)
			check("they all stood up", fauna.alive_count() == fauna.spots.size())
			check("same seed, same pool", JSON.stringify(FS.roll("jungle", 1234)) == JSON.stringify(FS.roll("jungle", 1234)))
			var rolls := {}
			for s in range(8):
				var r: Dictionary = FS.roll("jungle", 1000 + s * 77)
				rolls[JSON.stringify(r.keys().filter(func(k): return k != "morph" and k != "ambient"))] = true
			print("   8 seeds, %d different line-ups of kinds" % rolls.size())
			check("different seeds, different islands", rolls.size() >= 4)
			check("data for others: groups with roles", fauna.groups.all(func(g): return g.has("role") and g.has("at")))
			check("ambient life", isl.find_children("Swarm", "MultiMeshInstance3D", true, false).size() + isl.find_children("Flock", "MultiMeshInstance3D", true, false).size() > 0)
			# (an island's seed, not the chain's: 2749453084's island once had none)
			var bare: Array = []
			for s in [2749453084] + range(3000):
				var amb: Dictionary = FS.roll("jungle", s)["ambient"]
				if not (amb["butterflies"] or amb["fireflies"]) and int(amb["flocks"]) == 0:
					bare.append(s)
			check("every island's roll has ambient life, swarms by day or night or flocks (bare: %s)" % [bare.slice(0, 6)], bare.is_empty())
			wait = 0.6
			step = 1
		1:
			# the captain's on Brinehollow, far off: all asleep and hidden
			var awake := 0
			var shown := 0
			for s in fauna.spots:
				var cr = s["node"]
				if cr.is_physics_processing():
					awake += 1
				if cr.model.visible:
					shown += 1
			check("far away: asleep (%d awake)" % awake, awake == 0)
			check("far away: hidden (%d shown)" % shown, shown == 0)
			# go stand by a group on the island floor
			var g = fauna.groups.filter(func(g): return g["zone"] == "floor")
			var at: Vector3 = isl.to_global(g[0]["at"] if not g.is_empty() else fauna.spots[0]["at"])
			p.state_machine.force_state("Idle", {})
			p.global_position = at + Vector3(4.0, 1.0, 0)
			p.reset_physics_interpolation()
			heal()
			wait = 1.2
			step = 2
		2:
			var near := 0
			var near_awake := 0
			var far_hidden := true
			for s in fauna.spots:
				var cr = s["node"]
				var dd: float = cr.global_position.distance_to(p.global_position)
				if dd < 25.0:
					near += 1
					if cr.is_physics_processing() and cr.model.visible:
						near_awake += 1
				elif dd > 130.0 and cr.model.visible:
					far_hidden = false
			print("   by the group: %d creatures within 25 m, %d awake" % [near, near_awake])
			check("near: awake", near > 0 and near_awake == near)
			check("far ones stay hidden", far_hidden)
			frames = 0
			acc.clear()
			wait = 2.0
			step = 4
		4:
			var on: float = acc["frame"] / maxf(frames, 1)
			for s in fauna.spots:
				s["node"].set_lod(CR.LOD_SLEEP)
			fauna.process_mode = Node.PROCESS_MODE_DISABLED
			acc["on"] = on
			acc["frame"] = 0.0
			frames = 0
			wait = 2.0
			step = 5
		5:
			var off: float = acc["frame"] / maxf(frames, 1)
			var awake := 0
			for s in fauna.spots:
				if (s["node"] as Node3D).global_position.distance_to(p.global_position) < 70.0:
					awake += 1
			print("COST fauna at a busy spot: %d creatures within 70 m; process+physics %.2f ms with them, %.2f ms asleep: %.2f ms" % [awake, acc["on"] * 1000.0, off * 1000.0, (acc["on"] - off) * 1000.0])
			fauna.process_mode = Node.PROCESS_MODE_INHERIT
			# back home for the line-up of single creatures
			p.global_position = start + Vector3.UP
			p.reset_physics_interpolation()
			holder = Node3D.new()
			holder.name = "FaunaTest"
			current_scene.add_child(holder)
			queue = CASES.duplicate()
			wait = 0.8
			step = 6
		6:
			if queue.is_empty():
				step = 9
				return false
			cur = queue.pop_front()
			heal()
			p.state_machine.force_state("Idle", {})
			p.velocity = Vector3.ZERO
			seen.clear()
			c = spawn(cur[0], cur[1], cur[2])
			wait = float(cur[3])
			step = 7
		7:
			var want: Array = cur[4]
			var got := want.any(func(s): return seen.has(s))
			print("   %s: states %s" % [cur[0], seen.keys()])
			check(cur[5], got)
			if cur[0] == "snake":
				check("the bite poisoned the captain", p.get_node_or_null("Poison") != null or seen.has(5))
			# a light blow: it flinches (or shrugs it off rolled up / dives away)
			c.velocity = Vector3.ZERO
			var hp0: float = c.health.current_health
			var hit := HitData.new()
			hit.damage = 5.0
			hit.knockback_force = 4.0
			c.hurtbox.take_hit(hit, p)
			check("%s takes a hit" % cur[0], c.health.current_health < hp0)
			wait = 0.4
			step = 8
		8:
			c.drops = [["tusk", 1.0, 1]]
			var coins0 := current_scene.find_children("Coin*", "", false, false).size()
			var drops0 := current_scene.find_children("Drop_*", "", false, false).size()
			var hit := HitData.new()
			hit.damage = 99999.0
			hit.knockback_force = 6.0
			c.hurtbox.take_hit(hit, p)
			check("%s dies" % cur[0], c.is_dead())
			check("%s drops its loot" % cur[0], current_scene.find_children("Drop_*", "", false, false).size() > drops0)
			if cur[0] == "boar" and not cur[1].has("young"):
				check("coins", current_scene.find_children("Coin*", "", false, false).size() > coins0)
			wait = 0.3
			step = 6
		9:
			# levels scale it
			var lo = FS.make("jungle", "boar")
			lo.setup(p.global_position + Vector3(50, 0, 0), {})
			lo.level = 3
			var hi = FS.make("jungle", "boar")
			hi.setup(p.global_position + Vector3(52, 0, 0), {})
			hi.level = 18
			holder.add_child(lo)
			holder.add_child(hi)
			check("a level 18 boar is tougher than a level 3 (%d vs %d)" % [hi.health.max_health, lo.health.max_health], hi.health.max_health > lo.health.max_health * 1.5)
			check("dead ones sink away", holder.get_children().filter(func(n): return is_instance_of(n, CR) and n.is_dead()).size() < CASES.size())
			finish()
			return true
	return false
