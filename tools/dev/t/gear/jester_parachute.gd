extends SceneTree
## (1.29) Parachute pants and the jester outfit: the pants balloon wide of the legs (and push the cloth over them out
## with them); the jester's cap, motley top, motley hose and curled shoes are four items in two colours, the cap's points
## and the collar's bells swing on chains, three of them worn make a set; the tailor sells them, the creator has the
## pants but not the jester's motley.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var gear
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


func chains(node) -> int:
	var n := 0
	for c in node.get_children():
		if c is SpringChains:
			n += c.chain_count()
	return n


func legs_width(body) -> float:
	for c in body.hips.get_children():
		if c is LowerBody:
			for m in c.get_children():
				if m is MeshInstance3D and m.mesh:
					return m.mesh.get_aabb().size.x
	return 0.0


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			gear = load("res://scripts/loot/gear.gd")
			var stats = load("res://scripts/items/gear_stats.gd")
			var body = p.body_model
			var lk := CharacterLook.default_look()
			lk["legs"] = "trousers"
			body.apply_look(lk)
			var plain := legs_width(body)
			var thigh0: float = body._sims[0].colliders["thigh_l"]["r"] if not body._sims.is_empty() else 0.0
			lk["legs"] = "parachute"
			body.apply_look(lk)
			var puffed := legs_width(body)
			check("parachute pants balloon wide of the legs (%.2f m across, trousers %.2f)" % [puffed, plain], puffed > plain + 0.05)
			var thigh1: float = body._sims[0].colliders["thigh_l"]["r"] if not body._sims.is_empty() else 0.0
			check("...and the cloth over them is pushed out by them (thigh capsule %.3f, was %.3f)" % [thigh1, thigh0], thigh1 > thigh0 + 0.02)
			var C := CharacterLook.CLOTH
			var pieces := {"head": ["jester", {"hat": "jester", "hat_color": C[13], "motley_color": C[15]}],
				"torso": ["motley", {"top": "motley", "sleeves": "long", "top_color": C[13], "motley_color": C[15]}],
				"legs": ["motley_hose", {"legs": "motley_hose", "legs_color": C[13], "motley_color": C[15]}],
				"feet": ["curled", {"feet": "curled", "feet_color": C[13], "motley_color": C[15]}]}
			var bad := []
			p.equipment.clear()
			for slot in pieces.keys():
				var it = gear.make(slot, pieces[slot][0], pieces[slot][1])
				if gear.NAMES.get(pieces[slot][0], "") == "" or it.icon == null or stats.of(it).is_empty():
					bad.append(pieces[slot][0])
				p.equipment.equip(it, slot)
			check("each jester piece is its own named item with stats and an icon (bad: %s)" % str(bad), bad.is_empty())
			var head_before := chains(body.head)
			p.refresh_look()
			body = p.body_model
			check("worn: cap, motley top, hose and curled shoes in two colours", body.look.get("hat") == "jester" and body.look.get("top") == "motley"
				and body.look.get("legs") == "motley_hose" and body.look.get("feet") == "curled" and body.look.get("motley_color") == C[15])
			check("the cap's three points swing on the head's chains (%d)" % chains(body.head), chains(body.head) >= 3)
			check("the collar's bells on the torso's (%d)" % chains(body.torso), chains(body.torso) >= 4)
			check("three or more pieces: the jester set", stats.set_count(p.equipment.slots, "jester") == 4 and stats.totals(p.equipment.slots).has("dodge_dist_pct"))
			var shops = load("res://scripts/game/shops.gd")
			var sela: Array = (shops.SHOPS["sela"]["pool"] as Array).map(func(e): return str(e[1]))
			check("the tailor sells the jester's pieces and parachute pants", ["jester", "motley", "motley_hose", "curled", "parachute"].all(func(s): return sela.has(s)))
			var outfit: Dictionary = gear.items_from_look(body.look)
			check("a look's motley becomes gear in its two colours", outfit.has("head") and outfit["head"].look.get("motley_color") == C[15])
			check("the creator has parachute pants, not the jester's motley", CharacterLook.CREATOR_LEGS.has("parachute") and not CharacterLook.CREATOR_LEGS.has("motley_hose")
				and not CharacterLook.CREATOR_TOPS.has("motley"))
			TK.press("move_forward")
			until = TK.wait_secs(1.0)
		1:
			TK.release("move_forward")
			var ok := true
			for s in p.body_model._sims:
				for b in range(s.skel.get_bone_count()):
					var o: Vector3 = s.skel.get_bone_global_pose(b).origin
					if not o.is_finite() or o.length() > 3.0:
						ok = false
			check("walking: every bell and point stays on the body", ok)
			return TK.done(fails)
	step += 1
	return false
