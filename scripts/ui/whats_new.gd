extends PanelContainer
## "What's new" on the title screen: the version's big changes. Shown by itself
## the first time a new version is opened (SEEN_FILE), and from the version
## ribbon or the menu after that.

const SEEN_FILE := "user://whats_new_seen.txt"

## [heading, line] for this version.
const NOTES := [
	["1.20.3: the arena", "The capital's Grand Arena opens: walk in through its west gate onto the sand under a full crowd. Arena Master Corvin Bale runs the ladder: six named fighters, wooden blades, nobody dies, a purse for every win. Beat the Champion for the title and the Champion's Sabre, then defend it once a day. Each captain climbs their own ladder, in co-op too. Unstable: tell us what breaks."],
	["1.20.2: the palace", "The palace opens: up the road through the grounds, through the new gate in its ring wall, into the court between its wings and the throne hall, columns, banners and all. Lord Chamberlain Orme has three errands for a captain who wants an audience: a petition sealed, the Queen's stolen signet found, and the Queen herself. Unstable: tell us what breaks."],
	["1.20.1: the docks and the terrace", "The capital opens up: a warehouse row to the docks and the wharf, where Marta Coyle runs a shipwright's yard (every refit Tackett does, far from Brinehollow), a chandler sells timber and canvas, and a fence on the wharf pays over the odds for plunder. Up by the palace wall, the noble quarter's garden terrace and Ashgrove & Daughters, outfitters to the court. Two new city quests. Unstable: tell us what breaks."],
	["Beasts reborn", "Every beast boss and roamer reworked: eight rebuilt bodies with jointed legs that follow the slope, and each beast with its own moves. Big attacks have a readable wind-up and an opening after, and only one move each knocks you down."],
	["Grounds of their own", "A boss ground for every island type: the jungle canopy, an ice grotto on the snow, a half-buried ruin in the desert, a grove of standing stones in the forest."],
	["The fog isle", "A fifth island type: deep woods of giant twisted trees under endless fog, a cursed fishing village, the drowned who get back up and ghosts that bullets pass through. Light the old lanterns to push the fog and the dead back, then face the Drowned Captain on his wreck."],
	["Between places", "Fallen trunks, boulders, old walls, shrines, lone chests and left camps along the ways; more creatures and more people on the trails. Each island type builds in its own roofs and walls."],
	["New names", "Driftwake's powers, places and factions have their own names now: Driftfruits (Flux, Feral, Knack), Will (Iron Will, Weather Eye, Captain's Will), the Leviathan, the lodestone and the Admiralty."],
	["Since 1.19", "Rival crews who fight like you, bounties and the Admiralty, arrest and escape from the brig, a new opening at sea, and fighting in the water."],
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
