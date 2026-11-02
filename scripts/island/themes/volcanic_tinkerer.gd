extends Node
## The forge town's master tinkerer's teaching (VolcanicTown): his conversation, and on "Teach me" the first blueprint
## in his order (seeded per island) that the captain talking doesn't know, for `price` gold (Gadgets.teach). The answer
## is his line's token, filled as the line shows. Each captain learns on their own machine.

var key := ""
var who := ""
var price := 0
var order: Array = []
var _said := ""


## Defines his conversation (Dialogue.define); its id.
func define() -> String:
	var dlg := get_node("/root/Dialogue")
	dlg.register_token(_token(), func() -> String: return _said)
	# (1.28) his shelf of books (Books.tinker_shop)
	preload("res://scripts/game/shops.gd").extra[key + "_books"] = Books.tinker_shop(who.get_slice(" ", who.get_slice_count(" ") - 1))
	var nodes := {
		"intro": {"text": ["Mind the springs. Everything on this bench wants to fly apart, and some of it's supposed to.",
			"I draw gadgets. Hooks, pellets, boots with a kick in them. You build them at a bench like this one. I teach the drawing."], "next": "menu"},
		"books": {"text": ["Books. Every one of them has a gadget in it somewhere, if you read it right."], "event": "shop:" + key + "_books", "next": "end"},
		"menu": {"text": ["What'll it be, Captain?"], "choices": [
			{"text": "Teach me a blueprint. (%d gold)" % price, "next": "teach"},
			{"text": "A gadget belt. (%d gold)" % GadgetData.BELT_PRICE, "next": "belt"},
			{"text": "A gadget bag. (%d gold)" % GadgetBag.PRICE, "next": "bag"},
			{"text": "Any books?", "next": "books"},
			{"text": "What's the bench for?", "next": "bench"},
			{"text": "Goodbye.", "next": "end"}]},
		"teach": {"text": ["{%s}" % _token()], "event": "volcanic_teach:" + key, "next": "menu"},
		# (1.28.1) the gadget bag: one belt carries one gadget, his bag six; four colours, the same stitching
		"belt": {"text": ["{%s}" % _token()], "event": "volcanic_belt:" + key, "next": "menu"},
		"bag": {"text": ["A belt holds two gadgets. My bag holds four, with a wheel to pick from, and the clasp keeps them in when you're thrown about.",
			"Same cut, four cloths. Which?"], "choices": GadgetBag.ORDER.map(func(c): return {"text": c.capitalize() + ".", "next": "bag_" + c}) + [{"text": "Not now.", "next": "menu"}]},
		"bench": {"text": ["Blueprint, parts, a steady hand. The bench does the rest. Use it, it's free. Parts aren't.",
			"Salvage, ore, a beast's horn: it all goes into something. The traders by the quay sell the dull bits."], "next": "menu"},
	}
	for c in GadgetBag.ORDER:
		nodes["bag_" + c] = {"text": ["{%s}" % _token()], "event": "volcanic_bag:%s:%s" % [key, c], "next": "menu"}
	dlg.define(key, {"speaker": who, "voice": 0.8, "start": "intro", "return": "menu", "nodes": nodes})
	dlg.dialogue_event.connect(_on_event)
	return key


func _token() -> String:
	return "tinker_" + key


func _on_event(ev: String) -> void:
	var p := get_tree().get_first_node_in_group("player")
	if ev == "volcanic_teach:" + key:
		_said = teach(p)
	elif ev == "volcanic_belt:" + key:
		_said = Gadgets.buy_belt(p)
	elif ev.begins_with("volcanic_bag:%s:" % key):
		_said = Gadgets.buy_bag(p, ev.get_slice(":", ev.get_slice_count(":") - 1))


## Teaches the captain `p` the first blueprint in his order they don't know, if they can pay; his answer.
func teach(p: Node) -> String:
	var inv = p.inventory_component
	if inv.count("gold") < price:
		return "That's %d gold, Captain. Come back when your purse is heavier. The drawings will keep." % price
	for id in order:
		if Gadgets.teach(p, id):
			inv.remove_item(ItemDB.get_item("gold"), price)
			return "Watch closely. There: that's the whole trick of it. Build it at a bench when you've the parts."
	return "You know everything I've drawn, Captain. Come back when I've worked out something new."
