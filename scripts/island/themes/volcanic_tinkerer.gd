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
	dlg.define(key, {"speaker": who, "voice": 0.8, "start": "intro", "return": "menu", "nodes": {
		"intro": {"text": ["Mind the springs. Everything on this bench wants to fly apart, and some of it's supposed to.",
			"I draw gadgets. Hooks, pellets, boots with a kick in them. You build them at a bench like this one. I teach the drawing."], "next": "menu"},
		"menu": {"text": ["What'll it be, Captain?"], "choices": [
			{"text": "Teach me a blueprint. (%d gold)" % price, "next": "teach"},
			{"text": "What's the bench for?", "next": "bench"},
			{"text": "Goodbye.", "next": "end"}]},
		"teach": {"text": ["{%s}" % _token()], "event": "volcanic_teach:" + key, "next": "menu"},
		"bench": {"text": ["Blueprint, parts, a steady hand. The bench does the rest. Use it, it's free. Parts aren't.",
			"Salvage, ore, a beast's horn: it all goes into something. The traders by the quay sell the dull bits."], "next": "menu"},
	}})
	dlg.dialogue_event.connect(_on_event)
	return key


func _token() -> String:
	return "tinker_" + key


func _on_event(ev: String) -> void:
	if ev != "volcanic_teach:" + key:
		return
	var p := get_tree().get_first_node_in_group("player")
	_said = teach(p)


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
