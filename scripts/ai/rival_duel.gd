class_name RivalDuel
extends RefCounted
## A debug duel with a captain-style AI (Alt+F5 in a debug build): a rival with a random look and weapon steps up
## 8 m in front of the captain, sharper each time (skill 0.3, 0.6, 0.9, round again). The first piece of 1.19's
## rival crews (docs/v1_19_plan.md); the crews, their cutscenes and their retreat come later.

const WEAPONS := ["cutlass", "katana", "boarding_axe", "dagger", "spear", "warhammer", "greatsword"]
const SKILLS := [0.3, 0.6, 0.9]
static var _n := 0


static func spawn(near: Player, skill := -1.0, weapon := "") -> Player:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["rival", _n, randi()])
	if skill < 0.0:
		skill = SKILLS[_n % SKILLS.size()]
	_n += 1
	var lk: Dictionary = CharacterLook.random_look(rng)
	lk["name"] = "Rival"
	var fwd := -near.player_model.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var at := near.global_position + fwd * 8.0 + Vector3.UP * 0.5
	var brain := CaptainBrain.new()
	brain.skill = skill
	var r := Player.spawn_ai(near.get_parent(), lk, at, atan2(fwd.x, fwd.z), brain)
	var w := weapon if weapon != "" else str(WEAPONS[rng.randi() % WEAPONS.size()])
	var item := ItemDB.get_item(w)
	if item:
		r.equip_weapon(item, false)
	return r
