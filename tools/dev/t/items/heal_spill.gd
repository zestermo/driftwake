extends SceneTree
## A hit mid-drink spills the tonic: the item's gone, its heal never lands, the bottle leaves the hand, and the
## cooldown drops to the short retry.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var foe: Node3D
var n0 := 0
var hit_hp := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func hp() -> float:
	return p.health_component.current_health


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			var tonic: ItemData = load("res://resources/items/tonic.tres")
			p.inventory_component.add_item(tonic, 3)
			foe = Node3D.new()
			stage.add_child(foe)
			foe.global_position = p.global_position + Vector3(0, 0, -1.5)
			p.heal_cd = 0.0
			p.health_component.current_health = 20.0
			n0 = p.inventory_component.count("tonic")
			p.use_item(tonic)
			check("tonic: uncork and drink with a flask", p.body_model.current_action() == "tonic" and str(p.body_model._left_prop.mesh.get_meta("model")) == "flask")
			until = TK.wait_secs(0.3)
		1:
			var hd := HitData.new()
			hd.damage = 6.0
			p.hurtbox.take_hit(hd, foe)
			hit_hp = hp()
			check("a hit mid-drink spills it", not p.is_using_item() and p.body_model.current_action() != "tonic")
			check("...the tonic's gone", p.inventory_component.count("tonic") == n0 - 1)
			check("...and the cooldown drops to the retry (%.2f)" % p.heal_cd, p.heal_cd <= p.HEAL_RETRY)
			until = TK.wait_secs(1.2)
		2:
			check("...and its heal never lands (%.1f -> %.1f)" % [hit_hp, hp()], hp() < hit_hp + 2.0)
			check("the bottle's out of the hand", p.body_model._left_prop == null)
			return TK.done(fails)
	step += 1
	return false
