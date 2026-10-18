extends PanelContainer
## "What's new" on the title screen: the version's big changes. Shown by itself
## the first time a new version is opened (SEEN_FILE), and from the version
## ribbon or the menu after that.

const SEEN_FILE := "user://whats_new_seen.txt"

## [heading, line] for this version.
const NOTES := [
	["Forest islands", "Autumn woods of maple, oak, beech and birch, rivers that tumble into gorges, and a lumber town with a water-wheel sawmill. Climb a hollow giant tree, storm a ruined castle, and watch for the Stag King, the Elder Treant and the Wild Hunt at night."],
	["Build up your ship", "Tackett's yard sells upgrades in levels now: plating, guns, sails, rudder, copper, a bow chaser, a crow's nest, lanterns, railings, a tangerine grove, galley and bunks, and a bigger hold. Every level shows on the sloop, and higher ones need salvage from ships you sink."],
	["Seamanship", "A new SEA skill tree, earned at the helm, the guns and the pump. Its bonuses work at the station you're manning, so a crew that splits up sails better."],
	["A bigger Brinehollow", "The island grew south: farmland and a windmill hamlet, a waterfall pool, a wreck and a second cove. The town has a market street, houses up the hill and a shrine terrace at the top of a long stair, all inside thick woods."],
	["A livelier town", "Shopkeepers work the market street by day and the Salted Gull fills up at night. Fishing boats work the harbour. Haldor's Forge sells the weapons now and Corin sells instruments."],
	["The katana, redrawn", "Its cuts follow the blade, with drawn slashes that match the swing. Awakened, they billow into steel-blue cloud and sakura petals, and all five katana skills got the same treatment."],
]


static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))


## Not yet seen for this version?
static func unseen() -> bool:
	if not FileAccess.file_exists(SEEN_FILE):
		return true
	return FileAccess.get_file_as_string(SEEN_FILE).strip_edges() != version()


static func mark_seen() -> void:
	var f := FileAccess.open(SEEN_FILE, FileAccess.WRITE)
	f.store_string(version())


signal closed

var _close: Button


func _init() -> void:
	custom_minimum_size = Vector2(400, 0)
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	add_theme_stylebox_override("panel", UIStyle.panel())
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	add_child(vb)
	var t := UIStyle.title("What's new in v%s" % version())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var page := PanelContainer.new()
	page.add_theme_stylebox_override("panel", UIStyle.frame(UIStyle.CREAM, UIStyle.BORDER_DIM, 6, "well"))
	vb.add_child(page)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(368, 226)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(sc)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	for n in NOTES:
		list.add_child(UIStyle.label(str(n[0]), 12, Color(UIStyle.BG, 1.0)))
		var l := UIStyle.label(str(n[1]), 8, UIStyle.INK)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.custom_minimum_size = Vector2(348, 0)
		list.add_child(l)
	_close = UIStyle.button("Set sail", 120)
	_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close.pressed.connect(func():
		visible = false
		mark_seen()
		closed.emit())
	vb.add_child(_close)


func show_notes() -> void:
	visible = true
	UIStyle.fit_to_screen.call_deferred(self)
	_close.call_deferred("grab_focus")
