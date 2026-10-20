extends SceneTree
## No hit farming: each foe teaches its weapon only its first 12 hits (a fresh foe teaches again), and a kill
## gives a quarter of its experience to the weapon in hand, three times that for an elite (a pirate captain).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "cutlass", "grunts": [{"post": Vector3(0, 0, -12), "yaw": 0.0, "mode": "stand", "seed": 37, "role": "sword"},
		{"post": Vector3(6, 0, -12), "yaw": 0.0, "mode": "stand", "seed": 38, "role": "sword"}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func total() -> int:
	var m: Dictionary = pr.mastery_of("sword")
	var n := int(m["xp"])
	for lv in range(1, int(m["lv"])):
		n += pr.mastery_to_next(lv)
	return n


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			until = TK.wait_ticks(10)
		1:
			p = stage.player
			pr = p.progression
			var foes: Array = p.get_tree().get_nodes_in_group("enemies")
			check("two grunts", foes.size() == 2)
			var a = foes[0]
			var b = foes[1]
			for i in range(pr.HITS_PER_FOE):
				pr.on_hit(a)
			check("12 hits on one foe: 12 x %d mastery (%d)" % [pr.MASTERY_PER_HIT, total()], total() == pr.HITS_PER_FOE * pr.MASTERY_PER_HIT)
			var t0 := total()
			for i in range(5):
				pr.on_hit(a)
			check("...more on the same foe teach nothing", total() == t0)
			pr.on_hit(b)
			check("...a fresh foe teaches again", total() == t0 + pr.MASTERY_PER_HIT)
			t0 = total()
			pr.add_xp(100, (a as Node3D).global_position + Vector3(0, 2, 0))
			check("a plain kill (it's alive, or no elite): a quarter of its xp (%d)" % (total() - t0), total() - t0 == 25)
			b.captain = true
			b.health.current_health = 0.0
			t0 = total()
			pr.add_xp(100, (b as Node3D).global_position + Vector3(0, 2, 0))
			check("an elite's kill: three times that (%d)" % (total() - t0), total() - t0 == 75)
			return TK.done(fails)
	step += 1
	return false
