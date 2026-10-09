extends Node3D
class_name BeastArena
## The beast's ground on a generated island's far side (GenIsland.sites["boss"]):
## a clearing ringed with boulders and smashed trees, bones, a nest of torn
## branches, and the silverback asleep in the middle (JungleApe).
##
## The fight runs like Redtide's (the host decides, everyone sees): a banner as
## you come near, it wakes when a standing captain comes within WAKE_R, the top
## boss bar while it fights, a reset (healed, back to sleep) once everyone's
## been gone RESET_R for 6 s. Beaten: a banner, the fanfare, its hoard once per
## character, Dialogue flag "isle<id>_boss_beaten" (the village's job and the
## log pose read it). It's back after RESPAWN with nobody near (net_spawner).

const WAKE_R := 24.0
const RESET_R := 48.0
const RESPAWN := 900.0

var isl: GenIsland
var boss: JungleApe
var boss_gen: int = 0
var _empty_t: float = 0.0
var _dead_t: float = 0.0
var _celebrated: bool = false
var _arrived: bool = false
var _boss_ui: bool = false


static func build(gi: GenIsland, rng: RandomNumberGenerator) -> BeastArena:
	var site := gi.site_node("boss")
	var a := BeastArena.new()
	a.name = "Arena"
	a.isl = gi
	site.add_child(a)
	a._dress(rng)
	var baker := gi.get_parent().get_node_or_null("NavBaker")
	if baker:
		baker.add_zone(site, 42.0, false, gi.terrain_faces)
	return a


func _dress(rng: RandomNumberGenerator) -> void:
	var c: Vector2 = isl.sites["boss"]
	var site := get_parent() as Node3D
	# boulders round the edge, some smashed trees thrown down between them
	var rocks := [Props.rock_mesh(8801, 1.0), Props.rock_mesh(8802, 1.0, true), Props.rock_mesh(8803, 1.0)]
	var body := StaticBody3D.new()
	body.name = "Boulders"
	var mb := MeshBuilder.new()
	for i in range(14):
		var a := TAU * i / 14.0 + rng.randf_range(-0.15, 0.15)
		var p := c + Vector2.from_angle(a) * rng.randf_range(21.0, 25.0)
		var s := rng.randf_range(1.2, 2.6)
		var y := isl.hv(p) - isl.hv(c)
		var mi := MeshInstance3D.new()
		mi.mesh = rocks[i % rocks.size()]
		mi.position = Vector3(p.x - c.x, y - 0.3 * s, p.y - c.y)
		mi.rotation.y = rng.randf() * TAU
		mi.scale = Vector3(s, s * rng.randf_range(0.7, 1.1), s)
		body.add_child(mi)
		StarterIsland._cyl_col(body, s * 0.9, s * 1.6, mi.position + Vector3(0, s * 0.6, 0))
	var bark := PSXMat.lit("bark")
	var wood := PSXMat.lit("planks_dark", Color(0.7, 0.6, 0.5))
	for i in range(5):
		var a := rng.randf() * TAU
		var p := c + Vector2.from_angle(a) * rng.randf_range(12.0, 19.0)
		var y := isl.hv(p) - isl.hv(c)
		var len := rng.randf_range(5.0, 8.0)
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, PI * 0.5 - rng.randf_range(0.0, 0.15))
		mb.add_cylinder(bark, Transform3D(b, Vector3(p.x - c.x, y + 0.35, p.y - c.y)), 0.38, 0.28, len, 6, 1.0, Color.WHITE, true, true)
		# a splintered stump where it stood
		var sp := p + Vector2.from_angle(a + PI) * 2.0
		mb.add_cylinder(wood, Transform3D(Basis(), Vector3(sp.x - c.x, isl.hv(sp) - isl.hv(c) - 0.1, sp.y - c.y)), 0.42, 0.3, rng.randf_range(0.7, 1.4), 6, 1.0)
	# the nest: torn branches heaped in a ring
	for i in range(22):
		var a := TAU * i / 22.0
		var r := rng.randf_range(3.2, 4.4)
		var b := Basis(Vector3.UP, a + PI * 0.5 + rng.randf_range(-0.5, 0.5)) * Basis(Vector3.BACK, PI * 0.5 + rng.randf_range(-0.3, 0.3))
		mb.add_cylinder(bark, Transform3D(b, Vector3(cos(a) * r, 0.25 + (i % 3) * 0.18, sin(a) * r)), 0.1, 0.06, rng.randf_range(2.2, 3.4), 4, 1.0)
	# bones of whatever it caught
	var bone := PSXMat.flat(Color(0.88, 0.85, 0.74))
	for i in range(9):
		var p := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(5.0, 14.0)
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, PI * 0.5)
		mb.add_cylinder(bone, Transform3D(b, Vector3(p.x, isl.hv(c + p) - isl.hv(c) + 0.06, p.y)), 0.05, 0.05, rng.randf_range(0.6, 1.1), 5, 1.0, Color.WHITE, true, true)
		if i % 3 == 0:
			mb.add_blob(bone, Transform3D(Basis(), Vector3(p.x + 0.5, isl.hv(c + p) - isl.hv(c) + 0.12, p.y)), Vector3(0.16, 0.13, 0.2), rng, 0.15, 3, 5)
	body.add_child(mb.to_instance("Dressing"))
	site.add_child(body)


func _ready() -> void:
	add_to_group("net_spawner")
	_spawn_boss()


func _spawn_boss() -> void:
	if boss and is_instance_valid(boss):
		boss.queue_free()
	_celebrated = false
	_dead_t = 0.0
	boss = JungleApe.new()
	boss.name = "Ape%d" % boss_gen
	var away: Vector2 = (isl.sites["village"] - isl.sites["boss"]).normalized()
	boss.setup({"post": global_position, "yaw": atan2(-away.x, -away.y), "mode": "stand", "seed": int(isl.node["seed"]) + boss_gen})
	boss.arena = self
	add_child(boss)
	boss.global_position = global_position + Vector3.UP * 0.3
	boss.reset_physics_interpolation()


func net_gen():
	return boss_gen


func net_set_gen(g) -> void:
	if int(g) != boss_gen:
		boss_gen = int(g)
		_spawn_boss()


func _beaten_flag() -> String:
	return isl.save_key("boss_beaten")


func _process(delta: float) -> void:
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me and not _arrived and me.global_position.distance_to(global_position) < 60.0:
		_arrived = true
		get_tree().call_group("hud", "show_banner", "The Beast's Ground", "Smashed trees, gnawed bones. Something huge sleeps here.", true)
	var alive: bool = boss != null and is_instance_valid(boss) and boss.state != PirateGrunt.S.DEAD
	_boss_hud(me, alive)
	if boss != null and is_instance_valid(boss) and not alive and not _celebrated:
		_celebrated = true
		_victory(me)
	if Net.is_client():
		return
	if alive and boss.state == PirateGrunt.S.IDLE:
		for p in Net.all_players():
			var pp := p as Node3D
			if pp.global_position.distance_to(global_position) < WAKE_R and p.has_method("is_standing") and p.is_standing():
				boss.alert()
				break
	elif alive and boss.in_combat():
		var near := false
		for p in Net.all_players():
			if (p as Node3D).global_position.distance_to(global_position) < RESET_R and p.has_method("is_standing") and p.is_standing():
				near = true
		_empty_t = 0.0 if near else _empty_t + delta
		if _empty_t > 6.0:
			_empty_t = 0.0
			boss.reset_fight()
	elif not alive:
		_dead_t += delta
		if _dead_t > RESPAWN:
			for p in Net.all_players():
				if (p as Node3D).global_position.distance_to(global_position) < 70.0:
					return
			boss_gen += 1
			_spawn_boss()
			Net.spawned(self, net_gen())


func _boss_hud(me: Node3D, alive: bool) -> void:
	var show: bool = me != null and alive and boss.in_combat() and me.global_position.distance_to(global_position) < RESET_R + 8.0
	if show:
		get_tree().call_group("hud", "show_boss", boss.boss_name, boss.health_frac(), boss.phase)
		_boss_ui = true
	elif _boss_ui:
		_boss_ui = false
		get_tree().call_group("hud", "hide_boss")


## Beaten: banner and fanfare for whoever's here, the flag, its hoard once per character.
func _victory(me: Node3D) -> void:
	Dialogue.set_flag(_beaten_flag())
	if me and me.global_position.distance_to(global_position) < RESET_R + 20.0:
		get_tree().call_group("hud", "show_banner", "%s falls!" % boss.boss_name, "The jungle goes quiet.", true)
		var music := get_node_or_null("/root/Music")
		if music:
			music.victory()
	var key := isl.save_key("boss_hoard")
	if GameManager.opened.has(key) or get_node_or_null("Hoard"):
		return
	var t := IslandContent.tier(isl)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(isl.node["seed"]) + 31
	var c: Vector2 = isl.sites["boss"]
	var bag := isl.strongbox(self, c + Vector2(0, 0.5), 0.0, "boss_hoard", [
		["gold", 60 + t * 25], ["treasure", 4 + t], ["rum", 2],
		[ItemDB.tiered(IslandContent.LOOT_WEAPONS[rng.randi() % IslandContent.LOOT_WEAPONS.size()], mini(t + 1, 5)), 1],
		[Gear.make("accessory", "cape", {"cape": true, "cape_color": JungleApe.SILVER}, "Silverback Pelt", t), 1]], 1.35)
	bag.name = "Hoard"
	FX.sparkle(bag.global_position + Vector3(0, 0.9, 0), 24, Color(1.0, 0.85, 0.4))
