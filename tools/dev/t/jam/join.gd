extends SceneTree
## Joining a jam: a stand-in crewmate (a puppet captain, as co-op makes them) is playing the hurdy-gurdy 4 m away,
## 7.3 s into "The Drowned Bell". The music ducks for them; starting the whistle takes their tune and their start
## (the same place in it) and fades in over two beats. Beyond 20 m a captain starts a jam of their own.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var other
var net
var step := 0
var until := 0
var fails := 0
var t0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


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
			net = root.get_node("Net")
			other = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
			other.is_local = false
			other.net_id = 2
			other.name = "P2"
			stage.add_child(other)
			other.global_position = p.global_position + Vector3(4, 0, 0)
			until = TK.wait_ticks(4)
		1:
			t0 = net.time() - 7.3
			other.jam.net_event("jam", ["gurdy", 2, t0])
			var it = ItemDB.get_item("tin_whistle")
			p.inventory_component.add_item(it, 1)
			p.equip_gear_from_bag(p.inventory_component.find_index("tin_whistle"))
			until = TK.wait_secs(0.8)
		2:
			var oj = other.jam
			check("the crewmate plays: the gurdy's stem of the bell, past 7.3 s (%.2f)" % oj.where(), oj.playing and oj.kind == "gurdy" and oj.tune == 2 and oj.where() > 7.3 and oj.where() < 12.0)
			check("its gurdy is in its hands", oj._parts.has("crank") and oj._parts["crank"].visible)
			check("the music ducks for a crewmate playing near (%.1f dB)" % p.jam.music_duck_db(), p.jam.music_duck_db() < -6.0)
			p.jam.start()
			check("starting near them joins their tune (%d) at their start (%.4f off)" % [p.jam.tune, p.jam.t0 - t0], p.jam.playing and p.jam.tune == 2 and absf(p.jam.t0 - t0) < 0.0001)
			check("at the same place in it (%.3f / %.3f)" % [p.jam.where(), oj.where()], absf(p.jam.where() - oj.where()) < 0.001)
			check("on the whistle's stem", p.jam._audio.stream.resource_path == Instruments.tune_path(2, "whistle"))
			until = TK.wait_ticks(3)
		3:
			var two: float = p.jam.beat_len() * 2.0
			check("fading in over two beats (%.2f, two beats %.2f s)" % [p.jam._gain, two], p.jam._gain > 0.0 and p.jam._gain < 0.3 and two > 0.6 and two < 2.0)
			until = TK.wait_secs(p.jam.beat_len() * 2.0 + 0.2)
		4:
			check("in after two beats (%.2f)" % p.jam._gain, p.jam._gain > 0.99)
			check("in step: the same beat on both (%.3f)" % p.jam.beats(), absf(p.jam.beats() - other.jam.beats()) < 0.001)
			p.jam.stop()
			other.global_position = p.global_position + Vector3(30, 0, 0)
			until = TK.wait_ticks(4)
		5:
			p.state_machine.force_state("Idle", {})
			p.velocity = Vector3.ZERO
			p.jam.start()
			check("30 m off: a jam of our own (start %.2f s from theirs)" % (p.jam.t0 - t0), p.jam.playing and absf(p.jam.t0 - t0) > 5.0 and p.jam.where() < 0.2)
			return TK.done(fails)
	step += 1
	return false
