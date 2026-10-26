extends SceneTree
## 1.23 smarter enemies: a sword grunt blocks about a quarter of the hits from the front, never twice in a row without
## a counter in between, and sidesteps some; hit from behind it never blocks.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var g
var G
var step := 0
var until := 0
var fails := 0
var n := 0
var blocks := 0
var sides := 0
var twice := 0
var last_blocked := false
var countered := true
var behind_blocks := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [{"post": Vector3(0.0, 0, -3.0), "role": "sword", "seed": 81}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func light() -> HitData:
	var h := HitData.new()
	h.damage = 1.0
	h.poise = 0.1
	h.knockback_force = 0.5
	h.impact = "slice"
	return h


func face(front: bool) -> void:
	var pl: Node3D = stage.player
	var to: Vector3 = pl.global_position - g.global_position
	g.facing.rotation.y = atan2(-to.x, -to.z) + (0.0 if front else PI)


func _process(_d: float) -> bool:
	if g and G and g.state in [G.S.WIND, G.S.SWING]:
		countered = true
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			if stage.camp.grunts.size() < 1:
				return false
			G = load("res://scripts/enemies/pirate_grunt.gd")
			g = stage.camp.grunts[0]
			g.alert()
			stage.player.hurtbox.monitorable = false
			until = TK.wait_secs(1.0)
		1:
			# put it back in its guard each time (no turn: it circles), then a light from the front
			g.global_position = Vector3(0, g.global_position.y, -3.0)
			g._set_state(G.S.CIRCLE)
			g._cooldown = 5.0
			face(true)
			var hp: float = g.health.current_health
			g._on_hit(light(), stage.player)
			var blocked: bool = g.health.current_health == hp and g.state == G.S.BLOCK
			var side: bool = g.health.current_health == hp and not blocked
			if blocked:
				blocks += 1
				if last_blocked and not countered:
					twice += 1
				countered = false
			if side:
				sides += 1
			last_blocked = blocked
			g.health.current_health = g.health.max_health
			n += 1
			until = TK.wait_secs(0.7)
			if n < 60:
				return false
		2:
			var share := float(blocks) / n
			check("it blocks about a quarter of the front hits (%d of %d)" % [blocks, n], share > 0.1 and share < 0.42)
			check("never twice in a row without a counter between (%d)" % twice, twice == 0)
			check("it sidesteps some (%d of %d)" % [sides, n], sides > 0 and float(sides) / n < 0.35)
			n = 0
		3:
			g._set_state(G.S.CIRCLE)
			face(false)
			var hp: float = g.health.current_health
			g._on_hit(light(), stage.player)
			if g.health.current_health == hp:
				behind_blocks += 1
			g.health.current_health = g.health.max_health
			n += 1
			until = TK.wait_secs(0.3)
			if n < 15:
				return false
		4:
			check("from behind it never blocks (%d)" % behind_blocks, behind_blocks == 0)
			return TK.done(fails)
	step += 1
	return false
