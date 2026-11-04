extends SceneTree
## 1.30 verticality: an elite on a ledge 3 m above a captain dives off it onto them (the dive, not the walk round),
## and comes down by the captain.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var e
var G
var step := 0
var until := 0
var fails := 0
var dove := false
var landed_at := Vector3.INF


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [
		{"post": Vector3(0, 3.0, -7.0), "role": "sword", "seed": 71, "elite": true, "personality": "none"}]})
	var ledge := StaticBody3D.new()
	ledge.name = "Ledge"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 3.0, 5.0)
	cs.shape = box
	ledge.add_child(cs)
	ledge.position = Vector3(0, stage.GROUND_Y + 1.5, -8.5)
	stage.add_child(ledge)


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if e and G and e.state == G.S.POUNCE:
		if e._attack == "dive":
			dove = true
		if e._jump_land >= 0.0 and landed_at == Vector3.INF:
			landed_at = e.global_position
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			if stage.camp.grunts.size() < 1:
				return false
			G = load("res://scripts/enemies/pirate_grunt.gd")
			e = stage.camp.grunts[0]
			e._jump_cd = 0.0
			e._peril_cd = 99.0
			e._pistol_cd = 99.0
			stage.player.hurtbox.monitorable = false
			until = TK.wait_secs(1.0)
		1:
			check("it stands on the ledge (%.1f m up)" % (e.global_position.y - stage.GROUND_Y), e.global_position.y - stage.GROUND_Y > 2.5)
			e.alert()
			until = TK.wait_secs(4.0)
		2:
			check("it dives off the ledge", dove)
			var d := landed_at.distance_to(stage.player.global_position) if landed_at != Vector3.INF else INF
			check("down by the captain (%.1f m)" % d, d < 2.5)
			return TK.done(fails)
	step += 1
	return false
