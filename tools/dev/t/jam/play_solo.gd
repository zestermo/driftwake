extends SceneTree
## Playing alone: with an instrument worn the emote wheel (hold T) gets "Play"; picking it holds the instrument up
## (music_<kind>, the hands on it, the stem playing from the shared clock) and ducks the music; moving stops it,
## a hit stops it; a lone captain's tune is picked at random.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0
var tunes := {}
var tries := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func point_at(i: int, n: int) -> void:
	var a := TAU * i / n
	var mm := InputEventMouseMotion.new()
	mm.relative = Vector2(sin(a), -cos(a)) * 90.0
	mm.screen_relative = mm.relative
	p.emote_wheel._input(mm)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			Input.action_press("emote")
			until = TK.wait_ticks(3)
		1:
			check("no instrument, no Play on the wheel", not p.emote_wheel.entries.has("play"))
			Input.action_release("emote")
			var it = ItemDB.get_item("concertina")
			p.inventory_component.add_item(it, 1)
			p.equip_gear_from_bag(p.inventory_component.find_index("concertina"))
			until = TK.wait_ticks(4)
		2:
			Input.action_press("emote")
			until = TK.wait_ticks(3)
		3:
			var e: Array = p.emote_wheel.entries
			check("an instrument worn: Play on the wheel (%d entries)" % e.size(), e.has("play"))
			point_at(e.find("play"), e.size())
			check("pointing at it picks Play", p.emote_wheel._pick == e.find("play"))
			Input.action_release("emote")
			until = TK.wait_ticks(3)
		4:
			var j = p.jam
			check("letting go of T plays it (%s)" % p.body_model.current_action(), j.playing and p.body_model.current_action() == "music_concertina")
			check("a tune of the four, started now", j.tune >= 0 and j.tune < Instruments.TUNES.size() and absf(j.where() - (root.get_node("Net").time() - j.t0)) < 0.01 and j.where() < 0.5)
			check("its concertina stem (%s)" % str(j._audio.stream.resource_path), j._audio.stream.resource_path == Instruments.tune_path(j.tune, "concertina") and j._audio.bus == "SFX")
			check("all of a tune's stems are one length", _same_lengths(j.tune))
			until = TK.wait_secs(1.2)
		5:
			var j = p.jam
			check("faded in (%.2f)" % j._gain, j._gain > 0.99)
			check("the instrument is in the hands, not on the back", not j._back.visible and j._parts["end_r"].visible)
			var hr: Vector3 = p.body_model.hand_r.global_position
			var er: Vector3 = j._parts["end_r"].global_position
			check("the right hand is on its end (%.2f m)" % hr.distance_to(er), hr.distance_to(er) < 0.12)
			check("the music ducks (%.1f dB)" % p.jam.music_duck_db(), p.jam.music_duck_db() < -6.0)
			Input.action_press("move_forward")
			until = TK.wait_ticks(10)
		6:
			Input.action_release("move_forward")
			check("moving stops it (%s)" % p.body_model.current_action(), not p.jam.playing and p.body_model.current_action() != "music_concertina")
			until = TK.wait_secs(0.6)
		7:
			check("the concertina back on the back", p.jam._back.visible)
			p.state_machine.force_state("Idle", {})
			p.velocity = Vector3.ZERO
			p.jam.start()
			until = TK.wait_ticks(3)
		8:
			check("playing again", p.jam.playing)
			var hd := HitData.new()
			hd.damage = 1.0
			p.hurtbox.hit_received.emit(hd, null)
			until = TK.wait_ticks(2)
		9:
			check("a hit stops it", not p.jam.playing)
			until = TK.wait_secs(2.0)
		10:
			check("the music comes back up (%.1f dB)" % p.jam.music_duck_db(), p.jam.music_duck_db() > -1.0)
		11:
			# alone, each start picks its tune at random
			p.state_machine.force_state("Idle", {})
			p.velocity = Vector3.ZERO
			p.jam.start()
			tunes[p.jam.tune] = true
			p.jam.stop()
			tries += 1
			if tries < 12:
				until = TK.wait_ticks(2)
				return false
			check("a lone start picks a random tune (%d different in 12)" % tunes.size(), tunes.size() >= 2)
			return TK.done(fails)
	step += 1
	return false


func _same_lengths(tune: int) -> bool:
	var l0 := -1.0
	for k in Instruments.KINDS:
		var l: float = (load(Instruments.tune_path(tune, k)) as AudioStream).get_length()
		if l0 < 0.0:
			l0 = l
		if absf(l - l0) > 0.002:
			return false
	return true
