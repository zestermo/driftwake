extends SceneTree
## The desert's bandit chief (a "camp" miniboss): a GruntCamp setup with his script builds him in a
## captain's place, under a turban with a scimitar, a boss's health and his own barks; he comes for a
## captain in front of him and lands a blow. The desert's minis are the hyena and him, and his entry
## marks him a camp's.
const TK := preload("res://tools/dev/test_kit.gd")
const CHIEF := "res://scripts/enemies/bandit_chief.gd"
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
		"script": CHIEF, "look": load(CHIEF).chief_look(rng), "title": "Sharif the Red"}]})


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
			var d = load("res://scripts/island/themes/island_themes.gd").of("desert")
			check("the desert's minis are the hyena and the bandit chief, his entry a camp's", d.minis.has("hyena") and d.minis.has("bandit_chief")
				and d.beasts["bandit_chief"].get("camp", false) and d.beasts["bandit_chief"]["site"] == "camp")
			check("the camp built him from his script: a captain among the bosses, his title over him",
				chief.get_script().resource_path == CHIEF and chief.captain and chief.is_in_group("bosses") and chief.title == "Sharif the Red")
			check("under a turban, a scimitar in his hand", chief.look["hat"] == "turban" and chief.humanoid.weapon != null)
			check("a miniboss's health (%.0f) and his own barks" % chief.health.max_health, absf(chief.health.max_health - chief._boss_hp()) < 0.5
				and chief.health.max_health >= 300.0 and str(chief._barks("phase2")[0]).contains("sand"))
			chief.alert(0.1)
			until = TK.wait_secs(14.0)
		1:
			var hc = p.get_node("HealthComponent")
			check("he comes for the captain and lands a blow (%.0f)" % (hp0 - hc.current_health), hc.current_health < hp0)
			return TK.done(fails)
	step += 1
	return false
