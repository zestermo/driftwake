class_name EdyTree
extends RefCounted
## The Edy tree (1.26, docs/v1_26_plan.md round 3; the mock: https://claude.ai/artifact/91LwPHU2X7A7vxbLCP6ifa): one round
## constellation in place of the Will paths. The Edy core (the captain's type, read by the master) sits in the middle;
## eight branches go out round it, each splitting into two paths that meet at its big node; between neighbours two
## bridge nodes (a stat inside, a passive further out) reachable from either side. Anything linked to what you own can be
## bought with Edy points (Progression pool "will"). Four kinds:
##   stat     a plain bonus, always on                                     (SkillTrees kind "auto")
##   auto     a passive that works by itself; `switch`: you can turn it off (kind "auto")
##   equip    a passive that takes one of your passive slots              (kind "passive")
##   ability  a skill for the bar                                         (kind "tech", its `skill`)
## Abilities and some autos rank up by use (`tiers`: [name, uses, desc, effects], the effects replacing the rank before's;
## Progression.edy_uses counts them, `use()` from where each is used). Nodes are SkillTrees nodes (tree "captain",
## pool "will"), laid out round the core (`pos`), so the Captain page, saves and the bar take them like any other.

const CORE := "e_core"
## Branches in order round the circle (clockwise from the top).
const BRANCHES := ["iron", "sense", "conq", "tide", "tempo", "fury", "bond", "infuse"]
const BRANCH_NAMES := {"iron": "Iron Will", "sense": "Sense", "conq": "Captain's Will", "tide": "Tide", "tempo": "Tempo",
	"fury": "Fury", "bond": "Bond", "infuse": "Infusion"}
const BRANCH_SUBS := {"iron": "Edy through body and blade", "sense": "Read what's coming", "conq": "A will others bend to",
	"tide": "The sea answers you", "tempo": "Fight to your own beat", "fury": "Hurt makes you harder",
	"bond": "Your crew is your strength", "infuse": "Your Edy in every blow"}
## Each branch's seven nodes take these places: [ring, offset in half-sectors, links (slots, or "core")]. Two paths out
## of the first node that meet again at the fifth (slot 5), the capstone beyond.
const SLOTS := [[1, 0.0, ["core"]], [2, -0.42, [0]], [2, 0.42, [0]], [3, -0.42, [1]], [3, 0.42, [2]], [4, 0.0, [3, 4]], [5, 0.0, [5]]]
const RING := [0.0, 150.0, 228.0, 306.0, 384.0, 470.0]

## branch -> its seven nodes in slot order: [kind, name, cost, desc, effects, extra]. extra: "skill", "tiers", "switch".
const NODES := {
	"iron": [
		["stat", "Iron Body I", 1, "+15 max health.", {"max_hp": 15.0}, {}],
		["ability", "Infuse", 2, "Pour your Edy into your weapon or fists: infused blows can't be blocked and land harder (the skill).", {}, {"skill": "armament_coat", "tiers": [
			["Hardened", 25, "Infused blows land another 15% harder.", {"coat_dmg": 0.15}],
			["Overflow", 80, "And an infused heavy bursts out round the one it hits, through their guards.", {"coat_dmg": 0.15, "coat_burst": 1}]]}],
		["ability", "Reinforce", 1, "Edy through your whole body for 15 s: quicker, lighter on stamina, harder, and light blows don't rock you (the skill).", {}, {"skill": "edy_reinforce"}],
		["auto", "Iron Reflex", 2, "A blow that would knock you down hardens you instead for 1.5 s. Once every 15 s.", {"iron_reflex": 1}, {"switch": true}],
		["equip", "Inner Strike", 2, "Your heavy attacks can't be blocked, hit 8% harder and stagger what they hit.", {"armament": 1, "damage_pct": 0.08, "inner_strike": 1}, {}],
		["auto", "Emission", 3, "While infused, a heavy attack throws a line of Edy 6 m ahead.", {"emission": 1}, {"switch": true, "tiers": [
			["Ring", 20, "The coated heavy bursts a ring of Edy 4 m round you instead.", {"emission": 2}],
			["Stomp", 60, "It stamps a 3.5 m quake round you that knocks guards and shields aside.", {"emission": 3}]]}],
		["equip", "Mirror Guard", 4, "A perfect parry sends the blow back: the attacker takes it, through any guard.", {"mirror_guard": 1}, {}],
	],
	"sense": [
		["stat", "Keen Eye I", 1, "Your parry window is a little wider.", {"parry_all": 0.04}, {}],
		["auto", "Flash", 2, "Foes flash red as they start an attack.", {"observation": 1}, {"switch": true}],
		["stat", "Keen Eye II", 1, "4% of the blows that would hit you miss.", {"evade_chance": 0.04}, {}],
		["auto", "Foresight", 2, "Once every 20 s, a blow that would hit you is dodged by itself.", {"foresight_auto": 20.0}, {"switch": true, "tiers": [
			["Second Sight", 40, "Every 14 s, and a dodge it makes slows time a moment so you can answer.", {"foresight_auto": 14.0, "foresight_slow": 0.4}],
			["Future Sight", 150, "Every 8 s, and every foe near you flashes as it starts an attack.", {"foresight_auto": 8.0, "foresight_slow": 0.4, "crowd_read": 1, "observation": 1}]]}],
		["ability", "Glimpse", 2, "For 3 s you see foes and closed chests within 40 m through walls (the skill).", {}, {"skill": "will_glimpse", "tiers": [
			["Weak Point", 20, "And a boss's breakable parts stay marked while you're near it.", {"weak_point": 1}]]}],
		["equip", "Gunsight", 2, "Guns and bosses' big moves flash too, and every flash comes earlier.", {"observation": 1, "flash_shots": 1, "flash_boss": 1, "flash_early": 1}, {}],
		["equip", "Crowd Read", 4, "Every foe within 20 m flashes as it starts an attack; after a perfect dodge you see them all.", {"crowd_read": 1, "observation": 1}, {}],
	],
	"conq": [
		["stat", "Presence I", 1, "+4% damage.", {"damage_pct": 0.04}, {}],
		["ability", "Roar", 2, "A king's will (the ultimate): weak foes round you drop; everyone else is thrown back, reeling.", {}, {"skill": "conquerors_haki", "tiers": [
			["Far Roar", 15, "The roar reaches half again as far.", {"roar_reach": 0.5}]]}],
		["stat", "Presence II", 1, "+20 max health.", {"max_hp": 20.0}, {}],
		["equip", "Rally", 2, "While you fight, you and every crewmate within 12 m deal 10% more damage.", {"will_rally": 0.1}, {}],
		["auto", "Intimidate", 2, "Weak foes throw down their arms and run instead of fainting at your Roar. Your bounty rises.", {"intimidate": 1}, {"switch": true}],
		["ability", "Plant the Flag", 3, "For 20 s every captain within 6 m of your flag mends 3% of their health a second (the skill).", {}, {"skill": "will_flag"}],
		["auto", "Clash", 4, "Two big Edy attacks meeting start a clash won by timed presses.", {"will_clash": 1}, {}],
	],
	"tide": [
		["stat", "Deep Lungs", 1, "Half again the breath on a dive.", {"breath_pct": 0.5}, {}],
		["auto", "Wave Walk", 2, "Run onto deep water and it holds you for 6 steps, then you swim.", {"wave_walk": 1}, {"switch": true}],
		["stat", "Strong Stroke", 1, "Swim 30% faster.", {"swim_pct": 0.3}, {}],
		["equip", "Helm Sense", 2, "While you steer, your ship's hull takes 20% less damage.", {"helm_sense": 0.2}, {}],
		["ability", "Swell", 2, "Aboard your ship: a wave rolls over the deck and throws every boarder off it (the skill).", {}, {"skill": "will_swell"}],
		["stat", "Sea Born", 1, "Another half of breath, and swim 15% faster.", {"breath_pct": 0.5, "swim_pct": 0.15}, {}],
		["ability", "Call the Wind", 4, "Aboard or beside your ship: 25% more sail speed for 30 s (the skill).", {}, {"skill": "will_wind"}],
	],
	"tempo": [
		["stat", "Light Feet", 1, "+4% move speed.", {"move_pct": 0.04}, {}],
		["auto", "Second Step", 2, "One more jump in mid-air.", {"air_jumps": 1}, {"switch": true}],
		["stat", "Wind", 1, "Sprinting costs 10% less stamina.", {"sprint_cost_pct": 0.1}, {}],
		["equip", "Cancel", 2, "Dodge out of a combo blow's recovery as soon as its hit lands.", {"dash_cancel": 1}, {}],
		["equip", "Flow", 2, "Every blow you land while unhit makes your attacks 2% faster, up to 20%; a blow on you breaks it.", {"will_flow": 1}, {}],
		["ability", "Still Point", 3, "Foes within 20 m move and strike at half speed for 3 s (the skill).", {}, {"skill": "will_still_point"}],
		["stat", "Perfect Rhythm", 4, "Your dodge and parry windows are wider.", {"dodge_iframe_pct": 0.1, "parry_all": 0.03}, {}],
	],
	"fury": [
		["stat", "Heavy Hand", 1, "Heavy attacks hit 4% harder.", {"heavy_pct": 0.04}, {}],
		["auto", "Red Mist", 2, "+1% damage for every 4% of your health missing.", {"red_mist": 1}, {"switch": true}],
		["stat", "Thick Hide", 1, "+15 max health.", {"max_hp": 15.0}, {}],
		["ability", "Berserk", 2, "For 10 s your blows heal you 4% of their damage, and blows on you land 20% harder (the skill).", {}, {"skill": "will_berserk"}],
		["equip", "Thick Blood", 2, "Bleeding, burning and poison hurt you half as much.", {"thick_blood": 0.5}, {}],
		["stat", "Last Stand", 1, "Hit harder while you're low on health.", {"adrenaline": 0.06}, {}],
		["equip", "Unbowed", 4, "Once a fight, a blow that would fell you leaves you at 1 health, and nothing touches you for 2 s.", {"unbowed": 1}, {}],
	],
	"bond": [
		["stat", "Steady Hands", 1, "Get crewmates up 15% faster.", {"revive_pct": 0.15}, {}],
		["equip", "Link", 2, "Tethered to the nearest crewmate within 15 m, you take 15% of every blow on them (alone: your ship's hull takes 15% of yours).", {"will_link": 1}, {}],
		["stat", "Shoulder to Shoulder", 1, "+4 defense.", {"defense": 4.0}, {}],
		["equip", "Shelter", 2, "A crewmate within 3 m who's down or under 30% health takes nothing: the blow is yours.", {"shelter": 1}, {}],
		["auto", "Crew's Strength", 2, "+4% damage for every crewmate within 20 m (alone: your ship).", {"crew_strength": 0.04}, {"switch": true}],
		["stat", "Joint Gauge", 1, "The joint gauge for Twin Finisher fills with your link near.", {"joint_gauge": 1}, {}],
		["ability", "Twin Finisher", 4, "Gauge full: you and your link strike as one (the skill).", {}, {"skill": "will_twin"}],
	],
	"infuse": [
		["auto", "Edy Techniques", 1, "Switchable. Your techniques and ultimates carry your Edy: its look and 8% more damage, for 2 more energy each.", {"edy_tech": 1}, {"switch": true}],
		["stat", "Deep Well", 1, "+15 max energy.", {"max_energy": 15.0}, {}],
		["stat", "Steady Flow", 1, "Energy comes back 20% faster.", {"energy_regen_pct": 0.2}, {}],
		["auto", "Edy Strikes", 2, "Switchable. Your plain attacks carry your Edy too: its look and 5% more damage, half an energy a blow (plain again at none).", {"edy_strikes": 1}, {"switch": true}],
		["stat", "Dense Edy", 1, "Infused blows and techniques hit 6% harder; Reinforce gives 2 more defense.", {"edy_dense": 0.06}, {}],
		["stat", "Second Wind", 2, "Every infused blow that lands gives back a third of an energy.", {"edy_regain": 0.3}, {}],
		["auto", "Brimming", 4, "While your energy is above 80%, infusing costs nothing.", {"edy_brimming": 1}, {}],
	],
}
## Between branch i and i+1: [the inner stat, the outer passive] (same shape as NODES).
const BRIDGES := [
	[["stat", "Steady Guard", 1, "+3 defense, and a wider parry window.", {"defense": 3.0, "parry_all": 0.02}, {}],
		["equip", "Read and Strike", 2, "Every flash comes earlier, and you hit 3% harder.", {"flash_early": 1, "damage_pct": 0.03}, {}]],
	[["stat", "Clear Head", 1, "+10 max energy.", {"max_energy": 10.0}, {}],
		["equip", "Called Shot", 2, "You and every crewmate within 12 m deal 5% more damage.", {"will_rally": 0.05}, {}]],
	[["stat", "Weathered", 1, "+10 max health.", {"max_hp": 10.0}, {}],
		["auto", "Flag Over Water", 2, "While you steer, your ship's hull takes 10% less damage.", {"helm_sense": 0.1}, {}]],
	[["stat", "Swift Water", 1, "Swim 15% faster and move 2% faster.", {"swim_pct": 0.15, "move_pct": 0.02}, {}],
		["auto", "Rolling Gait", 2, "Sprinting costs a quarter less stamina.", {"sprint_cost_pct": 0.25}, {}]],
	[["stat", "Quick Temper", 1, "Heavy attacks hit 3% harder.", {"heavy_pct": 0.03}, {}],
		["equip", "Slip", 2, "4% more of the blows that would hit you miss.", {"evade_chance": 0.04}, {}]],
	[["stat", "Blood Brothers", 1, "+10 max health.", {"max_hp": 10.0}, {}],
		["auto", "Avenge", 2, "You hit 3% harder.", {"damage_pct": 0.03}, {}]],
	[["stat", "Shared Well", 1, "+10 max energy.", {"max_energy": 10.0}, {}],
		["equip", "Kindred Edy", 2, "+3% damage for every crewmate within 20 m.", {"crew_strength": 0.03}, {}]],
	[["stat", "Tempered", 1, "Infused blows land 5% harder.", {"coat_dmg": 0.05}, {}],
		["equip", "Edy Armour", 2, "+5 defense.", {"defense": 5.0}, {}]],
]
const KIND := {"stat": "auto", "auto": "auto", "equip": "passive", "ability": "tech"}


static func node_id(branch: String, slot: int) -> String:
	return "e_%s_%d" % [branch, slot]


static func bridge_id(i: int, k: int) -> String:
	return "e_br%d_%d" % [i, k]


## Where a node sits in tree space (the core at 0, 0; y down is +, so the top branch is at -y).
static func pos_of(branch_i: int, ring: float, off: float) -> Vector2:
	var sec := TAU / BRANCHES.size()
	var a := -PI * 0.5 + branch_i * sec + off * sec * 0.5
	return Vector2(cos(a), sin(a)) * ring


## Every node of the tree: id -> {branch, slot, kind, name, cost, desc, effects, skill, tiers, switch, links, pos, bridge}.
static func all() -> Dictionary:
	var out := {}
	out[CORE] = {"branch": "", "slot": -1, "kind": "core", "name": "Edy", "cost": 0, "desc": "Your Edy, read by the master.",
		"effects": {}, "skill": "", "tiers": [], "switch": false, "links": [], "pos": Vector2.ZERO, "bridge": false}
	for bi in range(BRANCHES.size()):
		var b: String = BRANCHES[bi]
		var list: Array = NODES[b]
		for s in range(list.size()):
			var d: Array = list[s]
			var sl: Array = SLOTS[s]
			var links: Array = []
			for l in sl[2]:
				links.append(CORE if str(l) == "core" else node_id(b, int(l)))
			out[node_id(b, s)] = _make(d, b, s, links, pos_of(bi, RING[int(sl[0])], float(sl[1])), false)
	for i in range(BRIDGES.size()):
		var a: String = BRANCHES[i]
		var c: String = BRANCHES[(i + 1) % BRANCHES.size()]
		var inner: Array = BRIDGES[i][0]
		var outer: Array = BRIDGES[i][1]
		out[bridge_id(i, 0)] = _make(inner, a, -1, [node_id(a, 2), node_id(c, 1)], pos_of(i, (RING[2] + RING[3]) * 0.5, 1.0), true)
		out[bridge_id(i, 1)] = _make(outer, a, -1, [node_id(a, 4), node_id(c, 3)], pos_of(i, (RING[3] + RING[4]) * 0.5 + 10.0, 1.0), true)
	return out


static func _make(d: Array, branch: String, slot: int, links: Array, pos: Vector2, bridge: bool) -> Dictionary:
	var extra: Dictionary = d[5]
	return {"branch": branch, "slot": slot, "kind": str(d[0]), "name": str(d[1]), "cost": int(d[2]), "desc": str(d[3]),
		"effects": d[4], "skill": str(extra.get("skill", "")), "tiers": extra.get("tiers", []), "switch": bool(extra.get("switch", false)),
		"links": links, "pos": pos, "bridge": bridge}


static var _all: Dictionary = {}
static var _adj: Dictionary = {}


static func info(id: String) -> Dictionary:
	if _all.is_empty():
		_all = all()
		for k in _all.keys():
			_adj[k] = []
		for k in _all.keys():
			for l in _all[k]["links"]:
				(_adj[k] as Array).append(l)
				(_adj[l] as Array).append(k)
	return _all.get(id, {})


static func is_edy(id: String) -> bool:
	return id.begins_with("e_") and not info(id).is_empty()


static func neighbours(id: String) -> Array:
	info(id)
	return _adj.get(id, [])


## Why node `id` can't be bought now ("" = it can): the Edy read, a link to something you own (the core is yours once
## read), the points.
static func why(pr, id: String) -> String:
	var n := info(id)
	if n.is_empty():
		return "Unknown"
	if pr.bought.has(id):
		return "Learned"
	if str(pr.will_color) == "":
		return "Your Edy isn't read yet: see the master at Brinehollow's shrine"
	if not neighbours(id).any(func(l): return l == CORE or pr.bought.has(l)):
		return "Learn a node linked to it first"
	if int(n["cost"]) > pr.pool("will"):
		return "Needs %d Edy point%s" % [int(n["cost"]), "" if int(n["cost"]) == 1 else "s"]
	return ""


## The rank (1..) of a tiered node by its uses, and the effects that rank gives (each tier's effects replace the last's).
static func rank(pr, id: String) -> int:
	var tiers: Array = info(id).get("tiers", [])
	var u := int(pr.edy_uses.get(id, 0))
	var r := 1
	for i in range(tiers.size()):
		if u >= int(tiers[i][1]):
			r = i + 2
	return r


static func effects(pr, id: String) -> Dictionary:
	var n := info(id)
	if n.is_empty():
		return {}
	if pr.edy_off.has(id):
		return {}
	var r := rank(pr, id)
	if r <= 1:
		return n["effects"]
	var e: Dictionary = (n["effects"] as Dictionary).duplicate()
	e.merge(n["tiers"][r - 2][3], true)
	return e


## Node `id` used once (an ability cast, a foresight dodge...): its uses count toward its next rank, with a toast as
## one's reached (the captain's own machine).
static func use(p, id: String, n := 1) -> void:
	if p == null or p.get("progression") == null or not p.progression.bought.has(id):
		return
	var pr = p.progression
	var before := rank(pr, id)
	pr.edy_uses[id] = int(pr.edy_uses.get(id, 0)) + n
	var after := rank(pr, id)
	if after > before:
		var t: Array = info(id)["tiers"][after - 2]
		pr._dirty()
		if p.has_method("_toast"):
			p.call("_toast", "%s ranks up: %s (rank %s)" % [info(id)["name"], str(t[0]), ["I", "II", "III", "IV"][after - 1]])


## The tiered node an ability's skill belongs to ("" none).
static func of_skill(skill: String) -> String:
	info(CORE)
	for k in _all.keys():
		if str(_all[k]["skill"]) == skill:
			return k
	return ""


## (tests, tools) Buys the shortest chain of nodes from what `pr` owns (or the core) to `id`, gifting nothing: false if
## the points run out or something on the way can't be bought.
static func learn_path(pr, id: String) -> bool:
	info(CORE)
	if pr.bought.has(id):
		return true
	var from := {CORE: ""}
	var q: Array = [CORE]
	for k in pr.bought.keys():
		if is_edy(str(k)):
			from[str(k)] = ""
			q.append(str(k))
	while not q.is_empty():
		var c: String = q.pop_front()
		if c == id:
			break
		for n in neighbours(c):
			if not from.has(n):
				from[n] = c
				q.append(n)
	if not from.has(id):
		return false
	var chain: Array = []
	var c := id
	while c != "" and c != CORE and not pr.bought.has(c):
		chain.push_front(c)
		c = str(from[c])
	for k in chain:
		if not pr.buy(k):
			return false
	return pr.bought.has(id)
