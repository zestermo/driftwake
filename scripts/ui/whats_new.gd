extends PanelContainer
## "What's new" on the title screen: the version's big changes. Shown by itself
## the first time a new version is opened (SEEN_FILE), and from the version
## ribbon or the menu after that.

const SEEN_FILE := "user://whats_new_seen.txt"

## [heading, line] for this version.
const NOTES := [
	["The biggest update yet", "Every island down the chain is now its own adventure, different each time you sail. A real milestone: enough out there to play and play again."],
	["Harbours and villages", "Five kinds of harbour and five kinds of village (towns, hamlets, walled posts, stilt villages, ruins), with shops and homes you can walk into."],
	["People with lives", "Villagers work, eat, drink at the inn and go home at night. Named locals gossip about the chain and hand out quests."],
	["Caves and the temple", "One to three caves on every island, each with a boss and a reward, and a ruined temple with levers, a gate and its Warden on some."],
	["The jungle grew up", "Six kinds of forest, giant canopy trees, thick undergrowth, landmarks, a set piece on every island, and new coastlines with cliffs and wadeable shallows."],
	["New beasts", "The Silverback fights from the canopy, with rivals: the Strangler, the Shade and the Mantis Queen. Boars, crabs, snakes, monkeys, toucans and bats move in."],
	["Daggers", "One or two: quick, close, bleeding wounds and backstabs. Shadow Lunge, Red Eclipse and Hundred Fangs. An off-hand dagger is held reversed."],
	["Fights with more bite", "Bosses close the gap if you hang back, bug poison lingers on the ground, riflemen telegraph their shove, and tougher pirates dodge like you do."],
	["A harder road to Grell", "His den now sits on a clifftop out of sight of the beach. Climb the pillars or take the rope ladder from his pier."],
	["New drip", "23 new pieces of clothing and armour: a fez, a kimono, brass goggles, a frock coat, sabatons, a crown you'll have to steal... Sela sells cloth and leather, Vey the steel."],
	["A fresh coat of paint", "New colours everywhere: cream, teal, coral and sunflower, with rounded, gilded frames on every menu, the shipyard and the character builder."],
	["A cleaner inventory", "What you hold isn't in your bag, tooltips compare against what you use, and the text is crisp. Option arrows go back as well as forward."],
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
