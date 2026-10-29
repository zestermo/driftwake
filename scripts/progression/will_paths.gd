class_name WillPaths
extends RefCounted
## Will (1.23, docs/v1_23_previews.md section 2): points from big fights and meditation, spent on three paths. No
## Will is tied to a boss or a theme. Each captain's own (Progression.will_earned, saved with the captain).
##   iron   Iron Will: Infuse (tier 1, was Coat) and Reinforce (1, was the passive Hardening), Emission (2),
##          Inner Strike (3); no passive
##   sense  Sense: Flash (1), Foresight (2), Crowd Read (3); its passive Instinct
##   conq   Captain's Will: Roar (2), Clash (3); its passive King's Will (needs 4 Will spent in each of the others)
## 1.24 (docs/v1_24_previews.md section 2), always open, tiers by all the Will spent (OPEN); at work in WillPowers / WillArts:
##   tide   Tide: Deep Breath (1), Sea Legs: Wave Walk / Swell (2), Call the Wind (3); its passive Helm Sense
##   tempo  Tempo: Second Step (1), Rhythm: Cancel / Flow (2), Still Point (3); its passive Light on Your Feet
##   fury   Fury: Red Mist (1), Berserk (2), Unbowed (3); its passive Thick Blood
##   bond   Bond: Link (1), Side by Side: Joint Gauge / Shelter (2), Twin Finisher (3); its passive Crew's Strength
## A tier's ability has versions, each bought for the tier's points (1, 2, 3); the first bought is the active one and
## the others are switched in at a rest spot (Progression.set_version). A path's next tier opens with Will spent in it
## (TIER_AT); the first path is free to pick, a second opens at SECOND_AT Will spent. A passive (PASSIVE_COST) needs the
## path's first ability. The nodes themselves are SkillTrees' (the Captain tree's Will branch, pool "will").

## Will points for a big fight (Net.bounty's kinds and the outposts'): a boss, villain, hunter or Leviathan 2; a rival
## captain, officer, sergeant or miniboss 1.
const SOURCES := {"boss": 2, "villain": 2, "hunter": 2, "leviathan": 2, "rival": 1, "officer": 1, "sergeant": 1, "miniboss": 1}
## Meditation (Downtime "meditate"): a point for every 3 game days spent meditating (game seconds).
const MEDITATE_SECS := 3.0 * 1440.0
const PATHS := ["iron", "sense", "conq", "tide", "tempo", "fury", "bond"]
const PATH_NAMES := {"iron": "Iron Will", "sense": "Sense", "conq": "Captain's Will", "tide": "Tide", "tempo": "Tempo", "fury": "Fury", "bond": "Bond"}
## The Will page's two sets of columns (A/D or a click flips them).
const PAGES := [["iron", "sense", "conq"], ["tide", "tempo", "fury", "bond"]]
## The 1.24 paths (docs/v1_24_previews.md section 2): five nodes each, always open, their tiers opened by all the Will
## you've spent (a path's own five nodes, 10 Will, can't reach 4 and 8 by themselves).
const OPEN := ["tide", "tempo", "fury", "bond"]
## Will spent that opens each tier (a path's first tier opens at 0: Captain's Will starts at tier 2): in the path, or
## in all for the OPEN paths.
const TIER_AT := {1: 0, 2: 4, 3: 8}
const SECOND_AT := 8
const CONQ_NEEDS := 4
const PASSIVE_COST := 2
## (The colours picked before 1.24.1 are Edy types now: EdyTypes.)

## The paths' abilities: id -> [path, tier, name, desc, versions: [[id, name, effects, desc, skill, chip label]]], in tier order.
const ABILITIES := {
	"w_coat": ["iron", 1, "Infuse", "Pour your Edy down your arms into your weapon or fists (the skill): infused blows can't be blocked and land 30% harder.", [
		["w_coat_heavy", "Heavy Infuse", {"coat_dmg": 0.15}, "Infused blows land another 15% harder.", "armament_coat", "Heavy"],
		["w_coat_quick", "Quick Infuse", {"cdr_armament_coat": 0.3}, "Infuse comes back 30% sooner, for a faster rhythm.", "armament_coat", "Quick"],
		["w_coat_break", "Breaking Infuse", {"coat_burst": 1}, "An infused heavy blow bursts out round the one it hits, through their guards.", "armament_coat", "Break"]]],
	"w_reinforce": ["iron", 1, "Reinforce", "Edy through your whole body (the skill): quicker, lighter on stamina, harder, and light blows don't rock you.", [
		["w_reinforce_v", "Reinforce", {}, "For 15 s: +10% speed, a quarter less stamina, +8 defense, and light blows don't make you flinch. Every minute.", "edy_reinforce", "Body"]]],
	"w_emit": ["iron", 2, "Emission", "Edy leaves the blade: while infused, a heavy attack strikes 6 m ahead too.", [
		["w_emit_line", "Emission: Line", {"emission": 1}, "A coated heavy throws a line of Will 6 m straight ahead.", "", "Line"],
		["w_emit_ring", "Emission: Ring", {"emission": 2}, "A coated heavy bursts a ring of Will 4 m round you.", "", "Ring"],
		["w_emit_stomp", "Stomp", {"emission": 3}, "A coated heavy stamps Will into the ground: a 3.5 m quake round you that knocks shields and guards aside.", "", "Stomp"]]],
	"w_inner": ["iron", 3, "Inner Strike", "Through guards and armour: your heavy attacks can't be blocked, hit 8% harder and stagger.", [
		["w_inner_v", "Inner Strike", {"armament": 1, "damage_pct": 0.08, "inner_strike": 1}, "Your heavy attacks can't be blocked, hit 8% harder and stagger what they hit.", "", "Strike"],
		["w_mirror", "Mirror Guard", {"mirror_guard": 1}, "A perfect block (a parry) sends the blow back: the attacker takes it, through any guard.", "", "Mirror"]]],
	"w_flash": ["sense", 1, "Flash", "Sense intent: foes flash red as they start an attack, and your parry window is a little wider.", [
		["w_flash_long", "Long Warning", {"observation": 1, "flash_early": 1}, "The flash comes earlier: more time to answer.", "", "Early"],
		["w_flash_shots", "Gunsight", {"observation": 1, "flash_shots": 1}, "Guns flash too, before the shot.", "", "Guns"],
		["w_flash_boss", "Big Moves", {"observation": 1, "flash_boss": 1}, "Bosses' big moves flash as well.", "", "Bosses"],
		["w_flash_ambush", "Ambush Sense", {"observation": 1, "ambush_sense": 1}, "A foe starting an attack behind you, out of sight, warns you: a mark over it and a sharp note.", "", "Ambush"]]],
	"w_fore": ["sense", 2, "Foresight", "Sense what's coming (the skill): the next blows that would hit you are dodged by themselves.", [
		["w_fore_sight", "Second Sight", {"foresight_charges": 1}, "Foresight dodges one more blow.", "foresight", "Second"],
		["w_fore_slow", "Slow Sight", {"foresight_slow": 0.6}, "A perfect dodge (a blow passing through you as you dodge) slows time for 0.6 s.", "foresight", "Slow"],
		["w_glimpse", "Glimpse", {}, "Glimpse (the skill, in Foresight's place): for 3 s you see foes and closed chests within 40 m through walls.", "will_glimpse", "Glimpse"]]],
	"w_crowd": ["sense", 3, "Crowd Read", "Read a whole crowd: every foe round you shows its next move.", [
		["w_crowd_v", "Crowd Read", {"crowd_read": 1, "observation": 1}, "Every foe within 20 m flashes as it starts an attack, and for 4 s after a perfect dodge you see them all.", "", "Read"],
		["w_weak", "Weak Point", {"weak_point": 1, "observation": 1}, "A boss's breakable parts are marked through everything while you're within 40 m of it.", "", "Weak"]]],
	"w_roar": ["conq", 2, "Roar", "A king's will (the ultimate): weak foes round you drop; everyone else is thrown back, reeling.", [
		["w_roar_king", "King's Roar", {}, "Weak foes faint on the spot.", "conquerors_haki", "King"],
		["w_roar_far", "Far Roar", {"roar_reach": 0.5}, "The roar reaches half again as far.", "conquerors_haki", "Far"],
		["w_roar_fear", "Intimidate", {"intimidate": 1}, "Weak foes don't faint: they throw down their arms and run. No loot from them, but your bounty rises.", "conquerors_haki", "Fear"]]],
	"w_clash": ["conq", 3, "Clash", "When two great wills meet, they clash: timed presses decide who breaks.", [
		["w_clash_v", "Clash", {"will_clash": 1}, "Two big Will attacks meeting (a boss's, a rival's or a crewmate's in a duel) start a clash won by timed presses.", "", "Clash"],
		["w_rally", "Rally", {"will_rally": 0.1}, "While you fight, you and every crewmate within 12 m deal 10% more damage.", "", "Rally"],
		["w_flag", "Plant the Flag", {}, "Plant the Flag (the skill): for 20 s every captain within 6 m of it mends 3% of their health a second.", "will_flag", "Flag"]]],
	"w_breath": ["tide", 1, "Deep Breath", "The sea's own lungs: you hold your breath longer and swim faster.", [
		["w_breath_v", "Deep Breath", {"breath_pct": 1.0, "swim_pct": 0.3}, "Twice the breath on a dive, and you swim 30% faster.", "", "Breath"]]],
	"w_sea": ["tide", 2, "Sea Legs", "The sea answers you: it holds you for a few steps, or rolls over your deck at a word.", [
		["w_wave", "Wave Walk", {"wave_walk": 1}, "Run onto deep water and it holds you for 6 steps, then you swim. Ground or a deck fills the steps again.", "", "Walk"],
		["w_swell", "Swell", {}, "Aboard your ship (the skill): a wave rolls over the deck and throws every boarder off it.", "will_swell", "Swell"]]],
	"w_wind": ["tide", 3, "Call the Wind", "Whistle up a wind (the skill): your ship's sails fill.", [
		["w_wind_v", "Call the Wind", {}, "Aboard or beside your ship: 25% more sail speed for 30 s. Every 3 minutes.", "will_wind", "Wind"]]],
	"w_step": ["tempo", 1, "Second Step", "Kick off the air once more: one more jump in mid-air.", [
		["w_step_v", "Second Step", {"air_jumps": 1}, "+1 air step.", "", "Step"]]],
	"w_rhythm": ["tempo", 2, "Rhythm", "Fight to your own beat: dash out of a blow's recovery, or flow faster while nothing touches you.", [
		["w_cancel", "Cancel", {"dash_cancel": 1}, "Dodge out of a combo blow's recovery as soon as its hit is done.", "", "Cancel"],
		["w_flow", "Flow", {"will_flow": 1}, "Every blow you land while unhit makes your attacks 2% faster, up to 20%; a blow on you breaks the flow.", "", "Flow"]]],
	"w_still": ["tempo", 3, "Still Point", "Find the still point (the skill): for 3 s everything round you moves at half speed; you don't.", [
		["w_still_v", "Still Point", {}, "Foes within 20 m move and strike at half speed for 3 s. Every 2 minutes.", "will_still_point", "Still"]]],
	"w_mist": ["fury", 1, "Red Mist", "The worse you're hurt, the harder you hit.", [
		["w_mist_v", "Red Mist", {"red_mist": 1}, "+1% damage for every 4% of your health missing.", "", "Mist"]]],
	"w_berserk": ["fury", 2, "Berserk", "Throw your guard away (the skill): your blows heal you, theirs land harder.", [
		["w_berserk_v", "Berserk", {}, "For 10 s every blow you land heals you 4% of its damage, and blows on you land 20% harder.", "will_berserk", "Berserk"]]],
	"w_unbowed": ["fury", 3, "Unbowed", "Refuse to fall: once a fight, the blow that would fell you doesn't.", [
		["w_unbowed_v", "Unbowed", {"unbowed": 1}, "Once a fight a blow that would fell you leaves you at 1 health, and nothing touches you for 2 s.", "", "Unbowed"]]],
	"w_link": ["bond", 1, "Link", "Bound to a crewmate: you take a share of what lands on them.", [
		["w_link_v", "Link", {"will_link": 1}, "Tethered to the nearest crewmate within 15 m: you take 15% of every blow on them. Alone, bonded to your ship: 15% of the blows on you go to her hull.", "", "Link"]]],
	"w_side": ["bond", 2, "Side by Side", "Fight as one: build a joint gauge together, or shelter a crewmate who's down.", [
		["w_gauge", "Joint Gauge", {"joint_gauge": 1}, "Your blows landed with your link within 8 m (alone: your ship within 20 m) fill the joint gauge for Twin Finisher; half as fast without this.", "", "Gauge"],
		["w_shelter", "Shelter", {"shelter": 1}, "A crewmate within 3 m who's down or under 30% health takes nothing: the blow is yours. Alone: once a fight, a blow while you're under 30% does nothing.", "", "Shelter"]]],
	"w_twin": ["bond", 3, "Twin Finisher", "Spend the full joint gauge (the skill): you and your link strike as one.", [
		["w_twin_v", "Twin Finisher", {}, "Gauge full: you and your linked crewmate close on a foe from both sides and cross your weapons through it. Alone, your ship's broadside is the second weapon.", "will_twin", "Twin"]]],
}
## Each path's passive: id -> [path, name, effects, desc] (bought for PASSIVE_COST once the path's first ability is yours).
const PASSIVES := {
	"h_instinct": ["sense", "Instinct", {"evade_chance": 0.08, "parry_all": 0.04}, "Passive (a slot). 8% of the blows that would hit you are sidestepped on instinct, and your parry window is wider."],
	"h_will": ["conq", "King's Will", {"damage_pct": 0.06, "max_hp": 20.0}, "Passive (a slot). +6% damage, +20 max health."],
	"h_helm": ["tide", "Helm Sense", {"helm_sense": 0.2}, "Passive (a slot). While you steer, your ship's hull takes 20% less damage."],
	"h_feet": ["tempo", "Light on Your Feet", {"move_pct": 0.08}, "Passive (a slot). +8% move speed."],
	"h_crew": ["bond", "Crew's Strength", {"crew_strength": 0.04}, "Passive (a slot). +4% damage for every crewmate within 20 m (alone: your ship)."],
	"h_blood": ["fury", "Thick Blood", {"thick_blood": 0.5}, "Passive (a slot). Bleeding, burning and poison hurt you half as much."],
}
## The Will milestones of saves before 1.23 (format < 8): each comes back as SOURCES["boss"] Will points.
const OLD := ["h_arm", "h_coat", "h_obs", "h_fore", "h_conq"]


static func abilities_of(path: String) -> Array:
	return ABILITIES.keys().filter(func(k): return ABILITIES[k][0] == path)


static func first_tier(path: String) -> int:
	return int(ABILITIES[abilities_of(path)[0]][1])


## Will spent in a path (its versions and its passive).
static func spent_in(pr, path: String) -> int:
	var n := 0
	for k in pr.bought.keys():
		var d := SkillTrees.node_def(k)
		if d.get("pool", "") == "will" and d.get("path", "") == path:
			n += SkillTrees.price(k)
	return n


static func spent_all(pr) -> int:
	var n := 0
	for p in PATHS:
		n += spent_in(pr, p)
	return n


## Why a path can't be bought into yet ("" = it's open).
static func path_why(pr, path: String) -> String:
	if path in OPEN:
		return ""
	if path == "conq":
		if spent_in(pr, "iron") < CONQ_NEEDS or spent_in(pr, "sense") < CONQ_NEEDS:
			return "Needs %d Edy spent in Iron Will and in Sense" % CONQ_NEEDS
		return ""
	var other := "sense" if path == "iron" else "iron"
	if spent_in(pr, path) == 0 and spent_in(pr, other) > 0 and spent_all(pr) < SECOND_AT:
		return "A second path opens at %d Edy spent" % SECOND_AT
	return ""


## Why a Will version or passive can't be bought now ("" = it can).
static func why(pr, id: String) -> String:
	var n := SkillTrees.node_def(id)
	if pr.bought.has(id):
		return "Learned"
	if str(pr.will_color) == "":
		return "Your Edy isn't read yet: see Master Isao at Brinehollow's shrine"
	var path := str(n["path"])
	var pw := path_why(pr, path)
	if pw != "":
		return pw
	if n["kind"] == "passive":
		var first: String = abilities_of(path)[0]
		if not pr.owns(first):
			return "Needs %s first" % ABILITIES[first][2]
	elif path in OPEN:
		var gate_all: int = TIER_AT[int(n["tier"])]
		if spent_all(pr) < gate_all:
			return "Needs %d Edy spent" % gate_all
	else:
		var gate: int = TIER_AT[int(n["tier"])] - TIER_AT[first_tier(path)]
		if spent_in(pr, path) < gate:
			return "Needs %d Edy spent in %s" % [gate, PATH_NAMES[path]]
	if SkillTrees.price(id) > pr.pool("will"):
		return "Needs %d Edy point%s" % [SkillTrees.price(id), "" if SkillTrees.price(id) == 1 else "s"]
	return ""


static func color_of(id: String) -> Color:
	return EdyTypes.color_of(id)
