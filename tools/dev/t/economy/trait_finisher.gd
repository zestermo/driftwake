extends SceneTree
## A blue weapon's trait changes its move: a Serrated cutlass's combo finisher opens a bleeding wound on the
## dummy, while the first two cuts don't; the item carries the trait in its id (saved and rebuilt by it), its
## name and its tooltip line.
const TK := preload("res://tools/dev/test_kit.gd")
const ID := "cutlass@2+serrated"
var stage
var p
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": ID, "dummy": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func bleeding() -> bool:
	return stage.dummy.get_node_or_null("Bleed") != null


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			var it: ItemData = ItemDB.get_item(ID)
			check("the trait rides in the id: %s, blue, %s" % [it.display_name, it.weapon_trait], it.weapon_trait == "serrated" and int(it.rarity) == 2 and it.display_name == "Serrated Cutlass")
			var sg = load("res://scripts/game/save_game.gd")
			check("saved and rebuilt by its id", sg.item_from(sg.item_ref(it)) == it)
			check("the tooltip line names the move", WeaponTraits.line("serrated").begins_with("Serrated - Finisher"))
			check("in hand", p.equipped_weapon == it and p.armed)
			until = TK.wait_secs(0.3)
		1:
			# click through the combo until the spin finisher plays
			var a: String = p.body_model.current_action()
			if a == "slash_spin":
				until = TK.wait_secs(0.45)
				step = 2
				return false
			if a == "slash_l":
				saw_second = true
				no_wound_before = no_wound_before and not bleeding()
			clicks += 1
			if clicks > 12:
				check("the combo reached its finisher", false)
				return TK.done(fails)
			TK.act("light_attack")
			until = TK.wait_secs(0.2)
			return false
		2:
			check("the first two cuts open no wound", saw_second and no_wound_before)
			check("the finisher opens a wound that bleeds", bleeding())
			return TK.done(fails)
	step += 1
	return false


var clicks := 0
var saw_second := false
var no_wound_before := true
