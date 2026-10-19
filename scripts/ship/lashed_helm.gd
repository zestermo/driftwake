class_name LashedHelm
extends RefCounted
## The lashed helm (sailing downtime): the helmsman sets a course and lashes the wheel (the action wheel at the
## helm), and she holds that heading with nobody steering, even solo: the lashing works the rudder back onto the
## course after a wave, a shore she slid along or a whirlpool's drag. It isn't an autopilot through danger: she
## keeps the heading into whatever lies on it, and a storm parts the lashing. Taking the wheel casts it off.
## Co-op: the lash is everyone's (Net.lash_helm), and whoever owns the ship (the host while nobody steers)
## runs the rudder from it in Ship._read_helm.

## Rudder per radian off the course, damping per rad/s of turn, and how hard the rope can put the helm over.
const GAIN := 3.0
const DAMP := 2.5
const MAX_RUDDER := 0.6
## Weather.storm above this parts the lashing.
const STORM := 0.55


## The rudder the lashing holds this tick (Ship._read_helm, on the ship's owner).
static func turn(ship) -> float:
	var err := wrapf(float(ship.lash_heading) - float(ship._heading), -PI, PI)
	return clampf(-(err * GAIN - float(ship._yaw_rate) * DAMP), -MAX_RUDDER, MAX_RUDDER)


## The owner's watch over the lash: a storm parts it.
static func watch(ship) -> void:
	if ship.get_node("/root/Weather").storm > STORM:
		Net.lash_helm(false, 0.0, "The lashing's parted in the blow - someone take the helm!")


## Lash (on) to `heading` or cast off, on this screen (Net._all_lash).
static func apply(ship, on: bool, heading: float) -> void:
	ship.lashed = on
	ship.lash_heading = heading
	var rope: Node3D = ship.ship_model.get_node_or_null("HelmLashing")
	if on and rope == null:
		rope = _rope()
		ship.ship_model.add_child(rope)
	if rope:
		rope.visible = on
	FX.sfx("rope", ship.global_transform * Vector3(0, HullBuilder.QD_Y + 0.8, HullBuilder.WHEEL_Z), -6.0, 0.05, 1.1 if on else 0.85)


## Two turns of line from the wheel's rim to the foot of its post, and a coil hitched round the post.
static func _rope() -> Node3D:
	var mb := MeshBuilder.new()
	var mat := PSXMat.lit("rope", Color(0.95, 0.88, 0.7))
	var hub := Vector3(0, HullBuilder.QD_Y + 0.93, HullBuilder.WHEEL_Z - 0.04)
	var foot := Vector3(0, HullBuilder.QD_Y + 0.28, HullBuilder.WHEEL_Z + 0.1)
	for s in [-1.0, 1.0]:
		var rim := hub + Vector3(s * 0.3, -0.3, 0)
		mb.add_tube(mat, MeshBuilder.curve_points(rim, (rim + foot) * 0.5 + Vector3(s * 0.12, -0.05, -0.08), foot + Vector3(s * 0.09, 0, 0), 4), 0.018, 0.018, 4, 1.0)
	var ring := PackedVector3Array()
	for i in range(9):
		var a := TAU * i / 8.0
		ring.append(foot + Vector3(cos(a) * 0.12, sin(a * 2.0) * 0.015, sin(a) * 0.12))
	mb.add_tube(mat, ring, 0.022, 0.022, 4, 1.0)
	var mi := mb.to_instance("HelmLashing")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 60.0
	return mi
