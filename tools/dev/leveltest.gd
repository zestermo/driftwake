extends SceneTree
## Level scaling (Levels): Brinehollow's enemies unchanged (level 0); a level-12
## camp's grunt and captain have the curve's health, damage and XP; a level-12
## burrow bug; the silverback scales from the first chain island (level 6);
## co-op's hp_scale multiplies on top; a level-12 pirate ship's hull and guns,
## and her deck crew inherit her level; the loot tier rule.
var t := 0.0
var step := 0
var wait := 0.0
var fails := 0
var p
var L
var camp
var nest
var apes: Array = []
var ships: Array = []


func _initialize():
	change_scene_to_file("res://scenes/world/world.tscn")


func check(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
	if not c:
		fails += 1


func near(a: float, b: float) -> bool:
	return absf(a - b) < 0.01


func ground(at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 30.0, at + Vector3.DOWN * 60.0, 1)
	var h: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	return h["position"] if not h.is_empty() else at


func total_xp() -> int:
	var pr = p.progression
	var n: int = pr.xp
	for lv in range(1, pr.level):
		n += pr.xp_to_next(lv)
	return n


func _process(d: float) -> bool:
	t += d
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 2.0:
				return false
			for c in root.find_children("*", "CharacterCreator", true, false):
				c._finish(true)
			p = root.get_tree().get_first_node_in_group("player")
			p.health_component.max_health = 9999.0
			p.health_component.current_health = 9999.0
			L = load("res://scripts/enemies/levels.gd")
			# --- the curves
			check("level 0 is unscaled", L.hp_k(0) == 1.0 and L.dmg_k(0) == 1.0 and L.xp_k(0) == 1.0 and L.coins_k(0) == 1.0 and L.hull_k(0) == 1.0)
			check("level 3 is Brinehollow's (1.0), level 4 gives the written XP", near(L.hp_k(3), 1.0) and near(L.dmg_k(3), 1.0) and near(L.xp_k(4), 1.0))
			check("the ape's reference: level 6 is 1.0 for it", near(L.hp_k(6, 6), 1.0) and near(L.dmg_k(6, 6), 1.0))
			check("loot tiers: green at 6-11, blue at 12, purple at 17, yellow at 22", L.tier(6) == 1 and L.tier(11) == 1 and L.tier(12) == 2 and L.tier(17) == 3 and L.tier(22) == 4 and L.tier(0) == 1)
			for lv in [1, 6, 10, 14, 18, 22]:
				print("   Lv %2d: hp x%.2f  dmg x%.2f  xp x%.2f  coins x%.2f  hull x%.2f  tier %d" % [lv, L.hp_k(lv), L.dmg_k(lv), L.xp_k(lv), L.coins_k(lv), L.hull_k(lv), L.tier(lv)])
			# --- Brinehollow as it was
			var smug = root.get_node("World/Islands/Brinehollow/SmugglersCamp")
			var same: bool = smug.level == 0 and smug.grunts.size() > 0
			for g in smug.grunts:
				var hp: float = 110.0 * (3.2 if g.captain else 1.0)
				var dm: float = 12.0 * (1.35 if g.captain else 1.0)
				if g.level != 0 or not near(g.health.max_health, hp) or not near(g._hit_light.damage, dm) or not near(g._hit_peril.damage, 24.0 * (1.35 if g.captain else 1.0)):
					same = false
			check("Brinehollow's smugglers unchanged (110 hp, 12 a cut)", same)
			var bugs_same := true
			var nb := 0
			for n in root.get_node("World/Islands/Brinehollow").find_children("*", "ScuttlebugNest", true, false):
				for s in n.spots:
					var b = s["bug"]
					if b == null or not is_instance_valid(b) or b.is_dead():
						continue
					nb += 1
					var hp0: float = b.max_hp
					if b.level != 0 or not near(b.health.max_health, hp0) or not (near(b.hitbox.hit_data.damage, 10.0) or near(b.hitbox.hit_data.damage, 18.0)):
						bugs_same = false
			check("Brinehollow's bugs unchanged (%d)" % nb, nb > 0 and bugs_same)
			# --- a level-12 camp
			var at: Vector3 = ground(p.global_position + Vector3(40, 0, 40))
			camp = load("res://scripts/enemies/grunt_camp.gd").new()
			camp.name = "LevelCamp"
			camp.level = 12
			camp.add_grunt({"post": Vector3(0, 0.2, 0), "mode": "stand", "seed": 11})
			camp.add_grunt({"post": Vector3(3, 0.2, 0), "mode": "stand", "seed": 12, "captain": true, "title": "Captain Test"})
			root.get_node("World").add_child(camp)
			camp.global_position = at
			# --- a level-12 burrow (a big bug)
			nest = load("res://scripts/enemies/scuttlebug_nest.gd").new()
			nest.name = "LevelNest"
			nest.level = 12
			nest.add_spot(Vector3.ZERO, true)
			root.get_node("World").add_child(nest)
			nest.global_position = ground(p.global_position + Vector3(-40, 0, 40))
			# --- the ape at 0, 6 and 14
			var Ape = load("res://scripts/enemies/jungle_ape.gd")
			for lv in [0, 6, 14]:
				var a = Ape.new()
				a.name = "LevelApe%d" % lv
				var ap: Vector3 = ground(p.global_position + Vector3(-60 + lv * 4, 0, -60))
				a.setup({"post": ap, "mode": "stand", "seed": 3})
				a.level = lv
				root.get_node("World").add_child(a)
				a.global_position = ap + Vector3.UP * 0.3
				apes.append(a)
			# --- pirate sloops at 0 and 12, far out at sea
			var Ship = load("res://scripts/ship/enemy_ship.gd")
			for lv in [0, 12]:
				var c := Vector3(900 + lv * 30, 0, -900)
				var s = Ship.new().setup(c, 60.0, 0.0, 4321 + lv, "sloop")
				s.name = "LevelShip%d" % lv
				s.level = lv
				s.position = c
				root.get_node("World").add_child(s)
				ships.append(s)
			step = 1
			wait = 0.5
		1:
			# --- the level-12 crew
			var g = camp.grunts[0]
			var cap = camp.grunts[1]
			print("   Lv 12 grunt: %.1f hp, %.2f a cut; captain %.1f hp, %.2f a cut" % [g.health.max_health, g._hit_light.damage, cap.health.max_health, cap._hit_light.damage])
			check("the camp's men are level 12", g.level == 12 and cap.level == 12)
			check("a level-12 grunt: 110 x %.3f health" % L.hp_k(12), near(g.health.max_health, 110.0 * L.hp_k(12)) and near(g.health.current_health, g.health.max_health))
			check("...and 12 / 16 / 24 x %.2f damage" % L.dmg_k(12), near(g._hit_light.damage, 12.0 * L.dmg_k(12)) and near(g._hit_heavy.damage, 16.0 * L.dmg_k(12)) and near(g._hit_peril.damage, 24.0 * L.dmg_k(12)) and near(g._dmg(15.0), 15.0 * L.dmg_k(12)))
			check("its captain: 352 x %.3f health, his blows x1.35 on top" % L.hp_k(12), near(cap.health.max_health, 352.0 * L.hp_k(12)) and near(cap._hit_light.damage, 12.0 * 1.35 * L.dmg_k(12)))
			# co-op: hp_scale multiplies on top, keeping the share left
			cap.health.current_health = cap.health.max_health * 0.5
			cap.net_rescale(1.6)
			check("co-op (x1.6) on top of the level (%.1f)" % cap.health.max_health, near(cap.health.max_health, 352.0 * L.hp_k(12) * 1.6) and near(cap.health.current_health, cap.health.max_health * 0.5))
			cap.net_rescale(1.0)
			check("...and back", near(cap.health.max_health, 352.0 * L.hp_k(12)))
			var x0 := total_xp()
			g.health.take_damage(99999.0)
			var gain := total_xp() - x0
			check("a level-12 grunt is worth 45 x %.2f XP (%d)" % [L.xp_k(12), gain], gain == roundi(45.0 * L.xp_k(12)))
			x0 = total_xp()
			cap.health.take_damage(99999.0)
			gain = total_xp() - x0
			check("its captain 220 x %.2f (%d)" % [L.xp_k(12), gain], gain == roundi(220.0 * L.xp_k(12)))
			# --- the bug
			var b = nest.spots[0]["bug"]
			check("a level-12 big bug: 75 x %.3f health, 18 x %.2f a ram" % [L.hp_k(12), L.dmg_k(12)], b.level == 12 and near(b.health.max_health, 75.0 * L.hp_k(12)) and near(b.hitbox.hit_data.damage, 18.0 * L.dmg_k(12)))
			x0 = total_xp()
			b.health.take_damage(99999.0)
			gain = total_xp() - x0
			check("...worth 120 x %.2f XP (%d)" % [L.xp_k(12), gain], gain == roundi(120.0 * L.xp_k(12)))
			# --- the ape
			var a0 = apes[0]
			var a6 = apes[1]
			var a14 = apes[2]
			print("   ape: Lv 0 %.0f hp / %.1f swipe, Lv 6 %.0f / %.1f, Lv 14 %.0f / %.1f" % [a0.health.max_health, a0._hit_swipe.damage, a6.health.max_health, a6._hit_swipe.damage, a14.health.max_health, a14._hit_swipe.damage])
			check("the silverback as tuned at level 0 and 6 (1500, 22 a swipe)", near(a0.health.max_health, 1500.0) and near(a6.health.max_health, 1500.0) and near(a0._hit_swipe.damage, 22.0) and near(a6._hit_swipe.damage, 22.0))
			check("at level 14 it's x%.2f health, x%.2f damage" % [L.hp_k(14, 6), L.dmg_k(14, 6)], near(a14.health.max_health, 1500.0 * L.hp_k(14, 6)) and near(a14._hit_swipe.damage, 22.0 * L.dmg_k(14, 6)) and near(a14._dmg(26.0), 26.0 * L.dmg_k(14, 6)))
			a14.net_rescale(2.2)
			check("...and co-op's x2.2 on top", near(a14.health.max_health, 1500.0 * L.hp_k(14, 6) * 2.2))
			a14.net_rescale(1.0)
			x0 = total_xp()
			a14.health.take_damage(9999999.0)
			gain = total_xp() - x0
			check("a level-14 ape: (600 + 45) x %.2f XP (%d)" % [L.xp_k(14), gain], gain == roundi(600.0 * L.xp_k(14)) + roundi(45.0 * L.xp_k(14)))
			# --- the ships
			var s0 = ships[0]
			var s12 = ships[1]
			var gun0 = s0.cannons[0]
			var gun12 = s12.cannons[0]
			print("   sloop Lv 0: hull %.0f, ball %.1f hull / %.1f splash; Lv 12: hull %.0f, ball %.1f / %.1f" % [s0.max_hull, gun0.hull_damage, gun0.splash_damage, s12.max_hull, gun12.hull_damage, gun12.splash_damage])
			check("a level-0 sloop as she was (260 hull, 14 / 14 a ball)", near(s0.max_hull, 260.0) and near(gun0.hull_damage, 14.0) and near(gun0.splash_damage, 14.0))
			check("a level-12 sloop: hull x%.2f, balls x%.2f on hulls and x%.2f on captains" % [L.hull_k(12), L.hull_k(12), L.dmg_k(12)],
				near(s12.max_hull, 260.0 * L.hull_k(12)) and near(s12.hull, s12.max_hull) and near(gun12.hull_damage, 14.0 * L.hull_k(12)) and near(gun12.splash_damage, 14.0 * L.dmg_k(12)))
			s12._crew_to_deck()
			var ok: bool = s12.deck_crew.size() > 0
			for m in s12.deck_crew:
				if m.level != 12 or not near(m.health.max_health, 110.0 * L.hp_k(12)) or not near(m._hit_light.damage, 12.0 * L.dmg_k(12)):
					ok = false
			check("her deck crew are level 12 too (%d men)" % s12.deck_crew.size(), ok)
			x0 = total_xp()
			s12._strike()
			gain = total_xp() - x0
			check("struck, she's worth 150 x %.2f XP (%d)" % [L.xp_k(12), gain], gain == roundi(150.0 * L.xp_k(12)))
			print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
			quit()
			return true
	return false
