extends SceneTree
## 1.23 beast pass: the Sand King. Phase 1 erupts, bites, slams and dives; each phase change is a moment; phase 2 adds
## the Sinkhole and the Acid Spit, phase 3 the Twin (a second worm up with it, biting) and the Sandstorm (it hunts by
## sound: a captain standing still is lost to it, one who moves is found); it never starts the same move twice running
## through its later phases. Its mandibles broken: no more Bite, a Mandible drops; a plate broken: a quarter more damage.
const TK := preload("res://tools/dev/test_kit.gd")
const FIGHT_S := 22.0
var stage
var p
var w
var step := 0
var until := 0
var fails := 0
var t := 0.0
var seq: Array = []
var was := ""


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _hp() -> float:
	return p.get_node("HealthComponent").current_health


func _drop_has(id: String) -> bool:
	for n in current_scene.get_children():
		if str(n.name).begins_with("Drop_") and n.contents.any(func(s): return s.item.id == id):
			return true
	return false


func _process(d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			p.get_node("HealthComponent").max_health = 99999.0
			p.get_node("HealthComponent").current_health = 99999.0
			var th = load("res://scripts/island/themes/island_themes.gd").of("desert")
			var at: Vector3 = p.global_position + Vector3(0, 0, -10.0)
			w = load(th.beasts["sandworm"]["script"]).new()
			w.setup({"post": at, "yaw": 0.0, "level": 6, "name": "The Sand King"})
			stage.add_child(w)
			w.global_position = at
			until = TK.wait_ticks(10)
		1:
			var m: Array = w.bp.moves()
			check("phase 1: erupt, bite, slam, dive (%s)" % str(m), m.size() == 4 and "bite" in m and not "sinkhole" in m and not "twin" in m)
			w.alert()
			until = TK.wait_secs(4.0)
		2:
			w.health.current_health = w.health.max_health * 0.55
			w._phase_check()
			check("below 60%%: phase 2, the moment (%s)" % w.move, w.phase == 2 and w.move == "moment")
			until = TK.wait_secs(3.0)
		3:
			var m: Array = w.bp.moves()
			check("phase 2 adds the Sinkhole and the Acid Spit (%s)" % str(m), "sinkhole" in m and "spit" in m and not "sandstorm" in m)
			w.health.current_health = w.health.max_health * 0.25
			w._phase_check()
			until = TK.wait_secs(3.0)
		4:
			var m: Array = w.bp.moves()
			check("phase 3 adds the Twin and the Sandstorm (%s)" % str(m), "twin" in m and "sandstorm" in m)
			t = 0.0
			seq = []
			was = ""
			step = 5
			return false
		5:
			# (the captain keeps moving: heard through any storm)
			t += d
			p.get_node("HealthComponent").current_health = 99999.0
			p.global_position = w.post + Vector3(sin(t * 0.7) * 7.0, 0.0, cos(t * 0.7) * 7.0)
			p.global_position.y = w.post.y + 0.1
			p.reset_physics_interpolation()
			if w.move != "" and w.move != was and w.move != "moment":
				seq.append(w.move)
			was = w.move
			if t < FIGHT_S:
				return false
			var twice := false
			for i in range(1, seq.size()):
				if seq[i] == seq[i - 1]:
					twice = true
			check("never the same move twice running: %s" % str(seq), not twice and seq.size() >= 4)
		6:
			# the twin, up with it
			w.end_move()
			w.rise = 0.0
			w.film("twin")
			until = TK.wait_secs(2.2)
		7:
			check("the Twin surfaces with it (up %.1f, %.1f s left)" % [w._twin_rise, w._twin_t], w._twin_t > 0.0 and w._twin_model.visible)
			# the storm: standing still, it loses you
			w.end_move()
			w._storm_t = 10.0
			w._heard.clear()
			w._heard_at.clear()
			until = TK.wait_secs(1.2)
		8:
			check("in the sandstorm a captain standing still isn't heard", w._target() == null)
			p.global_position += Vector3(2.0, 0, 0)
			until = TK.wait_secs(0.6)
		9:
			p.global_position += Vector3(2.0, 0, 0)
			until = TK.wait_secs(0.6)
		10:
			check("...one who moves is", w._target() == p)
			w._storm_t = 0.0
			w.part_hit("mandibles", 99999.0)
			w.part_hit("plate_a", 99999.0)
			until = TK.wait_secs(0.5)
		11:
			check("mandibles broken: no more Bite (%s)" % str(w.bp.moves()), not "bite" in w.bp.moves())
			check("...and a Sand King Mandible drops", _drop_has("mandible"))
			check("a plate broken: it takes a quarter more (x%.2f), a plate drops" % w._taken_k(p), absf(w._taken_k(p) - 1.25) < 0.01 and _drop_has("sand_plate"))
			check("parts_broken() counts them for the arcs (%d)" % w.parts_broken(), w.parts_broken() == 2)
			return TK.done(fails)
	step += 1
	return false
