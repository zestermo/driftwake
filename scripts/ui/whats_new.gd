extends PanelContainer
## "What's new" on the title screen: the version's big changes. Shown by itself
## the first time a new version is opened (SEEN_FILE), and from the version
## ribbon or the menu after that.

const SEEN_FILE := "user://whats_new_seen.txt"

## [heading, line] for this version.
const NOTES := [
	["A story to start", "A new captain wakes on the sand past the quay. Follow Old Pell's lead through Brinehollow to Captain Morrow, with your next goal on screen and a marker to follow."],
	["Brinehollow grows", "A deep forest to the west, a pirate den under Captain Grell, spitters in the canopy, and the Brood Queen's cave."],
	["The harbour town", "A stone quay with piers, trading ships, waterfront houses and a harbour tower. The village has dressed houses, a furnished tavern, a cobbled plaza, a smithy and a sea chapel, lit at night."],
	["Morrow's log pose", "Beat Captain Morrow and wear his log pose. Hold L to raise it and see where the islands of the chain lie."],
	["The cutlass reborn", "A new three-hit combo, polished techniques with sea-spray effects, and a Kraken's Wake worth waiting for."],
	["Mastery wakes the elements", "Techniques start clean and physical; master a weapon's tree to wake its element. Spamming heavy attacks now tires you and makes you predictable."],
	["Fairer sea fights", "Enemy ships show their hull over the masthead, hole you far less, and won't fire up close: there they ram or board. The pump works three times faster."],
	["Sail anywhere", "The wind never holds you back. A fair wind gives you extra speed."],
	["Redtide Rock", "The fort's guns are gone. A stone stair climbs the cliff, and sea stacks and crags guard the rock."],
	["Hear the sea", "Surf on the shore, the open swell, water rushing past your hull, creaking timbers, gusting wind and whistling rigging."],
	["See the wind", "Surf rolls in over the shallows, whitecaps streak the crests in a blow, wind lines race past and spray flies over the bow."],
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
