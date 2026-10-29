class_name VendorMarks
extends RefCounted
## Who sells what, at a glance (1.24.1): a vendor (an NPC with a shop) wears a small gold badge over their head with their
## trade's sign on it, and the same sign is put on the held map (MapMarks kind "shop"). The sign is an item icon that
## says the trade: a stew for a cook, a cutlass for a smith, a fiddle for the luthier, a pearl for a treasure buyer...

## trade (Shops' "trade"; "" for a general store) -> the item icon that signs it ("@<kind>" an instrument's)
const Shops := preload("res://scripts/game/shops.gd")
const SIGNS := {"cook": "stew", "smith": "cutlass", "armourer": "iron", "tailor": "canvas", "luthier": "@fiddle",
	"treasure": "pearl", "grocer": "flour", "artisan": "copper", "desert_trade": "pepper", "": "biscuit",
	# (1.26) services that aren't shops: a shipwright's yard, a master's teaching (shop ids "@shipwright", "@master")
	"shipwright": "timber", "master": "katana"}
## Services by their talk's event: (event prefix, pseudo shop id, the map's name).
const SERVICES := [["shipwright", "@shipwright", "Shipwright"], ["master:", "@master", "Master"], ["learn_black_leg", "@master", "Master"]]
## The badge's size on screen (metres over the head) and how far off it shows.
const BADGE_SIZE := 0.62
const SHOW_R := 30.0

static var _badge: Texture2D
static var _signs := {}


## The shop an NPC sells from: its own ("shop"), else one its conversation opens (a "shop:<id>" event); "" none.
static func shop_of(npc: Node) -> String:
	var own := str(npc.get("shop_id"))
	if own != "":
		return own
	var did := str(npc.get("dialogue_id"))
	var dlg := npc.get_node_or_null("/root/Dialogue")
	if did == "" or dlg == null:
		return ""
	var data: Dictionary = dlg._load(did)
	for n in (data.get("nodes", {}) as Dictionary).values():
		var ev := str((n as Dictionary).get("event", ""))
		if ev.begins_with("shop:") and not _shop(ev.substr(5)).is_empty():
			return ev.substr(5)
	for n in (data.get("nodes", {}) as Dictionary).values():
		var ev := str((n as Dictionary).get("event", ""))
		for s in SERVICES:
			if ev.begins_with(str(s[0])):
				return str(s[1])
	return ""


## The trade of a shop ("" a general store).
static func trade_of(shop_id: String) -> String:
	return str(_shop(shop_id).get("trade", ""))


static func _shop(shop_id: String) -> Dictionary:
	for s in SERVICES:
		if shop_id == str(s[1]):
			return {"name": str(s[2]), "trade": shop_id.substr(1)}
	return Shops.shop(shop_id) if Shops.SHOPS.has(shop_id) or Shops.extra.has(shop_id) else {}


## The sign for a trade (an item icon), cached.
static func sign_for(trade: String) -> Texture2D:
	var key := str(SIGNS.get(trade, SIGNS[""]))
	if _signs.has(key):
		return _signs[key]
	var tex: Texture2D = null
	if key.begins_with("@"):
		tex = Instruments.icon(key.substr(1))
	else:
		var path := "res://assets/textures/icons/%s.png" % key
		if ResourceLoader.exists(path):
			tex = load(path)
	_signs[key] = tex
	return tex


## The round gold-rimmed badge behind a sign (made once).
static func badge() -> Texture2D:
	if _badge:
		return _badge
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n, n) * 0.5 - Vector2(0.5, 0.5)
	for y in range(n):
		for x in range(n):
			var d := Vector2(x, y).distance_to(c)
			if d <= 15.5:
				var col := Color(0.12, 0.08, 0.05)
				if d > 13.0:
					col = Color(0.95, 0.72, 0.25) if d < 15.0 else Color(0.35, 0.2, 0.06)
				elif d > 12.0:
					col = Color(0.3, 0.18, 0.06)
				img.set_pixel(x, y, col)
	_badge = ImageTexture.create_from_image(img)
	return _badge


## The badge (with the shop's sign) over an NPC's head: a Node3D of two billboarded sprites, hidden until shown.
static func make_badge(shop_id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "VendorMark"
	for i in range(2):
		var s := Sprite3D.new()
		s.texture = badge() if i == 0 else sign_for(trade_of(shop_id))
		s.pixel_size = BADGE_SIZE / 32.0 if i == 0 else BADGE_SIZE * 0.66 / 24.0
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.no_depth_test = true
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.shaded = false
		s.render_priority = i
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(s)
	root.visible = false
	return root


## The vendor on the held map (this screen only): the shop's name and its sign.
static func map_put(key: String, at: Vector3, shop_id: String) -> void:
	MapMarks.put(key, at, "shop", str(_shop(shop_id).get("name", "")))
	MapMarks.marks[key]["trade"] = trade_of(shop_id)
