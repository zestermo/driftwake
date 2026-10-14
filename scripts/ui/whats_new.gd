extends PanelContainer
## "What's new" on the title screen: the version's big changes. Shown by itself
## the first time a new version is opened (SEEN_FILE), and from the version
## ribbon or the menu after that.

const SEEN_FILE := "user://whats_new_seen.txt"

## [heading, line] for this version.
const NOTES := [
	["New moves", "Standing, running and sprinting jumps each have their own take-off and landing, there's a double jump with a somersault, and the dash snaps harder."],
	["Draw like you mean it", "Every weapon draws and sheathes its own way, with its own sound: the katana from the hip with a ring, axes off your back, pistols spun into the holster."],
	["Heal in a fight", "Food, rum, stew and the new Sea Tonic share a short cooldown and take a moment to eat or drink. Get hit mid-swig and it's spilled."],
	["Take a seat", "Sit on any bench, stool, log or crate (F), or on the ground from the emote wheel. Seats on the ship sail with you."],
	["Sneak", "C crouches: quieter steps, and pirates and creatures notice you much later. Creep up behind someone and stick a dagger in."],
	["Emotes", "Hold T: wave, point, salute, laugh, cheer, hornpipe, shanty sway, bow, flex, shrug, facepalm, sit. Your crew sees every one."],
	["Hands that talk", "Captains and villagers gesture as they talk, chests open with both hands, levers get hauled, and you hand things over when you trade."],
	["More drip, less clipping", "Coats, vests, belts and armour sit properly over each other now, and nine new pieces: an admiral's coat, cavalier boots, a slouch hat, a spyglass and more."],
	["Every screen, crisp", "The skill map, shops, dialogue, the chart, the HUD and the creator get the inventory's crisp text, tooltips and frames. The log pose (L) is held properly."],
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
