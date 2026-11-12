extends SceneTree
## Every icon the game renders itself, on one sheet: the items whose picture comes from their model (weapons, fish,
## bait, rods, gadgets, books, instruments: WeaponDesigns.mesh_icon) and a spread of generated gear (GearIcons), each
## in an inventory slot as a 1080p screen shows it (2x). Headless is fine: the icons are drawn on the CPU.
##   & $env:GODOT --headless --path . --script res://tools/dev/itemicons.gd -- res://tools/dev/out/iconreview/runtime
## writes <prefix>_models.png and <prefix>_gear.png.
const SLOT := 42
const PER := 16


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0] if a.size() > 0 else "res://tools/dev/out/iconreview/runtime"
	var DB = load("res://scripts/loot/item_db.gd")
	var G = load("res://scripts/loot/gear.gd")
	DB.get_item("cutlass")
	var seen := {}
	var models: Array = []
	var ids: Array = DB._items.keys()
	ids.sort()
	for id in ids:
		var it = DB._items[id]
		if it.icon == null or it.icon.resource_path != "" or seen.has(it.icon) or str(id).begins_with("gear_"):
			continue
		seen[it.icon] = true
		models.append(it.icon)
	var gear: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for k in range(400):
		var it = G.random_piece(rng, k % 4)
		if it and it.icon and not seen.has(it.icon):
			seen[it.icon] = true
			gear.append(it.icon)
		if gear.size() >= 96:
			break
	_sheet(models, out + "_models.png")
	_sheet(gear, out + "_gear.png")
	print("ITEMICONS %d models, %d gear" % [models.size(), gear.size()])
	quit()


func _sheet(icons: Array, path: String) -> void:
	var rows := ceili(icons.size() / float(PER))
	var cell := SLOT + 2
	var img := Image.create(PER * cell + 2, rows * cell + 2, false, Image.FORMAT_RGBA8)
	img.fill(Color8(26, 28, 41))
	for i in range(icons.size()):
		var x0 := 2 + (i % PER) * cell
		var y0 := 2 + (i / PER) * cell
		img.fill_rect(Rect2i(x0, y0, SLOT, SLOT), Color8(190, 150, 70))
		img.fill_rect(Rect2i(x0 + 1, y0 + 1, SLOT - 2, SLOT - 2), Color8(14, 40, 46))
		var src: Image = (icons[i] as Texture2D).get_image()
		src.convert(Image.FORMAT_RGBA8)
		img.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i(x0 + (SLOT - src.get_width()) / 2, y0 + (SLOT - src.get_height()) / 2))
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(path))
