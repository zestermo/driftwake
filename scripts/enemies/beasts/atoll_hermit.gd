extends "res://scripts/enemies/beasts/alpha_boar.gd"
## The giant hermit crab (BeastPool "hermit_crab", the coral atoll's boss, on the tidal flat in the lagoon): a crab the
## size of a hut living in a borrowed shell as big as a boat's cabin, one claw grown huge. On the beast pass (1.23):
##   its shell  takes the blows: while it wears one, a hit chips the shell and barely reaches the crab (D.HERMIT_SHELL_K);
##              chip the shell away (D.HERMIT_SHELL) and it cracks off: the soft body underneath takes D.HERMIT_BODY_K
##   hiding     hurt enough bare (D.HERMIT_HIDE_AT of its health since it last hid) it scuttles off to one of the spare
##              shells lying on the flat (a coral boulder, a giant conch, the bow of a wreck), backs into it and hides:
##              nothing reaches it, it mends a little; then it bursts out, its new shell to break again (each a little
##              thinner). Out of spares it fights bare to the end
##   phase 1    pinch (the small claw in front: parry it), crush (the great claw slams down ahead), spit (a jet of grit
##              and seawater down a line)
##   phase 2    sweep (the great claw swings round its front), charge (it runs you down sideways: its one knockdown)
##   phase 3    spin (it whirls with its claws out: a ring round it)
## Looks: coral red with a conch, violet with a coral-boulder shell, sand gold with a wreck's bow for a house.

const D := preload("res://scripts/island/themes/atoll_data.gd")
const LOOKS_H := [
	[Color(0.78, 0.26, 0.16), Color(0.95, 0.72, 0.6), Color(0.96, 0.86, 0.78)],
	[Color(0.42, 0.28, 0.62), Color(0.75, 0.62, 0.88), Color(0.9, 0.62, 0.6)],
	[Color(0.78, 0.6, 0.3), Color(0.95, 0.85, 0.6), Color(0.62, 0.5, 0.36)],
]
const BODY_Y := 1.25
## The spare shells on the flat: how far out from its post, how many.
const SPARE_R := 12.0
const SPARES := 3
const SCUTTLE_SPEED := 9.0

var shell_on := true
var shell_hp := 0.0
## Shells it has moved into (the first is its own); spares used (a bit each).
var shells := 0
var spares_used := 0
var hidden := false
var _hurt_since := 0.0
var _shell_node: Node3D
var _abdomen: Node3D
var _body: Node3D
var _claws: Array = []
var _spare_nodes: Array = []
var _goal := -1
var _t_anim := 0.0
var _shown := -1


func _init() -> void:
	boss_name = "The Shell King"
	wake_r = 0.0


func _spec() -> Dictionary:
	return {"hip_h": BODY_Y + 0.3, "chest_r": 1.35, "hip_r": 1.35, "len": 2.6}


## (its model is built in the world, not ahead on a worker: the rig is its own, not QuadBeast's)
func prebuild() -> void:
	model = Node3D.new()
	model.name = "Model"


func _hp_base() -> float:
	return D.HERMIT_HP


func _phase_at() -> Array:
	return [0.66, 0.33]


func _xp_base() -> int:
	return 800


func _coins_base() -> int:
	return 46


func _speed() -> float:
	return 5.0 if phase < 3 else 6.2


func _hit_point() -> Vector3:
	return global_position + Vector3(0, BODY_Y + 0.4, 0)


func _pass_moves() -> Array:
	return [["pinch", "crush", "spit"], ["sweep", "charge"], ["spin"]]


func _chain_waits() -> Array:
	return ["charge", "spin"]


func _moment_color() -> Color:
	return LOOKS_H[variant % LOOKS_H.size()][0]


func trophy(t: int) -> ItemData:
	return Gear.make("accessory", "cape", {"cape": true, "cape_color": (LOOKS_H[variant % LOOKS_H.size()][0] as Color).darkened(0.2)}, "Shell King's Mantle", t)


# ==========================================================================
# Its body
# ==========================================================================
func _build() -> void:
	spec = _spec()
	var look: Array = LOOKS_H[variant % LOOKS_H.size()]
	var shell_c: Color = look[0]
	var pale: Color = look[1]
	var soft: Color = look[2]
	var skin := own(PSXMat.lit("scales", Color.WHITE))
	var flesh := own(PSXMat.lit("leather", Color.WHITE))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7731 + variant
	_body = Node3D.new()
	_body.name = "Body"
	_body.position = Vector3(0, BODY_Y, 0)
	model.add_child(_body)
	var bmb := MeshBuilder.new()
	# the carapace over its front half, eyes on stalks, feelers
	bmb.add_blob(skin, Transform3D(Basis(), Vector3(0, 0.05, -0.55)), Vector3(1.05, 0.5, 0.85), rng, 0.05, 3, 9, 0.8, shell_c)
	bmb.add_blob(skin, Transform3D(Basis(), Vector3(0, -0.25, -0.5)), Vector3(0.9, 0.3, 0.75), rng, 0.04, 2, 8, 0.8, pale)
	var eye := own(PSXMat.flat(Color(0.05, 0.05, 0.06)))
	for s in [-1.0, 1.0]:
		Creature.seg(bmb, skin, Vector3(s * 0.28, 0.3, -1.1), Vector3(s * 0.4, 1.0, -1.35), 0.1, shell_c)
		bmb.add_blob(eye, Transform3D(Basis(), Vector3(s * 0.4, 1.05, -1.38)), Vector3.ONE * 0.13, rng, 0.0, 2, 6)
		bmb.add_tube(skin, PackedVector3Array([Vector3(s * 0.15, 0.1, -1.3), Vector3(s * 0.6, 0.6, -2.2), Vector3(s * 1.1, 0.9, -3.0)]), 0.04, 0.01, 3, 1.0, pale)
	_body.add_child(bmb.to_instance("Mesh"))
	# the soft abdomen curling back (out of sight in the shell until the shell's gone)
	_abdomen = Node3D.new()
	_abdomen.name = "Abdomen"
	_body.add_child(_abdomen)
	var amb := MeshBuilder.new()
	amb.add_blob(flesh, Transform3D(Basis(Vector3.RIGHT, -0.4), Vector3(0, 0.25, 0.75)), Vector3(0.85, 0.75, 1.05), rng, 0.08, 3, 9, 0.8, soft)
	amb.add_blob(flesh, Transform3D(Basis(Vector3.RIGHT, -0.9), Vector3(0.1, 0.65, 1.55)), Vector3(0.6, 0.55, 0.6), rng, 0.08, 3, 8, 0.8, soft.darkened(0.08))
	_abdomen.add_child(amb.to_instance("Mesh"))
	# its house
	_shell_node = Node3D.new()
	_shell_node.name = "Shell"
	_shell_node.position = Vector3(0, -0.45, 0.55)
	_body.add_child(_shell_node)
	_shell_node.add_child(_shell_mesh(variant % 3, rng, 1.35).to_instance("Mesh"))
	# claws: the small one left, the great one right
	for s in [-1.0, 1.0]:
		var big: bool = s > 0.0
		var k := 1.6 if big else 1.0
		var claw := Node3D.new()
		claw.name = "ClawR" if big else "ClawL"
		claw.position = Vector3(s * 0.8, -0.15, -1.1)
		_body.add_child(claw)
		var cmb := MeshBuilder.new()
		Creature.seg(cmb, skin, Vector3.ZERO, Vector3(s * 0.6, 0.15, -0.6) * k, 0.3 * k, shell_c)
		cmb.add_blob(skin, Transform3D(Basis(), Vector3(s * 0.7, 0.2, -1.1) * k), Vector3(0.42, 0.36, 0.6) * k, rng, 0.05, 3, 7, 0.8, shell_c)
		var finger := PackedVector2Array([Vector2(-0.14, 0), Vector2(0.14, 0), Vector2(0.03, -0.9)])
		cmb.add_extrude(skin, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(s * 0.62, 0.38, -1.55) * k), finger, 0.24 * k, 0.8, pale)
		cmb.add_extrude(skin, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5 + 0.35), Vector3(s * 0.85, 0.0, -1.5) * k), finger, 0.2 * k, 0.8, pale.darkened(0.2))
		claw.add_child(cmb.to_instance("Mesh"))
		_claws.append([claw, s, big])
		for j in range(3):
			var leg := Node3D.new()
			leg.name = "Leg"
			leg.position = Vector3(s * 0.85, -0.15, -0.6 + j * 0.45)
			_body.add_child(leg)
			var lmb := MeshBuilder.new()
			Creature.seg(lmb, skin, Vector3.ZERO, Vector3(s * 0.9, 0.5, j * 0.2 - 0.25), 0.2, shell_c)
			Creature.seg(lmb, skin, Vector3(s * 0.9, 0.5, j * 0.2 - 0.25), Vector3(s * 1.5, -BODY_Y + 0.1, j * 0.35 - 0.45), 0.15, shell_c.darkened(0.15))
			leg.add_child(lmb.to_instance("Mesh"))
			_legs.append([leg, s, j])
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 1.4
	cap.height = 3.6
	col.shape = cap
	col.rotation = Vector3(PI * 0.5, 0, 0)
	col.position = Vector3(0, 1.4, 0)
	add_child(col)
	shell_hp = D.HERMIT_SHELL
	_last = global_position


## A shell of kind k (0 a spiral conch, 1 a coral boulder, 2 a wreck's bow), about 3 m long; its open mouth forward (-z).
static func _shell_mesh(k: int, rng: RandomNumberGenerator, s := 1.0) -> MeshBuilder:
	var mb := MeshBuilder.new()
	match k:
		0:
			var m := PSXMat.lit("atoll_coral", Color(1.15, 1.05, 0.95))
			for i in range(7):
				var t := float(i) / 6.0
				var r := lerpf(1.35, 0.25, t) * s
				var a := t * 4.2
				var c := Vector3(sin(a) * 0.35 * (1.0 - t), 0.25 + t * 1.6 + cos(a) * 0.3 * (1.0 - t), lerpf(0.0, 1.5, t)) * s
				mb.add_blob(m, Transform3D(Basis(Vector3.RIGHT, -0.5 - t), c), Vector3(r, r * 0.85, r * 1.1), rng, 0.06, 3, 8, 0.8, Color(1.0, 0.9, 0.82).lerp(Color(0.95, 0.6, 0.5), t * 0.6))
			for i in range(9):
				var t := rng.randf()
				mb.add_cone(m, Transform3D(Basis(Vector3.FORWARD, rng.randf_range(-0.6, 0.6)), Vector3(rng.randf_range(-0.6, 0.6), 0.6 + t * 1.6, t * 1.5) * s), 0.12 * s, 0.5 * s, 4, 0.8, Color(0.95, 0.85, 0.75))
		1:
			var m := PSXMat.lit("atoll_coral", Color(0.95, 0.9, 0.85))
			mb.add_blob(m, Transform3D(Basis(), Vector3(0, 0.75, 0.6) * s), Vector3(1.55, 1.25, 1.7) * s, rng, 0.25, 3, 8, 0.6, Color.WHITE, -0.1)
			for i in range(10):
				var a := rng.randf() * TAU
				var at := Vector3(cos(a) * 1.0, 1.4 + rng.randf() * 0.5, sin(a) * 1.0 + 0.6) * s
				mb.add_cylinder(m, Transform3D(Basis(Vector3.FORWARD, rng.randf_range(-0.4, 0.4)), at), 0.14 * s, 0.07 * s, rng.randf_range(0.4, 0.9) * s, 5, 0.8, [Color(1.0, 0.55, 0.55), Color(0.7, 0.5, 1.0), Color(1.0, 0.85, 0.4)][i % 3])
		2:
			var wood := PSXMat.lit("planks_weathered", Color(0.85, 0.8, 0.72))
			for i in range(6):
				var z := lerpf(-0.2, 2.2, i / 5.0) * s
				var w := lerpf(1.2, 0.5, i / 5.0) * s
				for sd in [-1.0, 1.0]:
					mb.add_box(wood, Transform3D(Basis(Vector3.FORWARD, sd * 0.35), Vector3(sd * w * 0.7, 0.9 * s, z)), Vector3(0.16 * s, 1.6 * s, 0.5 * s))
			mb.add_box(wood, Transform3D(Basis(Vector3.RIGHT, -0.1), Vector3(0, 1.75 * s, 1.0 * s)), Vector3(1.5 * s, 0.14 * s, 2.6 * s))
			var shell := PSXMat.lit("atoll_coral", Color(1.1, 1.0, 0.9))
			for i in range(12):
				mb.add_blob(shell, Transform3D(Basis(), Vector3(rng.randf_range(-0.9, 0.9), rng.randf_range(0.4, 1.8), rng.randf_range(0.0, 2.2)) * s), Vector3.ONE * 0.12 * s, rng, 0.2, 2, 5)
	return mb


# ==========================================================================
# Its spare shells on the flat
# ==========================================================================
func _ready() -> void:
	super._ready()
	_place_spares()


## Where its spares lie: round its post (the same on every screen: from the post and its yaw).
func spare_at(i: int) -> Vector3:
	var a := post_yaw + PI * 0.5 + TAU * i / SPARES
	return post + Vector3(cos(a), 0.0, sin(a)) * SPARE_R


func _place_spares() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7751 + variant
	for i in range(SPARES):
		var n := StaticBody3D.new()
		n.name = "%sSpare%d" % [name, i]
		n.collision_layer = 1
		n.collision_mask = 0
		var mi := _shell_mesh((variant + 1 + i) % 3, rng, 0.85).to_instance("Mesh")
		mi.visibility_range_end = 260.0
		n.add_child(mi)
		KitLandmarks.box_col(n, Vector3(2.4, 2.0, 2.6), Vector3(0, 1.0, 1.0))
		parent.add_child(n)
		n.global_position = spare_at(i) + Vector3.DOWN * 0.15
		n.rotation.y = rng.randf() * TAU
		_spare_nodes.append(n)


func _exit_tree() -> void:
	for n in _spare_nodes:
		if is_instance_valid(n):
			n.queue_free()


func _show_state() -> void:
	var s := spares_used * 10 + (1 if shell_on else 0) * 2 + (1 if hidden else 0)
	if s == _shown:
		return
	_shown = s
	_shell_node.visible = shell_on
	_abdomen.visible = not shell_on or hidden
	for i in range(_spare_nodes.size()):
		if is_instance_valid(_spare_nodes[i]):
			(_spare_nodes[i] as Node3D).visible = i >= spares_used
			((_spare_nodes[i] as StaticBody3D).get_child(1) as CollisionShape3D).disabled = i < spares_used
	for n in _body.get_children():
		if n != _shell_node and n != _abdomen:
			(n as Node3D).visible = not hidden


func _pack_extra() -> Array:
	return [shell_on, hidden, spares_used]


func _unpack_extra(a: Array, _b: Array, _f: float) -> void:
	if a.size() >= 3:
		shell_on = bool(a[0])
		hidden = bool(a[1])
		spares_used = int(a[2])
		hurtbox.monitorable = not hidden


# ==========================================================================
# Blows on it
# ==========================================================================
func _taken_k(_attacker: Node) -> float:
	return D.HERMIT_SHELL_K if shell_on else D.HERMIT_BODY_K


func _on_hit(hit: HitData, attacker: Node) -> void:
	if state == S.DEAD:
		return
	if hidden:
		Net.fx("sparkle", [_hit_point() + Vector3.UP * 0.8, 6, Color(1.0, 0.95, 0.85)])
		return
	var hp0 := health.current_health
	var on := shell_on
	if shell_on and not hit.dot:
		shell_hp -= hit.damage
		Net.fx("dust", [global_position + Vector3(0, BODY_Y + 1.2, 0.8), 4, 0.8])
	super._on_hit(hit, attacker)
	if state == S.DEAD:
		return
	if on and shell_hp <= 0.0:
		_crack()
	elif not on:
		_hurt_since += hp0 - health.current_health


## The shell cracks off: the soft body's bare.
func _crack() -> void:
	shell_on = false
	_hurt_since = 0.0
	var at := global_position + global_basis * Vector3(0, BODY_Y + 1.2, 0.9)
	BeastFX.part_break(at, Color(0.95, 0.88, 0.8))
	Net.fx("float_text", [at + Vector3.UP * 1.5, "Shell broken!", Color(1.0, 0.85, 0.4), 30])
	Net.fx("sfx", ["rock_crash", at, 4.0, 0.1, 0.8])
	say("hiss", global_position, 6.0, 0.7)
	if state == S.FIGHT and move != "moment":
		end_move()
		stagger(1.8)


## Hurt enough bare, and a spare shell left to run to.
func _want_hide() -> bool:
	return not shell_on and spares_used < SPARES and _hurt_since >= D.HERMIT_HIDE_AT * health.max_health


# ==========================================================================
# Its brain: the table's moves, and running for a new shell
# ==========================================================================
func _brain(delta: float, p: Node3D, to: Vector3, dist: float) -> Vector3:
	if _want_hide():
		begin("scuttle")
		return Vector3.ZERO
	return super._brain(delta, p, to, dist)


func _on_begin(m: String) -> void:
	match m:
		"scuttle":
			_goal = spares_used
			say("hiss", global_position, 4.0, 1.3)
		"hide":
			# (backed into the spare: where it lay)
			var at := spare_at(spares_used)
			global_position = Vector3(at.x, global_position.y, at.z)
			reset_physics_interpolation()
			_set_hidden(true)
			spares_used += 1
			shells += 1
			shell_on = true
			shell_hp = D.HERMIT_SHELL * pow(0.8, shells)
			_hurt_since = 0.0
			health.current_health = minf(health.current_health + health.max_health * 0.04, health.max_health)
			Net.fx("dust", [global_position + Vector3.UP * 0.5, 14, 1.4])
			Net.fx("sfx", ["thud", global_position, 2.0, 0.1, 0.6])
		_:
			super._on_begin(m)


func _move_tick(delta: float, p: Node3D) -> Vector3:
	match move:
		"scuttle":
			var goal := spare_at(_goal)
			var to := _flat(goal - global_position)
			if to.length() < 4.6 or mv_t > 8.0:
				end_move()
				begin("hide")
				return Vector3.ZERO
			if fmod(mv_t, 0.2) < delta:
				Net.fx("dust", [global_position, 3, 0.8])
			# (straight across its open flat: the spares lie in the clear)
			var nd := to.normalized()
			_face(nd)
			return nd * SCUTTLE_SPEED
		"hide":
			if mv_t < D.HERMIT_HIDE_S:
				return Vector3.ZERO
			_set_hidden(false)
			warn_ring(global_position, 4.6, 0.01)
			strike("ring", [global_position, 4.6], 14.0, false, false, 1.1, 11.0)
			quake(global_position, 0.8)
			end_move(0.6)
			return Vector3.ZERO
	return super._move_tick(delta, p)


func _set_hidden(on: bool) -> void:
	hidden = on
	hurtbox.set_deferred("monitorable", not on)


func _armoured() -> bool:
	return move in ["hide", "scuttle"] or super._armoured()


func end_move(recover: float = 0.0) -> void:
	if hidden and move == "hide":
		_set_hidden(false)
	super.end_move(recover)


func reset_fight() -> void:
	super.reset_fight()
	shell_on = true
	shell_hp = D.HERMIT_SHELL
	shells = 0
	spares_used = 0
	_hurt_since = 0.0
	_set_hidden(false)


func _table() -> Dictionary:
	var sea := Color(0.55, 0.85, 0.95)
	# (the big ones first: the pick takes the first ready, and in a chain the small ones are always ready)
	return {
		"spin": {"phase": 3, "max": 5.5, "cd": [8.0, 10.0], "tell": 0.9, "shape": "ring", "r": 5.2, "dmg": 22.0, "kb": 10.0, "rec": 1.2, "hits": 2, "every": 0.45,
			"fx": "dust", "say": ["hiss", 0.6], "armour": true},
		"charge": {"phase": 2, "min": 6.0, "max": 20.0, "cd": [7.0, 9.0], "tell": 0.9, "shape": "charge", "len": 16.0, "w": 2.0, "speed": 13.0, "dmg": 28.0, "knock": true,
			"rec": 1.5, "say": ["click", 0.7]},
		"sweep": {"phase": 2, "max": 5.5, "cd": [4.0, 6.0], "tell": 0.6, "shape": "cone", "r": 5.6, "deg": 75.0, "dmg": 20.0, "kb": 9.0, "rec": 0.9},
		"crush": {"max": 6.0, "cd": [3.5, 5.0], "tell": 0.8, "shape": "ring", "at": 3.4, "r": 2.6, "dmg": 26.0, "kb": 6.0, "rec": 1.0, "fx": "quake"},
		"spit": {"min": 5.0, "max": 15.0, "cd": [5.0, 7.0], "tell": 0.7, "shape": "lane", "len": 15.0, "w": 1.1, "dmg": 14.0, "kb": 5.0, "rec": 0.8,
			"fx": "sparkle", "col": sea, "say": ["hiss", 1.1]},
		"pinch": {"max": 4.6, "cd": [1.6, 2.4], "tell": 0.5, "shape": "cone", "r": 4.4, "deg": 50.0, "dmg": 18.0, "kb": 6.0, "parry": true, "rec": 0.6,
			"say": ["click", 1.1]},
	}


func _wake_move() -> String:
	return "crush"


func _on_table_hit(m: String, _e: Dictionary, at: Vector3) -> void:
	if m == "spit":
		Net.fx("splash", [at, 10, 1.2])
	elif m == "crush":
		Net.fx("sfx", ["rock_crash", at, 3.0, 0.1, 0.7])


# ==========================================================================
# Its animation (host and puppets read the same state)
# ==========================================================================
func _animate(delta: float) -> void:
	_show_state()
	_t_anim += delta
	var moved := _flat(global_position - _last)
	_last = global_position
	_spd = lerpf(_spd, moved.length() / maxf(delta, 0.001), minf(delta * 8.0, 1.0))
	var moving := clampf(_spd / 2.0, 0.0, 1.0)
	_gait += delta * _spd * 1.4
	var e: Dictionary = _tbl().get(move, {})
	var tell := float(e.get("tell", 0.6))
	var wind := move != "" and mv_t < tell
	for c in _claws:
		var node: Node3D = c[0]
		var s: float = c[1]
		var big: bool = c[2]
		var rx := 0.0
		var ry := -s * (0.2 + sin(_t_anim * 1.4 + s) * 0.05)
		match move:
			"pinch":
				if not big:
					ry = -s * (0.7 if wind else -0.1)
			"crush":
				if big:
					rx = 1.2 if wind else -0.35
			"sweep":
				if big:
					ry = (-0.9 if wind else 1.0)
			"spin":
				ry = -s * 1.2
		node.rotation = Vector3(lerp_angle(node.rotation.x, rx, minf(delta * 14.0, 1.0)), lerp_angle(node.rotation.y, ry, minf(delta * 14.0, 1.0)), 0)
	for l in _legs:
		var s: float = l[1]
		var ph := _gait + float(l[2]) * 1.6 + (PI if s > 0.0 else 0.0)
		(l[0] as Node3D).rotation = Vector3(cos(ph) * 0.2 * moving, sin(ph) * 0.3 * moving, 0)
	var low := 0.0
	if hidden:
		low = -0.75
	elif state == S.DEAD:
		low = -0.6
	_body.position.y = lerpf(_body.position.y, BODY_Y + low + absf(sin(_gait * 2.0)) * 0.05 * moving, minf(delta * 10.0, 1.0))
	if move == "spin" and not wind:
		model.rotation.y += delta * 9.0
	if move == "spit" and wind:
		_body.rotation.x = lerp_angle(_body.rotation.x, -0.2, minf(delta * 8.0, 1.0))
	else:
		_body.rotation.x = lerp_angle(_body.rotation.x, 0.0, minf(delta * 8.0, 1.0))
