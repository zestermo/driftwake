extends SceneTree
## A quest is turned in to whoever gave it, and only them: Kai offers a parcel for Pua; once taken Kai only
## reminds you, Pua takes the parcel (and has no turn-in of her own), then Kai's "done" shows and pays. A fetch
## quest's turn-in shows only while you carry what it asks for, and takes it from your bag.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var j
var dlg
var src
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"npc": {"name": "Net-mender Kai", "at": Vector3(-3, 0, -3)}})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func texts() -> Dictionary:
	return {"ask": "Need a hand?", "plea": ["Take this to Pua."], "accept": "I'll see to it.", "decline": "Not now.", "taken": "Good.",
		"remind_choice": "Who was it for?", "remind": "Pua, by the well.", "done": "It's done.", "thanks": ["Thank you."],
		"hand": "A parcel from Kai.", "got": ["From Kai? Well."], "favour_ask": "", "favour_thanks": []}


func menu(id: String) -> Array:
	dlg._cooldown = 0.0
	dlg.start(id, null)
	dlg._goto("menu")
	var out: Array = dlg._box._choices.map(func(c): return str(c["text"]))
	dlg._close()
	dlg._cooldown = 0.0
	return out


func say(id: String, node: String) -> void:
	dlg._cooldown = 0.0
	dlg.start(id, null)
	dlg._goto(node)
	dlg._close()
	dlg._cooldown = 0.0


func define(id: String, who: String, build: Callable) -> void:
	var m: Array = []
	var nodes := {"menu": {"text": "Yes?", "choices": m}}
	build.call(m, nodes)
	m.append({"text": "Goodbye.", "next": "end"})
	dlg.define(id, {"speaker": who, "start": "menu", "nodes": nodes})


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			j = root.get_node("Journal")
			dlg = root.get_node("Dialogue")
			j.reset()
			src = load("res://scripts/island/kit/kit_quests.gd").new()
			src.name = "Quests"
			stage.add_child(src)
			var parcel: Dictionary = texts().merged({"id": "t_parcel", "kind": "deliver", "title": "A parcel for Pua", "giver": "Net-mender Kai", "isle": "Test Isle",
				"pos": Vector3.ZERO, "src": "npc", "recipient": "Pua", "reward": {"gold": 15},
				"steps": [{"do": "talk", "goal": "Take the parcel to Pua", "who": "Pua"}, {"do": "turnin", "goal": "Tell Kai it's delivered"}]})
			var fetch: Dictionary = texts().merged({"id": "t_fish", "kind": "fetch", "title": "Two fish for Kai", "giver": "Net-mender Kai", "isle": "Test Isle",
				"pos": Vector3.ZERO, "src": "npc", "reward": {"gold": 20}, "cost": [["fish", 2]], "ask": "Hungry?", "remind": "Two fish.", "done": "Here: two fish.",
				"remind_choice": "What did you need?", "steps": [{"do": "turnin", "goal": "Bring two fish to Kai"}]}, true)
			for q in [parcel, fetch]:
				src.quests.append(q)
				j.register(q, src)
			define("t_kai", "Net-mender Kai", func(m, nodes):
				src.offer(parcel, m, nodes)
				src.offer(fetch, m, nodes))
			define("t_pua", "Pua", func(m, nodes): src.hand_over(parcel, m, nodes))
			var kai := menu("t_kai")
			check("Kai offers both (%s)" % [kai], kai.has("Need a hand?") and kai.has("Hungry?") and not kai.has("It's done."))
			check("Pua has nothing for you yet", not menu("t_pua").has("A parcel from Kai."))
			say("t_kai", "q_t_parcel_take")
			kai = menu("t_kai")
			check("taken: in the journal, and Kai only reminds you (%s)" % [kai], j.has("t_parcel") and kai.has("Who was it for?") and not kai.has("Need a hand?") and not kai.has("It's done."))
			var pua := menu("t_pua")
			check("Pua takes the parcel, with no turn-in of her own (%s)" % [pua], pua.has("A parcel from Kai.") and not pua.has("It's done."))
			say("t_pua", "q_t_parcel_got")
			check("handed over: the quest's on its turn-in", j.at_turnin("t_parcel"))
			check("...Pua is done with it (no turn-in to her)", not menu("t_pua").has("A parcel from Kai.") and not menu("t_pua").has("It's done."))
			kai = menu("t_kai")
			check("...and Kai's turn-in shows (%s)" % [kai], kai.has("It's done."))
			var g0: int = p.inventory_component.count("gold")
			say("t_kai", "q_t_parcel_pay")
			check("told Kai: Done and paid", j.is_done("t_parcel") and p.inventory_component.count("gold") - g0 == 15)
			# the fetch: on its turn-in from the start, but only with two fish in the bag
			say("t_kai", "q_t_fish_take")
			kai = menu("t_kai")
			check("fetch taken, no fish: Kai reminds, no turn-in (%s)" % [kai], j.at_turnin("t_fish") and kai.has("What did you need?") and not kai.has("Here: two fish."))
			check("...the goal counts what you carry (%s)" % j.goal("t_fish"), j.goal("t_fish") == "Bring two fish to Kai (0/2)")
			p.inventory_component.add_item(ItemDB.get_item("fish"), 3)
			kai = menu("t_kai")
			check("with the fish: the turn-in shows (%s)" % [kai], kai.has("Here: two fish.") and not kai.has("What did you need?"))
			say("t_kai", "q_t_fish_pay")
			check("handed over: two fish gone from the bag, Done", p.inventory_component.count("fish") == 1 and j.is_done("t_fish"))
			return TK.done(fails)
	step += 1
	return false
