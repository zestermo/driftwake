class_name ColossalSquid
extends Leviathan
## The colossal squid (1.28 leviathan): a great red mantle rearing out of the sea beside the ship, two feeding
## tentacles lashing the air, and up to ARMS arms that GRAB her rails (a red ring warns where, then the arm comes down
## across the deck: clear it or be flattened). Every arm holding on drags her (Ship.held_k: slower) and now and then
## the hull groans under them; an arm on the deck can be cut away by hand (ARM_HP: cut, it lets go and the beast
## takes CUT_HURT). An arm up there sometimes SLAMS the deck (a ring over mid-deck). Cannons and the harpoon wear the
## mantle down; reeled alongside, it lets go of everything.

const HP_BASE := 2200.0
const ARMS := 3
const ARM_HP := 180.0
const CUT_HURT := 140.0
## Where it sits: off her beam, this far out (ship-local x), a little aft.
const SIDE_X := 17.0
const GRAB_R := 2.2
const GRAB_DMG := 30.0
const GRAB_WARN := 1.2
const SLAM_R := 3.6
const SLAM_DMG := 26.0
const SLAM_WARN := 1.1
const DRAG_PER_ARM := 0.22
const GROAN_EVERY := 5.0
const GROAN_HULL := 8.0
const SEG_N := 9
const RED := Color(0.62, 0.16, 0.14)
const PALE := Color(0.92, 0.66, 0.58)

var _side := 1.0
var _next := 3.0
## Each grabbing arm: held, where on her (ship-local), its hp, how far it's lifted (0..1, for the slam).
var arm_on: Array = [false, false, false]
var arm_at: Array = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var arm_hp: Array = [ARM_HP, ARM_HP, ARM_HP]
var arm_lift: Array = [0.0, 0.0, 0.0]
var _arm_boxes: Array = []
var _arm_segs: Array = []
var _feeders: Array = []
var _pending := {}
var _groan_t := 0.0
var _seg_mesh: Mesh
var _t := 0.0


func _init() -> void:
	title = "Colossal Squid"
	hp_base = HP_BASE


func _build() -> void:
	var skin := wet_hide("leather", 0.35)
	var mb := MeshBuilder.new()
	# the mantle, rearing up out of the water (+y), a fin either side near the tip
	var rings := [[-3.0, 3.0, 3.0], [-1.0, 3.4, 3.2], [2.0, 3.3, 3.0], [5.0, 2.6, 2.4], [7.5, 1.6, 1.5], [9.2, 0.5, 0.5], [9.8, 0.05, 0.05]]
	mb.add_loft(skin, Transform3D(), rings, MeshBuilder.profile_circle(10), 0.6, RED, true, true)
	for sx in [-1.0, 1.0]:
		var a := Vector3(sx * 0.4, 9.4, 0.0)
		var b := Vector3(sx * 4.0, 7.6, 0.0)
		var c := Vector3(sx * 3.6, 6.0, 0.0)
		var d := Vector3(sx * 2.5, 5.2, 0.0)
		mb.add_quad(skin, a, b, c, d, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), RED.darkened(0.15))
		mb.add_quad(skin, a, d, c, b, Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), RED.darkened(0.15))
	# the head below the mantle, the great eyes
	mb.add_loft(skin, Transform3D(Basis(), Vector3(0, -5.0, 0)), [[-0.5, 2.4, 2.4], [1.0, 3.0, 2.8], [2.2, 3.1, 3.0]], MeshBuilder.profile_circle(10), 0.6, PALE)
	var eye := PSXMat.glow(Color(1.0, 0.82, 0.25), 1.6)
	for sx in [-1.0, 1.0]:
		mb.add_cylinder(eye, Transform3D(Basis(Vector3.BACK, sx * PI * 0.5), Vector3(sx * 2.9, -3.6, 0.6)), 0.9, 0.9, 0.3, 10)
		mb.add_cylinder(PSXMat.flat(Color(0.05, 0.03, 0.03)), Transform3D(Basis(Vector3.BACK, sx * PI * 0.5), Vector3(sx * 3.08, -3.6, 0.6)), 0.4, 0.4, 0.06, 8)
	var body := MeshInstance3D.new()
	body.name = "Mantle"
	body.mesh = mb.commit()
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.visibility_range_end = 600.0
	core.add_child(body)
	hurtbox = make_hurtbox("Hurtbox", core, 4.2, Vector3(0, 2.0, 0))
	# one tentacle segment, shared
	var sb := MeshBuilder.new()
	sb.add_cylinder(skin, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.5)), 0.55, 0.45, 1.0, 6, 0.5, RED)
	_seg_mesh = sb.commit()
	for i in range(2):
		_feeders.append(_chain("Feeder%d" % i))
	for i in range(ARMS):
		_arm_segs.append(_chain("Arm%dSegs" % i))
		var holder := Node3D.new()
		holder.name = "ArmEnd%d" % i
		add_child(holder)
		var idx := i
		var hb := make_hurtbox("ArmBox%d" % i, holder, 1.3, Vector3(0, 0.8, 0), func(hit: HitData, by: Node): _arm_hit(idx, hit, by))
		hb.monitorable = false
		_arm_boxes.append(hb)


func _chain(nm: String) -> Array:
	var out: Array = []
	for k in range(SEG_N):
		var mi := MeshInstance3D.new()
		mi.name = "%s_%d" % [nm, k]
		mi.mesh = _seg_mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 400.0
		add_child(mi)
		out.append(mi)
	return out


func _rise_at(sp: Vector3) -> Vector3:
	_side = 1.0 if _rng.randf() < 0.5 else -1.0
	var s := ship()
	return s.global_transform * Vector3(_side * SIDE_X, -12.0, -1.0) if s else sp


func _spheres() -> Array:
	return [[core.global_position + Vector3(0, 2.0, 0), 4.4], [core.global_position + Vector3(0, 6.5, 0), 2.8]]


# --------------------------------------------------------------------------
# The fight (host)
# --------------------------------------------------------------------------
func _fight(delta: float, s: Ship) -> void:
	var want: Vector3 = s.global_transform * Vector3(_side * SIDE_X, 0.0, -1.0)
	want.y = -0.5 + 0.6 * sin(st_t * 0.7)
	core.global_position = core.global_position.lerp(want, clampf(delta * 1.5, 0.0, 1.0))
	var to := s.global_position - core.global_position
	to.y = 0.0
	if to.length() > 0.5:
		core.global_basis = core.global_basis.slerp(Basis.looking_at(to.normalized()), clampf(delta * 2.0, 0.0, 1.0))
	# pending blows land
	for k in _pending.keys():
		var e: Array = _pending[k]
		e[0] = float(e[0]) - delta
		if float(e[0]) <= 0.0:
			_pending.erase(k)
			if str(e[1]) == "grab":
				_land_grab(int(k), e[2], s)
			else:
				_land_slam(int(k), e[2], s)
	var held := arm_on.count(true)
	if held > 0:
		_groan_t += delta
		if _groan_t > GROAN_EVERY:
			_groan_t = 0.0
			s.hull_hit(GROAN_HULL * held, s.global_transform * Vector3(_side * 2.0, 0.5, 0.0))
			Net.fx("sfx", ["wood_crack", s.global_position, 2.0, 0.08, 0.6])
			Net.everyone("_all_rammed", [Net.key_of(s), core.global_position, (core.global_position - s.global_position).normalized() * 0.5])
	_next -= delta
	if _next > 0.0 or not _pending.is_empty():
		return
	_next = _rng.randf_range(4.5, 7.5)
	var free := -1
	for i in range(ARMS):
		if not arm_on[i]:
			free = i
			break
	var held_ids: Array = []
	for i in range(ARMS):
		if arm_on[i]:
			held_ids.append(i)
	if free >= 0 and (held_ids.is_empty() or _rng.randf() < 0.6):
		var at := Vector3(_side * (HullBuilder.half_width(0.0) - 0.4), Ship.DECK_Y, _rng.randf_range(Ship.DECK_Z_MIN + 1.5, Ship.DECK_Z_MAX - 1.0))
		_pending[free] = [GRAB_WARN, "grab", at]
		Net.fx("telegraph", [s.global_transform * at, GRAB_R, GRAB_WARN + 0.3, Color(1.0, 0.18, 0.12), Net.key_of(s)])
		Net.fx("sfx", ["roar", core.global_position, 4.0, 0.05, 1.1])
	elif not held_ids.is_empty():
		var i: int = held_ids[_rng.randi() % held_ids.size()]
		var mid := Vector3(_rng.randf_range(-1.2, 1.2), Ship.DECK_Y, _rng.randf_range(Ship.DECK_Z_MIN + 2.0, Ship.DECK_Z_MAX - 2.0))
		_pending[i] = [SLAM_WARN, "slam", mid]
		arm_lift[i] = 1.0
		Net.fx("telegraph", [s.global_transform * mid, SLAM_R, SLAM_WARN + 0.3, Color(1.0, 0.18, 0.12), Net.key_of(s)])


func _land_grab(i: int, at: Vector3, s: Ship) -> void:
	arm_on[i] = true
	arm_at[i] = at
	arm_hp[i] = ARM_HP * maxf(max_hp / HP_BASE, 1.0)
	arm_lift[i] = 0.0
	_arm_boxes[i].set_deferred("monitorable", true)
	Net.fx("dust", [s.global_transform * at, 16, 1.2])
	Net.fx("sfx", ["thud", s.global_transform * at, 6.0, 0.05, 0.6])
	_deck_hit(Net.key_of(s), at, GRAB_R, GRAB_DMG)
	Net.event(self, "deck_hit", [Net.key_of(s), at, GRAB_R, GRAB_DMG])


func _land_slam(i: int, at: Vector3, s: Ship) -> void:
	arm_lift[i] = 0.0
	if not arm_on[i]:
		return
	Net.fx("splash", [s.global_transform * at, 12, 1.0])
	Net.fx("sfx", ["thud", s.global_transform * at, 8.0, 0.05, 0.5])
	s.hull_hit(12.0, s.global_transform * at)
	_deck_hit(Net.key_of(s), at, SLAM_R, SLAM_DMG)
	Net.event(self, "deck_hit", [Net.key_of(s), at, SLAM_R, SLAM_DMG])


## Each captain on their own screen: under it when it came down? (Jump clear, or be flattened.)
func _deck_hit(ship_key: String, local: Vector3, r: float, dmg: float) -> void:
	var s := Net.node_of(ship_key) as Node3D
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if s == null or me == null or not me.has_node("Hurtbox"):
		return
	CombatManager.apply_camera_shake(0.35)
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
	hd.knockback_force = 8.0
	hd.stagger_duration = 0.4
	hd.camera_shake_intensity = 0.3
	hb.take_hit(hd, self)


func _arm_hit(i: int, hit: HitData, _by: Node) -> void:
	if not arm_on[i] or not is_up():
		return
	var dmg := hit.damage * (1.5 if hit.siege else 1.0)
	arm_hp[i] = float(arm_hp[i]) - dmg
	var end := (_arm_boxes[i] as Node3D).global_position
	Net.damage_number(dmg, end + Vector3.UP * 1.5)
	Net.fx("blood", [end, Vector3.UP, 10])
	if float(arm_hp[i]) <= 0.0:
		_let_go(i)
		hurt(CUT_HURT, core.global_position + Vector3.UP * 4.0)
		Net.fx("sfx", ["roar", core.global_position, 8.0, 0.03, 1.2])
		Net.event(self, "cut", [end])


func _let_go(i: int) -> void:
	arm_on[i] = false
	arm_lift[i] = 0.0
	_pending.erase(i)
	_arm_boxes[i].set_deferred("monitorable", false)


func _clear_parts() -> void:
	for i in range(ARMS):
		if arm_on[i]:
			_let_go(i)
	_pending.clear()


# --------------------------------------------------------------------------
# Every screen: the arms follow the beast and the ship, she's held back
# --------------------------------------------------------------------------
func _pose(delta: float) -> void:
	_t += delta
	var s := ship()
	var base := core.global_position + core.global_basis * Vector3(0, -2.5, 0)
	for i in range(_feeders.size()):
		var sway := Vector3(sin(_t * 1.3 + i * 2.0) * 3.0, 0.0, cos(_t * 0.9 + i) * 2.0)
		var tip := base + core.global_basis * Vector3((i * 2 - 1) * 5.0, 9.0 + 2.0 * sin(_t * 1.7 + i), -3.0) + sway
		_lay(_feeders[i], base, base + Vector3(0, 6.0, 0) + sway * 0.5, tip)
	for i in range(ARMS):
		var segs: Array = _arm_segs[i]
		var on: bool = arm_on[i] and s != null and is_up()
		for mi in segs:
			(mi as Node3D).visible = on
		if not on:
			continue
		var grip: Vector3 = s.global_transform * (arm_at[i] as Vector3)
		var lift := float(arm_lift[i])
		var end := grip + Vector3.UP * 5.0 * lift
		(_arm_boxes[i].get_parent() as Node3D).global_position = end
		_lay(segs, base, (base + end) * 0.5 + Vector3.UP * (4.0 + 3.0 * lift), end)
	if s:
		var held := 0
		for i in range(ARMS):
			if arm_on[i] and is_up():
				held += 1
		s.held_k = 1.0 - DRAG_PER_ARM * held


## Lay a chain of segments along a curve a -> c (bending through b), thinning to the tip.
func _lay(segs: Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := segs.size()
	var prev := a
	for k in range(n):
		var u := float(k + 1) / float(n)
		var p := a.lerp(b, u).lerp(b.lerp(c, u), u)
		var mi: MeshInstance3D = segs[k]
		var d := p - prev
		var len := maxf(d.length(), 0.01)
		mi.global_position = prev
		if len > 0.02:
			mi.global_basis = Basis.looking_at(d / len, Vector3.UP if absf(d.normalized().y) < 0.98 else Vector3.RIGHT) * Basis.from_scale(Vector3(1.0 - u * 0.6, 1.0 - u * 0.6, len))
		prev = p


# --------------------------------------------------------------------------
# Co-op
# --------------------------------------------------------------------------
func _pack_extra() -> Array:
	return [arm_on.duplicate(), arm_at.duplicate(), arm_lift.duplicate()]


func _unpack_extra(_a: Array, b: Array, _f: float) -> void:
	if b.size() < 3:
		return
	for i in range(ARMS):
		arm_on[i] = bool(b[0][i])
		arm_at[i] = b[1][i]
		arm_lift[i] = float(b[2][i])
		_arm_boxes[i].monitorable = arm_on[i] and is_up()


func _event(what: String, args: Array) -> void:
	match what:
		"deck_hit":
			_deck_hit(str(args[0]), args[1], float(args[2]), float(args[3]))
		"cut":
			FX.blood(args[0], Vector3.UP, 20)
