class_name CityFavour
extends RefCounted
## A city's favour (1.27 C5, docs/v1_27_plan.md "The Queen and the Doge"): how many of the city's quests the crew has
## finished (its KitQuests' done, from the Journal: shared in co-op), as a rank. The capital's Crown: Known 3, Trusted 6,
## Champion 9; the canal's Lagoon: Friend 3, Citizen 5, Gondolier 7. The second rank takes DISCOUNT off every one of
## the city's traders (Journal.perks, as a quest's discount); the third is a title the ruler names you by. The Queen and
## the Doge tell you where you stand ({<city>_favour}).

const DISCOUNT := 0.1
const RANKS := {"capital": [[3, "Known to the Crown"], [6, "Trusted by the Crown"], [9, "Champion of the Crown"]],
	"canal": [[3, "Friend of the Lagoon"], [5, "Citizen of the Republic"], [7, "Gondolier of the Republic"]]}


## The city's quests done.
static func done(life) -> int:
	var j := (life as Node).get_node("/root/Journal")
	return life.quest_node.quests.filter(func(q): return j.is_done(str(q["id"]))).size()


## 0 (no standing yet) .. 3.
static func rank(city: String, n: int) -> int:
	var r := 0
	for k in range(RANKS[city].size()):
		if n >= int(RANKS[city][k][0]):
			r = k + 1
	return r


static func title(city: String, r: int) -> String:
	return "" if r <= 0 else str(RANKS[city][r - 1][1])


## What the ruler says of your standing, and how far to the next.
static func line(city: String, n: int) -> String:
	var r := rank(city, n)
	var now := "You are not yet known here." if r == 0 else "You are %s." % title(city, r)
	if r < RANKS[city].size():
		var need := int(RANKS[city][r][0]) - n
		return "%s %d more service%s to this city and you'll be %s." % [now, need, "" if need == 1 else "s", title(city, r + 1)]
	return "%s There is no higher honour I can give." % now


## The second rank's discount on every trader in the city (`shops`: their shop ids), kept as Journal perks.
static func apply(city: String, life, shops: Array) -> void:
	if rank(city, done(life)) < 2:
		return
	var j := (life as Node).get_node("/root/Journal")
	for s in shops:
		var k := "discount:" + str(s)
		j.perks[k] = maxf(float(j.perks.get(k, 0.0)), DISCOUNT)


## A ruler's line (the Queen's, the Doge's): its first step is one of the city's investigations (`q`, offered by its own
## giver); the ruler points you at it, thanks you once it's done (LINE_REWARD, once: "line:<city>:1" in Journal.perks),
## then tells of the next step, which waits for 1.27's stronghold / the pirate's hideout. `say`: ask, point, done_ask,
## done, next_ask, next (each a line or lines); `after`: a quest that opens the line (the Queen's audience).
const LINE_REWARD := {"gold": 400, "xp": 1.0}


static func ruler_line(city: String, life, q: Dictionary, menu: Array, nodes: Dictionary, say: Dictionary, after := "") -> void:
	var j := (life as Node).get_node("/root/Journal")
	var id := str(q["id"])
	var flag := "line:%s:1" % city
	menu.insert(0, {"text": say["ask"], "next": "line_point", "if": func(): return (after == "" or j.is_done(after)) and not j.is_done(id)})
	menu.insert(1, {"text": say["done_ask"], "next": "line_done", "if": func(): return j.is_done(id) and not j.perks.has(flag)})
	menu.insert(2, {"text": say["next_ask"], "next": "line_next", "if": func(): return j.perks.has(flag)})
	nodes["line_point"] = {"text": say["point"], "next": "menu"}
	nodes["line_done"] = {"text": say["done"], "event": "ruler:" + city, "next": "menu"}
	nodes["line_next"] = {"text": say["next"], "next": "menu"}


## The ruler's thanks for the line's first step (the dialogue's "ruler:<city>" event): the reward, once per save.
static func thank(city: String, life) -> void:
	var n := life as Node
	var j := n.get_node("/root/Journal")
	var flag := "line:%s:1" % city
	if j.perks.has(flag):
		return
	j.perks[flag] = true
	var p = n.get_tree().get_first_node_in_group("player")
	if p:
		QuestRewards.give(LINE_REWARD, p)
