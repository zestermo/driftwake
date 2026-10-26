extends RefCounted
## Shared by the t/player/chains_* tests: bodies in the wardrobe's chains with their animators off, driven by one fixed
## script (running, sharp turns, hops, legs kicking back into the drapes, a leaning torso), their chains simulated at
## uneven frame times.
const DELTAS := [1.0 / 144.0, 1.0 / 60.0, 1.0 / 30.0, 1.0 / 90.0, 0.05, 1.0 / 60.0]
const FRAMES := 420


## A cloak over a long coat with long flowing hair, a scarf and a sash; a cape with a ponytail over a skirt.
static func looks() -> Array:
	var out: Array = []
	for o in [{"cloak": true, "coat": "longcoat", "hair": "cascade", "body": "fem", "scarf": true, "belt": "sash"},
			{"cape": true, "hair": "ponytail", "legs": "skirt"}]:
		var lk: Dictionary = CharacterLook.base_look()
		lk.merge(o, true)
		out.append(lk)
	return out


static func body(root: Node, lk: Dictionary, native: bool):
	var h = Humanoid.new()
	h.setup(lk)
	root.add_child(h)
	h.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	h.set_process(false)
	h.set_physics_process(false)
	h.position = Vector3(0, 3.0, 0)
	for s in h._sims:
		s.native = native
	return h


## Poses body `h` for frame `i` and steps its chains; returns the frame time used.
static func drive(h, i: int, yaw: float) -> float:
	var dt: float = DELTAS[i % DELTAS.size()]
	var t := i / 60.0
	var v := 9.0 * clampf(sin(t * 0.7) * 2.0, 0.0, 1.0)
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	h.position += fwd * v * dt
	h.position.y = 3.0 + maxf(0.0, sin(t * 2.3)) * 0.8
	h.rotation.y = yaw
	var kick := 1.1 * sin(t * 9.0)
	h.leg_l.rotation.x = kick
	h.leg_r.rotation.x = -kick
	h.shin_l.rotation.x = -0.6 * (1.0 + sin(t * 9.0 + 1.0))
	h.shin_r.rotation.x = -0.6 * (1.0 + sin(t * 9.0 + 4.0))
	h.torso.rotation.x = -0.3 * sin(t * 1.3)
	for s in h._sims:
		s.simulate(dt)
	return dt


static func yaw_at(i: int) -> float:
	var t := i / 60.0
	return 1.6 * sin(t * 0.9) + (PI if int(t / 2.5) % 2 == 1 else 0.0)
