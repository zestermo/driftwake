extends SceneTree
## 1.23 juggling (Juggle): a launcher throws a grunt up; hit up there it stays up (each hit lifting it less), and even
## hit on and on it drops by ~3 s and goes down. A camp captain doesn't go up on a launcher unless it breaks his poise.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0
var g
var cap
var G
var ground := 0.0
var t_up := 0
var lowest := INF
var landed_at := -1


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [
		{"post": Vector3(0.0, 0, -4.0), "role": "sword", "seed": 51},
		{"post": Vector3(8.0, 0, -6.0), "role": "sword", "seed": 52, "captain": true, "title": "Cap"}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func blow(dmg: float, launch: float) -> HitData:
	var h := HitData.new()
	h.damage = dmg
	h.launch = launch
	h.knockback_force = 3.0
	h.impact = "punch"
	return h


func _process(_d: float) -> bool:
	if g and G and g.state == G.S.AIR and step >= 3 and step < 12:
		lowest = minf(lowest, g.global_position.y - ground)
	if g and G and landed_at < 0 and step >= 3 and g.state != G.S.AIR:
		landed_at = Engine.get_physics_frames()
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			if stage.camp.grunts.size() < 2:
				return false
			G = load("res://scripts/enemies/pirate_grunt.gd")
			g = stage.camp.grunts[0]
			cap = stage.camp.grunts[1]
			ground = g.global_position.y
			until = TK.wait_secs(0.5)
		1:
			g._on_hit(blow(5.0, 9.0), stage.player)
			t_up = Engine.get_physics_frames()
			check("a launcher throws the grunt up (state %d)" % g.state, g.state == G.S.AIR)
			check("it's juggled (in the group)", g.is_in_group(Juggle.GROUP))
			until = TK.wait_secs(0.45)
		2:
			check("it's up in the air (%.2f m)" % (g.global_position.y - ground), g.global_position.y - ground > 1.2)
			until = TK.wait_ticks(1)
		3, 4, 5, 6, 7, 8, 9, 10, 11:
			# hit it again and again while it's up
			if g.state == G.S.AIR:
				g._on_hit(blow(2.0, 0.0), stage.player)
			if step == 6:
				check("hit up there it stays up (1.6 s in, %.2f m)" % (g.global_position.y - ground), g.state == G.S.AIR and g.global_position.y - ground > 0.4)
			until = TK.wait_secs(0.4)
		12:
			var secs := float(landed_at - t_up) / Engine.physics_ticks_per_second if landed_at > 0 else INF
			check("hit on and on, it still drops by ~3 s (%.2f s)" % secs, secs > 2.0 and secs < 4.3)
			check("and goes down (state %d)" % g.state, g.state in [G.S.DOWN, G.S.GETUP])
			check("no longer juggled", not g.is_in_group(Juggle.GROUP))
			cap.alert()
			until = TK.wait_secs(0.5)
		13:
			cap._on_hit(blow(5.0, 9.0), stage.player)
			check("a camp captain stays on his feet under a launcher (state %d)" % cap.state, cap.state != G.S.AIR)
			var big := blow(5.0, 9.0)
			big.poise = 200.0
			until = TK.wait_secs(0.3)
			cap.set_meta("big", big)
		14:
			cap._on_hit(cap.get_meta("big"), stage.player)
			check("but goes up when the launcher breaks his poise (state %d)" % cap.state, cap.state == G.S.AIR)
			return TK.done(fails)
	step += 1
	return false
