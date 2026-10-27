extends SceneTree
## A slingshot in hand: its own stance (the fork in the right hand, the pouch in the left), no off hand; left click
## draws and lets a stone fly into the dummy down range, again and again with no reload; right click held draws it right
## back in two levels and let go a heavy stone that knocks the dummy down; put away it hangs at the hip.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var hits := 0
var taken := 0.0
var last
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -8.0), "weapon": "slingshot"})


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
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(h, _a):
				hits += 1
				taken += h.damage
				last = h)
			stage.camera_rig.rotation.y = 0.05
			stage.camera_rig.get_node("SpringArm3D").rotation.x = -0.06
			until = TK.wait_secs(0.7)
		1:
			check("a slingshot fights as a slingshot (%s, %s)" % [p.style(), p.body_model.stance], p.style() == "slingshot" and p.body_model.stance == "slingshot")
			var dirk = ItemDB.get_item("dagger")
			p.inventory_component.add_item(dirk, 1)
			check("two hands on it: nothing goes in the off hand", not p.set_offhand(dirk) and p.offhand_weapon == null)
			var band: Array = p.body_model.get_meta("sling_band", [])
			check("the band stretched from the fork to the pouch hand", band.size() == 2 and (band[0] as Node3D).visible)
			TK.act("light_attack")
			until = TK.wait_ticks(4)
		2:
			check("left click draws (%s)" % p.body_model.current_action(), p.current_state_name() == "Shoot" and p.body_model.current_action() == "sl_shot")
			until = TK.wait_secs(0.7)
		3:
			check("a stone into the dummy down range (%d, %.0f)" % [hits, taken], hits == 1 and last.ranged and not last.knockdown)
			hits = 0
			TK.act("light_attack")
			until = TK.wait_secs(0.45)
		4:
			TK.act("light_attack")
			until = TK.wait_secs(0.8)
		5:
			check("and again, with no reload (%d)" % hits, hits == 2 and not p.reloading())
			hits = 0
			TK.press("heavy_attack")
			until = TK.wait_secs(1.1)
		6:
			var st = p.state_machine.current_state
			check("right click held: drawn right back to the second level (%s, %s)" % [p.body_model.current_action(), str(st.get("_level"))],
				p.current_state_name() == "HeavyAttack" and p.body_model.current_action() == "sl_draw" and int(st.get("_level")) == 2)
			TK.release("heavy_attack")
			until = TK.wait_secs(0.7)
		7:
			check("let go: a heavy stone that knocks the dummy down (%d)" % hits, hits == 1 and last.knockdown and last.damage > 25.0)
			until = TK.wait_secs(0.5)
		8:
			TK.act("ready_weapon")
			until = TK.wait_secs(1.0)
		9:
			var w = p.body_model.weapon
			check("put away, it hangs at the hip (%s), the band slack" % w.get_parent().name, w.get_parent() == p.body_model.hip_socket
				and not (p.body_model.get_meta("sling_band")[0] as Node3D).visible)
			return TK.done(fails)
	step += 1
	return false
