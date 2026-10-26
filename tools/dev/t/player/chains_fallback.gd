extends SceneTree
## Without the native library (SpringChains.native_ok false, as when the DLL isn't there or is out of date) bodies built
## afterwards run every chain on the GDScript solver: hair and cloth still swing, finite, and nothing asks for ChainSolver.
const TK := preload("res://tools/dev/test_kit.gd")
const KIT := preload("res://tools/dev/t/player/_chains_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0


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
	SpringChains.native_ok = false
	for lk in KIT.looks():
		var tag := "cloak" if lk.get("cloak", false) else "cape"
		var h = Humanoid.new()
		h.setup(lk)
		root.add_child(h)
		h.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		h.set_process(false)
		h.set_physics_process(false)
		h.position = Vector3(0, 3.0, 0)
		check("%s: every chain set built on the GDScript solver" % tag, h._sims.all(func(s): return not s.native))
		var swing := 0.0
		var finite := true
		for i in range(KIT.FRAMES):
			KIT.drive(h, i, KIT.yaw_at(i))
			for s in h._sims:
				for bi in range(s.skel.get_bone_count()):
					var o: Vector3 = s.skel.get_bone_global_pose(bi).origin
					finite = finite and o.is_finite()
					swing = maxf(swing, o.distance_to(s.skel.get_bone_global_rest(bi).origin))
		check("%s: no native solver made" % tag, h._sims.all(func(s): return s._nat == null))
		check("%s: the chains swung (%.2f m off rest)" % [tag, swing], swing > 0.1)
		check("%s: every bone finite" % tag, finite)
		h.queue_free()
	return TK.done(fails)
