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


## The cleave's charge reached `level` (1, 2): air drawn in round the raised blade, a glint off it, a rising note; at
## the top a ring round the feet (and the wind torn round you with the element).
static func charged(p: Player, level: int) -> void:
	var at := tip(p)
	var elem := p.progression.elemental("greatsword")
	var col := FX.tree_col("greatsword" if elem else "plain", FX.EDGE if level == 1 else FX.CORE)
	Net.fx("gather", [at, 0.9 + 0.5 * level, col, 0.22, 8 + 6 * level])
	Net.fx("glint", [at, col, 0.6 + 0.3 * level])
	Net.fx("sfx", ["blip_high", at, -8.0, 0.0, 0.8 + 0.2 * level])
	if level == 2:
		Net.fx("ring", [p.global_position, Vector3.UP, 2.2, col, 0.35, 0.1])
		Net.fx("dust_ring", [p.global_position, 10, 0.7])
		if elem:
			Net.fx("element", ["greatsword", p.global_position + Vector3(0, 0.4, 0), Vector3.UP, 10, 4.0])
	p.squash(1.0 + level)


## The cleave's blow at charge `level` (0-2): through any wind-up and staggering long (x the design's weight); a full
## charge can't be blocked and knocks them flat.
static func cleave_hit(p: Player, hit: HitData, level: int) -> void:
	var wt := WeaponDesigns.great(p.equipped_weapon.design, "weight")
	hit.breaker = true
	hit.knockback_force = (9.0 + 3.0 * level) * wt
	hit.stagger_duration = (0.7 + 0.25 * level) * wt
	hit.hitstop_duration = 0.09 + 0.03 * level
	hit.camera_shake_intensity = 0.18 + 0.08 * level
	hit.knockdown = level == 2
	hit.unblockable = hit.unblockable or level == 2
	shape_hit(p, hit)


## A full-charge cleave's crescent of air: its damage.
const GALE_DAMAGE := 18.0

## The cleave meeting the ground ahead: a crack run out down its line, dust, a ring; harder the more it was charged;
## a full charge flings a crescent of air on down the line (Projectile "gale", in the tree's colours with the element).
static func cleave_fx(p: Player, level: int) -> void:
	var face := -p.player_model.global_basis.z
	face.y = 0.0
	face = face.normalized()
	var elem := p.progression.elemental("greatsword", 2)
	var tree := "greatsword" if elem else "plain"
	var at := p.global_position + face * 1.7
	Net.fx("ground_crack", [at - face * 0.4, face, 1.6 + 1.6 * level, Color(0, 0, 0, 0), randi() % 10000, 0.1])
	Net.fx("heavy_dust", [at, 8 + 4 * level, 0.6 + 0.15 * level])
	Net.fx("debris", [at + Vector3(0, 0.1, 0), Vector3.UP + face * 0.3, 3 + 2 * level, Color(0.35, 0.3, 0.25), 4.5])
	Net.fx("ring", [at, Vector3.UP, 1.4 + 0.7 * level, FX.tree_col(tree, FX.EDGE), 0.26, 0.12])
	Net.fx("sfx", ["thud", at, -4.0 + 2.0 * level, 0.05, 0.8 - 0.05 * level])
	if elem:
		Net.fx("element", ["greatsword", at + Vector3(0, 0.3, 0), face + Vector3.UP * 0.4, 8 + 4 * level, 5.0])
	if level == 2:
		Projectile.launch(p.get_tree(), "gale", p.global_position + Vector3(0, 1.2, 0) + face * 1.2, face, p, GALE_DAMAGE, "elem" if p.progression.elemental("greatsword") else "")
		Net.fx("sfx", ["whoosh_big", at, -2.0, 0.05, 0.65])
	CombatManager.apply_camera_kick(0.12 + 0.06 * level, 0.3)


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
