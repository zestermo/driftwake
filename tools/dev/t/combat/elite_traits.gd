extends SceneTree
## 1.23 elites: about 1 in 6 grunts on tier 2 islands and 1 in 4 on tier 3+ roll a trait (none below tier 2); an
## armoured elite has half again an elite's poise, a burning one's blows set you alight, a berserk one under 30% health
## doesn't flinch; each wears its aura while it fights.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var G
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [
		{"post": Vector3(-3.0, 0, -3.0), "role": "sword", "seed": 91, "trait": "armoured"},
		{"post": Vector3(0.0, 0, -3.0), "role": "sword", "seed": 92, "trait": "burning"},
		{"post": Vector3(3.0, 0, -3.0), "role": "sword", "seed": 93, "trait": "berserk"}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			if stage.camp.grunts.size() < 3:
				return false
			G = load("res://scripts/enemies/pirate_grunt.gd")
			var ET = load("res://scripts/combat/elite_traits.gd")
			var counts := [0, 0, 0]
			for s in 600:
				counts[0] += 1 if ET.roll(s, 5) != "" else 0
				counts[1] += 1 if ET.roll(s, 13) != "" else 0
				counts[2] += 1 if ET.roll(s, 19) != "" else 0
			check("none below tier 2 (%d of 600)" % counts[0], counts[0] == 0)
			check("about 1 in 6 on tier 2 (%d of 600)" % counts[1], counts[1] > 70 and counts[1] < 130)
			check("about 1 in 4 on tier 3 (%d of 600)" % counts[2], counts[2] > 115 and counts[2] < 185)
			var a = stage.camp.grunts[0]
			var b = stage.camp.grunts[1]
			var c = stage.camp.grunts[2]
			check("an armoured elite: half again an elite's poise (%.0f)" % a.poise.full, absf(a.poise.full - 55.0 * 1.5) < 0.1)
			for e in [a, b, c]:
				e.alert()
			until = TK.wait_secs(1.0)
		1:
			var a = stage.camp.grunts[0]
			check("it wears its aura in a fight", a.get_node_or_null("Facing/Model/EliteAura") != null and a.get_node("Facing/Model/EliteAura").emitting)
			var b = stage.camp.grunts[1]
			b._on_blow_landed(stage.player, b._hit_light)
			check("a burning elite's blow sets you alight", stage.player.get_node_or_null("Burn") != null)
			var c = stage.camp.grunts[2]
			c.health.current_health = c.health.max_health * 0.2
			c._set_state(G.S.SWING)
			var h := HitData.new()
			h.damage = 12.0
			h.poise = 20.0
			c.facing.rotation.y = PI
			c._on_hit(h, stage.player)
			check("a berserk elite under 30%% health doesn't flinch (state %d)" % c.state, c.state == G.S.SWING)
			return TK.done(fails)
	step += 1
	return false
