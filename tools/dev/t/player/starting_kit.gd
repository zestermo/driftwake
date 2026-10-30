extends SceneTree
## A new captain starts with the cutlass sheathed on the hip and three rums, the tonic flask as the quick item.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	var p = stage.player
	var inv = p.inventory_component
	check("starts with cutlass", inv.count("cutlass") == 1)
	check("starts with 3 rum", inv.count("rum") == 3)
	check("the quick item: the tonic flask (1.25.2: every captain carries one) (%s)" % inv.quick, inv.quick == "tonic_flask")
	check("cutlass sheathed on hip", p.body_model.weapon != null and not p.body_model.weapon_in_hand and p.body_model.weapon.get_parent() == p.body_model.hip_socket)
	check("double jump starts locked", not p.has_ability("double_jump") and p.max_jumps == 1)
	return TK.done(fails)
