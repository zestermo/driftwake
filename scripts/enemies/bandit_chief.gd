extends PirateBoss
## The bandit chief (BeastPool "bandit_chief", a desert island's miniboss: he leads its pirates'
## camp in its captain's place). Morrow's three-act fight (combos, the lunge, the red chop, pistol
## volleys; the roar and the leaping slam below 60%; the glowing blade and the blade storm below
## 30%) under a turban with a scimitar, on an island's level: his health and every blow scaled
## by Levels like the crew's, a miniboss's pay. IslandContent._camp gives his setup a look from
## chief_look and his name as the title.

const HP := 620.0


static func chief_look(rng: RandomNumberGenerator) -> Dictionary:
	var lk := CharacterLook.base_look()
	var C := CharacterLook.CLOTH
	lk.merge({
		"name": "Bandit Chief", "body": "masc", "build": "broad", "height": 1.14,
		"skin": [Color(0.66, 0.47, 0.32), Color(0.55, 0.38, 0.26), Color(0.76, 0.56, 0.4)][rng.randi() % 3],
		"head": ["square", "long"][rng.randi() % 2], "nose": "hooked", "brows": 3, "mouth": 1, "marks": "scar",
		"hair": "short", "hair_color": Color(0.08, 0.06, 0.05), "facial_hair": ["long_beard", "goatee", "beard"][rng.randi() % 3],
		"hat": "turban", "hat_color": [Color(0.12, 0.1, 0.12), Color(0.72, 0.18, 0.14), Color(0.95, 0.93, 0.88)][rng.randi() % 3],
		"top": "tunic", "top_color": Color(0.92, 0.86, 0.72), "sleeves": "long",
		"vest": "vest", "vest_color": [C[5], C[13], C[14]][rng.randi() % 3],
		"coat": "duster", "coat_color": [Color(0.3, 0.22, 0.16), Color(0.55, 0.18, 0.14), Color(0.2, 0.2, 0.26)][rng.randi() % 3],
		"trim_color": CharacterLook.TRIM[0], "legs": "trousers", "legs_color": Color(0.4, 0.3, 0.22),
		"feet": "tall_boots", "feet_color": CharacterLook.LEATHER[0], "belt": "belt_sash", "belt_color": CharacterLook.LEATHER[0],
		"sash_color": [Color(0.72, 0.18, 0.14), Color(0.86, 0.66, 0.2)][rng.randi() % 2], "gloves": true,
		"gloves_color": CharacterLook.LEATHER[0], "earring": true, "eyepatch": rng.randf() < 0.4, "pauldron": false,
	}, true)
	return lk


func _boss_look() -> Dictionary:
	return look


func _boss_hp() -> float:
	return HP * Levels.hp_k(level, _lv_ref())


func _barks(kind: String) -> Array:
	return {"phase2": ["The sand drinks blood! Cut them down!", "Brothers! To me!"],
		"phase3": ["You'll feed the vultures!", "I'll bury you to the neck!"],
		"taunt": ["The desert takes the weak.", "Ha! Again!", "You've sand in your eyes!", "Come, then!"]}[kind]


func _prize() -> Array:
	return [_coins(12), _xp(220)]


func _ready() -> void:
	super._ready()
	var k := Levels.dmg_k(level, _lv_ref())
	_hit_light = _hit_light.duplicate() as HitData
	_hit_peril = _hit_peril.duplicate() as HitData
	_hit_rush = _hit_rush.duplicate() as HitData
	for hd in [_hit_light, _hit_heavy, _hit_peril, _hit_rush]:
		(hd as HitData).damage *= k
	humanoid.set_weapon(Props.weapon_mesh("cutlass:scimitar:2"))
