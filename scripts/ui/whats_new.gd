extends PanelContainer
## "What's new" on the title screen: the version's big changes. Shown by itself
## the first time a new version is opened (SEEN_FILE), and from the version
## ribbon or the menu after that.

const SEEN_FILE := "user://whats_new_seen.txt"

## [heading, line] for this version.
const NOTES := [
	["The island chain", "Past Redtide the log pose leads to islands built from your world's seed: jungle isles with a pirate camp and its captain, a bug lair, ruins and a lookout on the summit. Each grows tougher than the last."],
	["Outpost villages", "Every island has a village: an inn to rest at, a trader and a cook, a job board, and an elder who pays for work done and tells of the way on."],
	["The Silverback", "Each jungle isle's beast waits on the far side: roars, slams, leaps and hurled boulders. Fell it for its hoard and the Silverback Pelt."],
	["Reading the log pose", "Its needles sit on your compass. Each island ahead shows its theme and how dangerous it is for you. At a fork, sail to the side you choose. The needle settles after a while on an island, or as soon as its beast falls."],
	["The sea between", "Every leg to the next island has pirate fleets of its level, reefs, fog, whirlpools and storms, a Sea King now and then, and wrecks, bottles and islets with a chest."],
	["Katana and axe", "Thousand Petals and Maelstrom rebuilt, with petals for the katana and embers, rock and fire for the axe. Earthsplitter tears the ground."],
	["Jumping attacks", "Twin Cyclone, Meteor Kick, Hang Shot and Boarding Dive, learned in each weapon's tree."],
	["A better sounding sea", "No more short hull-wash loop: long layered water that changes with your speed, footsteps for sand, grass, stone, wood and shallows, varied hits and shots, and island music that picks up where it left off."],
	["Steadier pacing", "Levels come slower, pistols lose punch at range, and pirate ships sail faster, fire more and board."],
	["Co-op fixes", "Guests see the pirates who board your ship, and a guest whose island builds late catches up on its fights."],
	["Play in the browser", "Driftwake runs at driftwake.fun too (co-op stays on desktop)."],
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
