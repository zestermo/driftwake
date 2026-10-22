extends SceneTree
## Thunder Javelin (PoleArts, Projectile "javelin"): the spear leaves the hand (the held one hidden), pierces the
## dummy 8 m down the line breaking its wind-up, a bolt drops on it with the storm awakened, it cuts again on the
## way home and the spear is back in the hand at the end.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var hits: Array = []
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -8.0), "weapon": "spear"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			stage.camera_rig.rotation.y = 0.0
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(h, _a): hits.append(h))
			p.progression.master_all()
			until = TK.wait_secs(0.5)
		1:
			if not p.is_free():
				return false
			p.power.energy = 999.0
			p.state_machine.force_state("Technique", {"id": "thunder_javelin", "slot": 0})
			until = TK.wait_secs(0.36)
		2:
			var flying: Array = get_nodes_in_group("projectiles").filter(func(x): return x.get("kind") == "javelin")
			check("the javelin is in the air", flying.size() == 1)
			check("the held spear is hidden while it flies", not p.body_model.weapon.visible)
			until = TK.wait_secs(1.4)
		3:
			check("it pierced the dummy on the way out, breaking its wind-up", hits.size() >= 1 and hits[0].breaker)
			check("a bolt and the way home: three hits in all (%d)" % hits.size(), hits.size() >= 3)
			check("nothing left flying", get_nodes_in_group("projectiles").filter(func(x): return x.get("kind") == "javelin" and not x.is_queued_for_deletion()).is_empty())
			check("the spear is back in the hand", p.body_model.weapon.visible)
			check("the technique is over", p.current_state_name() != "Technique")
			return TK.done(fails)
	step += 1
	return false
