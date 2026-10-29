extends SceneTree
## A gun's sprint attack fires out of a real sprint (1.26: Move's exit cleared `sprinting` before ShootState read it,
## so Cannon Ram, Skid Shot and Stock Rush never played in a game; the older tests set `sprinting` from Idle). Each gun
## in turn: hold forward + sprint, left-click, and its sprint move starts.
const TK := preload("res://tools/dev/test_kit.gd")
const GUNS := [["hand_cannon", "cn_ram"], ["slingshot", "sl_skid"], ["musket", "lg_rush"]]
var stage
var p
var i := 0
var step := 0
var until := 0
var fails := 0
var start := Vector3.ZERO


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "hand_cannon"})


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
			p.progression.master_all()
			start = p.global_position
			stage.camera_rig.rotation.y = 0.0
			until = TK.wait_secs(0.6)
		1:
			var id: String = GUNS[i][0]
			var it = ItemDB.get_item(id)
			if p.inventory_component.count(id) == 0:
				p.inventory_component.add_item(it)
			p.equip_weapon(it, true)
			p._reset_ammo()
			p.global_position = start
			p.reset_physics_interpolation()
			until = TK.wait_secs(0.8)
		2:
			TK.press("move_forward")
			TK.press("sprint")
			until = TK.wait_secs(0.5)
		3:
			check("%s: sprinting in Move (%s)" % [GUNS[i][0], p.current_state_name()], p.sprinting and p.current_state_name() == "Move")
			TK.act("light_attack")
			until = TK.wait_ticks(4)
		4:
			check("%s: left-click at a sprint plays %s (%s)" % [GUNS[i][0], GUNS[i][1], p.body_model.current_action()], p.body_model.current_action() == GUNS[i][1])
			TK.release("move_forward")
			TK.release("sprint")
			until = TK.wait_secs(1.6)
		5:
			i += 1
			if i < GUNS.size():
				step = 1
				return false
			return TK.done(fails)
	step += 1
	return false
