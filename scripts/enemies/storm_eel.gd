class_name StormEel
extends Leviathan
## The storm eel (1.28 leviathan): only rises in a storm (Weather.storm). A long black eel banded with glowing blue-white
## light, so it can be tracked under the waves. It coils round the ship and:
## * MAST: rears its head high, crackling (a ring round the mast's foot), then calls lightning down onto her mast: a
##   blow for everyone near the mast (get clear), her sail torn and a fire at its foot;
## * BELOW: dives, its glow sliding under her hull (a ring on deck warns where), and bursts up through the planks: a
##   breach in her side and a blow for anyone on the spot, its head left lying on the deck a moment: cut at it then.
## Cannons and the harpoon wear it down as for any leviathan.

const HP_BASE := 1900.0
const SEGS := 16
const SPACING := 2.4
const CIRCLE_R := 22.0
const MAST_R := 4.0
const MAST_DMG := 28.0
const MAST_WARN := 1.5
const BELOW_R := 3.0
const BELOW_DMG := 32.0
const BELOW_WARN := 1.6
const BELOW_HULL := 35.0
const DOWN_TIME := 1.8
const MAST_Z := -1.5
const BODY := Color(0.08, 0.1, 0.14)
const GLOW := Color(0.55, 0.85, 1.0)

enum A { SWIM, REAR, BOLT, DIVE, BURST, DOWN }

var _a: A = A.SWIM
var _a_t := 0.0
var _ang := 0.0
var _spin := 1.0
var _next := 4.0
var _below_at := Vector3.ZERO
var seg_pos: Array = []
var _segs: Array = []
var _head_mi: MeshInstance3D


func _init() -> void:
	title = "Storm Eel"
	hp_base = HP_BASE


func _wants_rise() -> bool:
	return float(Weather.storm) > 0.5


func _build() -> void:
	var hide := wet_hide("leather", 0.3)
	var glow := PSXMat.glow(GLOW, 2.2)
	# the head: a long wedge with glowing eyes and a lit band behind them
	var hb := MeshBuilder.new()
	hb.add_loft(hide, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO), [[-2.0, 1.1, 0.9], [0.0, 1.3, 1.0], [2.0, 0.9, 0.7], [3.4, 0.4, 0.35]],
		MeshBuilder.profile_circle(8), 0.6, BODY, true, true)
	for sx in [-1.0, 1.0]:
		hb.add_cylinder(glow, Transform3D(Basis(Vector3.BACK, sx * PI * 0.5), Vector3(sx * 0.95, 0.35, -1.4)), 0.22, 0.22, 0.1, 6)
	hb.add_cylinder(glow, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 1.2)), 1.32, 1.32, 0.25, 8)
	_head_mi = MeshInstance3D.new()
	_head_mi.name = "Head"
	_head_mi.mesh = hb.commit()
	_head_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.add_child(_head_mi)
	hurtbox = make_hurtbox("Hurtbox", core, 2.0, Vector3(0, 0, -0.5))
	# body segments, a glowing band on every other one
	var plain := MeshBuilder.new()
	plain.add_cylinder(hide, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, SPACING * 0.5)), 1.0, 1.0, SPACING + 0.3, 8, 0.5, BODY)
	var banded := MeshBuilder.new()
	banded.add_cylinder(hide, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, SPACING * 0.5)), 1.0, 1.0, SPACING + 0.3, 8, 0.5, BODY)
	banded.add_cylinder(glow, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, SPACING * 0.5)), 1.04, 1.04, 0.35, 8)
	var meshes := [plain.commit(), banded.commit()]
	for i in range(SEGS):
		var mi := MeshInstance3D.new()
		mi.name = "Seg%d" % i
		mi.mesh = meshes[i % 2]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 500.0
		add_child(mi)
		_segs.append(mi)
		seg_pos.append(Vector3.ZERO)


func _rise_at(sp: Vector3) -> Vector3:
	_ang = _rng.randf() * TAU
	var at := sp + Vector3(cos(_ang), 0, sin(_ang)) * CIRCLE_R + Vector3(0, -10.0, 0)
	for i in range(SEGS):
		seg_pos[i] = at + Vector3(0, -(i + 1) * 1.5, 0)
	return at


func _spheres() -> Array:
	var out := [[core.global_position, 2.4]]
	for i in range(0, SEGS, 2):
		out.append([seg_pos[i], 1.4])
	return out


# --------------------------------------------------------------------------
# The fight (host)
# --------------------------------------------------------------------------
func _fight(delta: float, s: Ship) -> void:
	_a_t += delta
	var sp := s.global_position
	match _a:
		A.SWIM:
			_ang += _spin * delta * 0.4
			var want := sp + Vector3(cos(_ang), 0, sin(_ang)) * CIRCLE_R
			want.y = 1.2 + 0.8 * sin(st_t * 1.4)
			_head_to(want, 12.0, delta)
			_next -= delta
			if _next <= 0.0:
				if _rng.randf() < 0.5:
					_go_a(A.REAR)
					Net.fx("telegraph", [s.global_transform * Vector3(0, Ship.DECK_Y, MAST_Z), MAST_R, MAST_WARN + 0.3, Color(0.6, 0.85, 1.0), Net.key_of(s)])
					Net.fx("sfx", ["roar", core.global_position, 6.0, 0.03, 1.3])
				else:
					_below_at = Vector3(_rng.randf_range(-1.6, 1.6), Ship.DECK_Y, _rng.randf_range(Ship.DECK_Z_MIN + 1.5, Ship.DECK_Z_MAX - 1.5))
					_go_a(A.DIVE)
		A.REAR:
			var want := sp + Vector3(cos(_ang), 0, sin(_ang)) * (CIRCLE_R - 6.0) + Vector3(0, 12.0, 0)
			_head_to(want, 10.0, delta)
			if fmod(_a_t, 0.25) < delta:
				Net.fx("bolt", [core.global_position, core.global_position + Vector3(_rng.randf_range(-3, 3), _rng.randf_range(-3, 3), _rng.randf_range(-3, 3)), GLOW, 0.06, 0.12])
			if _a_t > MAST_WARN:
				_mast_strike(s)
				_go_a(A.BOLT)
		A.BOLT:
			if _a_t > 0.8:
				_next = _rng.randf_range(4.5, 7.5)
				_go_a(A.SWIM)
		A.DIVE:
			# down and under her: the glow slides beneath the hull toward the spot
			var to: Vector3 = s.global_transform * _below_at
			_head_to(Vector3(to.x, -6.0, to.z), 16.0, delta)
			if _a_t > 1.0 and _a_t - delta <= 1.0:
				Net.fx("telegraph", [to, BELOW_R, BELOW_WARN, Color(1.0, 0.18, 0.12), Net.key_of(s)])
			if _a_t > 1.0 + BELOW_WARN:
				_burst(s)
				_go_a(A.BURST)
		A.BURST:
			var deck: Vector3 = s.global_transform * _below_at
			_head_to(deck + Vector3(0, 1.4, 0), 40.0, delta)
			if _a_t > 0.3:
				_go_a(A.DOWN)
		A.DOWN:
			core.global_position = s.global_transform * _below_at + Vector3(0, 1.4, 0)
			if _a_t > DOWN_TIME:
				_next = _rng.randf_range(4.5, 7.5)
				_ang += PI * _rng.randf_range(0.6, 1.4)
				_spin = -_spin
				_go_a(A.SWIM)


func _go_a(a: A) -> void:
	_a = a
	_a_t = 0.0


func _head_to(want: Vector3, spd: float, delta: float) -> void:
	var to := want - core.global_position
	core.global_position = core.global_position.move_toward(want, spd * delta)
	if to.length() > 0.2:
		core.global_basis = core.global_basis.orthonormalized().slerp(Basis.looking_at(to.normalized(), Vector3.UP if absf(to.normalized().y) < 0.98 else Vector3.RIGHT), clampf(delta * 4.0, 0.0, 1.0))


func _mast_strike(s: Ship) -> void:
	var top: Vector3 = s.global_transform * Vector3(0, 16.0, MAST_Z)
	var foot: Vector3 = s.global_transform * Vector3(0, Ship.DECK_Y, MAST_Z)
	Net.fx("bolt", [top + Vector3(0, 30, 0), top, Color(0.85, 0.95, 1.0), 0.18, 0.3])
	Net.fx("bolt", [core.global_position, top, GLOW, 0.12, 0.3])
	Net.fx("sfx", ["thunder", foot, 10.0, 0.05, 1.0])
	s.tear_sail(Vector3(0, 9.0, MAST_Z))
	s.add_fire(Vector3(0.6, Ship.DECK_Y, MAST_Z + 0.8))
	_deck_hit(Net.key_of(s), Vector3(0, Ship.DECK_Y, MAST_Z), MAST_R, MAST_DMG)
	Net.event(self, "deck_hit", [Net.key_of(s), Vector3(0, Ship.DECK_Y, MAST_Z), MAST_R, MAST_DMG])


func _burst(s: Ship) -> void:
	var at: Vector3 = s.global_transform * _below_at
	Net.fx("splash", [at, 24, 2.0])
	Net.fx("dust", [at, 18, 1.4])
	Net.fx("sfx", ["wood_crack", at, 8.0, 0.05, 0.6])
	s.hull_hit(BELOW_HULL, at)
	s.add_breach(signf(_below_at.x) if absf(_below_at.x) > 0.1 else 1.0, _below_at.z)
	_deck_hit(Net.key_of(s), _below_at, BELOW_R, BELOW_DMG)
	Net.event(self, "deck_hit", [Net.key_of(s), _below_at, BELOW_R, BELOW_DMG])


## Each captain on their own screen: in the ring when it came? (Clear it, or jump.)
func _deck_hit(ship_key: String, local: Vector3, r: float, dmg: float) -> void:
	var s := Net.node_of(ship_key) as Node3D
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if s == null or me == null or not me.has_node("Hurtbox"):
		return
	CombatManager.apply_camera_shake(0.4)
	var hb := me.get_node("Hurtbox") as Hurtbox
	if not hb.monitorable:
		return
	var at: Vector3 = s.global_transform * local
	if Vector2(me.global_position.x - at.x, me.global_position.z - at.z).length() > r or me.global_position.y > at.y + 1.8:
		return
	var hd := HitData.new()
	hd.damage = dmg
	hd.knockdown = true
	hd.unblockable = true
	hd.knockback_force = 8.0
	hd.stagger_duration = 0.4
	hd.camera_shake_intensity = 0.3
	hb.take_hit(hd, self)


func _clear_parts() -> void:
	if _a != A.SWIM:
		_go_a(A.SWIM)


# --------------------------------------------------------------------------
# Every screen: the body follows the head
# --------------------------------------------------------------------------
func _pose(_delta: float) -> void:
	if not net_puppet:
		var prev := core.global_position - core.global_basis.z * -1.6
		for i in range(SEGS):
			var p: Vector3 = seg_pos[i]
			var d := p - prev
			if d.length() > SPACING:
				p = prev + d.normalized() * SPACING
			# the body trails low in the water behind a risen head
			p.y = minf(p.y, maxf(prev.y - 0.4, -1.5 + 0.9 * sin(st_t * 1.6 - i * 0.6)))
			seg_pos[i] = p
			prev = p
	var last := core.global_position + core.global_basis.z * 1.6
	for i in range(SEGS):
		var p: Vector3 = seg_pos[i]
		var mi: MeshInstance3D = _segs[i]
		mi.global_position = last
		var d := p - last
		if d.length() > 0.05:
			mi.global_basis = Basis.looking_at(-d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.98 else Vector3.RIGHT) * Basis.from_scale(Vector3.ONE * (1.0 - float(i) / SEGS * 0.55))
		last = p


func _pack_extra() -> Array:
	return [PackedVector3Array(seg_pos)]


func _unpack_extra(a: Array, b: Array, f: float) -> void:
	if a.is_empty() or b.is_empty():
		return
	var sa: PackedVector3Array = a[0]
	var sb: PackedVector3Array = b[0]
	for i in range(mini(SEGS, sb.size())):
		seg_pos[i] = sa[i].lerp(sb[i], f) if i < sa.size() else sb[i]


func _event(what: String, args: Array) -> void:
	if what == "deck_hit":
		_deck_hit(str(args[0]), args[1], float(args[2]), float(args[3]))
