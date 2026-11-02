class_name Leviathan
extends Node3D
## A great beast of the deep on a sea leg (1.28, docs/v1_28_plan.md "Leviathans"): it lurks at its lair (SeaLegs lays
## it), rises when the crew's manned ship comes near and it wants to (the eel only in a storm, the angler only by night),
## and fights her from the sea: ship and deck, harpoon finish. Cannons (struck) and the harpoon cannon wear it down,
## its parts reach the deck to be fought by hand, and a harpooned leviathan (HarpoonCannon contract) is reeled alongside
## and held there REELED, its guard down (hand blows x FINISH_K) until the line goes. Killed, it sinks and leaves a hoard
## with leviathan scales (the gadgets' rarest part); back at its lair after RETURN_AFTER s.
## Subclasses (ColossalSquid, StormEel, AbyssalAngler) build the body and play the fight: _build, _fight(delta, ship),
## _wants_rise(), _pose(delta), and their own pack/unpack and events. The host runs it (net_sync); the others play it back.

enum S { LURK, RISE, FIGHT, REELED, DIVE, DEAD }

const NOTICE := 200.0
const RISE_TIME := 2.4
const SINK_TIME := 6.0
const RETURN_AFTER := 900.0
const FINISH_K := 2.0
## Every kind: its class's script (SeaLegs, the debug menu).
const KINDS := {"squid": "res://scripts/enemies/colossal_squid.gd", "eel": "res://scripts/enemies/storm_eel.gd",
	"angler": "res://scripts/enemies/abyssal_angler.gd"}

var kind := ""
var title := "Leviathan"
var hp_base := 2000.0
var lair := Vector2.ZERO
var level := 12
var state: S = S.LURK
var st_t := 0.0
var hp := 2000.0
var max_hp := 2000.0
var net_puppet := false
## The body's centre (what cannons aim at, what's reeled, the boss bar's anchor): a subclass builds it.
var core: Node3D
var hurtbox: Hurtbox
var _harpoon: Node3D
var _mats: Array = []
var _flash_t := 0.0
var _dead_t := 0.0
var _boss_shown := false
var _rng := RandomNumberGenerator.new()


## A leviathan of `kind` for the lair at `at` (not yet in the tree).
static func make(k: String, at: Vector2, lvl: int) -> Leviathan:
	var l: Leviathan = load(KINDS[k]).new()
	l.kind = k
	l.lair = at
	l.level = lvl
	l.name = "Leviathan_" + k
	return l


func _ready() -> void:
	add_to_group("net_sync")
	add_to_group("harpoonable")
	add_to_group("leviathans")
	net_puppet = Net.is_client()
	_rng.randomize()
	max_hp = hp_base * (1.0 + 0.04 * maxi(level - 12, 0))
	hp = max_hp
	core = Node3D.new()
	core.name = "Core"
	add_child(core)
	_build()
	_set_hidden(true)
	if Net.hosting:
		net_rescale(Net.hp_scale())


func _exit_tree() -> void:
	if _boss_shown:
		get_tree().call_group("hud", "hide_boss")


func net_rescale(k: float) -> void:
	var frac := hp / maxf(max_hp, 1.0)
	max_hp = hp_base * (1.0 + 0.04 * maxi(level - 12, 0)) * k
	if state != S.DEAD:
		hp = maxf(frac * max_hp, 1.0)


func is_dead() -> bool:
	return state == S.DEAD


func is_up() -> bool:
	return state not in [S.LURK, S.DEAD]


## A hurtbox on `parent` (a sphere of `r` at `at`) whose hits come to `on_hit` (the core's: _on_hit).
func make_hurtbox(nm: String, parent: Node3D, r: float, at := Vector3.ZERO, on_hit: Callable = Callable()) -> Hurtbox:
	var hb := Hurtbox.new()
	hb.name = nm
	hb.collision_layer = 32
	hb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = r
	cs.shape = sh
	cs.position = at
	hb.add_child(cs)
	parent.add_child(hb)
	hb.owner = self
	hb.hit_received.connect(on_hit if on_hit.is_valid() else _on_hit)
	return hb


## A wet, glossy hide of its own (the Sea King's shader; hits flash it: tint_mul), on `tex_name`.
func wet_hide(tex_name: String, rough := 0.4) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/psx/psx_wet.gdshader")
	m.set_shader_parameter("albedo_tex", PSXMat.tex(tex_name))
	m.set_shader_parameter("albedo_color", Color(1.05, 1.05, 1.05))
	m.set_shader_parameter("wet_rough", rough)
	_mats.append(m)
	return m


## Its own copy of a material (hits flash it: tint_mul).
func own_mat(m: Material) -> Material:
	var c := m.duplicate()
	_mats.append(c)
	return c


func _set_hidden(h: bool) -> void:
	visible = not h
	if hurtbox:
		hurtbox.set_deferred("monitorable", not h and state != S.DEAD)


# --------------------------------------------------------------------------
# For the kinds to fill in
# --------------------------------------------------------------------------
func _build() -> void:
	pass


## Does it come up now (weather, hour)? The squid always does.
func _wants_rise() -> bool:
	return true


## Up: where it surfaces (world) for a ship at `sp`.
func _rise_at(sp: Vector3) -> Vector3:
	var a := _rng.randf() * TAU
	return sp + Vector3(cos(a), 0, sin(a)) * 30.0 + Vector3(0, -10.0, 0)


func _fight(_delta: float, _ship: Ship) -> void:
	pass


## Every frame on every machine (the body follows the core: tentacles, coils, lights).
func _pose(_delta: float) -> void:
	pass


func _pack_extra() -> Array:
	return []


func _unpack_extra(_a: Array, _b: Array, _f: float) -> void:
	pass


func _event(_what: String, _args: Array) -> void:
	pass


## Gone back down mid-fight, or killed: anything it put on the deck goes.
func _clear_parts() -> void:
	pass


# --------------------------------------------------------------------------
# The brain (host)
# --------------------------------------------------------------------------
func ship() -> Ship:
	return get_tree().get_first_node_in_group("ship") as Ship


func _manned(s: Node3D) -> bool:
	for p in Net.all_players():
		if s.aboard((p as Node3D).global_position):
			return true
	return false


func _physics_process(delta: float) -> void:
	if net_puppet:
		return
	st_t += delta
	var s := ship()
	if s == null:
		return
	var sp := s.global_position
	var near := Vector2(sp.x, sp.z).distance_to(lair) < NOTICE and _manned(s)
	match state:
		S.LURK:
			if near and _wants_rise():
				core.global_position = _rise_at(sp)
				_set_hidden(false)
				go(S.RISE)
				Net.fx("sfx", ["roar", sp, 10.0, 0.02, 0.5])
				_banner()
				Net.event(self, "banner", [])
		S.RISE:
			core.global_position.y = move_toward(core.global_position.y, 0.0, 6.0 * delta)
			if st_t > RISE_TIME:
				Net.fx("splash", [Vector3(core.global_position.x, 0.5, core.global_position.z), 30, 2.8])
				go(S.FIGHT)
		S.FIGHT:
			if not near and st_t > 6.0:
				go(S.DIVE)
			else:
				_fight(delta, s)
		S.REELED:
			# alongside, held on the line: its guard down
			if _harpoon == null or not is_instance_valid(_harpoon):
				go(S.FIGHT)
		S.DIVE:
			_clear_parts()
			core.global_position.y = move_toward(core.global_position.y, -16.0, 7.0 * delta)
			if st_t > 3.0:
				_set_hidden(true)
				go(S.LURK)
		S.DEAD:
			_dead_t += delta
			core.global_position.y -= 1.6 * delta
			if _dead_t > SINK_TIME and visible:
				_set_hidden(true)
			if _dead_t > RETURN_AFTER:
				hp = max_hp
				_dead_t = 0.0
				hurtbox.set_deferred("monitorable", true)
				go(S.LURK)


func go(s_: S) -> void:
	state = s_
	st_t = 0.0


func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		for m in _mats:
			(m as ShaderMaterial).set_shader_parameter("tint_mul", Color(2.2, 1.4, 1.4) if _flash_t > 0.0 else Color(1, 1, 1))
	if net_puppet:
		_puppet()
	if visible:
		_pose(delta)
	var me := get_tree().get_first_node_in_group("player") as Node3D
	var show := visible and is_up() and me != null and me.global_position.distance_to(core.global_position) < 160.0
	if show:
		get_tree().call_group("hud", "show_boss", title, hp / maxf(max_hp, 1.0), 1)
		_boss_shown = true
	elif _boss_shown:
		_boss_shown = false
		get_tree().call_group("hud", "hide_boss")


func _banner() -> void:
	get_tree().call_group("hud", "show_banner", title + "!", "A leviathan rises beside the ship - man the guns, ready the harpoon!", true)


# --------------------------------------------------------------------------
# Hits: cannonballs, blades, the harpoon
# --------------------------------------------------------------------------
## Where a cannonball flying from `from` to `to` strikes it (INF: a miss). Kinds add their parts' spheres in _spheres.
func struck(from: Vector3, to: Vector3) -> Vector3:
	if not visible or not is_up():
		return Vector3.INF
	for sph in _spheres():
		var c: Vector3 = sph[0]
		var q := Geometry3D.get_closest_point_to_segment(c, from, to)
		if q.distance_to(c) < float(sph[1]):
			return q
	return Vector3.INF


## [[centre (world), radius], ...] a cannonball can strike.
func _spheres() -> Array:
	return [[core.global_position, 4.0]]


func _on_hit(hit: HitData, _attacker: Node) -> void:
	hurt(hit.damage * (1.5 if hit.siege else 1.0) * (FINISH_K if state == S.REELED and not hit.siege else 1.0), core.global_position + Vector3.UP * 3.0)


## Damage to the beast itself (the host's), shown at `at`.
func hurt(dmg: float, at: Vector3) -> void:
	if not is_up():
		return
	hp = maxf(hp - dmg, 0.0)
	Net.damage_number(dmg, at)
	Net.fx("blood", [at, Vector3.UP, 16])
	_flash_t = 0.12
	Net.event(self, "flash", [])
	if hp <= 0.0:
		_die()


func harpooned(_by_ship) -> void:
	Net.fx("sfx", ["roar", core.global_position, 8.0, 0.03, 0.7])


## The harpoon's reel: it comes alongside and stays there REELED (its guard down) while the line holds.
func reel_toward(at: Vector3, speed: float, delta: float) -> void:
	if not is_up():
		return
	if state != S.REELED:
		_clear_parts()
		go(S.REELED)
		for h in get_tree().current_scene.find_children("Harpoon", "", true, false):
			if h.get("target") == self:
				_harpoon = h
		Net.event(self, "reeled", [])
	var to := at - core.global_position
	to.y = 0.0
	core.global_position += to.normalized() * minf(speed * 0.6 * delta, to.length())
	core.global_position.y = move_toward(core.global_position.y, 0.5, delta * 2.0)


func released() -> void:
	if state == S.REELED:
		go(S.FIGHT)


func _die() -> void:
	_clear_parts()
	go(S.DEAD)
	_dead_t = 0.0
	hurtbox.set_deferred("monitorable", false)
	Net.award_xp(450, core.global_position, INF)
	Net.bounty("leviathan", core.global_position, 140.0)
	_dead_fx()
	Net.event(self, "dead", [])


## (every screen) The death roar, the banner, its hoard floating up: each captain finds their own.
func _dead_fx() -> void:
	FX.sfx("roar", core.global_position, 8.0, 0.02, 0.4)
	FX.splash(core.global_position, 40, 3.0)
	get_tree().call_group("hud", "show_banner", "The %s falls!" % title, "Its hoard floats up from the deep.", true)
	var bag := (load("res://scenes/loot/loot_bag.tscn") as PackedScene).instantiate() as LootBag
	var items: Array[ItemStack] = []
	var tier := 3 if randf() < 0.7 else 4
	for e in [["gold", 110], ["treasure@2", 6], ["leviathan_scale", 2 + (1 if randf() < 0.5 else 0)],
			["%s@%d" % [WeaponDesigns.random_item(_rng), tier], 1]]:
		var st := ItemStack.new()
		st.item = ItemDB.get_item(str(e[0]))
		st.quantity = int(e[1])
		if st.item:
			items.append(st)
	bag.setup(items, false)
	bag.floating = true
	bag.name = "LeviathanHoard"
	get_tree().current_scene.add_child(bag)
	bag.global_position = Vector3(core.global_position.x, 0.0, core.global_position.z)


# --------------------------------------------------------------------------
# Co-op
# --------------------------------------------------------------------------
func net_pack() -> Array:
	return [int(state), hp, max_hp, core.global_position, core.global_basis.get_rotation_quaternion(), visible, _pack_extra()]


func _puppet() -> void:
	var smp := Net.sample(self)
	if smp.is_empty():
		return
	var a: Array = smp[0]
	var b: Array = smp[1]
	var f: float = smp[2]
	state = int(b[0]) as S
	hp = float(b[1])
	max_hp = float(b[2])
	visible = bool(b[5])
	hurtbox.monitorable = visible and state != S.DEAD
	core.global_position = (a[3] as Vector3).lerp(b[3], f)
	core.global_basis = Basis((a[4] as Quaternion).slerp(b[4], f))
	_unpack_extra(a[6], b[6], f)


func net_event(what: String, args: Array) -> void:
	match what:
		"flash":
			_flash_t = 0.12
		"dead":
			_dead_fx()
		"banner":
			_banner()
		_:
			_event(what, args)
