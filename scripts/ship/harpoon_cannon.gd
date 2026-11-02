class_name HarpoonCannon
extends Node3D
## The harpoon cannon (1.28, a ship gadget: ShipGadgets): a barbed harpoon on a line shot from the bow at a ship or sea
## beast ahead; it bites (the tier's damage), then for the tier's hold the target is reeled toward the ship at its reel
## speed (stopping REEL_CLOSE m off), and the line's let go. Every machine shows its own line; only the host's hurts
## and reels (the host simulates foes).
## CONTRACT (for the leviathans and any other harpoonable thing; docs/gadgets_plan.md "Harpoon contract"):
##   HarpoonCannon.harpoon(ship: Node3D, target: Node3D, tier := 0, by: Node = null) -> bool
##       tether `target` to `ship` (false: no target / dead). Call it on every machine (ShipGadgets does).
##   A target is anything in group "enemy_ships", "sea_kings" or "harpoonable" with a `hurtbox` (Hurtbox) property;
##   on the host it may have:
##     harpooned(ship)                 the harpoon bit (once)
##     reel_toward(at, speed, delta)   pull yourself toward `at` (else its global_position is moved)
##     released()                      the line's let go (hold over, ship or target gone)
##     is_dead() -> bool               a dead one is let go
##   and every HarpoonCannon emits `released` (on every machine) when its line goes.

signal released

const GROUPS := ["enemy_ships", "sea_kings", "harpoonable"]
## Only a target this close to straight ahead of her bow (dot of the bow's direction).
const AHEAD_DOT := 0.82
const REEL_CLOSE := 14.0
const SHOT_SPEED := 90.0

var ship: Node3D
var target: Node3D
var tier := 0
var by: Node
var _t := 0.0
var _hold := 8.0
var _bit := false
var _rope: GadgetRope


static func harpoon(s: Node3D, tgt: Node3D, t := 0, who: Node = null) -> bool:
	if s == null or tgt == null or not is_instance_valid(tgt) or (tgt.has_method("is_dead") and tgt.is_dead()):
		return false
	var h := HarpoonCannon.new()
	h.name = "Harpoon"
	h.ship = s
	h.target = tgt
	h.tier = t
	h.by = who
	h._hold = float(GadgetData.tier_val("harpoon", "hold", t))
	var tree := s.get_tree()
	(tree.current_scene if tree.current_scene else tree.root).add_child(h)
	return true


## The harpoonable thing nearest straight ahead of `s`'s bow within `r` (null none).
static func target_ahead(s: Node3D, r: float) -> Node3D:
	var fwd: Vector3 = -s.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var best: Node3D = null
	var best_d := r
	for g in GROUPS:
		for e in s.get_tree().get_nodes_in_group(g):
			var n := e as Node3D
			if n == null or n == s or not n.is_visible_in_tree() or (n.has_method("is_dead") and n.is_dead()):
				continue
			var d := n.global_position - s.global_position
			d.y = 0.0
			if d.length() < best_d and fwd.dot(d.normalized()) > AHEAD_DOT:
				best_d = d.length()
				best = n
	return best


func bow() -> Vector3:
	return ship.global_transform * Vector3(0, HullLayout.DECK_Y + 1.0, HullLayout.BOW_Z)


func _bite_at() -> Vector3:
	return target.global_position + Vector3.UP * 1.5


func _ready() -> void:
	add_to_group("harpoons")
	_rope = GadgetRope.make(self, bow(), _bite_at(), tier)
	_rope.shoot_time = clampf(bow().distance_to(_bite_at()) / SHOT_SPEED, 0.12, 0.6)
	_rope._hook.mesh = GadgetModels.mesh("harpoon", tier)
	_rope.thick = 3.5
	var fx := get_node("/root/FX")
	fx.blast(bow(), -ship.global_basis.z, 0.6)
	fx.sfx("cannon", bow(), 0.0, 0.05, 1.3)
	fx.sfx("rope", bow(), -2.0, 0.05, 0.9)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(ship) or not is_instance_valid(target) or (target.has_method("is_dead") and target.is_dead()):
		_let_go()
		return
	_rope.set_ends(bow(), _bite_at())
	if not _rope.arrived():
		return
	if not _bit:
		_bite()
	_t += delta
	if _t >= _hold:
		_let_go()
		return
	if not get_node("/root/Net").is_host():
		return
	var to: Vector3 = ship.global_position - target.global_position
	to.y = 0.0
	if to.length() <= REEL_CLOSE:
		return
	var v := float(GadgetData.tier_val("harpoon", "reel", tier))
	if target.has_method("reel_toward"):
		target.reel_toward(ship.global_position, v, delta)
	else:
		target.global_position += to.normalized() * v * delta


## The harpoon bites: splinters and a jolt on every screen; on the host its damage and the target told.
func _bite() -> void:
	_bit = true
	var at := _bite_at()
	var fx := get_node("/root/FX")
	fx.debris(at, (bow() - at).normalized(), 12, Color(0.45, 0.32, 0.2), 6.0)
	fx.sfx("cannon_hit", at, 0.0, 0.05, 1.2)
	if not get_node("/root/Net").is_host():
		return
	var hb = target.get("hurtbox")
	if hb is Hurtbox:
		var hd := HitData.new()
		hd.damage = float(GadgetData.tier_val("harpoon", "damage", tier))
		hd.knockback_force = 0.0
		hd.stagger_duration = 0.0
		hd.hitstop_duration = 0.0
		hd.camera_shake_intensity = 0.0
		# (a ship's gun: hulls take it, as from a cannonball)
		hd.siege = true
		(hb as Hurtbox).take_hit(hd, by if by and is_instance_valid(by) else self)
	if target.has_method("harpooned"):
		target.harpooned(ship)


func _let_go() -> void:
	if is_queued_for_deletion():
		return
	if get_node("/root/Net").is_host() and is_instance_valid(target) and _bit and target.has_method("released"):
		target.released()
	released.emit()
	if is_instance_valid(_rope):
		_rope.retract(0.4)
		_rope.reparent(get_parent())
	queue_free()
