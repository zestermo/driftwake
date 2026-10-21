extends SceneTree
## Life skills are learned by doing: swimming across open water builds Swimming (a point a few metres, and
## only while swimming), its first milestone brings its perk by itself (faster strokes, on the swim speed
## stat), perks can't be bought, life skills give no points, and cooking and fishing take xp through the same
## call their systems will make. A crewmate's puppet earns nothing on our machine.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var step := 0
var until := 0
var fails := 0
var x0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "water": true, "crew": [{"name": "Mate", "at": Vector3(2, 0, 2)}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func total(tree: String) -> int:
	var m: Dictionary = pr.mastery_of(tree)
	var n := int(m["xp"])
	for lv in range(1, int(m["lv"])):
		n += pr.mastery_to_next(lv)
	return n


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			TK.press("move_right")
			until = TK.wait_secs(1.5)
		1:
			check("walking on land builds no Swimming", total("swim") == 0)
			TK.release("move_right")
			p.global_position = Vector3(stage.SHORE_X + 6.0, 1.0, 0)
			p.reset_physics_interpolation()
			p.state_machine.force_state("Swim", {"entry_vy": 0.0, "quiet": true})
			until = TK.wait_ticks(20)
		2:
			x0 = p.global_position.x
			TK.press("move_right")
			until = TK.wait_secs(4.0)
		3:
			TK.release("move_right")
			var swum: float = p.global_position.x - x0
			print("   swam %.1f m (%s): Swimming xp %d" % [swum, p.current_state_name(), total("swim")])
			check("still swimming", p.current_state_name() == "Swim")
			check("swimming builds Swimming, a point every %.0f m" % pr.SWIM_M, total("swim") > 0 and absf(total("swim") - swum / pr.SWIM_M) <= 2.0)
			check("...and nothing for the puppet's own tree", int(stage.crew[0].progression.mastery_of("swim")["xp"]) == 0)
			check("perks can't be bought", not pr.learn("sw_strokes") and pr.can_learn("sw_strokes") == "Comes at Swimming 2")
			var sp0: float = pr.stat("swim_pct")
			pr.add_life("swim", pr.mastery_to_next(1))
			check("Swimming 2 brings Strong Strokes by itself", pr.mastery_level("swim") == 2 and pr.owns("sw_strokes"))
			check("...swimming 10% faster", is_equal_approx(pr.stat("swim_pct") - sp0, 0.1))
			check("life skills give no points", pr.points("swim") == 0)
			pr.add_life("cook", 60)
			pr.add_life("fish", 60)
			check("cooking and fishing take xp the same way, their first perks with it", pr.owns("ck_hand") and pr.owns("fs_patient"))
			check("...and the skills' xp carries to no one else", total("sea") == 0 and total("sword") == 0)
			return TK.done(fails)
	step += 1
	return false
