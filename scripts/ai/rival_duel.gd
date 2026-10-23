class_name RivalDuel
extends RefCounted
## A debug duel with a captain-style AI (Alt+F5 in a debug build, the host's): a rival with a random look, weapon
## and a loadout that fits it steps up 8 m in front of the captain, sharper each time (skill 0.3, 0.6, 0.9, round
## again). The first piece of 1.19's rival crews (docs/v1_19_plan.md); the crews, their cutscenes and their retreat
## come later. Co-op: spawned on every screen through Net._all_spawn_rival (the guests get a puppet).

const WEAPONS := ["cutlass", "katana", "boarding_axe", "dagger", "spear", "warhammer", "greatsword"]
const SKILLS := [0.3, 0.6, 0.9]
static var _n := 0


static func spawn(near: Player, skill := -1.0, weapon := "") -> Player:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["rival", _n, randi()])
	if skill < 0.0:
		skill = SKILLS[_n % SKILLS.size()]
	var rname := "Rival_%d" % _n
	_n += 1
	var lk: Dictionary = CharacterLook.random_look(rng)
	lk["name"] = "Rival"
	var fwd := -near.player_model.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var at := near.global_position + fwd * 8.0 + Vector3.UP * 0.5
	var w := weapon if weapon != "" else str(WEAPONS[rng.randi() % WEAPONS.size()])
	var parent := near.get_parent()
	var net := near.get_node("/root/Net")
	net.everyone("_all_spawn_rival", [net.key_of(parent), rname, lk, w, at, atan2(fwd.x, fwd.z), skill])
	return parent.get_node_or_null(rname) as Player


## The host's rival: an AI captain with a CaptainBrain of `skill`, `weapon` in hand and a kit that fits it.
static func build(parent: Node, rname: String, look: Dictionary, weapon: String, at: Vector3, yaw: float, skill: float) -> Player:
	var brain := CaptainBrain.new()
	brain.skill = skill
	var r := Player.spawn_ai(parent, look, at, yaw, brain, rname)
	var item := ItemDB.get_item(weapon)
	if item:
		r.equip_weapon(item, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([rname, randi()])
	give_kit(r, skill, rng)
	return r


## A loadout that fits its weapon, by skill: a rookie 1 skill, a captain 4 and an ultimate (half charged at the
## sharpest). Only weapon and captain skills (no fruit's: fruit users are 1.22's).
static func give_kit(r: Player, skill: float, rng: RandomNumberGenerator) -> void:
	var st := r.style()
	var picks := []
	var ults := []
	for id in Skills.ALL:
		var sk: Dictionary = Skills.ALL[id]
		if str(sk.get("fruit", "")) != "" or not PowerComponent.weapon_skill(sk) or not PowerComponent.fits(sk, st):
			continue
		(ults if Skills.is_ult(id) else picks).append(id)
	picks.shuffle()
	var n := mini(1 + int(round(skill * 3.0)), PowerComponent.KEYS.size())
	for i in range(mini(n, picks.size())):
		r.power.loadout[PowerComponent.KEYS[i]] = picks[i]
	if skill >= 0.5 and not ults.is_empty():
		r.power.loadout[PowerComponent.ULT] = ults[rng.randi() % ults.size()]
		r.power.ult = PowerComponent.ULT_MAX * (0.5 if skill >= 0.8 else 0.0)
	r.power.energy = r.power.max_energy()
