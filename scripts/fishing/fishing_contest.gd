class_name FishingContest
extends Node
## A village's fishing contest (1.28, docs/life_systems_plan.md): the sign by the notice board (IslandVillage) takes
## ENTRY gold and starts LENGTH s for this captain; every catch landed meanwhile (rod or spear: Fishing.land calls
## `scored`) adds its worth x its length against its size. Three town anglers post scores rolled by the island's tier;
## at the end the best wins (PRIZES), the places on every crewmate's screen (Net banner). Once a game day per town.
## Each captain's own (a node under their Player while it runs, a HUD line with the clock and the scores).

const ENTRY := 10
const LENGTH := 180.0
const RIVALS := ["Old Teodor", "Marga the Net", "Young Pip", "Brannock", "Sela Hookhand", "Dov the Patient"]
## By place (1st, 2nd, 3rd): gold and items [[id, n]] ("book": one from BOOKS).
const PRIZES := [{"gold": 150, "items": [["bait_shrimp", 4], ["book", 1]]}, {"gold": 70, "items": [["bait_shrimp", 3]]}, {"gold": 30, "items": []}]
const BOOKS := ["chart_stops", "chart_wrecks", "manual_angler"]

## Town key -> the game day its contest was last held (each captain's own).
static var held := {}

var player
var town := ""
var left := LENGTH
var score := 0.0
var rivals: Array = []
var _hud: CanvasLayer
var _label: Label


## The one running for `p` (null when none).
static func of(p) -> FishingContest:
	return p.get_node_or_null("FishingContest") as FishingContest


## Can `p` enter `town`'s contest now? "" or why not.
static func refuse(p, town_key: String) -> String:
	if of(p) != null:
		return "You're already in a contest"
	if int(held.get(town_key, -1)) == _day(p):
		return "Today's contest is done. Come back tomorrow"
	if Fishing.rod_of(p) == "":
		return "Bring a rod (the equipment slot)"
	if p.inventory_component.count("gold") < ENTRY:
		return "The entry's %d gold" % ENTRY
	return ""


static func _day(p) -> int:
	return int(p.get_node("/root/Weather").day())


## Enter `town`'s contest (tier sets the town anglers' scores): "" when it's started, or why not.
static func enter(p, town_key: String, tier: int) -> String:
	var why := refuse(p, town_key)
	if why != "":
		return why
	p.inventory_component.remove_item(ItemDB.get_item("gold"), ENTRY)
	held[town_key] = _day(p)
	var c := FishingContest.new()
	c.name = "FishingContest"
	c.player = p
	c.town = town_key
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([town_key, _day(p)])
	var names := RIVALS.duplicate()
	for i in range(3):
		var n: String = names.pop_at(rng.randi() % names.size())
		var lo := 18.0 + tier * 4.0
		c.rivals.append([n, snappedf(rng.randf_range(lo, minf(lo + 22.0, 60.0)), 0.1)])
	p.add_child(c)
	p.call("_toast", "The contest's on! %d minutes: land the biggest, rarest fish you can" % int(LENGTH / 60.0))
	return ""


func _ready() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 5
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
	_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03))
	_label.add_theme_constant_override("outline_size", 3)
	_label.position = Vector2(12, 92)
	_hud.add_child(_label)
	add_child(_hud)


## A catch counted: its worth x how big it was against its size.
func scored(id: String, length_ratio: float) -> void:
	var it := ItemDB.get_item(id)
	var pts := float(it.value if it else 1) * length_ratio
	score += pts
	player.call("_toast", "+%.1f points (%.1f)" % [pts, score])


func best_rival() -> float:
	var b := 0.0
	for r in rivals:
		b = maxf(b, float(r[1]))
	return b


func _process(delta: float) -> void:
	left -= delta
	_label.text = "FISHING CONTEST  %d:%02d   YOU %.1f   BEST IN TOWN %.1f" % [int(maxf(left, 0.0)) / 60, int(maxf(left, 0.0)) % 60, score, best_rival()]
	if left <= 0.0:
		finish()


## Time: the places, the prize, a banner for the crew.
func finish() -> void:
	var board: Array = rivals.duplicate()
	board.append([player.display_name(), snappedf(score, 0.1)])
	board.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	var place := -1
	for i in range(board.size()):
		if str(board[i][0]) == player.display_name() and float(board[i][1]) == snappedf(score, 0.1):
			place = i
			break
	var got: Array = []
	if place >= 0 and place < PRIZES.size():
		var pz: Dictionary = PRIZES[place]
		var inv = player.inventory_component
		inv.add_item(ItemDB.get_item("gold"), int(pz["gold"]))
		got.append("%d gold" % int(pz["gold"]))
		for e in pz["items"]:
			var id := str(e[0])
			if id == "book":
				id = BOOKS[hash([town, held.get(town, 0)]) % BOOKS.size()]
			var item := ItemDB.get_item(id)
			if item:
				inv.add_item(item, int(e[1]))
				got.append(item.display_name + (" x%d" % int(e[1]) if int(e[1]) > 1 else ""))
	var ord := ["1st", "2nd", "3rd", "4th"]
	Net.banner("Fishing contest", "%s places %s with %.1f%s" % [player.display_name(), ord[clampi(place, 0, 3)], score,
		(": " + ", ".join(got)) if not got.is_empty() else ""])
	queue_free()
