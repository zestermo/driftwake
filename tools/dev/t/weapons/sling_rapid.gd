extends SceneTree
## The slingshot never reloads (1.26: Zach saw it hang "in a reload" after ~3 shots in a fight): left-click as fast as
## a shot allows, twelve times, and every click looses a stone with no reload in between.
const TK := preload("res://tools/dev/test_kit.gd")
const SHOTS := 12
var stage
var p
var shots := 0
var tries := 0
var stuck: Array = []
var step := 0
var until := 0
var fails := 0
var stones := 0
var mash_until := 0


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
			stage.camera_rig.rotation.y = 0.0
			until = TK.wait_secs(0.7)
			step = 1
		1:
			if p.reloading():
				stuck.append("reload after %d (%s)" % [shots, p.current_state_name()])
			if p.current_state_name() == "Shoot":
				return false
			if tries >= SHOTS * 3 or shots >= SHOTS:
				step = 2
				return false
			TK.act("light_attack")
			tries += 1
			until = TK.wait_ticks(4)
			step = 3
		3:
			if p.current_state_name() == "Shoot":
				shots += 1
			else:
				stuck.append("click %d: nothing (%s, ammo %s, armed %s, action %s)" % [tries, p.current_state_name(), str(p.ammo), str(p.armed), p.body_model.current_action()])
			step = 1
		2:
			check("%d stones loosed in %d clicks" % [shots, tries], shots >= SHOTS)
			check("never a reload, never a dead click (%s)" % "; ".join(stuck.slice(0, 4)), stuck.is_empty())
			# now mashed: a click every 4 ticks for 4 s, the next shot queued while one is in the air (the old bug: a queued
			# shot ran the long gun's shot, which spent a load and started a reload)
			stones = 0
			node_added.connect(func(n): if n.get_script() and str(n.get_script().resource_path).ends_with("weapons/shell.gd"): stones += 1)
			mash_until = TK.wait_secs(4.0)
			step = 4
		4:
			if p.reloading():
				stuck.append("mashing: a reload after %d stones" % stones)
			if TK.ticking(mash_until):
				TK.act("light_attack")
				until = TK.wait_ticks(4)
				return false
			check("mashed for 4 s: %d stones, no reload (%s)" % [stones, "; ".join(stuck.slice(0, 3))], stones >= 8 and stuck.is_empty())
			return TK.done(fails)
	return false
