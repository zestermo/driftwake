extends SceneTree
## 1.25.4 the Brinehollow opening: the story's 21 steps in order; an old save's step resumes where it was (every
## pre-1.25.4 id is still on the list), an unknown one finishes the story; a new game starts with no weapon in the bag
## or the hands; the quay brawl (Story step "brawl") is a bare-handed bout with a dock tough that fights at once, and
## putting him down moves the story on to Vey (a loss doesn't).
const TK := preload("res://tools/dev/test_kit.gd")
const ORDER := ["find_town", "see_gus", "see_nessa", "lighthouse", "brawl", "see_vey", "vey_rack", "vey_drills", "smugglers",
	"vey_skills", "shrine", "tomo", "ruins", "grell", "see_odile", "see_tackett", "forest", "queen", "tackett_ship",
	"see_gus_redtide", "morrow"]
const OLD := ["find_town", "see_gus", "see_nessa", "see_vey", "vey_drills", "smugglers", "vey_skills", "grell", "see_odile",
	"see_tackett", "queen", "tackett_ship", "see_gus_redtide", "morrow"]
var stage
var p
var story
var bout
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
			p = stage.player
			story = root.get_node("Story")
			var ids: Array = story.STEPS.map(func(s): return s["id"])
			check("21 steps in order (%s)" % ", ".join(ids), ids == ORDER)
			var kept := true
			for id in OLD:
				story.from_dict({"step": id, "won": ["smugglers"]})
				kept = kept and story.step == id and story.won.has("smugglers")
			check("every old save's step resumes where it was", kept)
			story.from_dict({"step": "no_such_step"})
			check("an unknown step: the story's done, nothing locked", not story.active())
			story.from_dict({"step": "done"})
			check("a finished story stays done", not story.active())
			check("(the stage captain starts armed)", p.equipped_weapon != null)
			story.begin()
			var weapons := 0
			for st in p.inventory_component.get_all_items():
				if st.item.is_weapon():
					weapons += 1
			check("a new game: no weapon in the bag (%d)" % weapons, weapons == 0)
			check("...nor in the hands", p.equipped_weapon == null and p.offhand_weapon == null)
			check("...and the story's on its first step", story.step == "find_town")
			for id in ["find_town", "see_gus", "see_nessa", "lighthouse"]:
				story.complete(id)
			check("Nessa's parcel taken up: the brawl's next", story.step == "brawl")
			var hc = p.get_node("HealthComponent")
			hc.max_health = 99999.0
			hc.current_health = 99999.0
			root.get_node("Net").request_arena("brawl", 0)
			until = TK.wait_secs(0.5)
		1:
			var bouts := get_nodes_in_group("arena_bouts")
			bout = bouts[0] if not bouts.is_empty() else null
			check("the brawl starts: a dock tough steps out", bout != null and is_instance_valid(bout.rival))
			if bout == null:
				return TK.done(fails + 1)
			check("...bare-handed (%s)" % bout.rival.style(), bout.rival.equipped_weapon == null and bout.rival.style() == "fist")
			check("...and fighting at once (%s)" % bout.phase, bout.phase == "fight" and bout.rival.get_node("Brain").order == "fight")
			story.bout_done("brawl", false)
			check("a lost brawl doesn't move the story on", story.step == "brawl")
			bout.rival.health_component.current_health = 1.0
			until = TK.wait_secs(0.5)
		2:
			check("Harl put down: off to Vey (%s)" % story.step, story.step == "see_vey")
			story.reset()
			return TK.done(fails)
	step += 1
	return false
