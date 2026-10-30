extends PanelContainer
## "What's new" on the title screen: the version's big changes. Shown by itself
## the first time a new version is opened (SEEN_FILE), and from the version
## ribbon or the menu after that.

const SEEN_FILE := "user://whats_new_seen.txt"

## [heading, line] for this version.
const NOTES := [
	["Every weapon, more", "All 17 weapons get a second ultimate, a second crew technique, free alternate aerial, sprint and right-click attacks as their mastery grows, a launcher, an aerial heavy at mastery 10, and bridges between their branches."],
	["A new beginning", "New captains wake on Brinehollow with nothing. Fight with your fists, pick your weapon from Sergeant Vey's rack, have your Edy read by Master Isao at the shrine, and cross the whole island before you sail."],
	["The Edy tree", "One round tree of eight branches. Abilities rank up as you use them, passives switch off, Infusion puts your Edy into every blow, and subtler auras glow on your arms and legs (the whole body when you Reinforce)."],
	["Islands worth landing on", "Side jobs weaken the island's villain, shops you walk into, a special place in every village, dojo masters who spar you for real, dice and arm wrestling at the inn, and villages the pirates have taken."],
	["Saves without a limit", "As many saves as you like, each with its picture, place, crew and play time, and three backups kept of each. Host or join a crew without making a save first."],
	["The sea pushes back", "Bounty hunters are announced before they walk in, Admiralty ships chase with bow chasers, blockades of three ships can be broken, and your sails come down when you're rammed."],
	["Finding your way", "The compass stays up with your crew and objective, every captain carries a tonic flask, villagers glance instead of spinning round, and Vsync, a frame cap and Reduce flashing are in the options."],
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
