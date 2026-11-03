class_name LineQuests
extends RefCounted
## Story lines as journal quests (1.30 guidance): a city ruler's line (the Queen's forger, her writ, the fortress fallen;
## the Doge's smugglers) and the stronghold run (its seals, the Commodore, the vault, the escape). A step finishes when
## the world says so, not at a turn-in: each step has an "until" (data, kept in the journal entry, so a loaded save or a
## captain who joins mid-line carries on with no island built) and an "at" (where its marker goes). Journal polls the
## live lines on every machine and asks the host to move them on (it takes the first word).
## until: ["done", quest id] / ["perk", journal perk] / ["flag", world flag] / ["flags", [world flags]] (all of them,
## counted "(n/m)") / ["opened", save id]. at: ["npc", name] / ["quest", quest id, giver] (its own marker while it's
## live, else its giver) / ["sh"] (the stronghold) / ["sh_room", room] / ["sh_seals"] (the nearest seal not yet taken).

const RULERS := {"capital": "Queen Ilsabet", "canal": "Doge Benedetto Vael"}
const LINE_TITLE := {"capital": "The Queen's line", "canal": "The Doge's line"}
const SEAL_BOSSES := {"sh_seal_arsenal": "kesh", "sh_seal_prison": "marrow"}


## A ruler's line: their investigation `q` (KitQuests def), the ruler's thanks, and for the Queen the Admiralty's
## fortress (found, the writ, fallen, her thanks). Its id is the investigation's with "_line".
static func ruler(city: String, q: Dictionary, isle: String) -> Dictionary:
	var who: String = RULERS[city]
	var first := who.split(" ")[0]
	var steps: Array = [
		{"goal": "%s: %s's trouble" % [q["title"], q["giver"]], "until": ["done", q["id"]], "at": ["quest", q["id"], q["giver"]]},
		{"goal": "Tell %s it's done" % who, "until": ["perk", "line:%s:1" % city], "at": ["npc", who], "person": true}]
	if city == "capital":
		steps += [
			{"goal": "Find where the Admiralty keeps its fortress (rumours, charts, its ships)", "until": ["flag", "stronghold_known"], "at": []},
			{"goal": "Tell the %s you've found the fortress: her writ" % first.to_lower(), "until": ["perk", "line:capital:writ"], "at": ["npc", who], "person": true},
			{"goal": "Take the Admiralty's fortress and open its vault", "until": ["flag", "sh_seal_keep"], "at": ["sh"]},
			{"goal": "Tell %s the fortress has fallen" % who, "until": ["perk", "line:capital:2"], "at": ["npc", who], "person": true}]
	return {"id": str(q["id"]) + "_line", "title": LINE_TITLE[city], "giver": who, "isle": isle, "pos": q.get("pos", Vector3.ZERO), "src": "line",
		"steps": steps, "reward": {"xp": 0.0, "note": "the %s's purse and favour" % ("Crown" if city == "capital" else "Republic")}}


## The stronghold run (once the crew knows of it): both seals, the Commodore, the vault, out of the Scouring's ring.
static func stronghold(chain: Chain) -> Dictionary:
	var n: Dictionary = chain.node(chain.stronghold_id())
	var nm := str(n["name"])
	var p: Vector2 = n["pos"]
	var vault := "sh_vault_%d" % chain.seed_value
	return {"id": "stronghold_%d" % chain.seed_value, "title": "Storm %s" % nm, "giver": "The Admiralty's fortress", "isle": nm,
		"pos": Vector3(p.x, 0.0, p.y), "src": "line", "reward": {"xp": 0.0, "note": "the Commodore's vault"}, "steps": [
		{"goal": "Take the keep's two seals: Lieutenant Kesh in the Arsenal, Captain Marrow at the Prison Tower",
			"until": ["flags", SEAL_BOSSES.keys()], "at": ["sh_seals"]},
		{"goal": "Cross the Bridge of Judgement: beat Commodore Vane in the Command Hall", "until": ["flag", "sh_seal_keep"], "at": ["sh_room", "command"]},
		{"goal": "Open the Commodore's vault before his dais", "until": ["opened", vault], "at": ["sh_room", "command"]},
		{"goal": "Escape the Scouring: out of the warships' ring", "until": ["flag", "sh_escaped"], "at": []}]}


## Is `until` met?
static func met(tree: SceneTree, until: Array) -> bool:
	if until.is_empty():
		return false
	var gm: Node = tree.root.get_node("GameManager")
	match str(until[0]):
		"done":
			return tree.root.get_node("Journal").is_done(str(until[1]))
		"perk":
			return tree.root.get_node("Journal").perks.has(str(until[1]))
		"flag":
			return gm.world_flags.has(str(until[1]))
		"flags":
			return (until[1] as Array).all(func(f): return gm.world_flags.has(str(f)))
		"opened":
			return gm.opened.has(str(until[1]))
	push_error("LineQuests: no until \"%s\"" % until[0])
	return false


## How far along a step is ("(1/2)"), or "".
static func progress(tree: SceneTree, until: Array) -> String:
	if until.is_empty() or str(until[0]) != "flags":
		return ""
	var gm: Node = tree.root.get_node("GameManager")
	var fs: Array = until[1]
	return " (%d/%d)" % [fs.filter(func(f): return gm.world_flags.has(str(f))).size(), fs.size()]


## Where a step's marker goes (Vector3.INF: nowhere to point).
static func where(tree: SceneTree, at: Array) -> Vector3:
	if at.is_empty():
		return Vector3.INF
	var j: Node = tree.root.get_node("Journal")
	match str(at[0]):
		"npc":
			return npc(tree, str(at[1]))
		"quest":
			if j.has(str(at[1])) and not j.is_done(str(at[1])):
				return j.target(str(at[1]))
			return npc(tree, str(at[2]))
		"sh":
			return _stronghold_pos(tree)
		"sh_room":
			var isl = _stronghold(tree)
			for r in StrongholdPlan.ROOMS:
				if isl != null and str(r[0]) == str(at[1]):
					var c: Vector2 = (r[2] as Rect2).get_center()
					return isl.city_global(c, float(r[3]) + 1.5)
			return _stronghold_pos(tree)
		"sh_seals":
			var isl = _stronghold(tree)
			if isl == null:
				return _stronghold_pos(tree)
			var gm: Node = tree.root.get_node("GameManager")
			var me := tree.get_first_node_in_group("player") as Node3D
			var best := Vector3.INF
			for f in SEAL_BOSSES:
				if gm.world_flags.has(f):
					continue
				var b: Dictionary = StrongholdBoss.BOSSES[SEAL_BOSSES[f]]
				var q: Vector2
				var y: float
				if b.has("room"):
					for r in StrongholdPlan.ROOMS:
						if str(r[0]) == str(b["room"]):
							q = (r[2] as Rect2).get_center()
							y = float(r[3])
				else:
					q = b["arena"][0]
					y = float(StrongholdPlan.DISTRICTS[int(b["district"])][2])
				var w: Vector3 = isl.city_global(q, y + 1.5)
				if best == Vector3.INF or (me and w.distance_to(me.global_position) < best.distance_to(me.global_position)):
					best = w
			return best
	push_error("LineQuests: no at \"%s\"" % at[0])
	return Vector3.INF


## (1.30, the stronghold's objective indicator) What to do in the stronghold district `at` stands in, or "" outside it:
## "THE ARSENAL  -  beat Lieutenant Kesh in the Casting Hall: the Arsenal's seal", with its muster flag while it's down.
static func district_hint(tree: SceneTree, at: Vector3) -> String:
	var isl = _stronghold(tree)
	if isl == null:
		return ""
	var l: Vector3 = isl.to_local(at)
	var di := StrongholdPlan.district_at(isl.to_city(Vector2(l.x, l.z)))
	if di < 0:
		return ""
	var gm: Node = tree.root.get_node("GameManager")
	var f: Dictionary = gm.world_flags
	var seals := SEAL_BOSSES.keys().filter(func(s): return f.has(s)).size()
	var key := str(StrongholdPlan.DISTRICTS[di][0])
	var hint := ""
	match key:
		"landing":
			hint = "climb the grand stair to the Lower Ward"
		"ward":
			hint = "the Arsenal (east) and the Prison Tower (west) hold the keep's seals: %d of 2 taken" % seals
		"arsenal":
			hint = "the Arsenal's seal is yours" if f.has("sh_seal_arsenal") else "beat Lieutenant Kesh in the Casting Hall for the Arsenal's seal"
		"prison":
			hint = "the prison's seal is yours" if f.has("sh_seal_prison") else "beat Captain Marrow in the yard for the prison's seal"
		"keep":
			if seals < 2:
				hint = "the keep's gate holds until both seals are yours (%d of 2)" % seals
			elif not f.has("sh_seal_keep"):
				hint = "beat Commodore Vane in the Command Hall"
			elif not gm.opened.has("sh_vault_%d" % int(gm.chain_seed)):
				hint = "open the Commodore's vault before his dais"
			else:
				hint = "get back to the ship and out of the ring"
	if StrongholdMuster.AT.has(key) and not f.has("sh_muster_" + key):
		hint += "; cut down their banner (F) for a muster point"
	var titles := {"landing": "THE LANDING", "ward": "THE LOWER WARD", "arsenal": "THE ARSENAL", "prison": "THE PRISON TOWER", "keep": "THE KEEP"}
	return "%s  -  %s" % [titles[key], hint]


static func npc(tree: SceneTree, who: String) -> Vector3:
	for p in tree.get_nodes_in_group("npcs"):
		if (p as NPC).npc_name == who:
			return (p as Node3D).global_position + Vector3.UP * KitQuests.HEAD
	return Vector3.INF


## The stronghold island while it stands (built when a ship is near), else null.
static func _stronghold(tree: SceneTree):
	var wg := tree.get_first_node_in_group("world_gen")
	if wg == null:
		return null
	var isl = wg.chain_islands.get(Chain.STRONGHOLD_ID)
	return isl if isl != null and is_instance_valid(isl) else null


static func _stronghold_pos(tree: SceneTree) -> Vector3:
	var c: Chain = tree.root.get_node("GameManager").chain()
	if c == null or c.stronghold_id() < 0:
		return Vector3.INF
	var p: Vector2 = c.node(c.stronghold_id())["pos"]
	return Vector3(p.x, 0.0, p.y)
