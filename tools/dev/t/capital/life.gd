extends SceneTree
## The capital's life (CapitalLife, CapitalCrowd, piece 3): its named people at their places with their shops and
## talk; the curio dealer a treasure merchant a tier above the islands' whose stock is the same for a day and turns
## over with it; the inn's rest heals and saves; the notice board posts the Watch's notice and taking it puts it in
## the journal; eight city quests registered (1.21: the docks' manifest, the terrace's invitation, the palace's line of three, each
## offered only after the last); the docks' chandler, fence and
## Marta Coyle's yard (the yard screen under her name), the terrace's outfitter; the toughs of Gallows Row muster host-side (single player is the host)
## round their fire; the crowd walks where the shared clock says, the same at the same time, and swaps real bodies in
## only near the camera.
const TK := preload("res://tools/dev/test_kit.gd")
const SHOPS := preload("res://scripts/game/shops.gd")
const AT := Vector3(0, 0, 4000)
var stage
var step := 0
var until := 0
var fails := 0
var w
var isl


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			until = TK.wait_ticks(2)
		1:
			isl = w.build_capital(AT)
			until = TK.wait_secs(4.0)
		2:
			var life = isl.life_node
			var names := {}
			for n in isl.find_children("*", "NPC", true, false):
				names[n.npc_name] = n
			var want: Array = load("res://scripts/island/capital_life.gd").cast().map(func(c): return c["name"])
			var missing: Array = want.filter(func(nm): return not names.has(nm))
			check("every named person is there (%d; missing %s)" % [names.size(), missing], missing.is_empty())
			var curio: String = isl.save_key("capital_curio")
			var sh: Dictionary = SHOPS.extra.get(curio, {})
			check("the curio dealer is a treasure merchant a tier above the islands' (tier %s)" % sh.get("tier"), sh.get("trade", "") == "treasure" and int(sh.get("tier", 0)) >= 3)
			check("Severin Quayle trades there", names.has("Severin Quayle") and names["Severin Quayle"].shop_id == curio)
			check("his stock is the same for a day and turns over", str(SHOPS.stock_on(curio, 12)) == str(SHOPS.stock_on(curio, 12)) and str(SHOPS.stock_on(curio, 12)) != str(SHOPS.stock_on(curio, 13)))
			for id in ["capital_grocer", "capital_fish", "capital_tailor", "capital_inn"]:
				check("the %s shop is open" % id, SHOPS.extra.has(isl.save_key(id)))
			# 1.21: the docks and the noble quarter
			var fence: Dictionary = SHOPS.extra.get(isl.save_key("capital_fence"), {})
			var outfit: Dictionary = SHOPS.extra.get(isl.save_key("capital_outfitter"), {})
			check("the chandler sells the shipwright's materials", str(SHOPS.extra.get(isl.save_key("capital_chandler"), {}).get("stock", [])).contains("timber"))
			check("the fence pays more than full price for plunder", fence.get("trade", "") == "treasure" and float((fence.get("buys", {}) as Dictionary).get("loot", 0.0)) > 1.0)
			check("the outfitter's gear a tier above the curio dealer's floor (tier %s)" % outfit.get("tier"), outfit.get("trade", "") == "treasure" and int(outfit.get("tier", 0)) >= 3)
			var yard: Dictionary = root.get_node("Dialogue")._cache.get(isl.save_key("capital_shipwright"), {})
			check("Marta Coyle's yard opens under her name", str(yard).contains("shipwright:Coyle"))
			var menu = root.get_node("GameMenu")
			menu._yard.set_yard("Coyle")
			check("...and the yard screen says so", menu._yard.who == "Coyle" and menu._yard._title.text == "Coyle's Yard")
			menu._yard.set_yard("Tackett")
			var rest = life.get_node_or_null("Rest")
			var odile: Node3D = names.get("Odile Marchbank")
			check("the inn's rest at its door, by the innkeeper", rest != null and odile != null and (rest as Node3D).global_position.distance_to(odile.global_position) < 5.0)
			var p = stage.player
			p.health_component.current_health = p.health_component.max_health * 0.3
			rest.interacted.emit(p)
			check("resting at the inn heals", p.health_component.current_health >= p.health_component.max_health - 0.5)
			check("eight city quests in the journal's sources", life.quest_node.quests.size() == 8)
			var cham: Dictionary = root.get_node("Dialogue")._cache.get(isl.save_key("capital_chamberlain"), {})
			var offered := {}
			for c in (cham.get("nodes", {}).get("menu", {}).get("choices", []) as Array):
				offered[str(c["text"])] = not c.has("if") or (c["if"] as Callable).call()
			check("the palace line starts with the petition (%s)" % offered, offered.get("I'd like an audience with the Queen.", false))
			check("...and the signet waits for it", not offered.get("What delicate matter?", true) and not offered.get("I'm ready to see the Queen.", true))
			var gid: String = isl.save_key("capital_gallows")
			root.get_node("Dialogue").emit_signal("dialogue_event", "isle_q:%s:take" % gid)
			check("taking the Watch's notice puts it in the journal", root.get_node("Journal").has(gid))
			until = TK.wait_secs(6.0)
		3:
			var life = isl.life_node
			var camp = life.ruffians
			check("the toughs muster round their fire (%d)" % camp.alive_count(), camp.alive_count() == 4)
			var fire: Vector3 = life._spot("fire")[0]
			var near := true
			for g in camp.grunts:
				near = near and isl.to_local((g as Node3D).global_position).distance_to(fire) < 8.0
			check("all of them in the yard", near)
			var crowd = isl.crowd
			var a: Array = crowd.place_of(5, 100.0)
			var b: Array = crowd.place_of(5, 100.0)
			var c: Array = crowd.place_of(5, 110.0)
			check("a walker is where the clock says, the same each time", a[0] == b[0] and (a[0] as Vector3).distance_to(c[0]) > 3.0)
			var P = load("res://scripts/island/capital_plan.gd")
			var off := 0
			for i in range(crowd.walkers.size()):
				var q: Vector3 = crowd.place_of(i, 50.0 + i * 3.0)[0]
				if not P.in_floor(Vector2(q.x, q.z)):
					off += 1
			check("the crowd walks on the floors (%d off)" % off, off == 0)
			var bodies: Array = crowd._bodies.filter(func(h): return h.visible)
			check("no real bodies in the crowd with the camera far off (%d)" % bodies.size(), bodies.is_empty())
			isl.queue_free()
			return TK.done(fails)
	step += 1
	return false
