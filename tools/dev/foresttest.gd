extends SceneTree
## Brinehollow's west: the island reaches the deep forest and the north-west beach;
## the pirate den (crew, Captain Grell's overhead name and bar, strongbox, sloop);
## canopy spitters (hidden in a crown, drop on a thread when you walk under,
## spit venom that poisons, fall when hit and fight on the ground, climb back up);
## the brood cave (the queen wakes, boss bar, no throws but a stagger, brood,
## slam, venom fan, reset, death, hoard) and the Queen's Fang poisoning.
var t := 0.0
var wait := 0.0
var step := 0
var fails := 0
var p
var isl
var bug
var hp0 := 0.0
var seen := {}
var cave
var q
# Scuttlebug.S (not named here: the class touches autoloads)
const WANDER := 0
const NOTICE := 1
const DAZED := 6
const DOWN := 8
const DEAD := 9
const HIDE := 10
const DROP := 11
const DANGLE := 12
const CLIMB := 13
const FALL := 14


const TK = preload("res://tools/dev/test_kit.gd")
var until := 0
var puddle
var t0 := 0.0
var grell


func _initialize():
	TK.seed_of(self)
	change_scene_to_file("res://scenes/world/world.tscn")


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		fails += 1


func hud():
	return root.get_tree().get_first_node_in_group("hud")


func _put(at: Vector3) -> void:
	p.health_component.heal(9999.0)
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func _get_up() -> void:
	if p.current_state_name() == "Downed":
		p.body_model.end_ragdoll()
		p.body_model.reset_pose()
	p.state_machine.force_state("Idle", {})
	p.hurtbox.monitorable = true


## Grell back at his post, the captain 10 m off across open, level ground in his den, and his charge begun.
func _grell_setup() -> void:
	_get_up()
	var space = grell.get_world_3d().direct_space_state
	var g0: Vector3 = grell.post
	var spot := g0
	for i in range(24):
		var a := TAU * i / 24.0
		var d := Vector3(sin(a), 0.0, cos(a))
		var blocked := false
		for h in [0.4, 1.0]:
			for side in [-0.4, 0.0, 0.4]:
				var o: Vector3 = Vector3(0, h, 0) + d.cross(Vector3.UP) * side
				var los := PhysicsRayQueryParameters3D.create(g0 + o, g0 + d * 12.5 + o, 1)
				los.exclude = [grell.get_rid()]
				blocked = blocked or not space.intersect_ray(los).is_empty()
		if blocked:
			continue
		var down := PhysicsRayQueryParameters3D.create(g0 + d * 10.0 + Vector3(0, 4.0, 0), g0 + d * 10.0 - Vector3(0, 6.0, 0), 1)
		var hit: Dictionary = space.intersect_ray(down)
		if not hit.is_empty() and absf((hit["position"] as Vector3).y - g0.y) < 0.8:
			spot = hit["position"]
			break
	grell.global_position = g0 + Vector3.UP * 0.2
	grell.velocity = Vector3.ZERO
	grell.reset_physics_interpolation()
	_put(spot + Vector3.UP * 0.3)
	hp0 = p.health_component.current_health
	grell._start_rush()
	t0 = t


func _cure() -> void:
	var ps = p.get_node_or_null("Poison")
	if ps:
		p.remove_child(ps)
		ps.queue_free()


func _process(d: float) -> bool:
	t += d
	if wait > 0.0:
		until = TK.wait_secs(wait)
		wait = 0.0
	if TK.ticking(until):
		if bug and is_instance_valid(bug):
			seen[bug.state] = true
		return false
	match step:
		0:
			if t < 2.5:
				return false
			for c in root.find_children("*", "CharacterCreator", true, false):
				c._finish(true)
			p = root.get_tree().get_first_node_in_group("player")
			isl = root.get_node("World/Islands/Brinehollow")
			# (the den is far from the captain: held awake (ActorSleep) so the hit plays out on Grell)
			if not has_meta("den_awake"):
				set_meta("den_awake", true)
				for g in isl.get_node("PirateDen").grunts:
					g.set_meta("no_sleep", true)
				wait = 1.0
				return false
			# --- the land
			check("the west coast reaches past 190 m (forest)", isl.height_at(-185.0, 60.0) > 0.5)
			check("the north-west beach is land at the den", isl.height_at(-112.0, -112.0) > 1.0)
			check("the dock's shore is where it was (sea north of the dock end)", isl.height_at(0.0, -170.0) < -2.0)
			check("the cave clearing is flat", absf(isl.height_at(-150.0, 45.0) - isl.height_at(-140.0, 45.0)) < 0.3)
			# --- the den
			var den = isl.get_node("PirateDen")
			check("the den's crew (7)", den.alive_count() == 7)
			var cap = null
			for g in den.grunts:
				if g.captain:
					cap = g
			check("one of them is the captain", cap != null)
			check("captain is tougher (%d hp)" % int(cap.health.max_health), cap.health.max_health > 300.0)
			var bar = cap.get_node_or_null("OverheadBar")
			check("captain's name over his head", bar != null and bar._label.text == "Captain Grell" and bar.visible)
			check("no health bar until he's hit", not bar._bar.visible)
			var hit := HitData.new()
			hit.damage = 20.0
			hit.knockback_force = 1.0
			cap.hurtbox.take_hit(hit, p)
			bug = null
			wait = 0.2
		1:
			var cap = null
			for g in isl.get_node("PirateDen").grunts:
				if g.captain:
					cap = g
			var bar = cap.get_node("OverheadBar")
			check("hit: his bar shows over his head", bar._bar.visible)
			check("bar shows what's left", float(bar._mat.get_shader_parameter("frac")) < 0.99)
			var box := false
			for n in isl.get_children():
				if n.get("save_id") == "den_strongbox":
					box = true
			check("the captain's strongbox", box)
			check("their sloop is tied up at the pier", isl.get_node_or_null("DenSloop") != null)
			# --- spitters
			var roosts = isl.get_node("SpitterRoosts")
			check("spitters roost in the deep forest (%d)" % roosts.spots.size(), roosts.spots.size() >= 6)
			bug = roosts.spots[0]["bug"]
			check("a spitter hides in the crown", bug.state == HIDE and bug.global_position.y - isl.height_at(bug.global_position.x - isl.global_position.x, bug.global_position.z - isl.global_position.z) > 5.0)
			var g: Vector3 = bug.home
			_put(g + Vector3(3.0, 0.5, 0.0))
			hp0 = p.health_component.current_health
			seen.clear()
			wait = 1.6
		2:
			check("walk under it: it drops on its thread", seen.has(DROP) and bug.state == DANGLE)
			check("its thread shows", bug._thread.visible)
			check("dangles about head height", absf(bug.global_position.y - bug.home.y - bug.DANGLE_Y) < 0.4)
			wait = 3.5
		3:
			check("its spit hurt the captain", p.health_component.current_health < hp0)
			check("and poisoned them", p.get_node_or_null("Poison") != null or p.health_component.current_health < hp0 - bug.SPIT_DAMAGE)
			var hit := HitData.new()
			hit.damage = 6.0
			hit.knockback_force = 4.0
			bug.hurtbox.take_hit(hit, p)
			check("hit it: the thread snaps and it falls", bug.state == FALL)
			seen.clear()
			wait = 2.5
		4:
			check("lands and fights on the ground", not bug._aloft() and bug.global_position.y - bug.home.y < 0.8 and not bug._thread.visible)
			_put(bug.home + Vector3(70.0, 4.0, 0.0))
			seen.clear()
			wait = 16.0
		5:
			check("lost you: climbed back up its thread", seen.has(CLIMB) and bug.state == HIDE)
			check("back in its crown", bug.global_position.distance_to(bug.anchor) < 0.1)
			# --- the brood cave
			cave = isl.get_node("BroodCave")
			q = cave.queen
			check("the queen sleeps on her nest", q.state == WANDER and cave.inside(q.global_position))
			check("she's big", q.size_k >= 4.0)
			_put(cave.to_global(Vector3(15.0, 0.6, 0.0)))
			hp0 = p.health_component.current_health
			bug = q
			seen.clear()
			wait = 2.0
		6:
			check("walk in: she wakes", seen.has(NOTICE) and q.in_combat())
			check("her name and health across the top", hud()._boss_box.visible and hud()._boss_name.text == "The Brood Queen")
			_put(cave.to_global(Vector3(-14.0, 0.6, 9.0)))
			var hit := HitData.new()
			hit.damage = 40.0
			hit.knockback_force = 9.0
			hit.knockdown = true
			q.hurtbox.take_hit(hit, p)
			check("a heavy blow doesn't throw her", q.state != DOWN and q._rag == null)
			for k in range(3):
				q.hurtbox.take_hit(hit, p)
			check("enough of them stagger her", q.state == DAZED)
			wait = 2.6
		7:
			q._begin("brood")
			wait = 1.2
		8:
			check("she shrieks and the brood hatches", cave.brood_alive() == 3)
			_put(q.global_position - q.model.global_basis.z * 3.0 + Vector3.UP * 0.3)
			hp0 = p.health_component.current_health
			q._begin("slam")
			wait = 1.3
		9:
			check("the slam lands on whoever stands in its ring", p.health_component.current_health < hp0)
			wait = 3.0
		10:
			_put(q.global_position + Vector3(0.0, 0.3, 10.0))
			hp0 = p.health_component.current_health
			q._begin("volley")
			wait = 2.6
		11:
			check("her venom fan hits from range", p.health_component.current_health < hp0)
			# keep away and she burrows at you (the fan's puddles mopped up and the brood held first:
			# a brood bug's ram landing in the burrow's warning read as her coming up early)
			for pp in load("res://scripts/combat/poison_puddle.gd").live():
				pp.queue_free()
			for b in cave.brood.get_children():
				if b is CharacterBody3D:
					b.process_mode = Node.PROCESS_MODE_DISABLED
			_get_up()
			_put(q.global_position + Vector3(0.0, 0.3, 10.0))
			_cure()
			hp0 = p.health_component.current_health
			q._begin("burrow")
			t0 = t
			step = 30
			return false
		30:
			if not (q._special == "burrow" and q._fired == 2) and t - t0 < 6.0:
				return false
			check("she dives under the floor, out of sight", q._special == "burrow" and q._sunk > 0.9 and not q.model.visible)
			check("a red ring marks where she'll burst out: under you", Vector2(q._erupt_at.x - p.global_position.x, q._erupt_at.z - p.global_position.z).length() < 1.2)
			check("...it shows before she comes up", p.health_component.current_health >= hp0 - 0.01)
			wait = 1.2
		31:
			check("she bursts out under whoever stayed in it", p.health_component.current_health < hp0)
			check("...back in sight", q._special == "erupt" and q.model.visible)
			wait = 3.0
		32:
			_get_up()
			var back: Vector3 = q.home - q.global_position
			back.y = 0.0
			_put(q.global_position + back.normalized() * 10.0 + Vector3.UP * 0.3)
			_cure()
			hp0 = p.health_component.current_health
			q._begin("burrow")
			t0 = t
		33:
			if not (q._special == "burrow" and q._fired == 2) and t - t0 < 6.0:
				return false
			var mouth: Vector3 = cave.to_global(Vector3(1.0, 0.0, 0.0)) - cave.to_global(Vector3.ZERO)
			mouth.y = 0.0
			_put(p.global_position + mouth.normalized() * 5.5)
			_cure()
			hp0 = p.health_component.current_health
			wait = 1.3
		34:
			check("step out of the ring once it shows: she comes up empty", p.health_component.current_health >= hp0 - 0.01)
			_put(cave.to_global(Vector3(60.0, 2.0, 0.0)))
			wait = 8.0
			step = 12
			return false
		12:
			check("everyone left: she settles back on her eggs, healed", q.state == WANDER and q.health_frac() > 0.99)
			check("the boss bar goes away", not hud()._boss_box.visible)
			_put(cave.to_global(Vector3(12.0, 0.6, 0.0)))
			wait = 1.0
		13:
			var hit := HitData.new()
			hit.damage = 5000.0
			q.hurtbox.take_hit(hit, p)
			check("she dies", q.state == DEAD)
			wait = 0.5
		14:
			var hoard = cave.get_node_or_null("Hoard")
			check("her hoard on the nest", hoard != null)
			var fang = null
			if hoard:
				for st in hoard.contents:
					if st.item.id.begins_with("queens_fang"):
						fang = st.item
			check("with the Queen's Fang (epic, venomous)", fang != null and int(fang.rarity) == 3 and fang.poison > 0.0)
			# the Fang poisons what it cuts
			p.equip_weapon(fang)
			var victim = isl.get_node("ScuttlebugNest").spots[1]["bug"]
			var hit := HitData.new()
			hit.damage = 1.0
			p.power.on_sword_hit(victim, hit)
			check("a cut with the Fang poisons", victim.get_node_or_null("Poison") != null)
			# --- poison puddles: a blob that lands on the ground leaves one
			_put(cave.to_global(Vector3(10.0, 0.6, 0.0)))
			_cure()
			var at: Vector3 = p.global_position + Vector3(0.0, 0.0, 3.0)
			root.get_node("FX").spit(at + Vector3(0.0, 2.0, 0.0), Vector3(0.0, -6.0, 0.0), 6.0, 1.0, 4.0, 3.0)
			wait = 0.6
		15:
			var near: Array = load("res://scripts/combat/poison_puddle.gd").live()
			puddle = near[0] if near.size() > 0 else null
			check("a glob landing on the ground leaves a poison puddle", puddle != null)
			check("standing beside it: not poisoned", p.get_node_or_null("Poison") == null)
			_put(puddle.global_position + Vector3(0.0, 0.3, 0.0))
			hp0 = p.health_component.current_health
			wait = 1.2
		16:
			check("stepping in it poisons you", p.get_node_or_null("Poison") != null and p.health_component.current_health < hp0)
			check("...a tick, not a stun-lock", p.current_state_name() in ["Idle", "Move", "Fall"])
			_put(puddle.global_position + Vector3(4.0, 0.3, 0.0))
			wait = 2.0
		17:
			check("out of it: the poison wears off", p.get_node_or_null("Poison") == null)
			wait = 2.0
		18:
			check("the puddle dries up after a few seconds", not is_instance_valid(puddle))
			# --- Captain Grell's gap closer: the shoulder charge
			var den = isl.get_node("PirateDen")
			for g in den.grunts:
				if g.captain:
					grell = g
				else:
					g.process_mode = Node.PROCESS_MODE_DISABLED
			grell.hold = []
			grell.alert()
			_grell_setup()
			step = 50
			return false
		50:
			if grell._rush_dir == Vector3.ZERO and t - t0 < 3.0:
				return false
			check("Grell lowers his shoulder and an amber lane shows where he'll charge", grell.state == 5 and root.find_children("Lane", "", true, false).size() > 0)
			check("...before he goes", p.health_component.current_health >= hp0 - 0.01)
			wait = 1.5
		51:
			check("...the charge hits whoever stays in the lane: staggered or floored (1.26.1 poise)", p.health_component.current_health < hp0 and p.current_state_name() in ["Downed", "Stagger"])
			wait = 2.0
		52:
			_grell_setup()
		53:
			if grell._rush_dir == Vector3.ZERO and t - t0 < 3.0:
				return false
			_put(p.global_position + grell._rush_dir.cross(Vector3.UP) * 4.5 + Vector3.UP * 0.3)
			hp0 = p.health_component.current_health
			wait = 1.6
		54:
			check("...sidestep out of it once it shows: he charges past", p.health_component.current_health >= hp0 - 0.01)
			check("...and he's open after it", grell.state in [6, 7, 9])
			print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
			quit()
			return true
	step += 1
	return false
