class_name FishRod
extends Node3D
## A captain's fishing rod on every machine (the Player's child "Rod", the puppets' too), like Jam for the
## instruments: carried broken down on the back when it's in the equipment slot (unless hidden), and while
## the body plays a "rod_*" action (FishPoses) held in torso space on that action's clock, bent by the line,
## with both hands put on it by IK (the right on the fore grip, the left on the butt, the crank while
## reeling, the catch when it's landed). The bobber (it flies, floats on Ocean's waves, nibbles, dips),
## the line and the catch on it are drawn here too, from FishState's calls on the captain's own machine
## and the same calls arriving as Net.events elsewhere (cast, nibble, bite, escape, reel, land, stop), so a
## crewmate sees the cast, the float and the catch. Cast from a deck, the bobber keeps to the ship's frame
## (trolling). The local captain's `cast_ready` is where a cast would land now (INF: it can't), checked
## every READY_EVERY s while a rod is carried: InteractionComponent's "Cast your line" prompt reads it.

const IK_IN := 0.25
const READY_EVERY := 0.25
## Carried: the broken-down rod (along +Y) slung across the back, from the right hip over the left shoulder.
const BACK := Transform3D(Basis(Vector3.BACK, 0.6), Vector3(0.05, -0.12, 0.17))
## Where each wrist sits from the point of the rod it holds (rod-local): the fore grip, the butt, the crank.
const HAND_R := Vector3(0.0, -0.035, 0.07)
const HAND_L := Vector3(0.0, -0.035, 0.36)
const HAND_CRANK := Vector3(-0.03, -0.03, 0.03)
## The catch held up to look at (torso space), and how fast the crank turns (rad/s).
const FISH_HOLD := Vector3(-0.32, 0.46, -0.42)
## A catch longer than this (m) stays on the line under the tip.
const BIG := 0.7
const CRANK_SPEED := 16.0
## Rod keys per action: [u, grip (torso space), pitch (up), yaw (left), bend (tip down), left hand on the
## crank 0..1, left hand on the catch 0..1, "out" (leaves the key before fast)].
const WAIT := Vector3(0.12, 0.16, -0.48)
const KEYS := {
	"rod_cast": [[0.0, WAIT, 0.38, 0.0, 0.0, 0.0, 0.0, ""], [0.08, WAIT, 0.48, 0.0, 0.0, 0.0, 0.0, ""],
		[0.28, Vector3(0.15, 0.62, -0.2), 1.95, 0.12, -0.1, 0.0, 0.0, ""], [0.4, Vector3(0.15, 0.64, -0.18), 2.05, 0.12, -0.35, 0.0, 0.0, ""],
		[0.52, Vector3(0.14, 0.45, -0.42), 0.85, 0.0, 0.4, 0.0, 0.0, "out"], [0.68, Vector3(0.13, 0.22, -0.48), 0.15, -0.02, -0.12, 0.0, 0.0, ""],
		[1.0, WAIT, 0.38, 0.0, 0.0, 0.0, 0.0, ""]],
	"rod_reel": [[0.0, WAIT, 0.38, 0.0, 0.15, 0.0, 0.0, ""], [0.1, Vector3(0.15, 0.42, -0.3), 1.3, 0.0, 0.7, 0.0, 0.0, "out"],
		[0.22, Vector3(0.14, 0.3, -0.34), 1.0, 0.0, 0.5, 1.0, 0.0, ""], [0.8, Vector3(0.14, 0.3, -0.34), 1.0, 0.0, 0.45, 1.0, 0.0, ""],
		[0.95, Vector3(0.15, 0.4, -0.3), 1.3, 0.0, 0.35, 0.0, 0.0, ""], [1.0, Vector3(0.15, 0.4, -0.3), 1.3, 0.0, 0.3, 0.0, 0.0, ""]],
	"rod_strike": [[0.0, WAIT, 0.38, 0.0, 0.0, 0.0, 0.0, ""], [0.18, Vector3(0.15, 0.42, -0.3), 1.25, 0.0, 0.05, 0.0, 0.0, "out"],
		[0.4, Vector3(0.14, 0.3, -0.34), 0.9, 0.0, 0.0, 1.0, 0.0, ""], [0.8, Vector3(0.14, 0.3, -0.34), 0.9, 0.0, 0.0, 1.0, 0.0, ""],
		[1.0, WAIT, 0.38, 0.0, 0.0, 0.0, 0.0, ""]],
	"rod_land": [[0.0, Vector3(0.15, 0.4, -0.3), 1.3, 0.0, 0.3, 0.0, 0.0, ""], [0.3, Vector3(0.2, 0.42, -0.28), 1.45, 0.1, 0.25, 0.0, 0.0, ""],
		[0.45, Vector3(0.22, 0.18, -0.3), 0.75, -0.35, 0.05, 0.0, 1.0, "out"], [0.85, Vector3(0.22, 0.18, -0.3), 0.75, -0.35, 0.05, 0.0, 1.0, ""],
		[1.0, WAIT, 0.38, 0.0, 0.0, 0.0, 0.0, ""]],
}

static var _line_mat: StandardMaterial3D

var player
var cast_ready := Vector3.INF
## "" (no line out), "flight", "float", "bite", "reel", "land".
var phase := ""
var _tier := ""
var _built_on: Node = null
var _back: MeshInstance3D
var _parts: Dictionary = {}
var _w := 0.0
var _ready_t := 0.0
var _bob: MeshInstance3D
var _line: MeshInstance3D
var _im: ImmediateMesh
var _fish: MeshInstance3D
## Where the bobber lies: world, or ship-local when cast from her deck (_ship).
var _spot := Vector3.ZERO
var _ship: Ship
var _from := Vector3.ZERO
var _pt := 0.0
var _dip := 0.0
var _twitch := 0.0
var _tip := Vector3.ZERO
var _bob_at := Vector3.ZERO
var _catch := ""


func _ready() -> void:
	process_priority = 10


func _exit_tree() -> void:
	for n in [_bob, _line, _fish]:
		if n and is_instance_valid(n):
			n.queue_free()


func _body() -> Humanoid:
	return player.body_model


## The carried rod's tier from the body's look ("" none).
func carried() -> String:
	var b := _body()
	var t := str(b.look.get("rod", "none")) if b else "none"
	return "" if t == "none" else t


func _process(delta: float) -> void:
	var b := _body()
	if b == null:
		return
	var tier := carried()
	_models(b, tier)
	if tier == "":
		if phase != "":
			stop()
		return
	var act := b.current_action()
	var using := act.begins_with("rod_")
	_w = move_toward(_w, 1.0 if using else 0.0, delta / IK_IN)
	_back.visible = not using and not b.look.get("equip_hidden", false)
	for n in _parts.values():
		(n as Node3D).visible = using
	if using:
		_hold(b, act)
	if phase != "":
		_line_tick(delta)
	if player.is_local:
		_ready_t -= delta
		if _ready_t <= 0.0:
			_ready_t = READY_EVERY
			cast_ready = Fishing.cast_spot(player, tier) if phase == "" and player.is_free() and player.is_on_floor() and not player.is_swimming() else Vector3.INF


# --------------------------------------------------------------------------
# The rod: on the back, or in the hands
# --------------------------------------------------------------------------
func _models(b: Humanoid, tier: String) -> void:
	if tier == _tier and _built_on == b.torso and (tier == "" or is_instance_valid(_back)):
		return
	for n in [_back] + _parts.values():
		if n != null and is_instance_valid(n):
			(n as Node).queue_free()
	_back = null
	_parts.clear()
	_tier = tier
	_built_on = b.torso
	cast_ready = Vector3.INF
	if tier == "":
		return
	_back = _mesh("RodCarried", Rods.mesh(tier, "carried"), b.torso)
	_back.transform = BACK
	for part in ["butt", "mid", "tip", "crank"]:
		_parts[part] = _mesh("Rod_" + part, Rods.mesh(tier, part), b.torso)
		(_parts[part] as Node3D).visible = false


func _mesh(nm: String, m: Mesh, parent: Node) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## The rod's keys for `act` at `u`: [grip, pitch, yaw, bend, crank hand, catch hand].
static func rod_at(act: String, u: float, t: float) -> Array:
	if not KEYS.has(act):
		return [WAIT + Vector3(0, 0.008 * sin(t * 1.6), 0), 0.38 + 0.015 * sin(t * 1.1), 0.0, 0.0, 0.0, 0.0]
	var keys: Array = KEYS[act]
	var i := 0
	while i < keys.size() - 2 and u > float(keys[i + 1][0]):
		i += 1
	var a: Array = keys[i]
	var c: Array = keys[i + 1]
	var k := clampf((u - float(a[0])) / maxf(float(c[0]) - float(a[0]), 0.001), 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 3.0) if c[7] == "out" else k * k * (3.0 - 2.0 * k)
	return [(a[1] as Vector3).lerp(c[1], e), lerpf(a[2], c[2], e), lerpf(a[3], c[3], e), lerpf(a[4], c[4], e), lerpf(a[5], c[5], e), lerpf(a[6], c[6], e)]


## The rod held for the body's action, bent, and both hands on it.
func _hold(b: Humanoid, act: String) -> void:
	var dur := maxf(float(b._action["dur"]), 0.001)
	var t := float(b._action["t"])
	var r := rod_at(act, clampf(t / dur, 0.0, 1.0), t)
	var bend: float = r[3]
	var pitch: float = r[1]
	if phase == "bite":
		# the fish pulls the tip down and the rod trembles
		bend += 0.4 + 0.06 * sin(t * 40.0)
		pitch -= 0.08
	elif phase == "float" and act == "rod_wait":
		bend += 0.06 * _twitch
	var grip := Transform3D(Basis(Vector3.UP, r[2]) * Basis(Vector3.RIGHT, pitch), r[0])
	var length := Rods.stat(_tier, "length")
	(_parts["butt"] as Node3D).transform = grip
	var mid := grip * Transform3D(Basis(Vector3.RIGHT, -bend * 0.4), Vector3(0, 0, -Rods.SEG1))
	(_parts["mid"] as Node3D).transform = mid
	var tip := mid * Transform3D(Basis(Vector3.RIGHT, -bend * 0.6), Vector3(0, 0, -Rods.SEG2))
	(_parts["tip"] as Node3D).transform = tip
	var turn := t * CRANK_SPEED if act in ["rod_reel", "rod_strike"] else 0.0
	var crank := grip * Transform3D(Basis(Vector3.RIGHT, turn), Rods.REEL_AT)
	(_parts["crank"] as Node3D).transform = crank
	var tg := b.torso.global_transform
	_tip = tg * (tip * Vector3(0, 0, -(length - Rods.SEG1 - Rods.SEG2)))
	var body_b := b.global_basis
	var e := _w * _w * (3.0 - 2.0 * _w)
	var on_r := tg * (grip * HAND_R)
	b.reach_hand(true, b.hand_r.global_position.lerp(on_r, e), body_b * Vector3(1.0, -1.0, 0.3))
	var on_l := tg * (grip * HAND_L)
	if float(r[4]) > 0.0:
		var knob := crank * Vector3(Rods.CRANK_X - 0.015, Rods.CRANK_ARM, 0)
		on_l = on_l.lerp(tg * (Transform3D(grip.basis, knob) * HAND_CRANK), r[4])
	# (a big fish stays hanging off the rod: it won't hang from one hand)
	if _catch != "" and float(FishTable.look_of(_catch)[1]) > BIG:
		r[5] = 0.0
	if float(r[5]) > 0.0:
		on_l = on_l.lerp(tg * FISH_HOLD, r[5])
	b.reach_hand(false, b.hand_l.global_position.lerp(on_l, e), body_b * Vector3(-1.0, -1.0, 0.3))
	if _fish and _fish.visible:
		_place_fish(b, act, clampf(t / dur, 0.0, 1.0), float(r[5]))


# --------------------------------------------------------------------------
# The line, the bobber and the catch (FishState's calls here; Net.events on the other screens)
# --------------------------------------------------------------------------
## The cast leaves the rod for `spot` (world, the calm sea level).
func throw(spot: Vector3) -> void:
	_send("throw", [spot])
	_ensure_line()
	var ship := Downtime.ship_under(player)
	_ship = ship
	_spot = ship.global_transform.affine_inverse() * spot if ship else spot
	_from = _tip if _tip != Vector3.ZERO else player.global_position + Vector3.UP * 1.6
	_pt = 0.0
	_dip = 0.0
	_twitch = 0.0
	_catch = ""
	phase = "flight"
	_bob.visible = true
	_line.visible = true
	_fish.visible = false
	FX.sfx("fish_cast", _from, -4.0, 0.05)


## A fish noses the bait: the float twitches.
func nibble() -> void:
	_send("nibble", [])
	if phase != "float":
		return
	_twitch = 1.0
	FX.water_ring(_bob_at, 0.35, 0.6)
	FX.sfx("fish_plop", _bob_at, -10.0, 0.15, 1.35)


## It bites: the float goes under with a splash and bubbles.
func bite() -> void:
	_send("bite", [])
	if phase not in ["float", "bite"]:
		return
	phase = "bite"
	_pt = 0.0
	FX.splash(_bob_at, 5, 0.45)
	FX.bubbles(_bob_at + Vector3.DOWN * 0.1, 6)
	FX.water_ring(_bob_at, 0.9, 0.9)
	FX.sfx("fish_bite", _bob_at, 0.0, 0.08)


## Missed it: the float bobs back up (the line's still in).
func escape() -> void:
	_send("escape", [])
	if phase == "bite":
		phase = "float"
		_pt = 0.0
		FX.bubbles(_bob_at, 3)


## Reeling in (a fish on, or nothing).
func reel() -> void:
	_send("reel", [])
	if phase in ["float", "bite", "flight"]:
		FX.sfx("fish_reel", player.global_position + Vector3.UP * 1.2, -4.0 if phase == "bite" else -8.0, 0.05, 1.0 if phase == "bite" else 1.25)
		phase = "reel"
		_pt = 0.0
		_from = _bob_at


## Landed: `id`'s fish comes up on the line, swung in to the left hand, and goes in the bag.
func land(id: String) -> void:
	_send("land", [id])
	_ensure_line()
	_catch = id
	phase = "land"
	_pt = 0.0
	_bob.visible = false
	var lk: Array = FishTable.look_of(id)
	_fish.mesh = FishModels.fish(str(lk[0]), float(lk[1]), lk[2], lk[3])
	_fish.visible = true
	FX.splash(_tip_ground(), 4, 0.4)
	FX.sfx("fish_catch", _tip, -2.0, 0.05)


## The line's out of the water: everything put away.
func stop() -> void:
	_send("stop", [])
	phase = ""
	_catch = ""
	for n in [_bob, _line, _fish]:
		if n:
			n.visible = false


func _send(what: String, args: Array) -> void:
	if player.is_local:
		Net.event(self, what, args)


func net_event(what: String, args: Array) -> void:
	match what:
		"throw":
			throw(args[0])
		"nibble":
			nibble()
		"bite":
			bite()
		"escape":
			escape()
		"reel":
			reel()
		"land":
			land(str(args[0]))
		"stop":
			stop()


func _ensure_line() -> void:
	if _bob and is_instance_valid(_bob):
		return
	var root := get_tree().current_scene
	_bob = MeshInstance3D.new()
	_bob.name = "Bobber_%s" % player.name
	_bob.mesh = FishModels.bobber()
	_bob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bob.visibility_range_end = 80.0
	root.add_child(_bob)
	if _line_mat == null:
		_line_mat = StandardMaterial3D.new()
		_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_line_mat.albedo_color = Color(0.9, 0.9, 0.86)
	_im = ImmediateMesh.new()
	_line = MeshInstance3D.new()
	_line.name = "FishLine_%s" % player.name
	_line.mesh = _im
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_line.extra_cull_margin = 16.0
	root.add_child(_line)
	_fish = MeshInstance3D.new()
	_fish.name = "Catch_%s" % player.name
	_fish.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(_fish)


## Where the bobber lies now (world, on the water).
func _target() -> Vector3:
	var s := _ship.global_transform * _spot if _ship and is_instance_valid(_ship) else _spot
	return Vector3(s.x, float(get_node("/root/Ocean").get_wave_height(s)), s.z)


func _tip_ground() -> Vector3:
	return Vector3(_tip.x, float(get_node("/root/Ocean").get_wave_height(_tip)), _tip.z)


func _line_tick(delta: float) -> void:
	_pt += delta
	_twitch = move_toward(_twitch, 0.0, delta * 2.5)
	var end := _bob_at
	var sag := 0.0
	match phase:
		"flight":
			var to := _target()
			var k := minf(_pt / Fishing.FLIGHT, 1.0)
			var arc := 1.2 + _from.distance_to(to) * 0.12
			_bob_at = _from.lerp(to, k) + Vector3.UP * arc * 4.0 * k * (1.0 - k)
			end = _bob_at
			if k >= 1.0:
				phase = "float"
				_pt = 0.0
				FX.splash(_bob_at, 3, 0.35)
				FX.water_ring(_bob_at, 0.6, 0.8)
				FX.sfx("fish_plop", _bob_at, -2.0, 0.1)
		"float", "bite":
			var to := _target()
			_dip = move_toward(_dip, 1.0 if phase == "bite" else 0.0, delta * (9.0 if phase == "bite" else 3.0))
			var bob := 0.015 * sin(_pt * 2.3) - 0.07 * _twitch * absf(sin(_pt * 18.0)) - 0.2 * _dip
			_bob_at = to + Vector3(0, 0.02 + bob, 0)
			end = _bob_at
			sag = 0.0 if phase == "bite" else 0.25 + 0.03 * _tip.distance_to(to)
			if phase == "bite" and fmod(_pt, 0.3) < delta:
				FX.bubbles(_bob_at, 2)
		"reel":
			var k := minf(_pt / (Fishing.REEL_LEN * 0.85), 1.0)
			var g := _tip_ground()
			var at := _from.lerp(g, pow(k, 1.4))
			at.y = float(get_node("/root/Ocean").get_wave_height(at)) + 0.03
			if k > 0.75:
				at = at.lerp(_tip + Vector3.DOWN * 0.5, (k - 0.75) / 0.25)
			_bob_at = at
			end = at
			if fmod(_pt, 0.18) < delta and k < 0.8:
				FX.splash(at, 1, 0.25)
		"land":
			end = _fish.global_position + _fish.global_basis * Vector3(0, 0, -float(FishTable.look_of(_catch)[1]) * 0.5) if _fish.visible else _tip
	_bob.visible = phase in ["flight", "float", "bite", "reel"]
	if _bob.visible:
		_bob.global_position = _bob_at
		_bob.rotation = Vector3(0.12 * sin(_pt * 1.7), 0.0, 0.1 * sin(_pt * 1.3))
	_draw_line(_tip, end, sag)


func _draw_line(a: Vector3, b: Vector3, sag: float) -> void:
	_im.clear_surfaces()
	_im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _line_mat)
	for i in range(11):
		var k := float(i) / 10.0
		_im.surface_add_vertex(a.lerp(b, k) + Vector3.DOWN * sag * 4.0 * k * (1.0 - k))
	_im.surface_end()


## The catch: hanging off the line under the tip, swung in to the left hand, held up (snout up), then bagged.
func _place_fish(b: Humanoid, act: String, u: float, held: float) -> void:
	var length := float(FishTable.look_of(_catch)[1])
	var hang := _tip + Vector3.DOWN * (0.55 + length * 0.5)
	var hand: Vector3 = b.hand_l.global_position + Vector3.DOWN * (length * 0.5 + 0.04)
	var up := Basis(Vector3.RIGHT, PI * 0.5).rotated(Vector3.UP, b.global_rotation.y + 0.5 * sin(_pt * 5.0) * (1.0 - held))
	_fish.global_transform = Transform3D(up, hang.lerp(hand, held))
	if act == "rod_land" and u >= Fishing.BAGGED:
		_fish.visible = false
		FX.sparkle(b.hand_l.global_position, 6)
