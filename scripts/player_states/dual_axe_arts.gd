class_name DualAxeArts
## Twin axes (style "dual_axe": an axe in each hand): the pair's numbers and its shared blows. Poses in
## DualAxeMoves.


## The pair's design number ("speed", "hook"): the two axes' average (WeaponDesigns.axe).
static func pair(p: Player, key: String) -> float:
	var a := WeaponDesigns.axe(p.equipped_weapon.design, key)
	var b := WeaponDesigns.axe(p.offhand_weapon.design, key) if p.offhand_weapon else a
	return (a + b) * 0.5


## A blow with the off-hand axe hits as hard as that axe (x its power against the main hand's).
static func off_k(p: Player) -> float:
	return p.offhand_weapon.power() / p.equipped_weapon.power() if p.offhand_weapon else 1.0
