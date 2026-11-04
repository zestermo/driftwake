extends SceneTree
## (1.30) Transmog in the inventory, at 1920x1080: a MOG box under each clothing slot's outer side; ticking it shows a
## cosmetic slot there (not over anything else), drag-and-drop and right-click put a bag piece in it, a click takes it
## back out; the tooltip says FOR LOOKS, and the bag's better-than-worn arrow still compares with the worn piece.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var gm
var ui
var inv
var gear
var helm
var straw
var cav
var hakama
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


func idx_of(it) -> int:
	for i in range(inv.items.size()):
		if inv.items[i].item == it:
			return i
	return -1


func rect(c: Control) -> Rect2:
	return Rect2(ui._par[c][0], c.size)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			root.size = Vector2i(1920, 1080)
			p = stage.player
			gm = root.get_node("GameMenu")
			inv = p.inventory_component
			gear = load("res://scripts/loot/gear.gd")
			helm = gear.make("head", "kettle", {"hat": "kettle"}, "", 0)
			straw = gear.make("head", "straw", {"hat": "straw"}, "", 0)
			cav = gear.make("head", "cavalier", {"hat": "cavalier"}, "", 0)
			p.equipment.equip(helm)
			inv.add_item(straw, 1)
			inv.add_item(cav, 1)
			hakama = gear.make("legs", "hakama", {"legs": "hakama"}, "", 0)
			inv.add_item(hakama, 1)
			p.refresh_look()
			gm.open("inventory")
			until = TK.wait_ticks(6)
		1:
			ui = gm._inventory
			check("a MOG box for each of the 10 clothing slots, none for accessories or equipment",
				ui._mog_box.size() == 10 and not ui._mog_box.has("acc1") and not ui._mog_box.has("equipment"))
			var shown := 0
			for s in ui._mog_box.keys():
				if ui._mog_box[s].visible and not ui._mog_box[s].button_pressed and not ui._mog[s].visible:
					shown += 1
			check("all unticked, their cosmetic slots hidden (%d)" % shown, shown == 10)
			for s in ui._mog.keys():
				ui._mog_box[s].button_pressed = true
			var bad := []
			var others: Array = ui._doll.values() + [ui._drape_box, ui._show_box, ui._weapon_slot, ui._offhand_slot]
			var all: Array = []
			for s in ui._mog.keys():
				all.append(ui._mog[s])
				all.append(ui._mog_box[s])
			for a in all:
				var r: Rect2 = rect(a)
				if r.position.x < 0 or r.end.x > ui._canvas.x or r.end.y > ui._canvas.y or r.intersects(rect(ui._panel)):
					bad.append(a.name + " off the canvas or under the panel")
				for o in others + all:
					if o != a and r.intersects(rect(o)):
						bad.append("%s over %s" % [a.name, o.name])
			check("ticked: every cosmetic slot and box clear of the rest (%s)" % ", ".join(bad.slice(0, 4)), bad.is_empty())
			var head_r: Rect2 = rect(ui._doll["head"])
			var legs_r: Rect2 = rect(ui._doll["legs"])
			check("...beside its slot on the outer side (head left, legs right)", rect(ui._mog["head"]).end.x <= head_r.position.x
				and is_equal_approx(rect(ui._mog["head"]).position.y, head_r.position.y) and rect(ui._mog["legs"]).position.x >= legs_r.end.x)
			for s in ui._mog.keys():
				if s != "head" and s != "legs":
					ui._mog_box[s].button_pressed = false
			check("the body still wears the helm (an empty cosmetic slot)", p.body_model.look.get("hat") == "kettle")
			var d := {"src": "bag", "idx": idx_of(cav), "item": cav}
			check("the hakama can't be dropped on the head's cosmetic slot",
				not ui._can_drop_on({"src": "mog", "slot": "head"}, {"src": "bag", "idx": idx_of(hakama), "item": hakama}))
			ui._drop_on({"src": "mog", "slot": "head"}, d)
			check("drag a cavalier hat onto it: the body wears it (%s)" % p.body_model.look.get("hat"), p.body_model.look.get("hat") == "cavalier" and idx_of(cav) == -1)
			check("...the worn slot still holds the helm, the stats its", p.equipment.get_item("head") == helm)
			ui._right_click_bag(idx_of(straw))
			check("right-click the straw hat: it swaps in, the cavalier back to the bag", p.body_model.look.get("hat") == "straw" and idx_of(cav) != -1 and idx_of(straw) == -1)
			ui.fill_info(ui._tip_box, straw, 1, "mog", ui.TIP_W, p)
			var txt := ""
			for n in ui._tip_box.find_children("*", "Label", true, false):
				txt += n.text + " "
			check("its tooltip says FOR LOOKS", txt.contains("FOR LOOKS"))
			check("the bag's arrow compares with the worn helm, not the straw hat", not ui.better_than_worn(cav))
			ui._drop_on({"src": "bag", "idx": inv.items.size()}, {"src": "mog", "slot": "head", "item": straw})
			check("drag it back to the bag: the helm shows again", idx_of(straw) != -1 and p.equipment.get_cosmetic("head") == null and p.body_model.look.get("hat") == "kettle")
			ui._right_click_bag(idx_of(straw))
			ui._on_mog_pressed("head")
			check("click the cosmetic slot: back to the bag", idx_of(straw) != -1 and p.body_model.look.get("hat") == "kettle")
			ui._right_click_bag(idx_of(straw))
			ui._mog_box["head"].button_pressed = false
			check("untick MOG: the slot hides, the helm shows, the straw hat waits there", not ui._mog["head"].visible
				and p.body_model.look.get("hat") == "kettle" and p.equipment.get_cosmetic("head") == straw)
			gm.close()
			return TK.done(fails)
	step += 1
	return false
