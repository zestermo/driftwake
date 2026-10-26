extends SceneTree
## The hot pure-math candidates for native code (1.23 perf track, piece 4): the captain's own rig posed N times in a
## row (idle, running; whole, and without each part: springs, foot IK, the look layer), its parts alone (each spring
## chain's simulate, _foot_ik, _locomotion, _update_look), and the sea's wave height sampled. us per call, best of
## ROUNDS. On the light stage; headless is fine (scripts only): & $env:GODOT --headless --path . --script res://tools/dev/rigprobe.gd
const TK := preload("res://tools/dev/test_kit.gd")
const N := 300
const ROUNDS := 5
const DT := 1.0 / 60.0
var stage
var rig
var done := false


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func _process(_d: float) -> bool:
	if not stage.up or done:
		return false
	done = true
	rig = stage.player.body_model
	rig.set_process(false)
	for run in [false, true]:
		var tag := "run" if run else "idle"
		_line("pose %s whole" % tag, func(): _pose(run))
		var sims: Array = rig._sims
		rig._sims = []
		_line("pose %s no springs" % tag, func(): _pose(run))
		rig._sims = sims
		rig.foot_ik = false
		_line("pose %s no foot IK" % tag, func(): _pose(run))
		rig.foot_ik = true
		_line("  _locomotion %s" % tag, func(): _moving(run); rig._locomotion(DT))
		_line("  _foot_ik %s" % tag, func(): rig._foot_ik(DT))
		_line("  _update_look %s" % tag, func(): rig._update_look(DT))
		_line("  _update_physics (all %d spring sets) %s" % [rig._sims.size(), tag], func(): rig._update_physics(DT))
		for s in rig._sims:
			_line("    %s simulate (%s, %d chains)" % [s.name, s.mode, s._chains.size()], func(): s.simulate(DT))
	for lk in _dressed():
		rig.apply_look(lk)
		_line("pose run whole, %s" % lk["probe"], func(): _pose(true))
		for s in rig._sims:
			_line("    %s simulate (%s, %d chains)" % [s.name, s.mode, s._chains.size()], func(): s.simulate(DT))
			if s.native:
				s.native = false
				_line("    %s simulate (%s, %d chains), GDScript" % [s.name, s.mode, s._chains.size()], func(): s.simulate(DT))
				s.native = true
	var oc = root.get_node("Ocean")
	var at := Vector3(12.0, 0.0, -30.0)
	_line("Ocean.get_wave_height", func(): oc.get_wave_height(at))
	print("PROBE done")
	quit()
	return true


## The wardrobe's chains: a cape, the cloak, a long coat with long hair, a scarf and a sash, a skirt with a ponytail.
func _dressed() -> Array:
	var out: Array = []
	for o in [{"probe": "cape", "cape": true}, {"probe": "cloak", "cloak": true},
			{"probe": "longcoat+long hair+scarf+sash", "coat": "longcoat", "hair": "long", "scarf": true, "belt": "sash"},
			{"probe": "skirt+ponytail", "legs": "skirt", "hair": "ponytail"}]:
		var lk: Dictionary = CharacterLook.default_look()
		lk.merge(o, true)
		out.append(lk)
	return out


func _moving(run: bool) -> void:
	rig.ground_speed = 6.0 if run else 0.0
	rig.local_move = Vector2(0, 1)
	rig.grounded = true


func _pose(run: bool) -> void:
	_moving(run)
	rig._pose(DT)


## us per call: best of ROUNDS rounds of N calls.
func _line(what: String, f: Callable) -> void:
	var best := INF
	for r in range(ROUNDS):
		var t0 := Time.get_ticks_usec()
		for i in range(N):
			f.call()
		best = minf(best, float(Time.get_ticks_usec() - t0) / N)
	print("PROBE %-58s %8.1f us" % [what, best])
