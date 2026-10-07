extends PanelContainer
## "What's new" on the title screen: the version's big changes. Shown by itself
## the first time a new version is opened (SEEN_FILE), and from the version
## ribbon or the menu after that.

const SEEN_FILE := "user://whats_new_seen.txt"

## [heading, line] for this version.
const NOTES := [
	["Out at sea", "Wind and sail trim, an anchor on a chain (hold F at the capstan), hulls that hole, burn and flood while the crew patches, pumps and douses."],
	["Hazards and plunder", "Reefs, fog banks, whirlpools and storm cells. Wrecks to loot, messages in bottles, treasure to dig up."],
	["The Sea King", "A serpent lurks in deep water. Jump its tail slam, cut at its head when it bites the deck."],
	["Enemy ships", "Sloops, gunboats, brigs and Marines that ram, flee and surrender. Board them for their prize. Cut cannonballs in half with a katana or cutlass."],
	["Sea chart and compass", "M opens a chart that fills in as you sail. Click to set marks, C to clear them."],
	["Brinehollow's traders", "Buy and sell with Nessa, Gus, Marlo, Clothier Sela, Old Ida and Vey's Armoury. Tackett the shipwright refits and repaints your ship."],
	["Item tiers", "Common, Uncommon, Rare, Epic, Legendary, Ultra and Supreme. Better tiers hit harder and guard better."],
	["Weapons and armour", "27 weapon designs, and new armour and clothes: cuirass, mail, morion, greatcoat, gauntlets, greaves, capes."],
	["New moves", "The axe gets its own combo, a whirlwind and the Skybreaker leap. The cutlass cuts cleaner and has a running cut."],
	["And more", "Smoother co-op sailing, foam wakes, turquoise shallows, rain on deck. Levels now take twice the XP."],
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
	add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BG, UIStyle.BORDER, 10, 2))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	add_child(vb)
	var t := UIStyle.title("What's new in v%s" % version())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(380, 230)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	for n in NOTES:
		list.add_child(UIStyle.label(str(n[0]), 12, UIStyle.ACCENT))
		var l := UIStyle.label(str(n[1]), 8, UIStyle.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.custom_minimum_size = Vector2(360, 0)
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
