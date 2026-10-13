extends SceneTree
## The jungle's other bosses, its alpha boar and its roaming beast, on the first
## chain island (BeastArena.rebuild swaps each boss in): for the Strangler, the
## Shade and the Mantis Queen: asleep, woken by a captain coming close (its
## opening move), each of its moves lands on a captain standing where it aims,
## a phase change, everyone leaving resets it (healed, asleep), the kill (the
## victory, the flag, its hoard with its trophy) and its level scaling. The pool:
## over many chains no island's boss is the one before it on any route, every
## kind turns up, the same seed gives the same beasts; POIs. The boar wakes in
## its wallow and charges; the roamer grazes, turns on a captain and stomps.
var t := 0.0
var started := false
var p
var gm
var world
var isl
var arena
var boss
var fails := 0
## (loaded, not named: these reach the autoloads, which don't exist yet when a test script compiles)
var Arena
var Pool
var ChainK
const FIGHT := 1
const RETURN := 3
const MOVES := {
	"serpent": [["strike", 4.0, 1.6], ["sweep", 0.0, 1.3], ["coil", 3.0, 3.0], ["tree", 7.0, 8.0], ["ambush", 7.0, 9.0]],
	"stalker": [["claws", 3.0, 1.8], ["pounce", 9.0, 1.6], ["lash", 2.5, 1.2], ["stalk", 8.0, 9.0]],
	"mantis": [["scythe", 3.5, 1.5], ["snap", 6.0, 1.3], ["display", 4.0, 1.4], ["flit", 7.0, 4.0], ["whirl", 2.5, 1.6]],
}


func _initialize():
	change_scene_to_file("res://scenes/world/world.tscn")


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		fails += 1


func finish() -> void:
	print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	quit()


func _process(d: float) -> bool:
	t += d
	if t > 560.0:
		check("timed out", false)
		finish()
		return true
	if started or t < 1.5:
		return false
	world = root.get_node_or_null("World/Islands")
	if world == null or not world.chain_ready():
		return false
	started = true
	run()
	return false


func wait(s: float) -> void:
	await create_timer(s).timeout


func put(at: Vector3) -> void:
	p.state_machine.force_state("Idle", {})
	p.global_position = at + Vector3.UP * 0.6
	p.reset_physics_interpolation()
	p.velocity = Vector3.ZERO


func heal() -> float:
	p.health_component.max_health = 99999.0
	p.health_component.current_health = 99999.0
	return 99999.0


## A spot `d` m from the arena's middle toward the way in, on the ground.
func near(d: float) -> Vector3:
	var c: Vector2 = isl.sites["boss"]
	var q: Vector2 = c + (isl.sites["village"] - c).normalized() * d
	return isl.to_global(Vector3(q.x, isl.height_at(q.x, q.y), q.y))


func run() -> void:
	Arena = load("res://scripts/island/beast_arena.gd")
	Pool = load("res://scripts/enemies/beasts/beast_pool.gd")
	ChainK = load("res://scripts/world/chain.gd")
	p = get_first_node_in_group("player")
	gm = root.get_node("GameManager")
	isl = world.chain_islands[world.chain().start_next[0]]
	_pool()
	await _dens()
	for kind in ["serpent", "stalker", "mantis"]:
		await _boss(kind)
	finish()


func _pool() -> void:
	var seen := {}
	var bad := 0
	for s in range(1, 61):
		var c = ChainK.make(s * 7919, Vector2.ZERO, Vector2(1, 0))
		for n in c.nodes:
			seen[n["beast"]] = true
			for o in c.nodes:
				if (o["next"] as Array).has(n["id"]) and o["theme"] == n["theme"] and o["beast"] == n["beast"]:
					bad += 1
	check("the pool: no island's boss is the one on the island before it (60 chains, %d repeats)" % bad, bad == 0)
	check("...every boss turns up (%s)" % [seen.keys()], seen.size() == 4)
	var a = ChainK.make(4242, Vector2.ZERO, Vector2(1, 0))
	var b = ChainK.make(4242, Vector2.ZERO, Vector2(1, 0))
	check("...the same seed, the same beasts", a.nodes.map(func(n): return [n["beast"], n["beast_look"], n["minis"], n["roamer"]]) == b.nodes.map(func(n): return [n["beast"], n["beast_look"], n["minis"], n["roamer"]]))
	var pois: Array = Pool.pois(isl)
	check("POIs: the boss, each miniboss and the roamer (%d)" % pois.size(), pois.size() == 2 + (isl.node["minis"] as Array).size()
		and pois.all(func(q): return q.has("pos") and q.has("radius") and q.has("kind")))


func _dens() -> void:
	var boar = isl.get_node_or_null("Site_ruins/Boar")
	check("the alpha boar sleeps in its wallow at the ruins", boar != null and boar.asleep())
	if boar:
		var hp := heal()
		put(boar.ground_at(boar.global_position + boar._fwd() * 9.0))
		await wait(3.2)
		check("...a captain comes close: it wakes and charges, and the charge lands (%s)" % boar.state_name(), boar.in_combat() and p.health_component.current_health < hp)
		check("...its level is the island's", boar.level == int(isl.node["level"]))
		boar.health.take_damage(99999.0)
		await wait(0.5)
		check("...and it can be killed", boar.is_dead())
	var r = Pool.roamer_of(isl)
	check("the roaming beast is out on the island", r != null and r.asleep())
	if r:
		var at: Vector3 = r.global_position
		put(r.ground_at(r.global_position + Vector3(60.0, 0, 0)))
		await wait(6.0)
		check("...grazing its way about (%.1f m)" % r.global_position.distance_to(at), r.global_position.distance_to(at) > 1.0 or r._graze_t > 0.0)
		var hp := heal()
		# (the ray can land on a trunk or a crown in the thick jungle: the stomp is a ring on its own floor)
		var near: Vector3 = r.ground_at(r.global_position + r._fwd() * 4.0)
		if near.y - r.global_position.y > 1.0:
			near.y = r.global_position.y
		put(near)
		await wait(2.2)
		check("...a captain close: it turns and stomps them flat (%s, %.1f m off, captain %.1f m above it)" % [r.state_name(), r.global_position.distance_to(p.global_position), p.global_position.y - r.global_position.y], r.in_combat() and p.health_component.current_health < hp)
		put(r.ground_at(r.global_position + Vector3(0, 0, 80.0)))
		await wait(8.0)
		check("...everyone gone: it goes back to grazing, healed", r.state in [0, 3] and r.health.current_health == r.health.max_health)


func _boss(kind: String) -> void:
	arena = Arena.rebuild(isl, kind)
	boss = arena.boss
	put(near(40.0))
	await wait(1.0)
	check("%s: asleep on its ground" % boss.boss_name, boss.asleep())
	var lv := int(isl.node["level"])
	check("...its health and blows scale with the island's level (Lv %d)" % lv, boss.level == lv
		and is_equal_approx(boss.health.max_health, boss._hp_base() * Levels.hp_k(lv, 6) * root.get_node("Net").hp_scale()) and is_equal_approx(boss._dmg(10.0), 10.0 * Levels.dmg_k(lv, 6)))
	put(near(15.0))
	await wait(0.6)
	check("...a captain comes close: it wakes (%s)" % boss.state_name(), boss.in_combat() and boss.move == boss._wake_move())
	var hud = get_first_node_in_group("hud")
	check("...the boss bar shows", hud._boss_box.visible)
	await wait(2.0)
	for m in MOVES[kind]:
		var hp := heal()
		boss.health.current_health = boss.health.max_health
		boss.global_position = arena.global_position + Vector3.UP * 0.4
		boss.reset_physics_interpolation()
		boss.end_move()
		boss.model.visible = true
		var to: Vector3 = near(10.0) - boss.global_position
		boss._yaw = atan2(-to.x, -to.z)
		boss.model.rotation.y = boss._yaw
		if float(m[1]) > 0.0:
			put(boss.ground_at(boss.global_position + boss._fwd() * float(m[1])))
		elif kind == "serpent":
			put(boss.ground_at(boss._segs[12]))
		boss._set_state(FIGHT)
		boss.film(str(m[0]))
		var took := 0.0
		var waited := 0.0
		while waited < float(m[2]) + 1.0 and took <= 0.0:
			await wait(0.1)
			waited += 0.1
			took = hp - p.health_component.current_health
		check("...%s lands on a captain where it aims (%.0f)" % [m[0], took], took > 0.0)
		await wait(1.2)
	heal()
	put(near(8.0))
	boss.end_move()
	boss._set_state(FIGHT)
	boss.health.current_health = boss.health.max_health * 0.58
	var hd := HitData.new()
	hd.damage = 1.0
	boss._on_hit(hd, p)
	check("...below the mark: phase 2", boss.phase == 2)
	put(near(90.0))
	await wait(8.5)
	check("...everyone gone: back to sleep, healed", boss.asleep() or boss.state == RETURN)
	check("...healed and from the top", boss.health.current_health == boss.health.max_health and boss.phase == 1)
	put(near(12.0))
	await wait(0.6)
	boss.health.take_damage(9999999.0)
	await wait(1.0)
	check("...killed: the victory", arena._celebrated)
	check("...the flag the village and the log pose read", root.get_node("Dialogue").has_flag(isl.save_key("boss_beaten")))
	var trophy: String = boss.trophy(1).display_name
	check("...its hoard, with its trophy (%s)" % trophy, arena.get_node_or_null("Hoard") != null and arena.get_node("Hoard").contents.any(func(s): return s.item.display_name == trophy))
