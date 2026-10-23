extends SceneTree
## The weapons' enemy pass (PirateGrunt.ROLES): on a chain island an ordinary sword grunt is a spear, hammer, greatsword,
## twin-axe or black-leg grunt some of the time (seeded), never in Brinehollow's sea; each carries its weapon (black-leg
## none) in its stance, swings its own moves (its light move as the combo's tell), a hammer hits harder than a cutlass,
## a spear reaches further, and the weapon it drops is its own.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0
var grunts := {}


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func grunt(s: int, lv: int) -> Node:
	var G = load("res://scripts/enemies/pirate_grunt.gd")
	var g = G.new().setup({"post": stage.player.global_position + Vector3(6 + (s % 10), 0, 6 + s / 10), "seed": s, "role": "sword"})
	g.level = lv
	g.process_mode = Node.PROCESS_MODE_DISABLED
	stage.add_child(g)
	return g


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			var G = load("res://scripts/enemies/pirate_grunt.gd")
			var roled := 0
			var seen := {}
			for s in range(1, 41):
				var g = grunt(s, 3)
				if G.ROLES.has(g.role):
					roled += 1
					if not grunts.has(g.role):
						grunts[g.role] = g
						seen[g.role] = true
						continue
				g.queue_free()
			check("on a chain island, some sword grunts carry the newer weapons (%d of 40: %s)" % [roled, str(seen.keys())], roled >= 6 and roled <= 20 and seen.size() >= 4)
			var home := 0
			for s in range(1, 21):
				var g = grunt(100 + s, 0)
				if G.ROLES.has(g.role):
					home += 1
				g.queue_free()
			check("...never in Brinehollow's sea (%d)" % home, home == 0)
			var ok := true
			var msg := ""
			for r in grunts:
				var g = grunts[r]
				var spec: Dictionary = G.ROLES[r]
				var wm: String = str(g.humanoid.weapon.mesh.get_meta("model", "")) if g.humanoid.weapon else ""
				if g.humanoid.stance != spec["stance"] or (spec["weapon"] != "" and not wm.begins_with(str(spec["weapon"]))) or (spec["weapon"] == "" and g.humanoid.weapon != null):
					ok = false
					msg = "%s: stance %s, weapon %s" % [r, g.humanoid.stance, wm]
				if g._blade_id != str(spec["weapon"]):
					ok = false
					msg = "%s drops %s" % [r, g._blade_id]
			check("each carries its weapon in its stance, and drops it %s" % msg, ok)
			if grunts.has("hammer"):
				var sword = grunt(999, 0)
				check("a hammer hits harder than a cutlass (%.1f vs %.1f)" % [grunts["hammer"]._hit_light.damage, sword._hit_light.damage], grunts["hammer"]._hit_light.damage > sword._hit_light.damage * 1.2)
				sword.queue_free()
			if grunts.has("spear"):
				check("a spear reaches further (%.1f m)" % grunts["spear"]._reach(), grunts["spear"]._reach() > 2.5)
			var tells := []
			for r in grunts:
				var g = grunts[r]
				g._attack = "combo"
				g._swing_i = 0
				g._start_wind()
				tells.append([r, g.humanoid.current_action()])
			check("each swings its own moves (the tells: %s)" % str(tells),
				tells.all(func(t): return t[1] == str((G.ROLES[t[0]]["light"] as Array)[0])))
			return TK.done(fails)
	step += 1
	return false
