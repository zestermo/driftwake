class_name RapierArts
## The rapier's shared blows (tree "rapier": quicksilver mirror - silver afterimages, mirror flashes, phantom double
## thrusts). shape_hit() (a thrust's point: a design's bleed), thrust_fx() (a blow's show: a ring round the line at the
## point, a glint off it; the mirror's double and its quicksilver once the element follows every blow), phantom() (the
## combo's third: the mirror's thrust, a silver ghost of you left in it), lunge_fx() (the heavy lunge's line), riposte()
## (a landed parry answered with a thrust). Poses in RapierMoves.

const FXS := preload("res://scripts/game/fx.gd")


## Net (effects on every screen), reached through the tree: a static func can't see the autoloads in a --script run.
static func _net() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Net")


## Where the blade's point is now.
static func tip(p: Player) -> Vector3:
	var w: MeshInstance3D = p.body_model.weapon
	return w.global_transform * Vector3(0, 0, w.mesh.get_aabb().position.z * 0.96)


## The tree's colour: its own once the element is awakened at `tier` (1: techniques, 2: every blow), else plain steel.
static func col(p: Player, which: int, tier: int = 2) -> Color:
	return FXS.tree_col("rapier" if p.progression.elemental("rapier", tier) else "plain", which)


static func _face(p: Player) -> Vector3:
	var f := -p.player_model.global_basis.z
	f.y = 0.0
	return f.normalized()


## A thrust's design traits: the flamberge's wounds bleed.
static func shape_hit(p: Player, hit: HitData) -> void:
	var bleed := WeaponDesigns.rapier(p.equipped_weapon.design, "bleed", 0.0)
	if bleed > 0.0:
		hit.set_meta("bleed", bleed)


## A combo thrust's show at the strike: a thin ring round the line at the point and a glint off it; with the element on
## every blow (the tree's tier 2) the mirror's double of the line and quicksilver thrown off. `big`: the last of the combo.
static func thrust_fx(p: Player, big: bool) -> void:
	var at := tip(p)
	var face := _face(p)
	_net().fx("ring", [at, face, 0.45 if not big else 0.8, col(p, FXS.EDGE), 0.14, 0.1])
	_net().fx("glint", [at, col(p, FXS.CORE), 0.45 if not big else 0.7])
	if p.progression.elemental("rapier", 2):
		_net().fx("mirror_thrust", [at - face * 1.4, face, 1.8, col(p, FXS.EDGE), p.player_model.global_basis.x, col(p, FXS.ACCENT)])
		_net().fx("element", ["rapier", at, face + Vector3.UP * 0.15, 5 if not big else 8, 4.0])
	if big:
		p.cam_kick(0.08, 0.22)


## The combo's third, its first thrust: the mirror's. A silver ghost of you is left standing in the thrust as the body
## snaps back for the real one, its line drawn through them.
static func phantom(p: Player) -> void:
	var at := tip(p)
	var face := _face(p)
	_net().fx("afterimage", [p.body_model, col(p, FXS.CORE, 1), 0.32])
	_net().fx("streak", [at - face * 1.2, at + face * 0.3, col(p, FXS.EDGE, 1), 0.05, 0.26])
	_net().fx("sfx", ["whoosh", at, -10.0, 0.05, 1.45])


## The lunge's line: a streak of the point's whole travel, a ring where it stops, dust off the back foot, a mirror flash at
## the point; with the element the mirror's double of it and quicksilver beading off.
static func lunge_fx(p: Player, elem: bool) -> void:
	var face := _face(p)
	var from := p.global_position + Vector3(0, 1.15, 0) - face * 0.4
	var reach := 3.4 * WeaponDesigns.rapier(p.equipped_weapon.design, "reach")
	var end := from + face * reach
	var tree := "rapier" if elem else "plain"
	_net().fx("streak", [from, end, FXS.tree_col(tree, FXS.EDGE), 0.09, 0.26])
	_net().fx("ring", [end, face, 1.0, FXS.tree_col(tree, FXS.EDGE), 0.2, 0.14])
	_net().fx("star_glint", [end, 0.7, FXS.tree_col(tree, FXS.ACCENT), 0.22, false, 2.0])
	_net().fx("afterimage", [p.body_model, FXS.tree_col(tree, FXS.CORE), 0.28])
	_net().fx("dust", [p.global_position + Vector3(0, 0.05, 0) - face * 0.6, 6, 0.55])
	if elem:
		_net().fx("mirror_thrust", [from, face, reach, FXS.tree_col(tree, FXS.EDGE), p.player_model.global_basis.x, FXS.tree_col(tree, FXS.ACCENT)])
		_net().fx("element", ["rapier", end, face + Vector3.UP * 0.2, 10, 5.5])
	p.cam_kick(0.12, 0.28)


## The riposte: a landed parry answered at once. RIPOSTE_DELAY after the parry (the thrust's beat in rp_deflect), the
## point goes into the attacker if they're still in reach: a sure crit through their guard (they're open), reeling,
## a step in behind it; a mirror flash where it lands.
const RIPOSTE_DELAY := 0.16
const RIPOSTE_REACH := 3.2
const RIPOSTE_DAMAGE := 16.0


static func riposte(p: Player, attacker: Node) -> void:
	if not (attacker is Node3D) or not is_instance_valid(attacker):
		return
	var to := (attacker as Node3D).global_position - p.global_position
	to.y = 0.0
	if to.length() > 0.05:
		p.player_model.rotation.y = atan2(-to.x, -to.z)
	p.get_tree().create_timer(RIPOSTE_DELAY, false).timeout.connect(func():
		if not is_instance_valid(attacker) or not is_instance_valid(p):
			return
		var hb := (attacker as Node).get("hurtbox") as Hurtbox
		if hb == null or (attacker as Node3D).global_position.distance_to(p.global_position) > RIPOSTE_REACH:
			return
		var hd := p.melee_hit(RIPOSTE_DAMAGE, "finisher")
		if not hd.has_meta("crit"):
			hd.damage *= 1.5
			hd.set_meta("crit", true)
		hd.unblockable = true
		hd.breaker = true
		hd.knockback_force = 4.0
		hd.stagger_duration = 0.8
		hd.hitstop_duration = 0.07
		hd.camera_shake_intensity = 0.12
		hd.sever = true
		shape_hit(p, hd)
		hb.take_hit(hd, p)
		p.power.add_ult(hd.damage)
		p.power.on_sword_hit(attacker, hd)
		var face := _face(p)
		p.velocity += face * 4.0
		var at := tip(p)
		var elem := p.progression.elemental("rapier", 2)
		_net().fx("star_glint", [at, 0.75, col(p, FXS.ACCENT), 0.22, false, 1.8])
		_net().fx("ring", [at, face, 0.9, col(p, FXS.EDGE), 0.18, 0.12])
		_net().fx("afterimage", [p.body_model, col(p, FXS.CORE), 0.26])
		_net().fx("sfx", ["slice", at, -4.0, 0.05, 1.35])
		if elem:
			_net().fx("mirror_thrust", [at - face * 1.6, face, 2.0, col(p, FXS.EDGE), p.player_model.global_basis.x, col(p, FXS.ACCENT)])
			_net().fx("elem_hit", ["rapier", at, face])
		p.cam_kick(0.1, 0.22))
