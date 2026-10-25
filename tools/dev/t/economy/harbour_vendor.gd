extends SceneTree
## Harbour vendors (1.21 piece 6): some generated islands have one by the pier (not all); the same island seed gives
## the same vendor in the same spot (co-op: every crewmate builds it alike), on dry, fairly flat ground near the pier;
## built, they stand at their pitch and either open a yard with only their lines (no paint) or trade the yard's
## materials (the chandler).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var fails := 0
var step := 0
var until := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _prepared(n: Dictionary):
	var isl = load("res://scripts/island/gen_island.gd").new()
	isl.prepare(n)
	return isl


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var HV = load("res://scripts/island/harbour_vendor.gd")
	var menu = root.get_node("GameMenu")
	match step:
		0:
			var c = load("res://scripts/world/chain.gd").make(7, Vector2.ZERO, Vector2(0, -1))
			var with: Array = []
			var without := 0
			var isl = null
			var node := {}
			for id in range(mini(c.nodes.size(), 10)):
				var n: Dictionary = c.node(id)
				load("res://scripts/island/island_theme.gd").meshes(str(n["theme"]))
				var gi = _prepared(n)
				if gi.vendor.is_empty():
					without += 1
					gi.free()
				else:
					with.append(gi.vendor["kind"])
					if isl == null:
						isl = gi
						node = n
					else:
						gi.free()
				if isl != null and without > 0:
					break
			print("   vendors: %s, %d islands without" % [with, without])
			check("some islands have a harbour vendor, some don't", isl != null and without > 0)
			if isl == null:
				return TK.done(fails)
			var v: Dictionary = isl.vendor
			check("by the pier (%.0f m from its root), on dry land (%.1f m up)" % [isl.dock_shore.distance_to(v["at"]), isl.hv(v["at"])],
				isl.dock_shore.distance_to(v["at"]) < 30.0 and isl.hv(v["at"]) > 0.9)
			var twin = _prepared(node)
			check("the same seed, the same vendor in the same spot", twin.vendor["kind"] == v["kind"] and twin.vendor["at"] == v["at"] and twin.vendor["seed"] == v["seed"])
			twin.free()
			isl.name = "VendorIsland"
			stage.add_child(isl)
			for s in HV.steps(isl):
				s[1].call()
			var site: Node3D = isl.get_node_or_null("HarbourVendor")
			var npcs: Array = site.find_children("*", "NPC", true, false) if site else []
			check("built: the vendor at their pitch", site != null and npcs.size() == 1)
			# the chandler: the yard's materials in a shop
			var ch: Dictionary = v.duplicate()
			ch["kind"] = "chandler"
			isl.vendor = ch
			site.name = "OldVendor"
			HV.build(isl)
			var cn: Array = isl.get_node("HarbourVendor").find_children("*", "NPC", true, false)
			var sh: Dictionary = load("res://scripts/game/shops.gd").shop(cn[0].shop_id) if cn.size() == 1 else {}
			check("the chandler sells the yard's materials", not sh.is_empty() and (sh["stock"] as Array).map(func(e): return e[0]) == ["timber", "canvas", "iron", "copper"])
			# a craftsman: their yard shows only their lines and no paint
			menu._on_dialogue_event(HV.yard_event({"kind": "rig", "seed": 3}))
			root.get_node("Dialogue").dialogue_ended.emit("vendor")
			isl.queue_free()
			until = TK.wait_ticks(3)
		1:
			var y = menu._yard
			var shown: Array = []
			for id in y._rows:
				if (y._rows[id] as Control).visible:
					shown.append(id)
			shown.sort()
			check("the sailmaker's yard: only the rig's lines (%s)" % [shown], shown == ["nest", "ropes", "sails"])
			check("...no paint tab", not (y._tabs["paint"] as Control).visible)
			check("...under their own name (%s)" % y.who, y.who != "Tackett" and y.who != "")
			menu.close()
			menu._on_dialogue_event("shipwright")
			root.get_node("Dialogue").dialogue_ended.emit("tackett")
			until = TK.wait_ticks(3)
		2:
			var y = menu._yard
			check("Tackett's yard: every line and the paint again", y._rows.values().all(func(r): return (r as Control).visible) and (y._tabs["paint"] as Control).visible)
			menu.close()
			return TK.done(fails)
	step += 1
	return false
