extends Node3D
## The volcanic isle's lava burns (VolcanicLand._lava): five times a second, the local captain standing in hot lava on
## this island (a flow's hot stretch or the caldera's crescent) takes a burn and is thrown out of it, up and away from
## the flow, then a moment's grace. Each machine burns only its own captain (the lava isn't a host event); the embers
## and the hiss go to every screen. Asleep while the captain is off the island (one distance check).

const DAMAGE := 15.0
const THROW := 7.0
const LIFT := 9.0
const GRACE := 0.8
const TICK := 0.2

var isl
var _t := 0.0
var _grace := 0.0
const LAND := preload("res://scripts/island/themes/volcanic_land.gd")


func _physics_process(delta: float) -> void:
	_grace = maxf(_grace - delta, 0.0)
	_t += delta
	if _t < TICK:
		return
	_t = 0.0
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null or not p.is_local or _grace > 0.0:
		return
	var lpos: Vector3 = isl.to_local(p.global_position)
	var q := Vector2(lpos.x, lpos.z)
	if q.length() > float(isl.radius):
		return
	if not LAND.burning(isl, q, lpos.y):
		return
	burn(p, q)


func burn(p: Player, q: Vector2) -> void:
	_grace = GRACE
	p.health_component.take_damage(DAMAGE)
	var away := _away(q)
	var out: Vector3 = isl.global_transform.basis * Vector3(away.x, 0, away.y)
	p.velocity = out.normalized() * THROW + Vector3.UP * LIFT
	Net.fx("embers", [p.global_position, Vector3.UP, 14])
	Net.fx("sfx", ["fire_burst", p.global_position, -4.0, 0.1])


## The way out of the lava from q: off the flow's middle line sideways (the nearer edge), out of the crescent toward
## the caldera's middle.
func _away(q: Vector2) -> Vector2:
	var lp: Dictionary = isl.land_plan
	if LAND.in_crescent(isl, q):
		return (lp["cone"]["c"] as Vector2) - q
	var near: Array = LAND.flow_near(lp, q)
	var pts: PackedVector2Array = lp["flows"][int(near[1])]["pts"]
	var best := Vector2.ZERO
	var bd := INF
	for j in range(pts.size() - 1):
		var a := pts[j]
		var ab := pts[j + 1] - a
		var t := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var on := a + ab * t
		if q.distance_to(on) < bd:
			bd = q.distance_to(on)
			best = q - on if q.distance_to(on) > 0.05 else ab.orthogonal()
	return best
