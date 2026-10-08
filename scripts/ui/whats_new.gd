extends PanelContainer
## "What's new" on the title screen: the version's big changes. Shown by itself
## the first time a new version is opened (SEEN_FILE), and from the version
## ribbon or the menu after that.

const SEEN_FILE := "user://whats_new_seen.txt"

## [heading, line] for this version.
const NOTES := [
	["Skill trees", "Press K: a tab for every weapon, Base & Haki and your Devil Fruit. Weapon trees grow with mastery, earned by fighting with that weapon. Old saves get every skill point back."],
	["New techniques", "26 of them, like Riposte, Wind Severer, Hatchet Throw, Blade Dance, Deadeye and Smoke Bomb, and an ultimate for every weapon. Put any one on R."],
	["Grapples and martial arts", "Bare-handed, Suplex, Shoulder Throw or Giant Swing a pirate into his friends, or let loose Hundred Fists, Rising Dragon and the Sea King Fist."],
	["Master your abilities", "Use a skill to open its next tier. Soru becomes Shadow Step, Foresight a stance that dodges for you, and Tekkai hardens you by itself."],
	["Cut the bullets", "Learn your blade's parry upgrade to cut gunshots out of the air. Master it and shots are cut down on their own and fly back. Without it, a parry won't stop bullets."],
	["Haki and more", "17 new passives, from Featherfall to Adrenaline, and Conqueror's Haki at level 20: the weak faint where they stand."],
	["Bigger ships", "Ships are half again as big, with a raised quarterdeck over a crew cabin, a crow's nest, rigging to climb and ropes to swing from the yard."],
	["Life aboard", "Rest in the bunk, restock your rum at the galley and keep loot in the crew's shared chest. If you fall, you wake in the cabin."],
	["Your grave", "Die and your bag stays on a grave where you fell. Get back to it, because dying again sinks it for good."],
	["Summon your ship", "Hold B near the water and she fades into view and sails to the shore nearest you."],
	["And more", "Long sessions stay smooth, enemies reel away from your blows, weapons hang properly at the hip, and climbing is done by hand."],
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
