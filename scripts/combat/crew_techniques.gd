class_name CrewTechniques
extends Node
## Crew techniques (1.24, docs/v1_24_plan.md and v1_24_previews.md section 3): one two-person move per weapon kind,
## on the crouch key while your weapon is out (C; out of combat stance C still sneaks). Pressing it opens a join zone
## ZONE_R round you for ZONE_SECS that every screen draws; a crewmate inside it presses F (interact) to join, the host
## decides who got in first (Net.crew_join), and the move plays on both machines (CrewTechniqueState: the opener's
## "lead" side on theirs, the joiner's "partner" side on theirs). With no crewmate near (single player, or nobody
## within MATE_NEAR) the weapon's self version plays at once; C again while the zone is open goes alone too.
## Nobody joining in time costs nothing. Alone by a training dummy (single player), the throws are played with the
## yard's SparringPartner. One per captain, child "CrewTech" of the Player (puppets too: their zone).

const ZONE_R := 3.0
const ZONE_SECS := 6.0
const COOLDOWN := 90.0
const QUICK_COOLDOWN := 60.0
## In co-op, a crewmate this close (m) gets the zone; otherwise the self version plays straight away.
const MATE_NEAR := 14.0
## The press refused (cooling, busy) can't be retried for this long (s) so a held C doesn't spam toasts.
const REFUSE_LOCK := 0.4
## Guardian Stance: how long the guard holds, how many blows it turns, how near the guardian must be (m).
const GUARD_SECS := 8.0
const GUARD_BLOWS := 3
const GUARD_REACH := 10.0
## Shield Wall: a crewmate this close behind the wall (m) has shots stopped and blows halved.
const WALL_SECS := 8.0
const WALL_COVER := 4.0
const WALL_MELEE_K := 0.5
## Covering Fire: how long the cover lasts, the damage taken under it, the reload time.
const COVER_SECS := 8.0
const COVER_DAMAGE_K := 0.7
const COVER_RELOAD_K := 0.5
## Pincer: the extra crit on the marked foe (a share of the blow; more for the second of you to strike); solo: hits.
const PINCER_EXTRA := 0.75
const PINCER_BOTH := 1.5
const PINCER_SOLO := 3
const PINCER_SECS := 10.0
## What the joiner of a move that doesn't throw them is told.
const PARTNER_NOTE := {"guardian_stance": "you're under guard", "shield_wall": "stay behind the wall",
	"pincer": "strike the marked foe together", "covering_fire": "you're covered"}

## id -> name, the styles it belongs to, quick (the 60 s ones), launch (the crewmate plays a side: thrown), what the
## crewmate does, the self version.
const ALL := {
	"skyward_kick": {"name": "Skyward Kick", "styles": ["black_leg"], "launch": true, "solo": "Wall Kick",
		"desc": "Your crewmate steps onto your raised foot and you kick them high along your aim; they come down with a free plunge.",
		"solo_desc": "Kick off the wall ahead (or the ground) and launch yourself high."},
	"guardian_stance": {"name": "Guardian Stance", "styles": ["katana"], "solo": "Counter Stance",
		"desc": "Stand guard over a crewmate for 8 s: whoever strikes them eats your iai counter.",
		"solo_desc": "A long counter stance: the next blow is turned and answered."},
	"crossed_blades": {"name": "Crossed Blades", "styles": ["sword", "dual_sword"], "launch": true, "solo": "Blade Vault",
		"desc": "Brace your blade at shoulder height: your crewmate vaults off it into a leaping slash.",
		"solo_desc": "Vault forward into a leaping slash."},
	"hurl": {"name": "Hurl", "styles": ["axe", "dual_axe"], "launch": true, "solo": "Hurled Slam",
		"desc": "Swing your crewmate round by the arm and throw them into the crowd: they land in a ground slam.",
		"solo_desc": "A spinning leap that lands in a ground slam."},
	"pole_vault": {"name": "Pole Vault", "styles": ["polearm"], "launch": true, "solo": "Pole Vault",
		"desc": "Plant the polearm: your crewmate runs up it and vaults far (gaps, ledges, onto a boss).",
		"solo_desc": "Plant the pole and vault far yourself."},
	"anvil": {"name": "Anvil", "styles": ["hammer"], "launch": true, "solo": "Rebound",
		"desc": "Swing low: your crewmate stands on the head and is batted skyward.",
		"solo_desc": "Slam the hammer down and ride the rebound up."},
	"shield_wall": {"name": "Shield Wall", "styles": ["greatsword"], "solo": "Shield Wall",
		"desc": "Raise the flat as a wall for 8 s: shots from the front stop at it, and a crewmate behind it takes less from blows.",
		"solo_desc": "Raise the flat as a wall: shots and blows from the front stop at it."},
	"pincer": {"name": "Pincer", "styles": ["dagger", "dual_dagger"], "quick": true, "solo": "Marked Prey",
		"desc": "Mark a foe: your crewmate's next hit on it and yours strike together for a crit.",
		"solo_desc": "Mark a foe: your next three hits on it crit."},
	"covering_fire": {"name": "Covering Fire", "styles": ["pistol", "dual_pistol", "sword_pistol"], "quick": true, "solo": "Suppress",
		"desc": "Pin down the foes ahead with a volley: crewmates in the fight take less damage and reload faster.",
		"solo_desc": "A volley that pins down the foes ahead, then a fast reload."},
	"human_cannonball": {"name": "Human Cannonball", "styles": ["fist", "claw"], "launch": true, "solo": "Cannonball",
		"desc": "Cup your hands: your crewmate launches from your grip, shorter and faster than the kick, through anything in the way.",
		"solo_desc": "Launch yourself low and fast through the foes ahead."},
}

const FX_SCRIPT := preload("res://scripts/game/fx.gd")

## Open zones on this machine (for the local captain's join prompt).
static var _open: Array = []

var player
var cooldown: float = 0.0
var cooldown_len: float = COOLDOWN
## The zone's seconds left (on every screen), the move it's for, and whether the host gave it to someone.
var offer: float = 0.0
var offer_id: String = ""
var taken: bool = false
## (local) the zone we'd join with F, and whether its prompt is ours on the HUD.
var join_target = null
var _prompting := false
var _refused_until := -1.0
## Buffs a crew technique left on this captain: kind -> {"t": secs, "by": captain key}.
var marks: Dictionary = {}
var _ring: MeshInstance3D
var _inner: MeshInstance3D
var _ring_mat: StandardMaterial3D
static var _ring_mesh: ArrayMesh


static func of_style(style: String) -> String:
	for id in ALL:
		if style in ALL[id]["styles"]:
			return id
	return ""


static func name_of(id: String) -> String:
	return str(ALL.get(id, {}).get("name", ""))


## The weapon tree whose colours a technique wears.
static func tree_of(id: String) -> String:
	var tr := SkillTree.style_tree(str((ALL[id]["styles"] as Array)[0]))
	return tr if FX_SCRIPT.TREE_FX.has(tr) else "unarmed"


static func tree_col(id: String, which: int) -> Color:
	return FX_SCRIPT.tree_col(tree_of(id), which)


static func cooldown_of(id: String) -> float:
	return QUICK_COOLDOWN if ALL.get(id, {}).get("quick", false) else COOLDOWN


## The crew technique of the weapon in hand ("" for none).
func id() -> String:
	return of_style(player.style())


func _exit_tree() -> void:
	_open.erase(self)


## C in combat stance (Player._unhandled_input). What happened: "offer", "solo", "cooling", "busy", "none".
func trigger() -> String:
	var tid := id()
	if tid == "":
		return "none"
	# (in a crew technique already: C is the move's own, Shield Wall's drop)
	if player.current_state_name() == "CrewTechnique":
		player.state_machine.current_state.on_crouch()
		return "busy"
	if offer > 0.0 and not taken:
		# (C again while waiting: go alone)
		Net.everyone("_all_crew_close", [Net.key_of(player)])
		_solo(tid)
		return "solo"
	var now := PlayerState.now_s()
	if now < _refused_until:
		return "busy"
	if cooldown > 0.0:
		_refused_until = now + REFUSE_LOCK
		player.call("_toast", "%s ready in %ds" % [name_of(tid), ceili(cooldown)])
		return "cooling"
	if not _can_start():
		_refused_until = now + REFUSE_LOCK
		return "busy"
	if _mates_near().is_empty():
		# (alone in a training yard: the sparring partner steps in for the throws)
		var yard: Node3D = SparringPartner.at_side(player) if ALL[tid].get("launch", false) and not player.is_ai else null
		if yard:
			Net.everyone("_all_crew_offer", [Net.key_of(player), tid, ZONE_SECS])
			Net.crew_join(player, yard)
			return "yard"
		_solo(tid)
		return "solo"
	Net.everyone("_all_crew_offer", [Net.key_of(player), tid, ZONE_SECS])
	Net.fx("sfx", ["blip_high", player.global_position, -8.0, 0.0, 0.9])
	player.call("_toast", "%s: a crewmate joins with %s" % [name_of(tid), Glyphs.of("interact")])
	return "offer"


func _can_start() -> bool:
	return player.is_free() and player.is_on_floor() and not player.is_swimming() and not player.is_bleeding()


## Other captains standing close enough to be offered the zone.
func _mates_near() -> Array:
	var out: Array = []
	for p in get_tree().get_nodes_in_group("players"):
		if p == player or not is_instance_valid(p) or not p.is_standing():
			continue
		if (p as Node3D).global_position.distance_to(player.global_position) <= MATE_NEAR:
			out.append(p)
	return out


func _solo(tid: String) -> void:
	_start_cooldown(tid)
	player.state_machine.force_state("CrewTechnique", {"id": tid, "role": "solo"})


func _start_cooldown(tid: String) -> void:
	cooldown_len = cooldown_of(tid)
	cooldown = cooldown_len


## (every machine) The zone opens round this captain.
func open_zone(tid: String, secs: float) -> void:
	offer = secs
	offer_id = tid
	taken = false
	if not self in _open:
		_open.append(self)
	_show_ring(true)


## (every machine) The zone closes (taken, gone alone, or timed out).
func close_zone() -> void:
	offer = 0.0
	_open.erase(self)
	_show_ring(false)


## (host) Whether a crewmate may still join this zone.
func can_join() -> bool:
	return offer > 0.0 and not taken


## (every machine, Net._all_crew_go) `mate` got in: the move starts on both captains' own machines.
## The guard, the wall's cover and the covering fire are marks set here on both captains, on every machine; the thrown
## crewmate plays its side (CrewTechniqueState "partner"); the others just hear what they got.
func go(mate) -> void:
	taken = true
	close_zone()
	var tid := offer_id
	var lk := Net.key_of(player)
	var mk := Net.key_of(mate)
	match tid:
		"guardian_stance":
			mark("guarding", GUARD_SECS, mk, GUARD_BLOWS)
			mate.crew_tech.mark("guarded", GUARD_SECS, lk, GUARD_BLOWS)
		"shield_wall":
			mate.crew_tech.mark("walled", WALL_SECS, lk)
		"covering_fire":
			mark("covered", COVER_SECS, mk)
			mate.crew_tech.mark("covered", COVER_SECS, lk)
	if player.is_local:
		_start_cooldown(tid)
		player.state_machine.force_state("CrewTechnique", {"id": tid, "role": "lead", "mate": mate})
	if mate.is_local:
		if ALL[tid].get("launch", false):
			mate.state_machine.force_state("CrewTechnique", {"id": tid, "role": "partner", "mate": player})
		else:
			mate.call("_toast", "%s: %s" % [name_of(tid), PARTNER_NOTE[tid]])



## (every machine, Net._all_crew_signal) A message for this captain from a crewmate's move: only its own machine acts.
func signal_in(what: String, args: Array) -> void:
	if not player.is_local:
		return
	var st = player.state_machine.current_state
	if player.current_state_name() == "CrewTechnique" and st.on_signal(what, args):
		return
	match what:
		"guard_hit":
			# our ward was struck: out to answer it, from wherever we are (not from the water, a seat or the floor)
			var e := Net.node_of(str(args[0])) as Node3D
			if e and player.is_standing() and not player.is_swimming() and player.context == Player.Context.ON_FOOT \
					and player.current_state_name() not in ["Downed", "Grabbed", "Talk"]:
				player.state_machine.force_state("CrewTechnique", {"id": "guardian_stance", "role": "counter", "target": e})
		"pincer":
			mark("pincer", PINCER_SECS, str(args[0]), 1, str(args[1]))
		"pincer_struck":
			if marks.has("pincer"):
				marks["pincer"]["both"] = true


## A crew technique's mark on this captain: `kind` for `secs`, `by` (a node key: the guardian, the wall, the marked
## foe), `n` uses, `with` the crewmate in it.
func mark(kind: String, secs: float, by: String, n := 0, with := "") -> void:
	marks[kind] = {"t": secs, "by": by, "n": n, "with": with}


func marked(kind: String) -> bool:
	return float(marks.get(kind, {}).get("t", 0.0)) > 0.0


## A blow on this captain (Player._on_hit_received, on its own machine): turned aside by the Shield Wall in front of
## you, by a guardian standing over you, or (shots) by the wall you're behind. True: it does no harm.
func blow(hit: HitData, attacker: Node, dir: Vector3) -> bool:
	if hit.dot or attacker == null or attacker.is_in_group("players"):
		return false
	var fwd: Vector3 = -player.player_model.global_basis.z
	if marked("wall") and Vector2(fwd.x, fwd.z).normalized().dot(Vector2(-dir.x, -dir.z).normalized()) > 0.3:
		_turned(dir, "Walled!")
		return true
	if marked("guarded") and int(marks["guarded"]["n"]) > 0 and not hit.ranged:
		var g := Net.node_of(str(marks["guarded"]["by"])) as Node3D
		if g and g.is_standing() and g.global_position.distance_to(player.global_position) <= GUARD_REACH:
			marks["guarded"]["n"] = int(marks["guarded"]["n"]) - 1
			_turned(dir, "Guarded!")
			Net.crew_signal(g, "guard_hit", [Net.key_of(attacker)])
			return true
	if hit.ranged and _behind_wall():
		_turned(dir, "Walled!")
		return true
	return false


func _turned(dir: Vector3, text: String) -> void:
	var at: Vector3 = player.global_position + Vector3(0, 1.3, 0) - dir * 0.6
	Net.fx("parry_sparks", [at, -dir])
	Net.fx("float_text", [at + Vector3.UP * 0.5, text, Color(1.0, 0.95, 0.75)])
	Net.fx("sfx", ["clash", at, -4.0, 0.05, 1.2])


## Behind a crewmate's Shield Wall (still standing it) and close.
func _behind_wall() -> bool:
	if not marked("walled"):
		return false
	var g := Net.node_of(str(marks["walled"]["by"])) as Node3D
	if g == null or g.current_state_name() != "CrewTechnique":
		return false
	var f: Vector3 = -g.player_model.global_basis.z
	var to: Vector3 = player.global_position - g.global_position
	return to.length() <= WALL_COVER and Vector2(to.x, to.z).normalized().dot(Vector2(f.x, f.z).normalized()) < 0.2


## What a blow that gets through does to this captain (covered, behind the wall).
func damage_k() -> float:
	return (COVER_DAMAGE_K if marked("covered") else 1.0) * (WALL_MELEE_K if _behind_wall() else 1.0)


func reload_k() -> float:
	return COVER_RELOAD_K if marked("covered") else 1.0


## Our blow landed on `target` (PowerComponent.on_sword_hit): on a foe we've marked (Pincer) it lands a crit with it,
## bigger for the second of the pair to strike.
func on_hit(target: Node, hit: HitData) -> void:
	if not marked("pincer") or hit.has_meta("pincer") or Net.key_of(target) != str(marks["pincer"]["by"]):
		return
	var hb := target.get("hurtbox") as Hurtbox
	if hb == null:
		return
	var m: Dictionary = marks["pincer"]
	var both: bool = m.get("both", false)
	var extra := HitData.new()
	extra.damage = roundf(hit.damage * (PINCER_BOTH if both else PINCER_EXTRA))
	extra.set_meta("crit", true)
	extra.set_meta("pincer", true)
	extra.stagger_duration = 0.4
	extra.impact = hit.impact
	hb.take_hit(extra, player)
	var at := (target as Node3D).global_position + Vector3(0, 1.2, 0)
	var col := tree_col("pincer", FX.EDGE)
	Net.fx("glint", [at, tree_col("pincer", FX.CORE), 1.2 if both else 0.9])
	Net.fx("ring", [at, Vector3.UP, 1.6 if both else 1.0, col, 0.3, 0.16])
	Net.fx("float_text", [at + Vector3.UP * 0.6, "Pincer!" if both else "Crit!", col])
	m["n"] = int(m["n"]) - 1
	if int(m["n"]) <= 0:
		marks.erase("pincer")
	var mate := Net.node_of(str(m.get("with", "")))
	if mate:
		Net.crew_signal(mate, "pincer_struck", [])


## Ask to join the zone we're standing in (F).
func join() -> void:
	if join_target == null or not is_instance_valid(join_target):
		return
	Net.crew_join(join_target.player, player)
	_clear_prompt()
	join_target = null


func _physics_process(delta: float) -> void:
	if player == null:
		return
	cooldown = maxf(cooldown - delta, 0.0)
	for k in marks.keys():
		marks[k]["t"] = float(marks[k]["t"]) - delta
		if float(marks[k]["t"]) <= 0.0:
			marks.erase(k)
	if offer > 0.0:
		offer -= delta
		if _inner:
			var k := clampf(offer / ZONE_SECS, 0.05, 1.0)
			_inner.scale = Vector3(ZONE_R * k, 1.0, ZONE_R * k)
			_ring_mat.albedo_color.a = 0.45 + 0.3 * sin(offer * 9.0)
		if offer <= 0.0:
			close_zone()
			if player.is_local and not taken:
				player.call("_toast", "Nobody joined: %s is still ready" % name_of(offer_id))
	if player.is_local and not player.is_ai:
		_scan_join()


## The local captain: inside someone's open zone, free, with nothing else on F -> the join prompt.
func _scan_join() -> void:
	var best = null
	if not _open.is_empty() and player.is_free() and player.is_standing():
		var best_d := ZONE_R
		for z in _open:
			if z == self or not is_instance_valid(z) or not z.can_join():
				continue
			var d: float = (z.player as Node3D).global_position.distance_to(player.global_position)
			if d <= best_d:
				best_d = d
				best = z
	if best == join_target:
		return
	join_target = best
	if best == null:
		_clear_prompt()
		return
	_prompting = true
	get_tree().call_group("hud", "show_prompt", "%s: join %s's %s" % [Glyphs.of("interact"), best.player.display_name(), name_of(best.offer_id)], -1.0)


func _clear_prompt() -> void:
	if _prompting:
		_prompting = false
		get_tree().call_group("hud", "show_prompt", "", -1.0)


func _unhandled_input(event: InputEvent) -> void:
	if join_target != null and event.is_action_pressed("interact"):
		join()
		get_viewport().set_input_as_handled()


## The zone on the ground: a ring at ZONE_R in the weapon tree's colour and an inner one shrinking with the time left.
func _show_ring(on: bool) -> void:
	if not on:
		if _ring:
			_ring.visible = false
			_inner.visible = false
		return
	if _ring == null:
		if _ring_mesh == null:
			_ring_mesh = FX._fan(0.93, 1.0, TAU)
		_ring_mat = FX._glow_mat(Color.WHITE, 0.7)
		_ring = _ring_part(_ring_mat)
		_inner = _ring_part(_ring_mat)
	var c := tree_col(offer_id, FX.EDGE)
	_ring_mat.albedo_color = Color(c.r, c.g, c.b, 0.7)
	_ring.visible = true
	_inner.visible = true
	_ring.scale = Vector3(ZONE_R, 1.0, ZONE_R)
	_inner.scale = Vector3(ZONE_R, 1.0, ZONE_R)


func _ring_part(mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _ring_mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 70.0
	mi.position = Vector3(0, 0.06, 0)
	player.add_child(mi)
	return mi
