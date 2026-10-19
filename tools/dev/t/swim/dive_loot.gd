extends SceneTree
## Diving for loot: a sunken chest on the seabed opens with F under water (the loot goes in the bag, the
## chest is remembered), and an oyster bed gives its pearl once.
const TK := preload("res://tools/dev/test_kit.gd")
var DIVE
var stage
var p
var chest
var bed
var step := 0
var until := 0
var fails := 0
var gold0 := 0
var pearls0 := 0
var oysters0 := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"water": true, "hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			DIVE = load("res://scripts/swim/dive_sites.gd")
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			var floor_y: float = stage.SEA_FLOOR
			chest = DIVE.sunken_chest(stage, Vector3(stage.SHORE_X + 10.0, floor_y, 0), 0.3, "test_dive_chest", [["gold", 40]], rng)
			bed = DIVE.oyster_bed(stage, Vector3(stage.SHORE_X + 10.0, floor_y, 5.0), "test_dive_oysters", rng)
			p.global_position = Vector3(stage.SHORE_X + 10.0, 1.0, -1.0)
			p.reset_physics_interpolation()
			p.state_machine.force_state("Swim", {"entry_vy": 0.0, "quiet": true})
			gold0 = p.inventory_component.count("gold")
			pearls0 = p.inventory_component.count("pearl")
			oysters0 = p.inventory_component.count("oyster")
			until = TK.wait_secs(0.8)
		1:
			TK.press("dodge")
			until = TK.wait_secs(4.0)
		2:
			print("   down at y ", snappedf(p.global_position.y, 0.01), " (seabed ", stage.SEA_FLOOR, ")")
			check("dove to the seabed", p.global_position.y < stage.SEA_FLOOR + 1.2)
			var ic = p.interaction_component
			check("the sunken chest's prompt under water (%s)" % (ic.current_interactable.prompt_text if ic.current_interactable else "none"),
				ic.current_interactable == chest.interactable)
			TK.act("interact")
			until = TK.wait_ticks(3)
		3:
			var g: int = p.inventory_component.count("gold") - gold0
			check("its gold, rolled for this captain, went in the bag (+%d of 40)" % g, g > 0 and g <= 40)
			check("...and the chest is remembered as opened", stage.get_node("/root/GameManager").opened.has("test_dive_chest"))
			p.global_position = Vector3(stage.SHORE_X + 10.0, stage.SEA_FLOOR + 0.3, 4.0)
			p.reset_physics_interpolation()
			until = TK.wait_ticks(4)
		4:
			var ic = p.interaction_component
			check("the oyster bed's prompt (%s)" % (ic.current_interactable.prompt_text if ic.current_interactable else "none"),
				ic.current_interactable != null and ic.current_interactable.prompt_text == "Pry open the oysters")
			TK.act("interact")
			until = TK.wait_ticks(3)
		5:
			var got: int = p.inventory_component.count("pearl") - pearls0
			var oy: int = p.inventory_component.count("oyster") - oysters0
			check("a pearl (%d) and oysters (%d) from the bed" % [got, oy], got == 1 and oy >= 1 and oy <= 3)
			check("...the pearl's gone from the bed", not (bed[2] as Node3D).visible)
			var before: int = p.inventory_component.count("pearl")
			bed[0].get_node("Take").interact(p)
			check("...and only once", p.inventory_component.count("pearl") == before)
			TK.release("dodge")
			return TK.done(fails)
	step += 1
	return false
