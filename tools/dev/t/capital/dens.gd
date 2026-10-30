extends SceneTree
## The cities' dice dens (1.27 C4, TavernGames.make_at): a den in the capital's first courtyard and one in a canal
## campo, each with its dicer and its arm-wrestler standing there, and a throw for 10 gold moves 10 gold one way or the
## other.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var w
var cap
var canal
var gold0 := 0
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
	match step:
		0:
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			until = TK.wait_ticks(2)
		1:
			cap = w.build_capital(Vector3(900, 0, 900))
			canal = w.build_canal(Vector3(-900, 0, -900))
			until = TK.wait_ticks(6)
		2:
			var cd = cap.life_node.get_node_or_null("Den_court")
			var kd = canal.canal_life.get_node_or_null("Den_campo")
			check("the capital's den in a courtyard", cd != null and cd._npcs.size() == 2)
			check("the canal city's den in a campo", kd != null and kd._npcs.size() == 2)
			if cd == null:
				return TK.done(fails)
			var p = stage.player
			p.inventory_component.add_item(load("res://scripts/loot/item_db.gd").get_item("gold"), 100)
			gold0 = p.inventory_component.count("gold")
			root.get_node("Dialogue").dialogue_event.emit("tavern:%s:dice:10" % cd.key)
			until = TK.wait_ticks(2)
		3:
			var g: int = stage.player.inventory_component.count("gold")
			check("a throw for 10 gold moves 10 gold (%d -> %d)" % [gold0, g], absi(g - gold0) == 10)
			return TK.done(fails)
	step += 1
	return false
