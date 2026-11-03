extends SceneTree
## (1.30) A captain thrown flat (Splat): a strong enemy blow that breaks the captain's poise and takes over 30% of
## their health throws them into the wall behind (stuck, let go), then dazed ~1 s and a slower get-up than a
## knockdown; a poise break under the line is the plain knockdown; a duel opponent's blow over 20% does it too.
const TK := preload("res://tools/dev/test_kit.gd")
const GY := 3.0
var stage
var p
var g
var step := 0
var until := 0
var fails := 0
var down_t := 0
var dazed := 0.0
var getup := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [{"post": Vector3(0.0, 0, 3.0), "role": "sword", "seed": 41}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func blow(frac: float) -> HitData:
	var h := HitData.new()
	h.damage = p.health_component.max_health * frac
	h.poise = 200.0
	h.knockdown = true
	h.knockback_force = 8.0
	h.impact = "punch"
	return h


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			if stage.camp.grunts.is_empty():
				return false
			p = stage.player
			g = stage.camp.grunts[0]
			g.set_physics_process(false)
			var b := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(8, 6, 1)
			cs.shape = box
			b.add_child(cs)
			stage.add_child(b)
			b.global_position = Vector3(0, GY + 3.0, -6.5)
			until = TK.wait_ticks(5)
		1:
			p._on_hit_received(blow(0.45), g)
			check("the blow floors the captain (%s)" % p.current_state_name(), p.current_state_name() == "Downed")
			var r = p.body_model.ragdoll
			check("thrown flat (a Splat on the body)", r != null and r.get_node_or_null("Splat") != null)
			check("into the wall behind", r != null and r.get_node_or_null("Splat") != null and r.get_node("Splat").kind == "wall")
			until = TK.wait_secs(0.5)
		2:
			var hips: Vector3 = p.body_model.hips.global_position
			check("stuck to the wall half a second on (hips z %.2f, y %.2f)" % [hips.z, hips.y], hips.z < -5.2 and hips.y > GY + 0.8)
			check("still down", p.current_state_name() == "Downed")
			down_t = Engine.get_physics_frames()
			until = TK.wait_secs(2.2)
		3:
			check("2.2 s after the stick it's still down (%s)" % p.current_state_name(), p.current_state_name() == "Downed")
			step = 4
			return false
		4:
			if p.current_state_name() == "Downed":
				dazed = maxf(dazed, float(p.state_machine.current_state.get("_daze_t")))
				if bool(p.state_machine.current_state.get("getting_up")):
					getup = maxf(getup, float(p.state_machine.current_state.get("getup_time")))
				if Engine.get_physics_frames() - down_t > 60 * 8:
					check("gets back up within 8 s", false)
					return TK.done(fails)
				return false
			check("back up (%s)" % p.current_state_name(), p.current_state_name() != "Downed")
			check("dazed about a second first (%.2f s)" % dazed, dazed >= 0.9)
			check("a slower get-up than a knockdown's (%.2f s)" % getup, getup > 1.1)
			until = TK.wait_secs(4.5)
		5:
			p.health_component.current_health = p.health_component.max_health
			p._on_hit_received(blow(0.12), g)
			var r = p.body_model.ragdoll
			check("a poise break under the line is the plain knockdown", p.current_state_name() == "Downed"
				and r != null and r.get_node_or_null("Splat") == null)
			check("the plain knockdown isn't flagged a splat", not bool(p.state_machine.current_state.get("splat")))
			var S = load("res://scripts/combat/splat.gd")
			var mh: float = p.health_component.max_health
			var h := blow(0.25)
			check("a captain's blow over 20% flattens (duel)", S.flattens(h, h.damage, mh, p))
			check("an enemy's at 25% doesn't", not S.flattens(h, h.damage, mh, g))
			h.ranged = true
			check("a shot never does", not S.flattens(h, mh, mh, g))
			return TK.done(fails)
	step += 1
	return false
