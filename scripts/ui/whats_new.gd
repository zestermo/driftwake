extends PanelContainer
## "What's new" on the title screen: the version's big changes. Shown by itself
## the first time a new version is opened (SEEN_FILE), and from the version
## ribbon or the menu after that.

const SEEN_FILE := "user://whats_new_seen.txt"

## [heading, line] for this version.
const NOTES := [
	["Rival crews", "Four pirate crews sail the first chain: the Gilded Gulls, the Brine Wolves, the Lantern Saints and the Mudlark Brigade. Their captains fight with your weapons, skills and ultimates. Meet them and duel them one at a time while the rest of the crew waits at the side, drilling, reading, playing music or watching. They'll remember who won."],
	["A price on your head", "Every captain has a bounty now. Climb it and your poster goes up, townsfolk know your face, and shops pick a side. The Admiralty's grey ships come about for you, bounty hunters wait ashore, and named officers bring their squads."],
	["Arrested", "Lose to the Admiralty (the whole crew, in co-op) and you wake in their brig with your weapons in a chest past the guards. Pick the lock and fight your way out."],
	["A new opening", "New games start on a stormy night at sea, on Captain Maren Holt's deck. Cutscenes can be skipped (in co-op, once everyone presses skip)."],
	["In the water and on the islands", "Attack while swimming to strike with your own weapon; sharks and morays can be fought. Pirates now carry spears, hammers, greatswords and twin axes, or fight with their feet."],
	["Since 1.18", "New weapon kinds (polearms, hammers, twin axes, greatswords, Black Leg), simpler skill points, mastered guards, new techniques and acrobatics, controller support, and a first look at the royal capital."],
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
