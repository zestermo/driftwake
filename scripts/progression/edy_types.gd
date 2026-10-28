class_name EdyTypes
extends RefCounted
## Edy (1.24.1, docs/edy_plan.md): Driftwake's own word for the inner force the Will paths train (from an eddy: the water
## swirling round on itself). Every captain is attuned to one type of Edy, read by a master's questions (Hana at
## Brinehollow's teahouse the first time; Ilse Varro on the capital's terrace re-reads it for gold). The type is the
## colour and shape of everything their Edy does, and a small edge for one way of fighting. Saved as
## Progression.will_color (the type's id; "" until read). Edy points are WillPaths' "will" pool.

## id -> name, colour, the look of its effects, the edge (effects summed into Progression.stat), the edge said plainly,
## and the master's line when it's read.
const TYPES := {
	"still": {"name": "Still", "color": Color(0.42, 0.66, 1.0), "look": "haze", "edge": {"dodge_iframe_pct": 0.1, "parry_all": 0.03},
		"says": "Dodge and parry windows a little wider.", "read": "Still water. You wait, and the blow passes through the place you were."},
	"ember": {"name": "Ember", "color": Color(0.92, 0.2, 0.16), "look": "crackle", "edge": {"heavy_pct": 0.04},
		"says": "Heavy attacks hit 4% harder.", "read": "Ember. It burns low until you need it, and then it burns everything."},
	"crown": {"name": "Crown", "color": Color(1.0, 0.8, 0.3), "look": "shimmer", "edge": {"ult_charge_pct": 0.05},
		"says": "Your ultimate charges 5% faster.", "read": "Crown. You want the last word in every fight, and you usually get it."},
	"storm": {"name": "Storm", "color": Color(0.46, 0.2, 0.7), "look": "lightning", "edge": {},
		"says": "+3% attack speed for 2 s after a dodge.", "read": "Storm. Never still for long. You strike before the thunder."},
	"tide": {"name": "Tide", "color": Color(0.2, 0.78, 0.66), "look": "swirl", "edge": {"revive_pct": 0.1, "bond_gauge_pct": 0.05},
		"says": "Get crewmates up 10% faster; Bond's gauge fills 5% faster.", "read": "Tide. It comes back for the ones it carries. So do you."},
}
const ORDER := ["still", "ember", "crown", "storm", "tide"]
## Before it's read: a pale lilac.
const UNREAD := Color(0.79, 0.66, 1.0)
## The colours picked before 1.24.1 become types.
const OLD := {"blue": "still", "red": "ember", "gold": "crown", "black": "storm"}
## Storm's edge: this much attack speed for STORM_SECS after a dodge starts.
const STORM_HASTE := 0.03
const STORM_SECS := 2.0
## The capital's re-reading.
const REREAD_GOLD := 2000

## The master's questions: [question, [[answer, types it counts for], ...]]. The type with the most wins; a tie goes to
## the one answered last.
const QUIZ := [
	["When you've focused hard on something, how do you feel afterwards?", [
		["Calm. Clear, like after rain.", ["still"]], ["Spent, like after a rage.", ["ember"]],
		["Proud. It's done, and I did it.", ["crown"]], ["Restless. Ready for the next.", ["storm"]]]],
	["A wave knocks you flat. What do you do?", [
		["Let it carry me, and stand when it's passed.", ["still", "tide"]], ["Get up angry.", ["ember"]],
		["Laugh, and get up first.", ["crown"]], ["I'm already moving.", ["storm"]]]],
	["Your crew is losing a fight. You...", [
		["Hold the line for them.", ["tide"]], ["Charge the biggest one.", ["ember"]],
		["Call the orders.", ["crown"]], ["Find the gap.", ["storm"]]]],
	["What do you hear in a storm?", [
		["Nothing. It's quiet inside.", ["still"]], ["The thunder.", ["storm"]],
		["The crew's voices.", ["tide"]], ["A challenge.", ["crown"]]]],
	["If you could keep only one, which?", [
		["A calm sea.", ["still"]], ["A sharp blade.", ["ember"]], ["A flag.", ["crown"]],
		["A fast ship.", ["storm"]], ["My friends.", ["tide"]]]],
]


static func info(id: String) -> Dictionary:
	return TYPES.get(id, {})


static func color_of(id: String) -> Color:
	return TYPES[id]["color"] if TYPES.has(id) else UNREAD


static func name_of(id: String) -> String:
	return str(TYPES[id]["name"]) if TYPES.has(id) else "Unread"


## The type's edge for a Progression.stat key (0 for keys it doesn't touch).
static func bonus(id: String, key: String) -> float:
	return float(TYPES[id]["edge"].get(key, 0.0)) if TYPES.has(id) else 0.0


## Storm's attack speed now: STORM_HASTE for STORM_SECS after the last dodge (Player meta "edy_dodge_tick", the
## physics tick it started; no class names here: Progression loads this before the autoloads exist).
static func haste(p: Node) -> float:
	if p == null or p.get("progression") == null or p.progression.will_color != "storm" or not p.has_meta("edy_dodge_tick"):
		return 0.0
	var ticks := Engine.get_physics_frames() - int(p.get_meta("edy_dodge_tick"))
	return STORM_HASTE if ticks <= int(STORM_SECS * Engine.physics_ticks_per_second) else 0.0


## The type the answers point to (`counts`: id -> score, `last`: the types of the last answer). "" if none.
static func winner(counts: Dictionary, last: Array) -> String:
	var best := ""
	var top := -1
	for id in ORDER:
		var n := int(counts.get(id, 0))
		if n > top or (n == top and id in last and not (best in last)):
			best = id
			top = n
	return best if top > 0 else ""


## The quiz as dialogue nodes, under `prefix`: "<prefix>q0" asks the first question; each answer counts its types
## (the event "edy:+<types>") and goes on; after the last the type is read (`read_event`: "edy:read", or "edy:reread"
## for the paid re-reading; Progression keeps the counts) and the talk goes to `after`.
static func quiz_nodes(prefix: String, after: String, read_event: String = "edy:read") -> Dictionary:
	var nodes := {}
	for i in range(QUIZ.size()):
		var q: Array = QUIZ[i]
		var choices: Array = []
		for j in range(q[1].size()):
			var a: Array = q[1][j]
			var id := "%sq%d_%d" % [prefix, i, j]
			choices.append({"text": a[0], "next": id})
			var next := "%sq%d" % [prefix, i + 1] if i + 1 < QUIZ.size() else prefix + "read"
			nodes[id] = {"text": ["Mm."] if i % 2 == 0 else ["I see."], "event": "edy:+" + ",".join(a[1]), "next": next}
		nodes["%sq%d" % [prefix, i]] = {"text": q[0], "choices": choices}
		if i == 0:
			nodes["%sq0" % prefix]["event"] = "edy:reset"
	nodes[prefix + "read"] = {"text": ["{edy_read}", "{edy_says}"], "event": read_event, "next": after}
	return nodes


## A burst of the captain's Edy round them, in its type's colour and shape (an Edy buff starting, a big Edy move, the
## reading itself), on every screen: Still a haze rising, Ember sparks crackling up, Crown a gold shimmer and glint,
## Storm forked bolts, Tide a ring turning underfoot. `k` scales it; `at_pos` puts it somewhere else (an infused blow
## landing on its target).
static func burst(p: Node3D, k: float = 1.0, at_pos := Vector3.INF) -> void:
	var net := p.get_node_or_null("/root/Net")
	if net == null:
		return
	var id: String = str(p.progression.will_color) if p.get("progression") else ""
	var col := color_of(id)
	var at := p.global_position + Vector3(0, 1.1, 0) if at_pos == Vector3.INF else at_pos
	match str(TYPES.get(id, {}).get("look", "")):
		"haze":
			net.fx("puff", [at - Vector3(0, 0.6, 0), "mist", int(4 * k), 1.0 * k, 0.9, Color(col, 0.55), 0.8])
			net.fx("sparkle", [at, int(10 * k), col.lightened(0.3)])
		"crackle":
			net.fx("embers", [at - Vector3(0, 0.5, 0), Vector3.UP, int(14 * k), col, 4.0])
			net.fx("sparkle", [at, int(12 * k), col])
		"shimmer":
			net.fx("glint", [at + Vector3(0, 0.4, 0), col.lightened(0.4), 0.9 * k])
			net.fx("sparkle", [at, int(20 * k), col])
		"lightning":
			for i in range(int(3 * k)):
				var a := TAU * (i + 0.3) / maxf(3.0 * k, 1.0)
				var off := Vector3(cos(a), 0.0, sin(a)) * 0.9
				net.fx("bolt", [at + Vector3(0, 0.7, 0), at - Vector3(0, 1.0, 0) + off, col.lightened(0.25), 0.06, 0.2, i, true])
			net.fx("sparkle", [at, int(8 * k), col.lightened(0.4)])
		"swirl":
			net.fx("ring", [p.global_position + Vector3(0, 0.08, 0), Vector3.UP, 1.4 * k, col, 0.5, 0.1])
			net.fx("ring", [p.global_position + Vector3(0, 0.12, 0), Vector3.UP, 0.8 * k, col.lightened(0.3), 0.4, 0.08])
			net.fx("sparkle", [at, int(10 * k), col])
		_:
			net.fx("sparkle", [at, int(18 * k), col])


## The captain's Edy aura on their body for `secs` (EdyAura, on every screen): "arms" for Infuse, "body" for Reinforce
## and a big move's flare.
static func aura(p: Node3D, part: String, secs: float) -> void:
	var net := p.get_node_or_null("/root/Net")
	var body = p.get("body_model")
	if net == null or body == null or p.get("progression") == null:
		return
	var id := str(p.progression.will_color)
	net.fx("edy_aura", [body, part, secs, color_of(id), str(TYPES.get(id, {}).get("look", "haze"))])


## Powering up (Infuse, Reinforce): a wind blast off the captain, a shockwave ring and dust thrown out, in their Edy's
## colour, with a punch of the camera on their own screen.
static func blast(p: Node3D, k: float = 1.0) -> void:
	var net := p.get_node_or_null("/root/Net")
	if net == null:
		return
	var col := color_of(str(p.progression.will_color)) if p.get("progression") else UNREAD
	var at := p.global_position
	net.fx("ring", [at + Vector3(0, 0.15, 0), Vector3.UP, 3.2 * k, col, 0.35, 0.2])
	net.fx("ring", [at + Vector3(0, 1.0, 0), Vector3.UP, 2.0 * k, col.lightened(0.4), 0.25, 0.1])
	net.fx("dust_ring", [at, int(16 * k), 1.3 * k])
	net.fx("puff_ring", [at + Vector3(0, 0.1, 0), "dust_low", 10, 0.4, 1.2, 0.6, Color(1, 1, 1, 0.8), 7.0 * k])
	burst(p, k)
	if p.has_method("cam_shake"):
		p.call("cam_shake", 0.18 * k)
