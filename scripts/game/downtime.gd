class_name Downtime
extends RefCounted
## Sailing downtime (v1.18, the One Piece crew between islands: Zoro trains, Usopp tinkers, Robin reads): from
## the action wheel (N), short animated loops that build skills a little at a time (DowntimeState plays them).
## Aboard they need the ship looked after: the helm lashed (LashedHelm), the anchor down or a crewmate at the
## wheel. Danger ends them (danger()): a storm, a sail close by, a Sea King risen, enemies, a blow, the helm
## come loose. Progress per minute is real but less than the real thing (fighting for mastery).
##   train   weapon mastery of the weapon in your hand (ashore too)
## Each captain's own: rewards go to the local captain; the loop is seen by the crew (the state and the
## body's held action ride the snapshots).

## id -> label, where ("ship", or "any": ashore and aboard), the reward's interval (s), the wheel's order.
const KINDS := {
	"train": {"label": "Train", "where": "any", "every": 6.0, "order": 20},
}
## Mastery for each interval of training (fighting lands MASTERY_PER_HIT a hit, many hits a minute).
const TRAIN_MASTERY := 5
## Danger close enough to end an activity: a sail (m), a Sea King (m), enemies in a fight (m).
const SAIL_NEAR := 160.0
const KING_NEAR := 140.0
const FOES_NEAR := 30.0
const SEA_KING := preload("res://scripts/enemies/sea_king.gd")


## The activities on the action wheel (ActionWheel.ensure_builtins). Static method callables, not lambdas.
static func register_wheel() -> void:
	ActionWheel.register("lash", "Lash the helm", "", _lash_ok, lash, 5)
	ActionWheel.register("train", _train_label, "", _train_ok, _train, KINDS["train"]["order"])


static func _lash_ok(p) -> bool:
	return ActionWheel.place(p) == "helm"


## At the wheel: lash her to the heading she's on and step away (she holds it till someone takes the wheel).
static func lash(p) -> void:
	var ship: Ship = p.current_ship
	Net.lash_helm(true, ship._heading)
	p.call("_toast", "Helm lashed - she'll hold this heading. Take the wheel to cast it off.")
	p.state_machine.force_state("Idle", {})


static func _train_label(p) -> String:
	return "Train (%s)" % SkillTree.TREES[SkillTree.style_tree(p.style())]["name"] if _train_tree(p) != "" else "Train"


static func _train_ok(p) -> bool:
	return ActionWheel.place(p) in ["island", "ship"] and p.is_free()


static func _train(p) -> void:
	start(p, "train")


static func _train_tree(p) -> String:
	return SkillTree.style_tree(p.style())


## Begin an activity, or say why not.
static func start(p, kind: String) -> void:
	var why := refuse(p, kind)
	if why != "":
		p.call("_toast", why)
		return
	p.state_machine.force_state("Downtime", {"kind": kind})


## Why `kind` can't start now ("" = it can).
static func refuse(p, kind: String) -> String:
	if kind == "train" and _train_tree(p) == "":
		return "Nothing to train with in that shape"
	var ship := ship_under(p)
	if ship and not looked_after(ship):
		return "Lash the helm or drop anchor first (N at the wheel)"
	return danger(p)


## The crew's ship if `p` stands aboard her.
static func ship_under(p) -> Ship:
	var ship := p.get_tree().get_first_node_in_group("ship") as Ship
	return ship if ship and ship.aboard(p.global_position) else null


## She'll keep without you: lashed, anchored, a crewmate at the wheel, or lying still.
static func looked_after(ship: Ship) -> bool:
	return ship.lashed or ship.anchored or ship.helm_other or (ship.sail <= 0.0 and absf(ship.speed) < 0.5)


## What ends downtime now ("" = nothing): the reason, said to the captain.
static func danger(p) -> String:
	var tree: SceneTree = p.get_tree()
	var at: Vector3 = p.global_position
	var ship := ship_under(p)
	if ship:
		if p.get_node("/root/Weather").storm > LashedHelm.STORM:
			return "A storm's coming on - all hands!"
		if not looked_after(ship):
			return "The helm's loose - she's wandering off!"
	for es in tree.get_nodes_in_group("enemy_ships"):
		if es.state not in [EnemyShip.S.SINK, EnemyShip.S.PRIZE] and (es as Node3D).global_position.distance_to(at) < SAIL_NEAR:
			return "Sail ho! A ship bearing down!"
	for k in tree.get_nodes_in_group("sea_kings"):
		if k.state not in [SEA_KING.S.LURK, SEA_KING.S.DEAD] and (k as Node3D).global_position.distance_to(at) < KING_NEAR:
			return "Something huge in the water!"
	for e in tree.get_nodes_in_group("enemies"):
		if e.has_method("in_combat") and e.in_combat() and (e as Node3D).global_position.distance_to(at) < FOES_NEAR:
			return "Enemies!"
	return ""


## One interval's reward for `kind` (the local captain's).
static func reward(p, kind: String) -> void:
	match kind:
		"train":
			p.progression.add_mastery(_train_tree(p), TRAIN_MASTERY)


## The body's loop for `kind` (DowntimePoses).
static func pose_of(p, kind: String) -> String:
	match kind:
		"train":
			var st: String = p.style()
			if st in ["pistol", "dual_pistol"]:
				return "dt_train_gun"
			return "dt_train_fist" if st == "fist" else "dt_train_blade"
	return "dt_" + kind
