extends SceneTree
## A city's favour (1.27 C5, CityFavour): no standing at first; six of the capital's quests done makes the crew Trusted
## by the Crown (the Queen's line says so and names the next rank), and asking her puts the Crown's 10% on every capital
## trader; the Doge has a talk that tells the Lagoon's.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var w
var cap
var canal
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var F = load("res://scripts/island/city_favour.gd")
	var J = root.get_node("Journal")
	match step:
		0:
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			until = TK.wait_ticks(2)
		1:
			cap = w.build_capital(Vector3(900, 0, 900))
			canal = w.build_canal(Vector3(-900, 0, -900))
			until = TK.wait_ticks(6)
		2:
			var life = cap.life_node
			check("no standing with the Crown at first (%d done)" % F.done(life), F.rank("capital", F.done(life)) == 0)
			var qs: Array = life.quest_node.quests
			for i in range(6):
				J.entries[str(qs[i]["id"])] = {"done": true, "step": 0}
			var line: String = F.line("capital", F.done(life))
			check("six done: Trusted by the Crown (%s)" % line, F.rank("capital", F.done(life)) == 2 and "Trusted by the Crown" in line and "Champion" in line)
			root.get_node("Dialogue").dialogue_event.emit("favour:capital")
			var shops: Array = life.favour_shops()
			check("asking the Queen: 10%% off every capital trader (%d shops)" % shops.size(), shops.size() >= 3 and shops.all(func(s): return absf(J.discount(str(s)) - 0.1) < 0.001))
			check("the Lagoon's ranks are its own", F.title("canal", 3) == "Gondolier of the Republic")
			return TK.done(fails)
	step += 1
	return false
