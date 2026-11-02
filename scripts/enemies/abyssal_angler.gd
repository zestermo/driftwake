class_name AbyssalAngler
extends Leviathan
## The abyssal angler (1.28 leviathan): only rises by night. Most of it stays under: what you see is its lure, a cold
## green light on a long stalk drifting round the ship. The lure is its weak spot (blows on it x LURE_K, and enough of
## them, STUN_DMG, drag the whole beast up stunned for STUN_TIME: its great head at the surface for the guns). Its move:
## * JAWS: the lure goes dark; a wide ring on her deck, then the jaws burst up under her: she's thrown about, the hull
##   cracked, and anyone standing on deck floored (jump!); its head then lies at the surface beside her a moment.
## Cannons and the harpoon as for any leviathan.

const HP_BASE := 2000.0
const LURE_R := 18.0
const LURE_K := 2.0
const STUN_DMG := 260.0
const STUN_TIME := 4.5
const JAWS_DARK := 1.0
const JAWS_WARN := 1.8
const JAWS_R := 5.5
const JAWS_DMG := 30.0
const JAWS_HULL := 40.0
const UP_TIME := 2.2
const SKIN := Color(0.12, 0.13, 0.12)
const LIGHT := Color(0.6, 1.0, 0.75)

enum A { LURK, DARK, JAWS, UP, STUN }

var _a: A = A.LURK
var _a_t := 0.0
var _ang := 0.0
var _next := 5.0
var _stun_acc := 0.0
var lure_on := true
var lure_at := Vector3.ZERO
var lure_box: Hurtbox
var _lure: Node3D
var _lamp: OmniLight3D
var _bulb: MeshInstance3D
var _stalk: Array = []
var _stalk_mesh: Mesh


func _init() -> void:
	title = "Abyssal Angler"
	hp_base = HP_BASE


func _wants_rise() -> bool:
	return float(Weather.night) > 0.5


func _build() -> void:
	var hide := wet_hide("leather", 0.5)
	var mb := MeshBuilder.new()
	# a great round head-body, the jaw hanging open under it, needle teeth, little dead eyes
	mb.add_loft(hide, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO),
		[[-6.0, 2.5, 2.2], [-3.0, 5.0, 4.2], [0.0, 5.6, 4.6], [3.0, 4.8, 3.8], [5.0, 3.0, 2.4], [6.2, 0.6, 0.6]], MeshBuilder.profile_circle(10), 0.5, SKIN, true, true)
	mb.add_loft(hide, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, -3.2, -1.0)),
		[[-4.5, 4.6, 1.2], [0.0, 5.2, 1.6], [3.5, 4.0, 1.0]], MeshBuilder.profile_circle(10), 0.5, SKIN.darkened(0.2), true, true)
	var tooth := PSXMat.flat(Color(0.88, 0.86, 0.78))
	for i in range(11):
		var a := lerpf(-1.2, 1.2, float(i) / 10.0)
		var at := Vector3(sin(a) * 4.6, -1.4, -cos(a) * 4.0 - 1.0)
		mb.add_cone(tooth, Transform3D(Basis(Vector3.RIGHT, PI), at), 0.35, 1.6 + 0.6 * float(i % 2), 4)
		mb.add_cone(tooth, Transform3D(Basis(), at + Vector3(0, -2.6, 0.3)), 0.3, 1.2 + 0.5 * float((i + 1) % 2), 4)
	var eye := PSXMat.glow(Color(0.9, 0.85, 0.5), 1.0)
	for sx in [-1.0, 1.0]:
		mb.add_cylinder(eye, Transform3D(Basis(Vector3.BACK, sx * PI * 0.5), Vector3(sx * 4.8, 1.6, -2.0)), 0.35, 0.35, 0.1, 6)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = mb.commit()
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.visibility_range_end = 500.0
	core.add_child(body)
	hurtbox = make_hurtbox("Hurtbox", core, 5.5)
	# the lure: a bulb and a real light on a stalk from its brow
	_lure = Node3D.new()
	_lure.name = "Lure"
	add_child(_lure)
	var bm := MeshBuilder.new()
	bm.add_cylinder(PSXMat.glow(LIGHT, 1.3), Transform3D(), 0.55, 0.55, 1.0, 8)
	_bulb = MeshInstance3D.new()
	_bulb.mesh = bm.commit()
	_bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lure.add_child(_bulb)
	_lamp = OmniLight3D.new()
	_lamp.light_color = LIGHT
	_lamp.light_energy = 3.0
	_lamp.omni_range = 16.0
	_lamp.shadow_enabled = false
	_lure.add_child(_lamp)
	lure_box = make_hurtbox("LureBox", _lure, 1.0, Vector3.ZERO, _lure_hit)
	var sm := MeshBuilder.new()
	sm.add_cylinder(hide, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.5)), 0.22, 0.18, 1.0, 5, 0.5, SKIN)
	_stalk_mesh = sm.commit()
	for i in range(7):
		var mi := MeshInstance3D.new()
		mi.mesh = _stalk_mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_stalk.append(mi)


func _rise_at(sp: Vector3) -> Vector3:
	_ang = _rng.randf() * TAU
	return sp + Vector3(cos(_ang), 0, sin(_ang)) * LURE_R + Vector3(0, -14.0, 0)


func _set_hidden(h: bool) -> void:
	super._set_hidden(h)
	if lure_box:
		lure_box.set_deferred("monitorable", not h)


func _spheres() -> Array:
	return [[core.global_position, 6.0], [lure_at, 1.2]]


# --------------------------------------------------------------------------
# The fight (host)
# --------------------------------------------------------------------------
func _fight(delta: float, s: Ship) -> void:
	_a_t += delta
	var sp := s.global_position
	_ang += delta * 0.18
	var drift := sp + Vector3(cos(_ang), 0, sin(_ang)) * LURE_R
	match _a:
		A.LURK:
			# under, the lure up and drifting round her
			core.global_position = core.global_position.lerp(Vector3(drift.x, -7.5, drift.z) - Vector3(cos(_ang), 0, sin(_ang)) * 6.0, clampf(delta, 0.0, 1.0))
			lure_at = Vector3(drift.x, 3.0 + 0.6 * sin(st_t * 1.3), drift.z)
			lure_on = true
			_next -= delta
			if _next <= 0.0:
				_go_a(A.DARK)
				lure_on = false
				Net.fx("sfx", ["roar", core.global_position, 2.0, 0.05, 0.45])
		A.DARK:
			# dark: it goes under her
			core.global_position = core.global_position.move_toward(Vector3(sp.x, -12.0, sp.z), 14.0 * delta)
			lure_at = core.global_position + Vector3(0, 5.0, 0)
			if _a_t > JAWS_DARK and _a_t - delta <= JAWS_DARK:
				Net.fx("telegraph", [s.global_transform * Vector3(0, Ship.DECK_Y, -1.5), JAWS_R, JAWS_WARN, Color(1.0, 0.18, 0.12), Net.key_of(s)])
			if _a_t > JAWS_DARK + JAWS_WARN:
				_jaws(s)
				_go_a(A.JAWS)
		A.JAWS:
			var side: Vector3 = s.global_transform * Vector3(7.0, 0.0, -1.5)
			core.global_position = core.global_position.move_toward(Vector3(side.x, 1.0, side.z), 30.0 * delta)
			lure_at = core.global_position + Vector3(0, 6.0, -2.0)
			if _a_t > 0.5:
				_go_a(A.UP)
		A.UP, A.STUN:
			lure_at = core.global_position + Vector3(0, 6.0 + 0.3 * sin(st_t * 4.0), -2.0)
			lure_on = _a == A.UP
			if _a_t > (UP_TIME if _a == A.UP else STUN_TIME):
				lure_on = true
				_next = _rng.randf_range(5.0, 8.0)
				_go_a(A.LURK)
	var to := sp - core.global_position
	to.y = 0.0
	if to.length() > 0.5:
		core.global_basis = core.global_basis.slerp(Basis.looking_at(to.normalized()), clampf(delta * 1.5, 0.0, 1.0))


func _go_a(a: A) -> void:
	_a = a
	_a_t = 0.0


func _jaws(s: Ship) -> void:
	var at: Vector3 = s.global_transform * Vector3(0, Ship.DECK_Y, -1.5)
	Net.fx("splash", [at + Vector3(6.0, 0, 0), 40, 3.0])
	Net.fx("sfx", ["roar", at, 10.0, 0.03, 0.5])
	Net.fx("sfx", ["wood_crack", at, 8.0, 0.05, 0.55])
	s.hull_hit(JAWS_HULL, at)
	# (the blow first: the toss knocks captains flat, and a floored one can't be hit)
	_deck_hit(Net.key_of(s), Vector3(0, Ship.DECK_Y, -1.5), JAWS_R, JAWS_DMG)
	Net.event(self, "deck_hit", [Net.key_of(s), Vector3(0, Ship.DECK_Y, -1.5), JAWS_R, JAWS_DMG])
	Net.everyone("_all_rammed", [Net.key_of(s), at + Vector3(6.0, 0, 0), Vector3(-1.4, 0, 0)])


func _deck_hit(ship_key: String, local: Vector3, r: float, dmg: float) -> void:
	var s := Net.node_of(ship_key) as Node3D
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if s == null or me == null or not me.has_node("Hurtbox"):
		return
	CombatManager.apply_camera_shake(0.5)
	var hb := me.get_node("Hurtbox") as Hurtbox
	if not hb.monitorable:
		return
	var at: Vector3 = s.global_transform * local
	if Vector2(me.global_position.x - at.x, me.global_position.z - at.z).length() > r or me.global_position.y > at.y + 1.6:
		return
	var hd := HitData.new()
	hd.damage = dmg
	hd.knockdown = true
	hd.unblockable = true
	hd.knockback_force = 7.0
	hd.stagger_duration = 0.4
	hd.camera_shake_intensity = 0.35
	hb.take_hit(hd, self)


## A blow on the lure: x LURE_K, and enough of them drag it up stunned.
func _lure_hit(hit: HitData, _by: Node) -> void:
	if not is_up():
		return
	var dmg := hit.damage * (1.5 if hit.siege else 1.0) * LURE_K
	hurt(dmg, lure_at)
	_stun_acc += dmg
	if _stun_acc >= STUN_DMG and _a in [A.LURK, A.DARK] and state == S.FIGHT:
		_stun_acc = 0.0
		core.global_position = Vector3(lure_at.x, 0.8, lure_at.z) - core.global_basis.z * -4.0
		_go_a(A.STUN)
		Net.fx("splash", [core.global_position, 30, 2.5])
		Net.fx("sfx", ["roar", core.global_position, 8.0, 0.03, 0.6])
		get_tree().call_group("hud", "show_toast", "The angler's stunned at the surface - fire!")
		Net.event(self, "stunned", [])


func _clear_parts() -> void:
	if _a != A.LURK:
		_go_a(A.LURK)
	lure_on = true


# --------------------------------------------------------------------------
# Every screen
# --------------------------------------------------------------------------
func _pose(_delta: float) -> void:
	_lure.global_position = lure_at
	_bulb.visible = lure_on
	_lamp.visible = lure_on
	var root := core.global_position + core.global_basis * Vector3(0, 4.6, -3.0)
	var mid := (root + lure_at) * 0.5 + Vector3.UP * 3.0
	var prev := root
	for i in range(_stalk.size()):
		var u := float(i + 1) / _stalk.size()
		var p := root.lerp(mid, u).lerp(mid.lerp(lure_at, u), u)
		var mi: MeshInstance3D = _stalk[i]
		var d := p - prev
		mi.global_position = prev
		if d.length() > 0.05:
			mi.global_basis = Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.98 else Vector3.RIGHT) * Basis.from_scale(Vector3(1, 1, d.length()))
		prev = p


func _pack_extra() -> Array:
	return [lure_at, lure_on]


func _unpack_extra(a: Array, b: Array, f: float) -> void:
	if a.size() < 2 or b.size() < 2:
		return
	lure_at = (a[0] as Vector3).lerp(b[0], f)
	lure_on = bool(b[1])


func _event(what: String, args: Array) -> void:
	match what:
		"deck_hit":
			_deck_hit(str(args[0]), args[1], float(args[2]), float(args[3]))
		"stunned":
			get_tree().call_group("hud", "show_toast", "The angler's stunned at the surface - fire!")
