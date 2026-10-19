class_name Downtime
extends RefCounted
## Sailing downtime (v1.18, the One Piece crew between islands: Zoro trains, Usopp tinkers, Robin reads): from
## the action wheel (N), short animated loops that build skills a little at a time (DowntimeState plays them).
## Aboard they need the ship looked after: the helm lashed (LashedHelm), the anchor down or a crewmate at the
## wheel. Danger ends them (danger()): a storm, a sail close by, a Sea King risen, enemies, a blow, the helm
## come loose. Progress per minute is real but less than the real thing (fighting for mastery, kills for XP).
##   train   weapon mastery of the weapon in your hand (ashore too)
##   read    sat on a crate with a book: experience, sea lore now and then, and in time a recipe
##   tinker  sat with mallet and lock: the kit tuned a while (a spare shot, quicker reloads, a little bite)
##   fish    at the rail with a rod: ingredients tagged fish, Fishing mastery; Fishing's fish_* perks count
##   sleep   in the cabin's bunk: you heal, and (solo) the hours pass quickly
## (Cooking is the galley's, lane A's "cook" on the same wheel at order 30.)
## Each captain's own: rewards go to the local captain; the loop is seen by the crew (the state and the
## body's held action ride the snapshots; DowntimeProps makes what the body holds on every screen).

## id -> label, where ("ship", or "any": ashore and aboard), the reward's interval (s), the wheel's order.
const KINDS := {
	"train": {"label": "Train", "where": "any", "every": 6.0, "order": 20},
	"read": {"label": "Read", "where": "ship", "every": 8.0, "order": 40},
	"tinker": {"label": "Tinker", "where": "ship", "every": 10.0, "order": 50},
	"fish": {"label": "Fish", "where": "ship", "every": 20.0, "order": 60},
	"sleep": {"label": "Sleep in the bunk", "where": "ship", "every": 2.0, "order": 70},
}
## Mastery for each interval of training (fighting lands MASTERY_PER_HIT a hit, many hits a minute).
const TRAIN_MASTERY := 5
## Reading: experience an interval, a piece of lore every LORE_EVERY intervals, the recipe at RECIPE_AT.
const READ_XP := 6
const LORE_EVERY := 3
const RECIPE_AT := 20
const RECIPE := "captains_feast"
const LORE := [
	"The old charts say the sea gets rougher the further you sail from home. The old charts were drawn by cowards.",
	"A ship that's named and loved sails truer. Shipwrights swear to it, and they'd know.",
	"Sea Kings sleep deep in calm water. They wake for storms, and for cannon fire.",
	"Gulls follow a ship with a good cook. Crews follow one too.",
	"A log pose sets itself to the next island's pull. Leave before it's set and you sail blind.",
	"Pirates bury treasure because a full hold is a slow ship, not for the riddles.",
	"Salt keeps meat, salt keeps fish, and enough of it keeps a sailor from scurvy. Mostly.",
	"Lashing a helm keeps her heading. It won't keep her off the rocks.",
	"The fruits of the sea's devils taste foul, they say, and you only eat one. The sea takes back what it gave: you'll never swim again.",
	"Marines fly white sails. Pirates fly whatever they like.",
	"A swordsman who trains at sea learns to cut on a moving deck. Ashore, the ground feels like cheating.",
	"Every crew needs someone who reads. Someone has to know which island eats sailors.",
]
## Tinkering: seconds of tuned kit an interval adds, up to KIT_MAX; what it gives (Progression.stat keys).
const KIT_PER := 90.0
const KIT_MAX := 1200.0
const KIT := {"extra_shots": 1.0, "reload_pct": 0.15, "damage_pct": 0.04}
## Fishing: a catch (or one that got away) every FISH_SECS less the bite perk; FISH_LOST of them get away
## (less the reel perk); [item id, weight] (oysters and urchins are the rare ones, more with the rare perk).
const FISH_LOST := 0.3
const FISH_XP := 8
const FISH_LOST_XP := 3
const CATCH := [["fish", 60.0], ["crab_meat", 20.0], ["oyster", 12.0], ["sea_urchin", 8.0]]
const RARE := ["oyster", "sea_urchin"]
## Sleeping: health back a share of the most an interval; the day's clock runs this many times as fast (solo).
const SLEEP_HEAL := 0.05
const SLEEP_TIME := 30.0
## Danger close enough to end an activity: a sail (m), a Sea King (m), enemies in a fight (m).
const SAIL_NEAR := 160.0
const KING_NEAR := 140.0
const FOES_NEAR := 30.0
const SEA_KING := preload("res://scripts/enemies/sea_king.gd")


## The activities on the action wheel (ActionWheel.ensure_builtins). Static method callables, not lambdas.
## One list ashore and aboard; each says why it can't be done where you are (ActionWheel's greyed reason).
static func register_wheel() -> void:
	ActionWheel.register("lash", "Lash the helm", "", _lash_ok, lash, 5)
	ActionWheel.register("train", _train_label, "", _train_ok, _train, KINDS["train"]["order"])
	ActionWheel.register("read", KINDS["read"]["label"], "", _rest_ok, _read, KINDS["read"]["order"])
	ActionWheel.register("tinker", KINDS["tinker"]["label"], "", _rest_ok, _tinker, KINDS["tinker"]["order"])
	ActionWheel.register("fish", KINDS["fish"]["label"], "", _fish_ok, _fish, KINDS["fish"]["order"])
	ActionWheel.register("sleep", _sleep_label, "", _sleep_ok, _sleep, KINDS["sleep"]["order"])


static func _lash_ok(p) -> bool:
	return ActionWheel.place(p) == "helm"


## Aboard, the ship must keep without you (the reason if she won't; "" if she will).
static func _kept(p) -> String:
	var ship := ship_under(p)
	return "Lash the helm or drop anchor first" if ship and not looked_after(ship) else ""


## Reading and tinkering: aboard, or by a camp's fire.
static func _rest_ok(p):
	if not ActionWheel.on_foot(p):
		return false
	if ActionWheel.place(p) == "ship":
		return _first(_kept(p), ActionWheel.busy(p))
	return ActionWheel.busy(p) if Camp.near(p) else "Aboard or at camp"


static func _fish_ok(p):
	if not ActionWheel.on_foot(p):
		return false
	if ActionWheel.place(p) == "ship":
		return _first(_kept(p), ActionWheel.busy(p))
	return ActionWheel.busy(p) if Fishing.water_ahead(p) != Vector3.INF else "At the water's edge"


static func _sleep_label(p) -> String:
	return "Sleep by the fire" if ActionWheel.place(p) != "ship" and Camp.near(p) else KINDS["sleep"]["label"]


static func _sleep_ok(p):
	if not ActionWheel.on_foot(p):
		return false
	if ActionWheel.place(p) == "ship":
		return _first(_kept(p), ActionWheel.busy(p))
	return ActionWheel.busy(p) if Camp.near(p) else "In a bunk or at camp"


static func _first(a: String, b: String) -> String:
	return a if a != "" else b


## At the wheel: lash her to the heading she's on and step away (she holds it till someone takes the wheel).
static func lash(p) -> void:
	var ship: Ship = p.current_ship
	Net.lash_helm(true, ship._heading)
	p.call("_toast", "Helm lashed - she'll hold this heading. Take the wheel to cast it off.")
	p.state_machine.force_state("Idle", {})


static func _train_label(p) -> String:
	return "Train (%s)" % SkillTree.TREES[SkillTree.style_tree(p.style())]["name"] if _train_tree(p) != "" else "Train"


## Training: anywhere you're on your feet, aboard with nobody at the wheel too.
static func _train_ok(p):
	if not ActionWheel.on_foot(p):
		return false
	return "Nothing to train in that shape" if _train_tree(p) == "" else ActionWheel.busy(p)


static func _train(p) -> void:
	start(p, "train")


static func _read(p) -> void:
	start(p, "read")


static func _tinker(p) -> void:
	start(p, "tinker")


static func _fish(p) -> void:
	start(p, "fish")


static func _sleep(p) -> void:
	start(p, "sleep")


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
	if ship and not looked_after(ship) and kind != "train":
		return "Lash the helm or drop anchor first (N at the wheel)"
	return danger(p, kind)


## The crew's ship if `p` stands aboard her.
static func ship_under(p) -> Ship:
	var ship := p.get_tree().get_first_node_in_group("ship") as Ship
	return ship if ship and ship.aboard(p.global_position) else null


## She'll keep without you: lashed, anchored, a crewmate at the wheel, or lying still.
static func looked_after(ship: Ship) -> bool:
	return ship.lashed or ship.anchored or ship.helm_other or (ship.sail <= 0.0 and absf(ship.speed) < 0.5)


## What ends downtime now ("" = nothing): the reason, said to the captain. (Training aboard needs nobody
## at the wheel: a swordsman drills on a deck under way.)
static func danger(p, kind := "") -> String:
	var tree: SceneTree = p.get_tree()
	var at: Vector3 = p.global_position
	var ship := ship_under(p)
	if ship:
		if p.get_node("/root/Weather").storm > LashedHelm.STORM:
			return "A storm's coming on - all hands!"
		if not looked_after(ship) and kind != "train":
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


## Seconds between rewards (the bite perk shortens fishing's).
static func every(p, kind: String) -> float:
	var s: float = KINDS[kind]["every"]
	return s * (1.0 - p.progression.stat("fish_bite_pct")) if kind == "fish" else s


## One interval's reward for `kind` (the local captain's).
static func reward(p, kind: String) -> void:
	var pr = p.progression
	match kind:
		"train":
			pr.add_mastery(_train_tree(p), TRAIN_MASTERY)
		"read":
			pr.add_xp(READ_XP)
			var n := int(pr.downtime.get("read_n", 0)) + 1
			pr.downtime["read_n"] = n
			if n == RECIPE_AT and Food.teach(pr, RECIPE):
				p.call("_toast", "In the margins, in a cook's hand: a recipe! %s (the galley)" % Food.MEALS[RECIPE]["name"])
			elif n % LORE_EVERY == 0:
				p.call("_toast", LORE[(n / LORE_EVERY - 1) % LORE.size()])
		"tinker":
			var was: float = pr.kit_left
			pr.kit_left = minf(was + KIT_PER, KIT_MAX)
			if was <= 0.0:
				p.call("_recalc_stats")
			p.call("_toast", "Kit tuned: a spare shot, quicker reloads, +4%% damage (%d min)" % ceili(pr.kit_left / 60.0))
		"fish":
			_catch(p)
		"sleep":
			var hc = p.health_component
			hc.heal(hc.max_health * SLEEP_HEAL)


## Every tick of `kind` (the local captain's): sleeping runs the day's clock on (solo; in co-op the clock is
## the crew's).
static func tick(p, kind: String, delta: float) -> void:
	if kind == "sleep" and not Net.coop():
		p.get_node("/root/Weather").world_offset += delta * (SLEEP_TIME - 1.0)


## The tinkered kit wearing off (Progression._physics_process, game time).
static func tick_kit(pr, delta: float) -> void:
	pr.kit_left -= delta
	if pr.kit_left > 0.0:
		return
	pr.kit_left = 0.0
	pr.player.call("_recalc_stats")
	pr.player.call("_toast", "Your kit's worn back to plain")


## A bite: landed (an ingredient tagged fish; the double perk brings two) or lost; Fishing either way.
static func _catch(p) -> void:
	var pr = p.progression
	p.body_model.play("dt_fish_reel", 0.8)
	var line: Vector3 = p.global_position - p.player_model.global_basis.z * 2.6
	Net.fx("splash", [Vector3(line.x, 0.0, line.z), 6, 0.5])
	if randf() < FISH_LOST * (1.0 - pr.stat("fish_reel_pct")):
		pr.add_life("fish", FISH_LOST_XP)
		p.call("_toast", "It got away...")
		return
	var rare: float = 1.0 + pr.stat("fish_rare_pct")
	var total := 0.0
	for c in CATCH:
		total += float(c[1]) * (rare if c[0] in RARE else 1.0)
	var roll := randf() * total
	var id: String = CATCH[0][0]
	for c in CATCH:
		roll -= float(c[1]) * (rare if c[0] in RARE else 1.0)
		if roll <= 0.0:
			id = c[0]
			break
	var n := 2 if randf() < pr.stat("fish_double") else 1
	var item := ItemDB.get_item(id)
	pr.add_life("fish", FISH_XP)
	if p.inventory_component.room_for(item) < n:
		p.call("_toast", "A %s - but your bag's full, so back it goes" % item.display_name)
		return
	p.inventory_component.add_item(item, n)
	p.call("_toast", "Caught %s%s!" % ["two of " if n == 2 else "", item.display_name])


## The body's loop for `kind` (DowntimePoses; reading is the Blender clip pilot's, ClipPlayer).
static func pose_of(p, kind: String) -> String:
	match kind:
		"train":
			var st: String = p.style()
			if st in ["pistol", "dual_pistol"]:
				return "dt_train_gun"
			return "dt_train_fist" if st == "fist" else "dt_train_blade"
		"read":
			return "clip_read"
	return "dt_" + kind


## Sat on a crate (Humanoid's bench sit at this height), or 0 standing.
static func seat_of(kind: String) -> float:
	return 0.45 if kind in ["read", "tinker"] else 0.0


## Where `kind` takes you aboard: [ship-local spot, ship-local yaw], or [] to stay where you stand.
## Fishing: the rail of the side you're nearer, facing out. Sleeping: lying in the cabin's bunk, the head to
## the pillow (+Z).
static func spot(p, kind: String, ship: Ship) -> Array:
	match kind:
		"sleep":
			return [Vector3(Ship.BED_AT.x, Ship.BED_AT.y + 0.53, Ship.BED_AT.z - 0.15), 0.0]
		"fish":
			var l: Vector3 = ship.global_transform.affine_inverse() * p.global_position
			var side := 1.0 if l.x >= 0.0 else -1.0
			var z := clampf(l.z, -7.5, 3.5)
			return [Vector3(side * (HullBuilder.half_width(z) - 0.62), Ship.DECK_Y, z), -side * PI * 0.5]
	return []


## Where you get up to (ship-local) after `kind` took you to its spot.
static func leave_spot(kind: String, at: Vector3) -> Vector3:
	if kind == "sleep":
		return Vector3(Ship.BED_AT.x + 0.95, Ship.DECK_Y + 0.05, Ship.BED_AT.z)
	return Vector3(at.x * 0.9, at.y + 0.05, at.z)
