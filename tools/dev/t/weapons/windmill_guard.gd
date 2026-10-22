extends SceneTree
## Windmill Guard (PoleArts): held, a shot from the front is batted aside and one from behind lands, the dummy
## stepped in close is clipped; let go into the lunge, which nothing blocks; afterwards the guard is down.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var hc
var hits: Array = []
var behind: Node3D
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -2.0), "weapon": "spear"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func shot() -> HitData:
	var h := HitData.new()
	h.damage = 12.0
	h.ranged = true
	return h


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			hc = p.health_component
			stage.camera_rig.rotation.y = 0.0
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(h, _a): hits.append(h))
			behind = Node3D.new()
			stage.add_child(behind)
			behind.global_position = Vector3(0, 0, 4.0)
			until = TK.wait_secs(0.5)
		1:
			if not p.is_free():
				return false
			p.power.energy = 999.0
			p.state_machine.force_state("Technique", {"id": "windmill_guard", "slot": 0, "hold": 1.0})
			until = TK.wait_secs(0.45)
		2:
			check("spinning: the guard is up and bats shots", p.is_parrying and p.parries_shots())
			var hp: float = hc.current_health
			p._on_hit_received(shot(), stage.dummy)
			check("a shot from the front is batted aside", is_equal_approx(hc.current_health, hp))
			check("the dummy stepped in close is clipped (%d hits)" % hits.size(), hits.size() >= 1 and not hits.any(func(h): return h.unblockable))
			hits.clear()
			until = TK.wait_secs(1.25)
		3:
			check("let go: the lunge lands and can't be blocked", hits.any(func(h): return h.unblockable and h.damage >= 20.0))
			check("the guard is down after the lunge", not p.is_parrying and not p.parries_shots())
			check("the technique is over", p.current_state_name() != "Technique")
			until = TK.wait_secs(0.3)
		4:
			if not p.is_free():
				return false
			p.state_machine.force_state("Technique", {"id": "windmill_guard", "slot": 0, "hold": 1.0})
			until = TK.wait_secs(0.3)
		5:
			var hp: float = hc.current_health
			p._on_hit_received(shot(), behind)
			check("a shot from behind still lands", hc.current_health < hp)
			return TK.done(fails)
	step += 1
	return false
