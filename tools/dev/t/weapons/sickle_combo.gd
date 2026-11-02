extends SceneTree
## A chain sickle in hand (1.28): its own stance, nothing in the off hand (it holds the chain), the chain drawn from the
## pommel to the weight in the left hand; the two close cuts land; the third, the lash, lands from 4.5 m off with the
## weight thrown out along the line and drags them toward you; the right click whirls the weight round at full length
## (it lands on one behind).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var hits := 0
var last_hit: HitData
var far := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -2.0), "weapon": "chain_sickle"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func stand(off: float) -> void:
	p.global_position = stage.dummy.global_position + Vector3(0, 0.05, off)
	p.player_model.rotation.y = 0.0
	p.reset_physics_interpolation()
	p.velocity = Vector3.ZERO
	hits = 0


func _process(_d: float) -> bool:
	# (every frame, waiting or not: how far the weight gets during the lash)
	if p and p.body_model.current_action() == "sk_3":
		var w: Array = load("res://scripts/npc/sickle_moves.gd").weight_at(p.body_model)
		far = maxf(far, (w[0] as Vector3).distance_to(p.global_position))
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(h, _a):
				hits += 1
				last_hit = h)
			stage.camera_rig.rotation.y = 0.0
			until = TK.wait_secs(0.7)
		1:
			check("a chain sickle fights as one (%s / %s)" % [p.style(), p.body_model.stance], p.style() == "sickle" and p.body_model.stance == "sickle")
			var dirk = ItemDB.get_item("dagger")
			p.inventory_component.add_item(dirk, 1)
			check("nothing in the off hand: it holds the chain", not p.set_offhand(dirk) and p.offhand_weapon == null)
			var parts: Array = p.body_model.get_meta("sickle_chain", [])
			check("the chain and its weight are drawn", parts.size() == 2 and (parts[0] as Node3D).visible and (parts[1] as Node3D).visible)
			stand(1.6)
			TK.act("light_attack")
			until = TK.wait_ticks(6)
		2:
			check("left click: the first cut (%s)" % p.body_model.current_action(), p.body_model.current_action() == "sk_1")
			until = TK.wait_secs(0.35)
		3:
			check("it lands (%d)" % hits, hits >= 1)
			hits = 0
			TK.act("light_attack")
			until = TK.wait_secs(0.45)
		4:
			check("the second cut lands (%d)" % hits, hits >= 1)
			# out to 4.5 m for the lash
			stand(4.5)
			far = 0.0
			TK.act("light_attack")
			until = TK.wait_secs(0.15)
		5:
			check("then the lash (%s)" % p.body_model.current_action(), p.body_model.current_action() == "sk_3")
			until = TK.wait_secs(0.5)
		6:
			check("the weight flew out along the line (%.1f m)" % far, far > 3.8)
			check("the lash lands from 4.5 m (%d)" % hits, hits >= 1)
			check("...and drags them toward you (%.1f)" % (last_hit.knockback_force if last_hit else 0.0), last_hit != null and last_hit.knockback_force < 0.0)
			until = TK.wait_secs(0.9)
		7:
			if not p.is_free():
				return false
			stand(-3.5)
			TK.act("heavy_attack")
			until = TK.wait_ticks(6)
		8:
			check("right click: the Reaping Whirl (%s)" % p.body_model.current_action(), p.body_model.current_action() == "sk_heavy")
			until = TK.wait_secs(1.2)
		9:
			check("the whirl lands on one behind, 3.5 m off (%d)" % hits, hits >= 1)
			return TK.done(fails)
	step += 1
	return false
