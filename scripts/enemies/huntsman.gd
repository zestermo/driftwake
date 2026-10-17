extends PirateBoss
## The Cursed Huntsman (BeastPool "huntsman", a forest island's miniboss: he leads its outlaws' camp in its
## captain's place, IslandContent._camp). The lord's huntsman who shot the white stag, cursed to hunt these
## woods for ever: hooded in green-black, antlers bound to his hood, a war axe, his two hounds at his heel.
## Morrow's three-act fight (combos, the lunge, the red chop, volleys; the roar and the leaping slam below 60%,
## the glowing blade and the storm below 30%) on an island's level, every blow scaled by Levels; his hounds
## (wolves) come for you with him. A miniboss's pay.

const HP := 680.0
const WOLF := preload("res://scripts/enemies/fauna/wolf.gd")

var hounds: Array = []


static func chief_look(rng: RandomNumberGenerator) -> Dictionary:
	var lk := CharacterLook.base_look()
	lk.merge({
		"name": "Cursed Huntsman", "body": "masc", "build": "broad", "height": 1.16,
		"skin": [Color(0.72, 0.66, 0.62), Color(0.62, 0.58, 0.56), Color(0.8, 0.72, 0.66)][rng.randi() % 3],
		"head": ["long", "square"][rng.randi() % 2], "nose": "hooked", "brows": 3, "mouth": 1, "marks": "scar",
		"hair": "long", "hair_color": Color(0.32, 0.3, 0.28), "facial_hair": ["long_beard", "beard"][rng.randi() % 2],
		"hat": "hood", "hat_color": [Color(0.12, 0.16, 0.12), Color(0.16, 0.12, 0.1), Color(0.1, 0.1, 0.12)][rng.randi() % 3],
		"top": "tunic", "top_color": Color(0.28, 0.24, 0.18), "sleeves": "long",
		"vest": "jerkin", "vest_color": Color(0.36, 0.24, 0.14),
		"coat": "longcoat", "coat_color": [Color(0.16, 0.22, 0.14), Color(0.22, 0.16, 0.1), Color(0.14, 0.14, 0.16)][rng.randi() % 3],
		"trim_color": Color(0.5, 0.36, 0.18), "legs": "breeches", "legs_color": Color(0.24, 0.2, 0.16),
		"feet": "tall_boots", "feet_color": CharacterLook.LEATHER[0], "belt": "wide_belt", "belt_color": CharacterLook.LEATHER[0],
		"gloves": true, "gloves_color": CharacterLook.LEATHER[0], "earring": false, "eyepatch": rng.randf() < 0.3, "pauldron": true,
	}, true)
	return lk


func _boss_look() -> Dictionary:
	return look


func _boss_hp() -> float:
	return HP * Levels.hp_k(level, _lv_ref())


func _barks(kind: String) -> Array:
	return {"phase2": ["Hounds! Bring them down!", "The hunt never ends!"],
		"phase3": ["I'll mount your head with his!", "The wood remembers! The wood WANTS!"],
		"taunt": ["Run, little deer.", "Ha! Again!", "You bleed like the rest.", "I can smell your fear."]}[kind]


func _prize() -> Array:
	return [_coins(14), _xp(240)]


func _ready() -> void:
	super._ready()
	var k := Levels.dmg_k(level, _lv_ref())
	_hit_light = _hit_light.duplicate() as HitData
	_hit_peril = _hit_peril.duplicate() as HitData
	_hit_rush = _hit_rush.duplicate() as HitData
	for hd in [_hit_light, _hit_heavy, _hit_peril, _hit_rush]:
		(hd as HitData).damage *= k
	humanoid.set_weapon(Props.weapon_mesh("axe:war:3"))
	# (his hounds at his heel: named, made the same on every machine; the host runs them)
	for i in range(2):
		var h: Creature = WOLF.new()
		var off := Vector3(cos(i * 2.4 + 1.0), 0.0, sin(i * 2.4 + 1.0)) * 2.2
		h.setup(global_position + off, {"morph": 2, "pack": -int(get_instance_id() % 997) - 10, "lead": false})
		h.name = "%sHound%d" % [name, i + 1]
		h.level = level
		h.position = get_parent().to_local(global_position + off) if is_inside_tree() else position + off
		get_parent().add_child.call_deferred(h)
		hounds.append(h)
		# (no spawner looks after them: their own distance LOD, twice a second)
		var t := Timer.new()
		t.wait_time = 0.5
		t.autostart = true
		t.timeout.connect(func():
			var d := INF
			for p in Net.all_players():
				d = minf(d, (p as Node3D).global_position.distance_to(h.global_position))
			h.set_lod(Creature.LOD_FULL if d < Creature.LOD_RANGE[0] else (Creature.LOD_LOW if d < Creature.LOD_RANGE[1] else (Creature.LOD_SLEEP if d < Creature.LOD_RANGE[2] else Creature.LOD_HIDDEN))))
		h.add_child(t)
