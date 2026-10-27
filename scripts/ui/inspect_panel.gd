extends PanelContainer
## Inspect (the player menu): another captain's name, level, fighting style and fruit, and what they carry:
## weapons, the ten worn slots, the quick item. Read only; the inventory's slots and item cards (hover a slot).

const STYLES := {"fist": "Brawler", "black_leg": "Black Leg","sword": "Cutlass", "axe": "Axe", "katana": "Katana", "dagger": "Dagger", "polearm": "Polearm", "hammer": "Hammer", "greatsword": "Greatsword",
	"dual_sword": "Twin blades", "dual_dagger": "Twin daggers", "dual_axe": "Twin axes", "sword_pistol": "Blade and pistol",
	"pistol": "Pistol", "dual_pistol": "Twin pistols", "claw": "Beast claws", "long_gun": "Long gun"}
const TIP_W := 150

var viewer: Node
## What's shown, by slot ("weapon", "offhand", the doll's slots, "quick0").
var items: Dictionary = {}
var _name: Label
var _line: Label
var _slots: Dictionary = {}
var _tip: PanelContainer
var _tip_box: VBoxContainer
var _wait: Label


func _init() -> void:
	name = "Inspect"
	add_theme_stylebox_override("panel", UIStyle.panel(UIStyle.BG, UIStyle.BORDER, 8))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	add_child(vb)
	_name = UIStyle.label("", 16, UIStyle.ACCENT)
	_name.add_theme_font_override("font", load("res://assets/fonts/PixelifySans-SemiBold.woff2"))
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_name)
	_line = InventoryScreen.small("", UIStyle.TEXT_DIM)
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_line)
	vb.add_child(HSeparator.new())
	_wait = UIStyle.label("Asking...", 12, UIStyle.TEXT_DIM)
	_wait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_wait)
	vb.add_child(_row("HANDS", [["weapon", "MAIN"], ["offhand", "OFF"]]))
	for col in InventoryScreen.DOLL:
		var r: Array = []
		for s in col:
			r.append([s, InventoryScreen.TAGS[s]])
		vb.add_child(_row("WORN" if col == InventoryScreen.DOLL[0] else "", r))
	vb.add_child(_row("QUICK", [["quick0", "E"]]))
	vb.add_child(UIStyle.key_hint("ESC", "BACK"))
	_tip = PanelContainer.new()
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	_tip.top_level = true
	_tip_box = VBoxContainer.new()
	_tip_box.add_theme_constant_override("separation", 2)
	_tip.add_child(_tip_box)
	add_child(_tip)


func _row(label: String, slots: Array) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", InventoryScreen.GAP)
	var l := InventoryScreen.small(label, UIStyle.TEXT_DIM)
	l.custom_minimum_size = Vector2(38, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(l)
	for e in slots:
		var key: String = e[0]
		var s := InventoryScreen.Slot.new(str(e[1]), {})
		s.focus_mode = Control.FOCUS_NONE
		s.mouse_entered.connect(func(): _hover(key, s))
		s.mouse_exited.connect(func(): _tip.visible = false)
		hb.add_child(s)
		_slots[key] = s
	return hb


## Waiting for their kit (it comes from their machine).
func clear(who: String) -> void:
	_name.text = who
	_line.text = ""
	_wait.visible = true
	items.clear()
	for s in _slots.values():
		(s as InventoryScreen.Slot).show_item(null, 0)


func show_kit(k: Dictionary) -> void:
	var sg = load("res://scripts/game/save_game.gd")
	_wait.visible = false
	_name.text = str(k["name"])
	var fruit := str(k["fruit"])
	var fname := ""
	if fruit != "":
		fname = "    " + str(load("res://scripts/powers/devil_fruits.gd").get_fruit(fruit).get("name", "Driftfruit")).to_upper()
	_line.text = "LV %d    %s%s" % [int(k["level"]), str(STYLES.get(str(k["style"]), str(k["style"]))).to_upper(), fname]
	items.clear()
	items["weapon"] = sg.item_from(k["weapon"])
	items["offhand"] = sg.item_from(k["offhand"])
	for col in InventoryScreen.DOLL:
		for s in col:
			items[s] = sg.item_from(k["gear"][s]) if (k["gear"] as Dictionary).has(s) else null
	var quick: Array = k["quick"]
	for i in range(quick.size()):
		items["quick%d" % i] = sg.item_from(quick[i][0])
		items["quick%d_n" % i] = int(quick[i][1])
	for key in _slots.keys():
		var it: ItemData = items.get(key)
		var n: int = int(items.get(key + "_n", 1)) if it else 0
		(_slots[key] as InventoryScreen.Slot).show_item(it, n)


func _hover(key: String, s: Control) -> void:
	var it: ItemData = items.get(key)
	if it == null:
		_tip.visible = false
		return
	InventoryScreen.fill_info(_tip_box, it, int(items.get(key + "_n", 1)), "inspect", TIP_W, viewer)
	var border := it.rarity_color() if it.rarity != ItemData.Rarity.SUPREME else Color(0.85, 0.85, 0.8)
	_tip.add_theme_stylebox_override("panel", UIStyle.frame(UIStyle.BG_DARK, border, 5, "plank"))
	_tip.visible = true
	_tip.reset_size()
	# beside the panel (left of it, or right if there's no room), level with the slot
	var r := s.get_global_rect()
	var pr := get_global_rect()
	var vs := get_viewport_rect().size
	var x := pr.position.x - 4.0 - _tip.size.x if pr.position.x - 4.0 - _tip.size.x >= 2.0 else pr.end.x + 4.0
	_tip.global_position = Vector2(x, clampf(r.position.y, 2.0, vs.y - _tip.size.y - 2.0)).round()
