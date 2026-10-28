class_name WillBond
extends Node
## Bond Will on a captain (WillPowers' child "Bond", docs/v1_24_previews.md section 2): the link to a crewmate, the
## joint gauge, Shelter and Crew's Strength. Crewmates are the other captains (group "players", not AI ones); a captain
## with none about (solo) is bonded to the crew's ship instead.
##   Link (will_link): tethered to the nearest crewmate within LINK_REACH, 15% (LINK_SHARE) of the blows on them is
##     taken by you. The host decides every link (Net._all_will "link_ask" -> "link") and every machine keeps the table
##     (`links`); the crewmate's own machine (where their hits land) splits the blow and sends you your share ("took").
##     Solo: within LINK_REACH of the ship, 15% of the blows on you go to her hull instead (never below 1).
##   Joint Gauge (joint_gauge): your blows landed while your link is within JOINT_REACH (solo: the ship within
##     CREW_REACH) fill the gauge (GAUGE_PER of the damage; half that with Shelter carried instead). Full, it pays for
##     Twin Finisher (WillArts).
##   Shelter (shelter): a crewmate within SHELTER_REACH who is down or under SHELTER_HURT of their health takes nothing:
##     the blow is yours instead ("shelter" broadcasts, "took"). Solo: once a fight, a blow landing while you're under
##     SHELTER_HURT does nothing.
##   Crew's Strength (crew_strength 0.04): that much more damage per crewmate within CREW_REACH (solo: the ship).

const LINK_REACH := 15.0
const LINK_SHARE := 0.15
const JOINT_REACH := 8.0
const CREW_REACH := 20.0
const GAUGE_MAX := 100.0
const GAUGE_PER := 0.4
const SHELTER_REACH := 3.0
const SHELTER_HURT := 0.3
const SHELTER_HOLD := 0.7
## The bond's checks every this many physics ticks (links, crew near, shelter calls, the tether's look).
const EVERY := 20
const COL := Color(1.0, 0.78, 0.35)

## Every machine: captain key -> the key of the crewmate they're linked to ("ship": solo, to the crew's ship).
static var links: Dictionary = {}
## Every machine: captain key -> [shelterer's key, seconds left].
static var sheltered: Dictionary = {}

var player: Player
var gauge := 0.0
## Crewmates (or the ship, solo) within CREW_REACH at the last check.
var crew_near := 0
var _n := 0
var _shelter_used := false


func _ready() -> void:
	player = get_parent().get_parent().get_parent() as Player


func me() -> String:
	return Net.key_of(player)


## The other captains about (not AI ones).
func crewmates() -> Array:
	return get_tree().get_nodes_in_group("players").filter(func(c): return c != player and not c.is_ai and is_instance_valid(c))


func solo() -> bool:
	return crewmates().is_empty()


## The crew's ship (group "ship" holds moored hulls too), or null.
static func crew_ship(tree: SceneTree) -> Ship:
	for s in tree.get_nodes_in_group("ship"):
		if s is Ship:
			return s
	return null


func ship_near(reach: float) -> Node3D:
	var ship := crew_ship(get_tree())
	if ship and (ship.aboard(player.global_position) or ship.global_position.distance_to(player.global_position) < reach):
		return ship
	return null


## The node we're linked to now (a captain, the ship), or null.
func partner() -> Node3D:
	var k := str(links.get(me(), ""))
	if k == "ship":
		return ship_near(LINK_REACH)
	var n := Net.node_of(k) as Node3D
	return n if n and n.global_position.distance_to(player.global_position) <= LINK_REACH else null


func _physics_process(delta: float) -> void:
	if not player.is_local or player.is_ai:
		return
	for k in sheltered.keys():
		sheltered[k][1] = float(sheltered[k][1]) - delta
		if float(sheltered[k][1]) <= 0.0:
			sheltered.erase(k)
	_n += 1
	if _n % EVERY != 0 or not player.is_local or not player.is_inside_tree():
		return
	var pr := player.progression
	if not player.in_fight():
		_shelter_used = false
	if not (pr.has_flag("will_link") or pr.has_flag("shelter") or pr.has_flag("crew_strength")):
		crew_near = 0
		return
	var mates := crewmates()
	if mates.is_empty():
		crew_near = 1 if ship_near(CREW_REACH) else 0
	else:
		crew_near = mates.filter(func(c): return (c as Node3D).global_position.distance_to(player.global_position) <= CREW_REACH).size()
	if pr.has_flag("will_link"):
		_relink(mates)
	if pr.has_flag("shelter") and not mates.is_empty():
		for c in mates:
			if (c as Node3D).global_position.distance_to(player.global_position) <= SHELTER_REACH and _needs_shelter(c):
				Net.everyone("_all_will", ["shelter", [me(), Net.key_of(c), SHELTER_HOLD]])


## Down, or badly hurt (as this machine sees them).
static func _needs_shelter(c: Node) -> bool:
	var hc = c.get("health_component")
	return c.is_bleeding() or c.current_state_name() == "Downed" or (hc and hc.current_health < hc.max_health * SHELTER_HURT)


## The nearest crewmate within reach (solo: the ship), asked of the host when it changes; the tether drawn.
func _relink(mates: Array) -> void:
	var want := ""
	if mates.is_empty():
		want = "ship" if ship_near(LINK_REACH) else ""
	else:
		var best := LINK_REACH
		for c in mates:
			var d := (c as Node3D).global_position.distance_to(player.global_position)
			if d <= best and c.health_component.current_health > 0.0 and not c.is_bleeding():
				best = d
				want = Net.key_of(c)
	if want != str(links.get(me(), "")):
		Net.everyone("_all_will", ["link_ask", [me(), want]])
	var p := partner()
	if p and p != player:
		Net.fx("streak", [player.global_position + Vector3(0, 1.1, 0), p.global_position + Vector3(0, 1.1, 0), COL, 0.03, 0.3])


## A weapon blow of ours landed: the joint gauge.
func landed(hit: HitData) -> void:
	var pr := player.progression
	if not pr.has_flag("will_link") or gauge >= GAUGE_MAX:
		return
	var p := partner()
	if p == null:
		return
	var near := (p.is_in_group("ship") and ship_near(CREW_REACH) != null) or p.global_position.distance_to(player.global_position) <= JOINT_REACH
	if not near:
		return
	var was := gauge
	gauge = minf(gauge + hit.damage * GAUGE_PER * (1.0 if pr.has_flag("joint_gauge") else 0.5) * (1.0 + pr.stat("bond_gauge_pct")), GAUGE_MAX)
	if gauge >= GAUGE_MAX and was < GAUGE_MAX:
		player.call("_toast", "Joint gauge full: Twin Finisher")
		Net.fx("sparkle", [player.global_position + Vector3(0, 1.4, 0), 16, COL])


## Crew's Strength's damage share now.
func damage_k() -> float:
	return player.progression.stat("crew_strength") * crew_near


## A blow about to land on us for `dmg` (WillPowers.incoming): sheltered, split with whoever's linked to us, or (solo)
## with the ship. Returns what we take.
func incoming(hit: HitData, dmg: float) -> float:
	if hit.dot or dmg <= 0.0:
		return dmg
	var mine := me()
	var sh: Array = sheltered.get(mine, [])
	if not sh.is_empty():
		Net.everyone("_all_will", ["took", [str(sh[0]), dmg]])
		Net.fx("sparkle", [player.global_position + Vector3(0, 1.2, 0), 10, COL])
		Net.fx("float_text", [player.global_position + Vector3(0, 2.2, 0), "Sheltered", COL])
		return 0.0
	var pr := player.progression
	var hc := player.health_component
	if pr.has_flag("shelter") and solo() and not _shelter_used and hc.current_health < hc.max_health * SHELTER_HURT:
		_shelter_used = true
		Net.fx("float_text", [player.global_position + Vector3(0, 2.2, 0), "Sheltered", COL])
		Net.fx("ring", [player.global_position + Vector3(0, 0.1, 0), Vector3.UP, 1.6, COL, 0.35, 0.12])
		return 0.0
	if str(links.get(mine, "")) == "ship":
		var ship := ship_near(LINK_REACH)
		if ship:
			ship.hull = maxf(ship.hull - dmg * LINK_SHARE, 1.0)
			return dmg * (1.0 - LINK_SHARE)
	for h in links.keys():
		if str(links[h]) != mine:
			continue
		var holder := Net.node_of(str(h)) as Node3D
		if holder and holder.global_position.distance_to(player.global_position) <= LINK_REACH:
			Net.everyone("_all_will", ["took", [str(h), dmg * LINK_SHARE]])
			Net.fx("streak", [player.global_position + Vector3(0, 1.1, 0), holder.global_position + Vector3(0, 1.1, 0), COL, 0.06, 0.25])
			return dmg * (1.0 - LINK_SHARE)
	return dmg


## Every machine (WillPowers.all): the Bond's messages.
static func all(op: String, a: Array) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var net := tree.root.get_node("Net")
	match op:
		"link_ask":
			if not net.is_host():
				return
			var holder := net.node_of(str(a[0])) as Node3D
			var mate := net.node_of(str(a[1])) as Node3D
			var ok: bool = str(a[1]) in ["", "ship"] or (holder and mate and mate.is_in_group("players") and mate != holder
				and mate.global_position.distance_to(holder.global_position) <= LINK_REACH + 3.0)
			net.everyone("_all_will", ["link", a if ok else [str(a[0]), ""]])
		"link":
			if str(a[1]) == "":
				links.erase(str(a[0]))
			else:
				links[str(a[0])] = str(a[1])
		"shelter":
			sheltered[str(a[1])] = [str(a[0]), float(a[2])]
		"took":
			var p := net.node_of(str(a[0])) as Player
			if p and p.is_local and p.health_component.current_health > 0.0:
				p.health_component.take_damage(float(a[1]))
