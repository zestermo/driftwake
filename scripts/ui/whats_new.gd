extends PanelContainer
## "What's new" on the title screen: the version's big changes. Shown by itself
## the first time a new version is opened (SEEN_FILE), and from the version
## ribbon or the menu after that.

const SEEN_FILE := "user://whats_new_seen.txt"

## [heading, line] for this version.
const NOTES := [
	["Five new ways to fight", "Polearms (spear, trident, naginata, bisento, halberd, pitchfork), hammers and kanabo, twin axes, greatswords, and Black Leg kicks (learn them from Gus at the Salted Gull). Each has its own stance, moves, tree, element and ultimate. Find them in chests, shops and Haldor's forge."],
	["Stances with character", "Every weapon now stands, runs and breathes its own way: a side-on cutlass, a reverse-grip dagger, a pistol at low ready, an axe hung low. Master the polearm for Whitebeard's planted stance, or Black Leg for hands in your pockets."],
	["Play with a controller", "Full Xbox pad support: right-stick look, LB for skills, the radial wheels on the stick, and button prompts that follow whatever you're holding. This is an unstable build: tell us what breaks."],
	["Skill trees, rebuilt", "Every weapon has its own tree that grows only while you fight with it: moves and techniques come by themselves at their mastery level, stat steps cost points, and choices are versions you keep both of (switch them at the ship's bunk). Captain levels make you tougher with talents every 5 levels; Will comes from beating great foes. Adventure trees (sailing, swimming, cooking, fishing, acrobatics, defense, stealth, tinkering) show up as you do them. K opens it all."],
	["One skill bar, any weapon", "Put any weapon's skills from your loadouts on 1-5 and R: using one switches to that weapon and fires. Three passive slots, a library of everything you know, and new menus and wheels with a seafaring look. Smoother island loads and fights too."],
	["A first look at the capital", "Two islands down the chain from Brinehollow lies the First Sea's royal capital: a walled city with a palace on its hill. Walk the market street and plaza, rest at the Crown and Compass, take on city quests, and steer clear of Gallows Row. More of the city to come."],
	["Gold that means something", "Loot is much scarcer and rolled for each captain. Rare weapons carry a named trait that changes a move. Shops are trades with a stock that changes every day, and artisans camp on the islands' trails."],
	["Food and fishing", "Heal in a fight with E (hold it to pick). Cook ingredients at the galley or a campfire for meals that last 10-20 minutes. Buy a rod and bait, cast with F and strike when the bobber dips: 21 fish, common to legendary."],
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
