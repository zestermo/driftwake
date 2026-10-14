class_name DrawMoves
## Drawing and putting away, each weapon kind its own way and with its own sound (played here
## from the pose, so every screen that plays the action hears it once):
## katana from the left-hip scabbard (a ring out, a chiburi flick, the click home), cutlass and
## other blades cross-drawn from the hip with a flourish, an axe pulled off the back over the right
## shoulder, a two-hander heaved over the shoulder in both hands, daggers snapped out of the hip
## (the off hand's from the other hip, reversed), pistols drawn and cocked, holstered with a spin.

## Axe designs carried and drawn as two-handers.
const GREAT := ["war"]
## Where the axe's grip rides on the back (torso space, from the neck's height) and the way its
## head hangs: grip by the right shoulder blade, the head down by the left hip.
const BACK_AT := Vector3(0.12, 0.8, 0.17)
const BACK_DIR := Vector3(-0.45, -0.89, 0.0)

const SOUND := {"katana": ["draw_katana", "sheathe_katana"], "blade": ["draw_blade", "sheathe_blade"], "axe": ["draw_axe", "sheathe_axe"],
	"great": ["draw_great", "sheathe_great"], "dagger": ["draw_dagger", "sheathe_dagger"], "pistol": ["draw_pistol", "holster"]}


## The draw style for the body's weapon: katana, blade, axe, great, dagger or pistol.
static func kind(h) -> String:
	var model: String = str(h.weapon.mesh.get_meta("model", "")) if h.weapon != null and is_instance_valid(h.weapon) and h.weapon.mesh != null else ""
	var k := model.get_slice(":", 0)
	if k == "axe" and model.get_slice(":", 1) in GREAT:
		return "great"
	if k in ["katana", "axe", "dagger", "pistol"]:
		return k
	return "blade"


## An axe in the back socket: a two-hander rides higher (the haft's end up over the shoulder) with
## its head turned flat across the back, so the long head clears the legs.
static func on_back(w: MeshInstance3D) -> Transform3D:
	if str(w.mesh.get_meta("model", "")).get_slice(":", 1) in GREAT:
		return Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(0, 0, 0.28))
	return Transform3D.IDENTITY


## The socket on the back an axe hangs from (made on demand).
static func back_socket(h) -> Node3D:
	var s: Node3D = h.torso.get_node_or_null("BackSocket")
	if s == null:
		s = Node3D.new()
		s.name = "BackSocket"
		h.torso.add_child(s)
		s.position = Vector3(BACK_AT.x, h.neck.position.y * BACK_AT.y, BACK_AT.z)
		s.basis = Basis.looking_at(BACK_DIR.normalized(), Vector3(0, 0, 1))
	return s


static func pose(h, n: String, u: float) -> Array:
	var k := kind(h)
	return _draw(h, k, u) if n == "draw" else _sheathe(h, k, u)


## Once per action at `at` (u): the weapon into the hand (true) or put away, and/or a sound.
static func _event(h, u: float, at: float, ev: String, attach: int = -1, sound: String = "") -> void:
	if u < at or h._action["events"].has(ev):
		return
	h._action["events"][ev] = true
	if attach >= 0:
		h._attach_weapon(attach == 1)
	var fx = h.get_node_or_null("/root/FX")
	if sound != "" and fx != null:
		fx.sfx(sound, h.global_position + Vector3(0, 1.0, 0), -5.0, 0.05)


## The off hand's mirror of a right-arm key (dual wielding: it draws from the other hip).
static func _off(p: Dictionary) -> Dictionary:
	var out := {}
	for j in ["arm_r", "fore_r"]:
		if p.has(j):
			var v: Vector3 = p[j]
			out[j.replace("_r", "_l")] = Vector3(v.x, -v.y, -v.z)
	return out


static func _draw(h, k: String, u: float) -> Array:
	var g: Dictionary = h._guard()
	var dual: bool = h.offhand != null and is_instance_valid(h.offhand)
	var keys: Array
	match k:
		"katana":
			# right hand on the hilt by the left hip, the left thumb on the guard; then the
			# blade comes out in one flat cut across to the right (the ring hangs), into the guard
			var grip := {"arm_r": Vector3(0.5, 0.05, -0.7), "fore_r": Vector3(1.5, 0, 0), "hand_r": Vector3.ZERO,
				"arm_l": Vector3(0.25, -0.2, -0.15), "fore_l": Vector3(1.0, 0, 0), "torso": Vector3(-0.18, 0.35, 0), "head": Vector3(0.12, -0.3, 0)}
			var out := {"arm_r": Vector3(1.45, -0.45, 0.6), "fore_r": Vector3(0.08, 0, 0), "hand_r": Vector3(-1.25, 0, 0),
				"arm_l": Vector3(-0.35, 0, -0.35), "fore_l": Vector3(0.5, 0, 0), "torso": Vector3(-0.25, -0.35, 0), "head": Vector3(0.2, 0.3, 0)}
			_event(h, u, 0.28, "hand", 1, SOUND[k][0])
			keys = [[0.0, {}], [0.25, grip, "out"], [0.5, out, "out"], [0.7, out], [1.0, g]]
		"axe", "great":
			# a hand (both for a two-hander) up over the right shoulder for the haft, then the
			# head pulled up and over and brought down into the guard
			var reach := {"arm_r": Vector3(2.75, 0.2, 0.45), "fore_r": Vector3(2.0, 0, 0), "hand_r": Vector3(0.3, 0, 0),
				"arm_l": Vector3(0.4, 0, -0.45), "fore_l": Vector3(0.8, 0, 0), "torso": Vector3(0.05, -0.25, 0), "head": Vector3(0.0, 0.2, 0)}
			var over := {"arm_r": Vector3(2.3, -0.1, 0.3), "fore_r": Vector3(0.6, 0, 0), "hand_r": Vector3(0.5, 0, 0),
				"arm_l": Vector3(0.5, 0, -0.5), "fore_l": Vector3(0.9, 0, 0), "torso": Vector3(0.08, 0.1, 0), "head": Vector3(0.05, -0.05, 0)}
			if k == "great":
				reach.merge({"arm_l": Vector3(2.5, -0.55, 0.1), "fore_l": Vector3(2.0, 0, 0), "torso": Vector3(0.05, -0.35, 0)}, true)
				over.merge({"arm_r": Vector3(2.4, -0.15, 0.2), "fore_r": Vector3(0.9, 0, 0), "hand_r": Vector3(0.6, 0, 0),
					"arm_l": Vector3(2.3, 0.3, -0.1), "fore_l": Vector3(1.0, 0, 0), "_lift": Vector3(0, -0.06, 0)}, true)
			_event(h, u, 0.3, "hand", 1, SOUND[k][0])
			keys = [[0.0, {}], [0.28, reach, "out"], [0.55, over, "out"], [0.68, over], [1.0, g, "in"]]
		"dagger":
			# a quick cross-draw from the hip (both at once with two: arms crossed, the off hand
			# to the other hip), snapped out ahead
			var grip := {"arm_r": Vector3(0.42, 0.1, -0.6), "fore_r": Vector3(1.55, 0, 0), "hand_r": Vector3(0.4, 0, 0), "torso": Vector3(-0.1, 0.3, 0), "head": Vector3(0.05, -0.25, 0)}
			var snap := {"arm_r": Vector3(1.25, -0.35, 0.45), "fore_r": Vector3(0.35, 0, 0), "hand_r": Vector3(-1.1, 0, 0), "torso": Vector3(-0.08, -0.12, 0), "head": Vector3(0.05, 0.1, 0)}
			if dual:
				grip.merge(_off(grip).merged({"torso": Vector3(-0.15, 0, 0), "head": Vector3(0.1, 0, 0)}, true), true)
				snap.merge(_off(snap).merged({"hand_l": Vector3(-1.5, 0, 0), "torso": Vector3(-0.08, 0, 0), "head": Vector3(0.05, 0, 0)}, true), true)
			_event(h, u, 0.27, "hand", 1, SOUND[k][0])
			keys = [[0.0, {}], [0.25, grip, "out"], [0.45, snap, "out"], [0.62, snap], [1.0, g]]
		_:
			# blades and pistols: a cross-draw from the left hip; a blade sweeps out high to the
			# right in a flourish, a pistol comes up and is cocked at the aim
			var grip := {"arm_r": Vector3(0.5, 0.05, -0.72), "fore_r": Vector3(1.4, 0, 0), "hand_r": Vector3(0.3, 0, 0),
				"arm_l": Vector3(0.15, 0.1, -0.2), "fore_l": Vector3(0.7, 0, 0), "torso": Vector3(-0.12, 0.42, 0), "head": Vector3(0.05, -0.35, 0)}
			var out := {"arm_r": Vector3(1.55, -0.35, 0.75), "fore_r": Vector3(0.25, 0, 0), "hand_r": Vector3(-0.9, 0, 0),
				"arm_l": Vector3(0.4, 0, -0.6), "fore_l": Vector3(0.6, 0, 0), "torso": Vector3(-0.05, -0.2, 0), "head": Vector3(0.0, 0.15, 0)}
			if k == "pistol":
				out = {"arm_r": (g["arm_r"] as Vector3) + Vector3(0.35, 0, 0), "fore_r": g["fore_r"], "torso": g.get("torso", Vector3.ZERO), "head": g.get("head", Vector3.ZERO)}
			if dual:
				grip.merge(_off(grip).merged({"torso": Vector3(-0.15, 0, 0), "head": Vector3(0.1, 0, 0)}, true), true)
				if k == "pistol":
					out.merge({"arm_l": (g["arm_l"] as Vector3) + Vector3(0.35, 0, 0), "fore_l": g["fore_l"]}, true)
				else:
					out.merge(_off(out), true)
			_event(h, u, 0.3, "hand", 1, SOUND["pistol" if k == "pistol" else "blade"][0])
			keys = [[0.0, {}], [0.28, grip, "out"], [0.55, out, "out"], [0.68, out], [1.0, g]]
	return [h._keys(u, _guns_free(h, k, keys)), "upper", Vector3.ZERO]


static func _sheathe(h, k: String, u: float) -> Array:
	var g: Dictionary = h._guard()
	var rest: Dictionary = h.REST_ARMS
	var dual: bool = h.offhand != null and is_instance_valid(h.offhand)
	var keys: Array
	match k:
		"katana":
			# chiburi (the blood flicked off), the blade laid across to the scabbard's mouth, slid
			# home on the click, a beat on the hilt
			var flick := {"arm_r": Vector3(1.0, -0.25, 1.0), "fore_r": Vector3(0.1, 0, 0), "hand_r": Vector3(-1.35, 0, 0), "torso": Vector3(-0.15, -0.3, 0), "head": Vector3(0.1, 0.25, 0)}
			var mouth := {"arm_r": Vector3(0.95, 0.55, -0.35), "fore_r": Vector3(1.25, 0, 0), "hand_r": Vector3(0.15, 0, 0),
				"arm_l": Vector3(0.3, -0.25, -0.15), "fore_l": Vector3(1.0, 0, 0), "torso": Vector3(-0.12, 0.3, 0), "head": Vector3(0.1, -0.25, 0)}
			var home := mouth.merged({"arm_r": Vector3(0.5, 0.05, -0.7), "fore_r": Vector3(1.5, 0, 0), "hand_r": Vector3.ZERO}, true)
			_event(h, u, 0.45, "slide", -1, SOUND[k][1])
			_event(h, u, 0.8, "hip", 0)
			keys = [[0.0, g], [0.22, flick, "out"], [0.45, mouth], [0.8, home, "in"], [0.9, home], [1.0, rest]]
		"axe", "great":
			# raised, then swung back over the right shoulder onto the back
			var up := {"arm_r": Vector3(2.3, -0.1, 0.3), "fore_r": Vector3(0.6, 0, 0), "hand_r": Vector3(0.6, 0, 0), "torso": Vector3(0.05, 0.1, 0)}
			var back := {"arm_r": Vector3(2.75, 0.2, 0.45), "fore_r": Vector3(2.0, 0, 0), "hand_r": Vector3(0.3, 0, 0), "torso": Vector3(0.05, -0.25, 0), "head": Vector3(0.0, 0.2, 0)}
			if k == "great":
				up.merge({"arm_l": Vector3(2.3, 0.3, -0.1), "fore_l": Vector3(1.0, 0, 0)}, true)
				back.merge({"arm_l": Vector3(2.5, -0.55, 0.1), "fore_l": Vector3(2.0, 0, 0), "torso": Vector3(0.05, -0.35, 0)}, true)
			_event(h, u, 0.2 if k == "axe" else 0.12, "swing", -1, SOUND[k][1])
			_event(h, u, 0.66, "hip", 0)
			keys = [[0.0, g], [0.3, up, "out"], [0.62, back, "out"], [0.72, back], [1.0, rest]]
		"dagger":
			# a flip of the wrist (the blade turned over in the fingers), then home to the hip
			var twirl := {"arm_r": Vector3(0.9, -0.2, 0.35), "fore_r": Vector3(0.9, 0, 0), "hand_r": Vector3(1.4, 0, 0), "torso": Vector3(-0.05, -0.1, 0)}
			var hip := {"arm_r": Vector3(0.42, 0.1, -0.6), "fore_r": Vector3(1.55, 0, 0), "hand_r": Vector3(0.6, 0, 0), "torso": Vector3(-0.1, 0.3, 0), "head": Vector3(0.05, -0.25, 0)}
			if dual:
				twirl.merge(_off(twirl), true)
				hip.merge(_off(hip).merged({"torso": Vector3(-0.15, 0, 0), "head": Vector3(0.1, 0, 0)}, true), true)
			_event(h, u, 0.6, "hip", 0, SOUND[k][1])
			keys = [[0.0, g], [0.15, twirl.merged({"hand_r": Vector3(-1.4, 0, 0)}, true), "out"], [0.38, twirl, "out"], [0.6, hip], [0.72, hip], [1.0, rest]]
		"pistol":
			# the gun out low to the side, spun twice on the finger, dropped into the holster
			var low := {"arm_r": Vector3(0.45, -0.1, 0.55), "fore_r": Vector3(0.7, 0, 0), "torso": Vector3(0.0, -0.1, 0)}
			var hip := {"arm_r": Vector3(0.5, 0.05, -0.72), "fore_r": Vector3(1.4, 0, 0), "torso": Vector3(-0.12, 0.42, 0), "head": Vector3(0.05, -0.35, 0)}
			if dual:
				low.merge(_off(low).merged({"torso": Vector3.ZERO}, true), true)
				hip.merge(_off(hip).merged({"torso": Vector3(-0.15, 0, 0), "head": Vector3(0.1, 0, 0)}, true), true)
			_spin(h, u)
			_event(h, u, 0.12, "spin", -1, "gun_spin")
			_event(h, u, 0.68, "hip", 0, SOUND[k][1])
			keys = [[0.0, g], [0.15, low, "out"], [0.55, low], [0.68, hip, "out"], [0.8, hip], [1.0, rest]]
		_:
			# a flick of the blade, then the point guided back down into the hip scabbard
			var flick := {"arm_r": Vector3(1.2, -0.4, 0.95), "fore_r": Vector3(0.15, 0, 0), "hand_r": Vector3(-1.3, 0, 0), "torso": Vector3(-0.1, -0.25, 0), "head": Vector3(0.05, 0.2, 0)}
			var hip := {"arm_r": Vector3(0.5, 0.05, -0.72), "fore_r": Vector3(1.4, 0, 0), "hand_r": Vector3(1.2, 0, 0),
				"arm_l": Vector3(0.15, 0.1, -0.2), "fore_l": Vector3(0.7, 0, 0), "torso": Vector3(-0.12, 0.42, 0), "head": Vector3(0.05, -0.35, 0)}
			if dual:
				flick.merge(_off(flick), true)
				hip.merge(_off(hip).merged({"torso": Vector3(-0.15, 0, 0), "head": Vector3(0.1, 0, 0)}, true), true)
			_event(h, u, 0.55, "slide", -1, SOUND[k][1])
			_event(h, u, 0.64, "hip", 0)
			keys = [[0.0, g], [0.3, flick, "out"], [0.62, hip], [0.72, hip], [1.0, rest]]
	return [h._keys(u, _guns_free(h, k, keys)), "upper", Vector3.ZERO]


## Pistols sit in a fixed grip: their wrists aren't keyed.
static func _guns_free(_h, k: String, keys: Array) -> Array:
	if k != "pistol":
		return keys
	for key in keys:
		var d: Dictionary = (key[1] as Dictionary).duplicate()
		d.erase("hand_r")
		d.erase("hand_l")
		key[1] = d
	return keys


## The holster spin: two turns round the trigger guard (Humanoid.point_guns stands aside while
## sheathing); back in the grip once it's done.
static func _spin(h, u: float) -> void:
	var a := -TAU * 2.0 * Humanoid._ease((u - 0.12) / 0.45)
	for w in [h.weapon, h.offhand]:
		if w != null and is_instance_valid(w) and (w as Node3D).get_parent() in [h.hand_r, h.hand_l]:
			(w as Node3D).basis = Basis(Vector3.RIGHT, a) * Humanoid.GUN_GRIP
