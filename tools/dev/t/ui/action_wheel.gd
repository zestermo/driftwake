extends SceneTree
## The action wheel (hold N) shows the whole list everywhere; ashore with no fire or water Make camp and Train can
## be done, the rest greyed with why (and an entry another feature registers joins in). Picking Make camp lays a campfire in front of you and sits you by it; sitting there a
## moment rests you (health back, the game saved) and the entry reads "Rest by the fire". The fire burns out.
const TK := preload("res://tools/dev/test_kit.gd")
const ALL := ["camp", "train", "cook", "read", "meditate", "tinker", "fish", "cut_bait", "sleep"]
var stage
var p
var w
var AW
var camp_script
var save
var ran := 0
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


func point_at(i: int) -> void:
	var a: float = TAU * i / w.entries.size()
	var mm := InputEventMouseMotion.new()
	mm.relative = Vector2(sin(a), -cos(a)) * 90.0
	mm.screen_relative = mm.relative
	w._input(mm)


func camps() -> Array:
	return get_nodes_in_group("camps")


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			w = p.action_wheel
			AW = load("res://scripts/game/action_wheel.gd")
			camp_script = load("res://scripts/game/camp.gd")
			save = load("res://scripts/game/save_game.gd")
			# (a file of its own: every stage test starting meanwhile wipes the shared test slot)
			save.use_test_file("user://t_action_wheel_%d.dat" % OS.get_process_id())
			check("ashore: the place is the island", AW.place(p) == "island")
			check("ashore: the whole list (%s)" % str(AW.entries_for(p)), AW.entries_for(p) == ALL)
			check("...Make camp and Train can be done (%s)" % str(AW.ready_for(p)), AW.ready_for(p) == ["camp", "train"])
			AW.register("t_wave", "Wave", "", func(pl): return AW.place(pl) == "island", func(_pl): ran += 1, 5)
			check("a registered entry joins in its order", AW.entries_for(p) == ["t_wave"] + ALL)
			AW.run("t_wave", p)
			AW.unregister("t_wave")
			check("...runs, and leaves when unregistered", ran == 1 and AW.entries_for(p) == ALL)
			p.health_component.current_health = 35.0
			save.delete()
			Input.action_press("action_wheel")
			until = TK.wait_ticks(3)
		1:
			check("holding N opens the wheel", w.is_open() and w.entries == ALL)
			check("...the camp entry reads Make camp", w.shown_text(0)[0] == "Make camp")
			var cook: int = ALL.find("cook")
			check("...Cook greyed, its reason with it (%s)" % w.shown_text(cook)[1], w._dim("cook") and w.shown_text(cook)[1] == "At a galley or campfire" and not w._dim("camp"))
			point_at(0)
			Input.action_release("action_wheel")
			until = TK.wait_ticks(4)
		2:
			var c: Array = camps()
			check("Make camp lays one campfire", c.size() == 1 and c[0].name == "Camp_1")
			if c.size() == 1:
				var to: Vector3 = (c[0] as Node3D).global_position - p.global_position
				check("...in front of you, on the ground (%.2f m)" % to.length(), to.length() < 1.6 and -p.player_model.global_basis.z.dot(to.normalized()) > 0.8 and absf(to.y) < 0.2)
			check("...and sits you by it (%s)" % p.current_state_name(), p.current_state_name() == "Sit")
			until = TK.wait_secs(camp_script.REST + 0.6)
		3:
			check("a rest by the fire: health back (%.0f)" % p.health_component.current_health, p.health_component.current_health == p.health_component.max_health)
			check("...and the game saved", save.exists())
			check("the entry now reads Rest by the fire", AW.label_of("camp", p) == "Rest by the fire")
			p.state_machine.force_state("Idle", {})
			camps()[0]._left = 0.3
			until = TK.wait_secs(0.6)
		4:
			check("the fire burns out", camps().is_empty())
			until = TK.wait_secs(1.8)
		5:
			check("...and the camp goes", stage.get_node_or_null("Camp_1") == null)
			save.delete()
			return TK.done(fails)
	step += 1
	return false
