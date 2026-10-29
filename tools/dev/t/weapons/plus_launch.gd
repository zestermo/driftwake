extends SceneTree
## (1.26) Every wave-1 weapon can juggle: its launcher (an alternate) throws the grunt in front into the air (Juggle).
const TK := preload("res://tools/dev/test_kit.gd")
## tree -> [weapon item ("" black leg), launcher move]
const LAUNCHERS := [["sword", "cutlass", "boarding_hook"], ["katana", "katana", "wind_step"], ["pistol", "pistol", "barrel_lift"],
	["polearm", "spear", "skyward_pike"], ["greatsword", "greatsword", "wind_shear"], ["black_leg", "", "flambe_lift"]]
const GAP := 7.0
var stage
var p
var G
var i := 0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	var gs: Array = []
	for k in LAUNCHERS.size():
		gs.append({"post": Vector3(GAP * k, 0, -2.2), "role": "sword", "seed": 71 + k})
	stage = TK.stage(self, {"hud": false, "grunts": gs})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			if stage.camp.grunts.size() < LAUNCHERS.size():
				return false
			G = load("res://scripts/enemies/pirate_grunt.gd")
			p = stage.player
			stage.camera_rig.rotation.y = 0.0
			p.hurtbox.monitorable = false
			for g in stage.camp.grunts:
				g.alert()
				g.health.max_health = 999.0
				g.health.current_health = 999.0
			until = TK.wait_ticks(5)
		1:
			if i >= LAUNCHERS.size():
				return TK.done(fails)
			var l: Array = LAUNCHERS[i]
			if l[1] == "":
				p.unequip_weapon()
				p.learn_black_leg()
			else:
				p.equip_weapon(load("res://scripts/loot/item_db.gd").get_item(l[1]), true)
			p.progression.master_all()
			until = TK.wait_secs(0.8)
		2:
			if not p.is_free():
				return false
			var g = stage.camp.grunts[i]
			g.facing.rotation.y = PI
			p.global_position = Vector3(g.global_position.x, p.global_position.y, g.global_position.z + 2.0)
			p.reset_physics_interpolation()
			p.velocity = Vector3.ZERO
			p.state_machine.force_state("Technique", {"id": LAUNCHERS[i][2]})
			until = TK.wait_secs(0.5)
		3:
			var g = stage.camp.grunts[i]
			check("%s: %s launches the grunt (state %d, %.2f m up)" % [LAUNCHERS[i][0], LAUNCHERS[i][2], g.state, g.global_position.y], g.state == G.S.AIR)
			i += 1
			step = 1
			until = TK.wait_secs(0.8)
			return false
	step += 1
	return false
