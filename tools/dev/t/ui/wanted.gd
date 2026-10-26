extends SceneTree
## 1.23 "Bounty": a deed raises your bounty and is logged with why (saved with you); the pause menu's Wanted screen
## shows your number, its tier, what's next and the deeds; the HUD says HUNTED while a ship is chasing you (group
## "pursuing") and lets go when it's gone.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var hud
var chaser: Node
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			hud = get_first_node_in_group("hud")
			p.bounty = 0
			p.bounty_log.clear()
			Bounty.add(p, 6000, "boss")
			check("the deed raised it and was logged with why (%s)" % str(p.bounty_log), p.bounty == 6000 and p.bounty_log.size() == 1
				and p.bounty_log[0][0] == "boss" and int(p.bounty_log[0][1]) == 6000)
			var nx := Bounty.next_tier(6000)
			check("the next tier is Notorious at 20,000 (%s)" % str(nx), nx.size() == 3 and nx[0] == "Notorious" and int(nx[1]) == 20000)
			root.get_node("GameMenu").open("wanted")
			until = TK.wait_secs(0.5)
		1:
			var ws = root.get_node("GameMenu")._wanted
			check("the Wanted screen: your number and tier (%s / %s)" % [ws._amount.text, ws._tier.text], ws.visible and ws._amount.text == "6,000 gold" and ws._tier.text == "Wanted")
			check("...and the deed that raised it", ws._deeds.get_child_count() >= 1)
			root.get_node("GameMenu").close()
			chaser = Node3D.new()
			chaser.add_to_group("pursuing")
			stage.add_child(chaser)
			until = TK.wait_secs(1.2)
		2:
			check("HUNTED while a ship chases (%s)" % hud._heat_label.text, hud._heat_label.visible and hud._heat_label.text.begins_with("HUNTED"))
			chaser.queue_free()
			until = TK.wait_secs(1.2)
		3:
			check("...and it lets go when the chase is over", not hud._heat_label.visible)
			return TK.done(fails)
	step += 1
	return false
