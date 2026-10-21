class_name GreatswordArts
## The greatsword's shared blows (tree "greatsword": gale - white air pressure, a jade edge; gusts torn off the
## swings). shape_hit() (a design's bleed on every cut), swing_fx() (a combo blow's show, bigger as its momentum
## builds). Poses in GreatswordMoves.


## Where the blade's point is now.
static func tip(p: Player) -> Vector3:
	var w: MeshInstance3D = p.body_model.weapon
	return w.global_transform * Vector3(0, 0, w.mesh.get_aabb().position.z * 0.92)


## A greatsword hit's design traits: the sawtooth's cuts open a wound.
static func shape_hit(p: Player, hit: HitData) -> void:
	var bleed := WeaponDesigns.great(p.equipped_weapon.design, "bleed", 0.0)
	if bleed > 0.0:
		hit.set_meta("bleed", bleed)


## A combo blow's show: with momentum built, a ring of air pressure off the point and a rising whoosh; with the
## element on every blow (the tree's tier 2) the wind tears off it. `big`: the turn or the running cleave.
static func swing_fx(p: Player, mom: int, big: bool) -> void:
	var at := tip(p)
	var face := -p.player_model.global_basis.z
	var elem := p.progression.elemental("greatsword", 2)
	var col := FX.tree_col("greatsword" if elem else "plain", FX.EDGE)
	if mom > 0 or big:
		Net.fx("ring", [at, face, 0.8 + 0.3 * mom + (0.5 if big else 0.0), col, 0.2, 0.12])
		Net.fx("sfx", ["whoosh_big", p.global_position, -9.0 + 1.5 * mom, 0.06, 0.85 + 0.08 * mom])
	if elem:
		Net.fx("element", ["greatsword", at, face + Vector3.UP * 0.2, 5 + 2 * mom, 4.0 + mom])
	if mom >= 2 or big:
		CombatManager.apply_camera_kick(0.06 + 0.03 * mom, 0.22)
