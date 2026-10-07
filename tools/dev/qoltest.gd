extends SceneTree
## Brinehollow QoL round: traders (buy, sell treasure, gear made to order,
## stalls opened by talking), the gold counter, the yard's live preview, the
## anchor on its chain worked at the capstan, auto-anchor in port, the
## compass strip, chart marks (set, remove, clear, reached), Gus's Sea King
## rumour, hull damage numbers.
var t := 0.0
var step := 0
var wait := 0.0
var p
var ship
var menu
var hud
var gm
var net
var fails := 0
var t0 := 0.0
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond: fails += 1
func finish() -> void:
	Input.action_release("interact")
	print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	quit()
func gold() -> int:
	return p.inventory_component.count("gold")
func item(id: String):
	return load("res://resources/items/%s.tres" % id)
func click(at: Vector2, right: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT if right else MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = at
	menu._chart._gui_input(ev)
func _process(d: float) -> bool:
	t += d
	if t > 90.0:
		check("timed out at step %d" % step, false)
		finish()
		return true
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 1.5: return false
			p = get_first_node_in_group("player")
			ship = get_first_node_in_group("ship")
			menu = root.get_node("GameMenu")
			hud = get_first_node_in_group("hud")
			gm = root.get_node("GameManager")
			net = root.get_node("Net")
			# --- traders
			var vendors := {}
			for n in current_scene.find_children("*", "NPC", true, false):
				if n.shop_id != "":
					vendors[n.shop_id] = n
			check("market stalls trade (%s)" % ", ".join(vendors.keys()), vendors.has("marlo") and vendors.has("sela") and vendors.has("ida"))
			check("...and say so", vendors.has("marlo") and vendors["marlo"].interactable.prompt_text.begins_with("Trade"))
			# tiers: Brinehollow's goods are white or green
			var top := 0
			var shops = load("res://scripts/game/shops.gd")
			for sid in shops.SHOPS.keys():
				for e in shops.SHOPS[sid]["stock"]:
					top = maxi(top, int(shops.item_of(e).rarity))
			check("everything for sale on Brinehollow is white or green", top <= 1)
			check("a level takes twice the XP it did (100 for the first)", p.progression.xp_to_next(1) == 100)
			p.inventory_component.remove_item(item("gold"), gold())
			p.inventory_component.add_item(item("treasure"), 10)
			var dlg = root.get_node("Dialogue")
			dlg.dialogue_event.emit("shop:nessa")
			dlg.dialogue_ended.emit("nessa")
			wait = 0.3
			step = 1
		1:
			check("Nessa's 'Let's trade' opens her stall", menu._current == "shop" and menu._shop.shop_id == "nessa")
			var shop = menu._shop
			var gem: int = item("treasure").worth()
			shop.sell(item("treasure"), 10)
			print("   sold 10 treasure (green, %d each): gold %d" % [gem, gold()])
			check("she buys treasure at full worth", gold() == 10 * gem and gem >= 24 and p.inventory_component.count("treasure") == 0)
			check("the gold counter shows it", hud._gold_label.text == str(10 * gem) and hud._gold_t > 0.0)
			shop.buy(["rum", 9])
			check("buying rum: in the bag, gold gone", gold() == 10 * gem - 9 and p.inventory_component.count("rum") >= 1)
			menu.close()
			menu.open_shop("sela")
			var coat: Array = []
			for e in menu._shop.SHOPS.SHOPS["sela"]["stock"]:
				if e.size() == 5 and e[1] == "captain":
					coat = e
			var before: int = p.inventory_component.items.size()
			var g0 := gold()
			menu._shop.buy(coat)
			var got = p.inventory_component.items[-1].item
			check("Sela's captain's coat: a green gear piece, made to order", p.inventory_component.items.size() == before + 1
				and got.is_gear() and got.rarity == 1 and gold() == g0 - 190)
			menu._shop.buy(coat)
			check("no gold, no coat", gold() == g0 - 190)
			# selling clothes back to her, and spare steel to Vey
			var sold_coat := gold()
			menu._shop.sell(got, 1)
			check("Sela buys clothes back (at a tier-weighted price)", gold() > sold_coat and gold() == sold_coat + menu._shop.SHOPS.offer("sela", got))
			menu.close()
			menu.open_shop("vey")
			var blade = load("res://scripts/loot/item_db.gd").get_item("cutlass@2")
			p.inventory_component.add_item(blade, 1)
			var g1 := gold()
			menu._shop.sell(blade, 1)
			check("Vey buys a spare blue cutlass (%d g)" % (gold() - g1), gold() > g1 and blade.rarity == 2 and blade.id == "cutlass@2")
			check("a blue cutlass hits harder than a white one", blade.power() > item("cutlass").power())
			menu.close()
			menu.open_shop("sela")
			menu.close()
			menu.open_shop("marlo")
			check("Marlo doesn't buy", menu._shop._buy_list.get_child_count() >= 1)
			menu._shop.buy(["fish", 5])
			check("...but sells grilled fish (a meal: heals)", p.inventory_component.count("fish") == 1 and item("fish").heal_amount > 0.0)
			menu.close()
			# --- the yard: the ship on show, no dimming
			var cam0 = p.get_viewport().get_camera_3d()
			menu.open("yard")
			wait = 0.2
			set_meta("cam0", cam0)
			step = 2
		2:
			var cam = p.get_viewport().get_camera_3d()
			check("the yard shows the ship (its own camera, no dim)", cam != null and cam.name == "YardCamera" and not menu._dim.visible)
			var before: int = int(gm.ship_kit["hull"])
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_RIGHT
			ev.pressed = true
			menu._yard._cycles[0][1].gui_input.emit(ev)
			check("right-click steps a colour back", int(gm.ship_kit["hull"]) == posmod(before - 1, 6))
			menu.close()
			check("...and the view comes back after", p.get_viewport().get_camera_3d() == get_meta("cam0"))
			# --- the capstan: hold F to let go
			p.state_machine.force_state("Idle", {})
			p.global_position = ship.global_transform * (ship.CAPSTAN_AT + Vector3(0.0, 0.5, 0.8))
			p.reset_physics_interpolation()
			check("moored but not anchored to start", not ship.anchored)
			wait = 0.5
			step = 3
		3:
			Input.action_press("interact")
			t0 = t
			step = 4
		4:
			if p.body_model.kneeling:
				set_meta("knelt", true)
			if t - t0 < ship.ANCHOR_TIME + 0.5:
				return false
			Input.action_release("interact")
			check("kneeling at the capstan", bool(get_meta("knelt", false)))
			check("holding F there lets the anchor go", ship.anchored)
			wait = 6.0
			step = 5
		5:
			var shown := 0
			for c in ship._cable.get_children():
				if c.visible:
					shown += 1
			print("   chain links paid out: %d, anchor %.1f m down" % [shown, ship.ANCHOR_AT.y - ship._anchor.position.y])
			check("the chain pays out link by link after it", shown > 25 and ship._anchor.position.y < ship.ANCHOR_AT.y - 3.0)
			Input.action_press("interact")
			t0 = t
			step = 6
		6:
			if t - t0 < ship.ANCHOR_TIME + 0.5:
				return false
			Input.action_release("interact")
			check("...and weighs it again", not ship.anchored)
			# --- leave the wheel in port: anchored
			p.current_ship = ship
			p.state_machine.force_state("Helm", {})
			wait = 0.4
			step = 7
		7:
			check("the compass is up at the helm", hud._compass.visible)
			p.state_machine.force_state("Idle", {})
			check("leaving the wheel by the dock drops the anchor", ship.anchored and ship.in_port())
			ship.set_anchored(false)
			# --- chart marks
			p.global_position = ship.global_transform * Vector3(0, 0.6, 2.0)
			p.reset_physics_interpolation()
			menu.open("chart")
			click(Vector2(400, 100), false)
			click(Vector2(150, 220), false)
			var mine: Array = net.waypoints.get(net.my_id(), [])
			check("clicking the chart sets marks (2)", mine.size() == 2)
			click(Vector2(401, 101), true)
			mine = net.waypoints.get(net.my_id(), [])
			check("right-click on one takes it off", mine.size() == 1)
			menu._chart.clear_marks()
			check("C clears them all", not net.waypoints.has(net.my_id()))
			menu.close()
			var far := Vector2(p.global_position.x + 300.0, p.global_position.z)
			net.set_waypoints([far])
			p.global_position = Vector3(p.global_position.x, 30.0, p.global_position.z + 200.0)
			p.reset_physics_interpolation()
			wait = 0.3
			step = 8
		8:
			check("off the ship, a mark keeps the compass up", hud._compass.visible)
			var mine: Array = net.waypoints.get(net.my_id(), [])
			p.global_position = Vector3(mine[0].x + 5.0, 40.0, mine[0].y)
			p.reset_physics_interpolation()
			wait = 0.3
			step = 9
		9:
			check("reaching a mark clears it", not net.waypoints.has(net.my_id()))
			# --- Gus's rumour
			gm.charted.erase("king")
			root.get_node("Dialogue").dialogue_event.emit("rumour_king")
			check("Gus's Sea King tale puts it on the chart", gm.charted.has("king"))
			# --- hull damage numbers
			ship.hull_hit(20.0, ship.global_position + Vector3(2, 0, 0))
			var shown := false
			for l in current_scene.find_children("*", "Label3D", true, false):
				if l.text == "-20 hull":
					shown = true
			check("a hit on the hull floats its number", shown)
			# --- weapon designs
			var db = load("res://scripts/loot/item_db.gd")
			var designs = load("res://scripts/props/weapon_designs.gd")
			var n := 0
			var iconless := 0
			for k in designs.BASE_ITEM.keys():
				for id in designs.item_ids(k):
					var it = db.get_item(id)
					n += 1
					if it == null or not it.is_weapon() or it.icon == null:
						iconless += 1
			print("   %d weapon designs" % n)
			check("every weapon design is an item with its own icon (%d designs)" % n, n >= 24 and iconless == 0)
			var rap = db.get_item("rapier@4")
			check("a legendary rapier: its model carries design and tier", rap.model() == "cutlass:rapier:4" and str(Props.weapon_mesh(rap.model()).get_meta("model")) == "cutlass:rapier:4")
			p.state_machine.force_state("Idle", {})
			p.inventory_component.add_item(db.get_item("nodachi"), 1)
			p.equip_weapon(db.get_item("nodachi"))
			var saya = p.body_model._katana_socket.get_node("Saya") if p.body_model._katana_socket else null
			check("a nodachi is a katana (stance, scabbard) with a longer scabbard", p.style() == "katana" and p.body_model.is_katana() and saya != null and saya.scale.z > 1.2)
			var blades := {}
			for g in get_nodes_in_group("enemies"):
				if g.get("_blade_model") != null:
					blades[g._blade_model] = true
			print("   pirate blades: %s" % ", ".join(blades.keys()))
			check("pirates carry different blades", blades.size() >= 2)
			finish()
	return false
