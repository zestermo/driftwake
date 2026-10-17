extends SceneTree
## The forest's Cursed Huntsman (a "camp" miniboss): a GruntCamp setup with his script builds him in a captain's
## place, hooded, a war axe in his hand, a miniboss's health and his own barks, his two hounds (wolves) at his heel;
## alerted, he comes for a captain in front of him and he or his hounds land a blow.
const TK := preload("res://tools/dev/test_kit.gd")
const HUNT := "res://scripts/enemies/huntsman.gd"
var stage
var p
var chief
var step := 0
var until := 0
var fails := 0
var hp0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	stage = TK.stage(self, {"grunts": [{"post": Vector3(0, 0, -7.0), "yaw": PI, "mode": "stand", "seed": 3, "captain": true,
		"script": HUNT, "look": load(HUNT).chief_look(rng), "title": "Black Herne"}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			if stage.camp.grunts.is_empty():
				return false
			p = stage.player
			chief = stage.camp.grunts[0]
			var hc = p.get_node("HealthComponent")
			hc.max_health = 99999.0
			hc.current_health = 99999.0
			hp0 = hc.current_health
			until = TK.wait_ticks(4)
		1:
			var f = load("res://scripts/island/themes/island_themes.gd").of("forest")
			check("the forest's huntsman is a camp's miniboss", f.minis.has("huntsman") and f.beasts["huntsman"].get("camp", false) and f.beasts["huntsman"]["site"] == "camp")
			check("the camp built him from his script: a captain among the bosses, his title over him",
				chief.get_script().resource_path == HUNT and chief.captain and chief.is_in_group("bosses") and chief.title == "Black Herne")
			check("hooded, a war axe in his hand", chief.look["hat"] == "hood" and chief.humanoid.weapon != null)
			check("a miniboss's health (%.0f) and his own barks" % chief.health.max_health, absf(chief.health.max_health - chief._boss_hp()) < 0.5
				and chief.health.max_health >= 300.0 and str(chief._barks("phase2")[0]).contains("Hounds"))
			var hounds: Array = chief.hounds.filter(func(h): return is_instance_valid(h) and h.is_inside_tree())
			check("his two hounds with him (%d: %s)" % [hounds.size(), hounds.map(func(h): return "%.1f" % h.global_position.distance_to(chief.global_position))], hounds.size() == 2 and hounds.all(func(h): return h.global_position.distance_to(chief.global_position) < 12.0))
			chief.alert(0.1)
			until = TK.wait_secs(14.0)
		2:
			var hc = p.get_node("HealthComponent")
			check("he and his hounds come for the captain and land a blow (%.0f)" % (hp0 - hc.current_health), hc.current_health < hp0)
			return TK.done(fails)
	step += 1
	return false
