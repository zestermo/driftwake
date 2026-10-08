extends SceneTree
## Brinehollow's west: the island reaches the deep forest and the north-west beach;
## the pirate den (crew, Captain Grell's overhead name and bar, strongbox, sloop);
## canopy spitters (hidden in a crown, drop on a thread when you walk under,
## spit venom that poisons, fall when hit and fight on the ground, climb back up).
var t := 0.0
var wait := 0.0
var step := 0
var fails := 0
var p
var isl
var bug
var hp0 := 0.0
var seen := {}
# Scuttlebug.S (not named here: the class touches autoloads)
const HIDE := 10
const DROP := 11
const DANGLE := 12
const CLIMB := 13
const FALL := 14


func _initialize():
	change_scene_to_file("res://scenes/world/world.tscn")


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		fails += 1


func _put(at: Vector3) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func _process(d: float) -> bool:
	t += d
	if wait > 0.0:
		wait -= d
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
			print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
			quit()
			return true
	step += 1
	return false
