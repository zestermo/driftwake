extends PanelContainer
## "What's new" on the title screen: the version's big changes. Shown by itself
## the first time a new version is opened (SEEN_FILE), and from the version
## ribbon or the menu after that.

const SEEN_FILE := "user://whats_new_seen.txt"

## [heading, line] for this version.
const NOTES := [
	["Skill points, made simple", "One Combat pool from your Captain levels, spent on any weapon's tree, and one Adventure pool. Everything in a tree is bought now; a weapon's mastery decides what you may buy. Respec a tree at the ship's bunk for gold. Old saves buy back what they owned. K opens it all, with locked trees hidden and the details on select."],
	["A guard of your own", "Master a weapon to about 15 for a second guard: its own stance, carry and moves. Toggle between the two once owned. The axe, daggers, dual swords, twin daggers and corsair awaken with their own drawn elements."],
	["New techniques", "Two each for the polearm, hammer and twin axes: throw a Thunder Javelin, bat blows aside with Windmill Guard, send both axes round in Ravens' Return or swing a foe round you in Raider's Haul."],
	["Through the air", "An upright air walk, a tumble after a long fall (an air step pulls you out), and Acrobatics' Breakfall, Skyward Dash, Sky Leap, Moonstep and Crash Landing. Fists hit like a marine's now."],
	["Guard and swim", "Perfect Parry and Guard Style in Defense, Surface Sprint in Swimming. This is an unstable build: tell us what breaks."],
	["Five new ways to fight", "Polearms (spear, trident, naginata, bisento, halberd, pitchfork), hammers and kanabo, twin axes, greatswords, and Black Leg kicks (learn them from Gus at the Salted Gull). Each has its own stance, moves, tree, element and ultimate. Find them in chests, shops and Haldor's forge."],
	["Stances with character", "Every weapon now stands, runs and breathes its own way: a side-on cutlass, a reverse-grip dagger, a pistol at low ready, an axe hung low. Master the polearm for Whitebeard's planted stance, or Black Leg for hands in your pockets."],
	["Play with a controller", "Full Xbox pad support: right-stick look, LB for skills, the radial wheels on the stick, and button prompts that follow whatever you're holding."],
	["A first look at the capital", "Two islands down the chain from Brinehollow lies the First Sea's royal capital: a walled city with a palace on its hill. Walk the market street and plaza, rest at the Crown and Compass, take on city quests, and steer clear of Gallows Row. More of the city to come."],
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
