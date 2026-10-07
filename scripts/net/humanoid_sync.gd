class_name HumanoidSync
extends RefCounted
## Co-op: the continuous half of a Humanoid's animation state, packed into
## snapshots by whoever simulates the body and applied (interpolated) on the
## other players' copies. One-shot actions and ragdolls travel as events
## instead (Humanoid.net_event).

const FIELDS := ["ground_speed", "local_move", "grounded", "vertical_speed", "armed", "sprinting",
	"stance", "seated", "seat_y", "at_helm", "helm_steer", "swimming", "carry", "aim_pitch", "diving",
	"climbing", "climb_phase", "climb_hold", "dash_dir", "look_target", "look_weight", "dangle", "talking", "kneeling", "manning"]
## Fields blended between snapshots (the rest snap to the newer one).
const BLEND := ["ground_speed", "vertical_speed", "helm_steer", "aim_pitch", "look_target", "look_weight", "seat_y"]


static func model_of(mi: Node) -> String:
	if mi == null or not is_instance_valid(mi) or not (mi is MeshInstance3D):
		return ""
	var m: Mesh = (mi as MeshInstance3D).mesh
	return str(m.get_meta("model", "")) if m else ""


static func mesh_for(model: String) -> Mesh:
	if model == "":
		return null
	if model == "bottle":
		return Props.bottle_mesh()
	if model.begins_with("devil_fruit"):
		return Props.devil_fruit_mesh(model)
	return Props.weapon_mesh(model)


static func pack(h: Humanoid) -> Array:
	var a: Array = []
	for f in FIELDS:
		a.append(h.get(f))
	a.append(model_of(h.weapon))
	a.append(model_of(h.offhand))
	a.append(h.weapon_in_hand)
	a.append(model_of(h._left_prop))
	return a


## Apply snapshot `b` (blending from `a` by `f`). Gear changes are applied
## when the snapshots change (not compared with the body), so the body's own
## draw/sheathe animations aren't fought every frame.
static func apply(h: Humanoid, a: Array, b: Array, f: float) -> void:
	var n := FIELDS.size()
	if b.size() < n + 4 or a.size() < n + 4:
		return
	for i in range(n):
		var key: String = FIELDS[i]
		var v = b[i]
		if key in BLEND and typeof(a[i]) == typeof(b[i]):
			v = lerp(a[i], b[i], f)
		h.set(key, v)
	var w := str(b[n])
	if w != str(h.get_meta("net_w", "~")):
		h.set_meta("net_w", w)
		h.set_weapon(mesh_for(w))
	var o := str(b[n + 1])
	if o != str(h.get_meta("net_o", "~")):
		h.set_meta("net_o", o)
		h.set_offhand(mesh_for(o))
	var ih := bool(b[n + 2])
	if not h.has_meta("net_ih") or bool(h.get_meta("net_ih")) != ih:
		h.set_meta("net_ih", ih)
		h._attach_weapon(ih)
	var lp := str(b[n + 3])
	if lp != str(h.get_meta("net_lp", "")):
		h.set_meta("net_lp", lp)
		if lp == "":
			h.hide_left_prop()
		else:
			h.show_left_prop(mesh_for(lp))
