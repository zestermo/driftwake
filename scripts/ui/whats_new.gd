extends PanelContainer
## "What's new" on the title screen: the version's big changes. Shown by itself
## the first time a new version is opened (SEEN_FILE), and from the version
## ribbon or the menu after that.

const SEEN_FILE := "user://whats_new_seen.txt"

## [heading, line] for this version.
const NOTES := [
	["1.21.1: crews of five", "Up to five captains sail together now. Your crew has a name and a roster of everyone who's sailed with it, saved with the Captain's world: see it under Crew in the pause menu, where the Captain renames the crew, sets its flag and can send a crewmate ashore. The crew's emblem is painted on the main sail, and there are six new emblems: a kraken, a trident, a rose, a sun, a wave and a raven. Tackett's yard at Brinehollow does the basics; the finer refits are first seen at a city's yard. The opening at sea is set aside for now: a new game wakes on the beach."],
	["The capital opened up", "A warehouse row to the docks with Marta Coyle's shipwright's yard, a chandler and a fence; a garden terrace under the palace wall; the palace open, its throne hall, Queen Ilsabet and her Chamberlain's errands."],
	["The Grand Arena", "A one-on-one ladder of six fighters on the sand, nonlethal, a purse for every win. Beat the Champion for the title and the Champion's Sabre, then defend it once a day."],
	["The canal city", "A lagoon city of shipbuilders down the chain: canals, bridges, boatmen to row you between landings, a market, a glassworks, an inn and the arsenal."],
	["The caravel", "Master Grane builds her at the arsenal: faster and quicker to turn, a bow chaser and a bigger hold, a lighter hull. Your sloop is laid up with her upgrades; swap at a city shipwright."],
	["Out on the chain", "About half the harbours have a vendor by the pier: a craftsman doing one group of refits, or a chandler."],
	["Lived-in cities, a new sky", "Chimney smoke, pigeons, lanterns, ivy and busier lanes; rolling clouds that glow at dawn and dusk, and light shafts when you dive."],
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
