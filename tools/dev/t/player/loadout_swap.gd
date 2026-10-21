extends SceneTree
## Weapon loadouts (X): the cutlass in hand is loadout 1; a tap of X takes up the empty loadout 2 with the same
## hands, and the twin daggers put in hand then are loadout 2. Taps swap between them with the blade still out;
## a tap mid-swing swaps the moment the swing ends. Held, X opens the loadout wheel (the third slot locked until
## the Captain tree's Quartermaster); letting go on a slot takes it up. The loadouts are saved and loaded, and a
## save from before them loads with the hands as loadout 1.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var w
var save
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"weapon": "cutlass", "hud": false})


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


func rewrite(change: Callable) -> void:
	var d: Dictionary = save._read(save.path())
	change.call(d)
	var f := FileAccess.open(save.path(), FileAccess.WRITE)
	f.store_var(d)
	f.close()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			w = p.loadout_wheel
			check("the cutlass in hand is loadout 1 (%s)" % str(p.loadouts), p.loadout_at == 0 and p.loadouts[0] == ["cutlass", ""])
			check("two loadouts to start", p.loadout_slots() == 2)
			TK.act("loadout")
			until = TK.wait_ticks(3)
		1:
			check("a tap of X takes up the empty loadout 2 with the same hands", p.loadout_at == 1 and p.loadouts[1] == ["cutlass", ""] and not w.is_open())
			var dg = ItemDB.get_item("dagger")
			p.inventory_component.add_item(dg, 2)
			p.equip_weapon(dg, false)
			p.set_offhand(dg)
			check("the twin daggers put in hand are loadout 2 (%s)" % str(p.loadouts), p.loadouts[1] == ["dagger", "dagger"] and p.loadouts[0] == ["cutlass", ""])
			TK.act("loadout")
			until = TK.wait_ticks(3)
		2:
			check("a tap swaps back to the cutlass (%s)" % p.style(), p.loadout_at == 0 and p.style() == "sword" and p.offhand_weapon == null)
			check("...with the blade still out, drawn again (%s)" % p.body_model.current_action(), p.armed and p.body_model.current_action() == "draw")
			until = TK.wait_secs(0.4)
		3:
			TK.act("light_attack")
			until = TK.wait_ticks(3)
		4:
			check("swinging (%s)" % p.current_state_name(), p.current_state_name() == "LightAttack")
			TK.act("loadout")
			until = TK.wait_ticks(2)
		5:
			check("no swap mid-swing", p.style() == "sword")
			until = TK.wait_secs(0.8)
		6:
			check("the swing over, the daggers are out (%s)" % p.style(), p.style() == "dual_dagger" and p.loadout_at == 1)
			until = TK.wait_secs(0.3)
		7:
			Input.action_press("loadout")
			until = TK.wait_secs(0.4)
		8:
			check("held, X opens the loadout wheel with three slots", w.is_open() and w.entries == [0, 1, 2])
			check("...named for their styles (%s / %s)" % [w.shown_text(0)[0], w.shown_text(1)[0]], w.shown_text(0)[0] == "Cutlass" and w.shown_text(1)[0] == "Twin daggers")
			check("...the third locked", w.shown_text(2)[0] == "Locked" and w._dim(2))
			point_at(0)
			Input.action_release("loadout")
			until = TK.wait_ticks(3)
		9:
			check("letting go on loadout 1 takes up the cutlass", not w.is_open() and p.loadout_at == 0 and p.style() == "sword")
			while p.progression.level < 10:
				p.progression.add_xp(p.progression.xp_to_next(p.progression.level) - p.progression.xp)
			check("the Quartermaster comes at Captain level 10", p.progression.owns("c_quarter"))
			check("...and opens a third loadout", p.loadout_slots() == 3)
			TK.act("loadout")
			until = TK.wait_secs(0.4)
		10:
			TK.act("loadout")
			until = TK.wait_ticks(3)
		11:
			check("taps go round all three (%d)" % p.loadout_at, p.loadout_at == 2 and p.loadouts[2] == ["dagger", "dagger"])
			save = load("res://scripts/game/save_game.gd")
			save.use_test_file("user://t_loadout_swap_%d.dat" % OS.get_process_id())
			p.unequip_weapon()
			check("fists on loadout 3", p.loadouts[2] == ["", ""])
			check("saved", save.save(p))
			p.loadouts = [[], [], []]
			p.loadout_at = 0
			check("loaded", save.load_into(p))
			check("the loadouts come back (%s, %d)" % [str(p.loadouts), p.loadout_at], p.loadouts == [["cutlass", ""], ["dagger", "dagger"], ["", ""]] and p.loadout_at == 2)
			rewrite(func(d):
				d.erase("loadouts")
				d.erase("loadout_at")
				d["weapon"] = ["id", "cutlass"])
			check("a save from before loadouts loads", save.load_into(p))
			check("...with the hands as loadout 1 (%s)" % str(p.loadouts), p.loadout_at == 0 and p.loadouts == [["cutlass", ""], [], []])
			save.delete()
			return TK.done(fails)
	step += 1
	return false
