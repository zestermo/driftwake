extends SceneTree
## Tempo Will at work: Flow (a stack per blow landed while unhit, +2% attack speed each up to 20%, gone at a blow on
## you, the combo swings faster), Cancel (a dodge out of a combo blow's recovery once its hit is done), Still Point
## (foes within 20 m think and move every other tick and their bodies play at half speed for 3 s; one 30 m off
## untouched; all put back after).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var near
var far
var la
var step := 0
var until := 0
var fails := 0
var SP
var counting := false
var flips := 0
var was_on := true


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "cutlass",
		"grunts": [{"post": Vector3(0, 0, -6.0), "yaw": 0.0, "mode": "stand", "seed": 41, "role": "sword"},
			{"post": Vector3(0, 0, -30.0), "yaw": 0.0, "mode": "stand", "seed": 42, "role": "sword"}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func give(key: String, v: float = 1.0) -> void:
	pr.stat(key)
	pr._stats[key] = v


func _physics_process(_d: float) -> bool:
	if counting:
		var on: bool = near.is_physics_processing()
		if on != was_on:
			flips += 1
		was_on = on
	return false


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			near = stage.camp.grunts[0]
			far = stage.camp.grunts[1]
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			var w = p.power.will
			var hd := HitData.new()
			hd.damage = 10.0
			w.landed(hd)
			check("no Flow without the node", w.flow_k() == 0.0)
			give("will_flow")
			for i in 14:
				w.landed(hd)
			check("Flow: +2%% a blow landed, up to 20%% (%.2f)" % w.flow_k(), is_equal_approx(w.flow_k(), 0.2))
			la = p.state_machine.get_node("LightAttack")
			p.state_machine.force_state("LightAttack", {"combo_index": 0})
			check("...the combo swings faster (speed %.2f)" % la._spd, is_equal_approx(la._spd, 1.2))
			w.incoming(hd, 10.0)
			check("...a blow on you breaks it", w.flow_k() == 0.0)
			hd.dot = true
			w.landed(hd)
			w.incoming(hd, 2.0)
			check("...a bleed's tick doesn't", w.flow_k() > 0.0)
			give("will_flow", 0.0)
			until = TK.wait_secs(1.2)
		1:
			give("dash_cancel")
			p.state_machine.force_state("Idle", {})
			TK.act("light_attack")
			until = TK.wait_ticks(2)
		2:
			if p.current_state_name() != "LightAttack":
				check("Cancel: a light attack started (%s)" % p.current_state_name(), false)
				return TK.done(fails)
			if not la.hitbox_deactivated:
				return false
			check("Cancel: the blow's hit is done, its recovery not", not la.can_combo)
			TK.act("dodge")
			until = TK.wait_ticks(3)
		3:
			check("...dodge pressed: out of it into a dodge (%s)" % p.current_state_name(), p.current_state_name() == "Dodge")
			until = TK.wait_secs(1.0)
		4:
			SP = load("res://scripts/powers/still_point.gd")
			p.state_machine.force_state("Technique", {"id": "will_still_point"})
			until = TK.wait_secs(0.5)
		5:
			check("Still Point: the near foe slowed, the far one not", SP.slowed(near) and not SP.slowed(far))
			check("...its body plays at half speed", near.humanoid.time_k == 0.5 and far.humanoid.time_k == 1.0)
			was_on = near.is_physics_processing()
			counting = true
			until = TK.wait_ticks(20)
		6:
			counting = false
			check("...it thinks and moves every other tick (%d switches in 20 ticks), the far one every tick" % flips, flips >= 15 and far.is_physics_processing())
			until = TK.wait_secs(3.0)
		7:
			check("3 s on: put back (body, ticks)", not SP.slowed(near) and near.humanoid.time_k == 1.0 and near.is_physics_processing())
			return TK.done(fails)
	step += 1
	return false
