extends SceneTree
## The cloth lab: the cape's net on everything else (1.24). The captain in a look (long flowing hair; twin tails and a
## skirt; a long coat with long hair and a sash; a bandana, a braid and an apron) runs the cape lab's fixed script
## (walk, run, a sharp 180 turn, a dead stop, a jump, the cutlass combo's spin) twice, the net off
## (BodyBuilder.cloth_net false: the plain chains) and on, filmed at the PSX pixel grid at the key moments. Run it at a
## fixed frame rate so the two runs line up frame for frame:
##   & $env:GODOT --path . --fixed-fps 144 --script res://tools/dev/clothlab.gd
## Args: [out_dir=res://tools/dev/out/clothlab] [looks=hair,twin,coat,ties]
## Writes sheet_<look>.png (net off on top, on below; a column a moment) and metrics.txt (also printed): for every
## frame drawn, the chains' segments (as the bones draw them) inside the legs', hips' and torso's capsules, and the
## most any segment swung off its rest direction.
const TK := preload("res://tools/dev/test_kit.gd")
const CROP := Vector2i(200, 250)
const EVENTS := [[2.0, "walk"], [3.2, "run"], [4.4, "turn"], [5.3, "stop"], [7.3, "jump"], [8.6, "draw"],
	[9.3, "attack"], [9.75, "attack"], [10.35, "attack"], [12.0, "end"]]
const MOMENTS := [["run", 4.2, "behind"], ["turn1", 4.55, "q3"], ["turn2", 4.8, "behind"], ["stop1", 5.4, "side"],
	["stop2", 5.8, "behind"], ["jump", 7.65, "side"], ["spin1", 10.6, "q3"], ["spin2", 10.85, "behind"]]
const CAPS := ["thigh_l", "thigh_r", "shin_l", "shin_r", "hips", "torso"]
const LOOKS := {
	"hair": {"body": "fem", "hair": "cascade", "coat": "none"},
	"twin": {"body": "fem", "hair": "twintails", "legs": "skirt", "coat": "none"},
	"coat": {"hair": "long", "coat": "longcoat", "belt": "sash"},
	"ties": {"hair": "braid", "hat": "bandana", "apron": true, "coat": "none"},
}

var stage
var p
var out_dir := "res://tools/dev/out/clothlab"
var looks: Array = ["hair", "twin", "coat", "ties"]
var runs: Array = []
var run := -1
var t0 := 0
var ev := 0
var mo := 0
var cam: Camera3D
var pending := ""
var shots := {}
var rec := {}
var report: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		looks = Array(args[1].split(","))
	for lk in looks:
		for net in [false, true]:
			runs.append([lk, net])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "cutlass"})
	RenderingServer.frame_post_draw.connect(_grab)


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	if run < 0:
		var st = root.get_node("Settings")
		st.set_value("video", "pixelate", true, false)
		st.set_value("video", "dither", true, false)
		p = stage.player
		p.health_component.max_health = 99999.0
		p.health_component.current_health = 99999.0
		var rig := Node3D.new()
		var arm := Node3D.new()
		cam = Camera3D.new()
		cam.fov = 50.0
		cam.far = 300.0
		cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		# (in a rig and an arm at yaw 0: the player's states read the move direction off the camera's grandparent)
		rig.add_child(arm)
		arm.add_child(cam)
		stage.add_child(rig)
		cam.current = true
		_next()
		return false
	var t := (Engine.get_physics_frames() - t0) / float(Engine.physics_ticks_per_second)
	var cur := run
	while ev < EVENTS.size() and t >= float(EVENTS[ev][0]) and run == cur:
		ev += 1
		_event(str(EVENTS[ev - 1][1]))
	if run >= runs.size():
		return true
	if run != cur:
		return false
	_measure()
	var view := "behind"
	pending = ""
	if mo < MOMENTS.size() and t >= float(MOMENTS[mo][1]):
		pending = MOMENTS[mo][0]
		view = MOMENTS[mo][2]
		mo += 1
	_place(view)
	return false


func _next() -> void:
	run += 1
	if run >= runs.size():
		_sheets()
		var f := FileAccess.open(out_dir + "/metrics.txt", FileAccess.WRITE)
		f.store_string("\n".join(report) + "\n")
		print("\n".join(report))
		print("CLOTHLAB done")
		quit()
		return
	var r: Array = runs[run]
	BodyBuilder.cloth_net = r[1]
	seed(4242)
	p.sheathe_weapon(true)
	p.state_machine.force_state("Idle", {})
	p.global_position = Vector3(0, 3.05, 0)
	p.velocity = Vector3.ZERO
	p.player_model.rotation.y = 0.0
	var lk: Dictionary = CharacterLook.default_look()
	lk.merge(LOOKS[r[0]], true)
	p.body_model.apply_look(lk)
	var hm = p.body_model
	hm._rng.seed = 4242
	hm._t = 0.0
	hm._phase = 0.0
	hm._idle_seed = 0.0
	hm._glance_t = 1.0
	hm._glance = Vector3.ZERO
	p.reset_physics_interpolation()
	t0 = Engine.get_physics_frames()
	ev = 0
	mo = 0
	rec = {"frames": 0, "pen_frames": 0, "pen_n": 0, "pen_worst": 0.0, "swing": 0.0}
	print("RUN %s net %s" % r)


func _event(e: String) -> void:
	match e:
		"walk":
			TK.press("move_forward")
		"run":
			TK.press("sprint")
		"turn":
			TK.release("move_forward")
			TK.press("move_back")
		"stop":
			TK.release("move_back")
			TK.release("sprint")
		"jump":
			TK.act("jump")
		"draw":
			p.draw_weapon(true)
		"attack":
			TK.act("light_attack")
		"end":
			TK.release("move_forward")
			TK.release("move_back")
			TK.release("sprint")
			var r: Array = runs[run]
			report.append("%-5s net %-5s frames %4d  segments inside the body: %4d in %3d frames (worst %.1f cm)  most swing %.0f deg" % [
				r[0], "on" if r[1] else "off", rec["frames"], rec["pen_n"], rec["pen_frames"], rec["pen_worst"] * 100.0, rad_to_deg(rec["swing"])])
			_next()


func _facing_yaw() -> float:
	var f: Vector3 = -p.player_model.get_global_transform_interpolated().basis.z
	return atan2(-f.x, -f.z)


func _place(view: String) -> void:
	var at: Vector3 = p.get_global_transform_interpolated().origin
	var yaw := _facing_yaw()
	var back := Vector3(sin(yaw), 0, cos(yaw))
	var aim := at + Vector3(0, 0.95, 0)
	match view:
		"q3":
			cam.look_at_from_position(at + back.rotated(Vector3.UP, 0.87) * 4.0 + Vector3(0, 1.7, 0), aim, Vector3.UP)
		"side":
			cam.look_at_from_position(at + back.rotated(Vector3.UP, PI * 0.5) * 4.0 + Vector3(0, 1.3, 0), aim, Vector3.UP)
		_:
			cam.look_at_from_position(at + back * 4.2 + Vector3(0, 1.9, 0), aim, Vector3.UP)


## Every drawn frame: each chain segment of the body's sets (a cape's aside) as its bone draws it, against the capsules.
func _measure() -> void:
	var hm = p.body_model
	var caps: Array = []
	var cols: Dictionary = {}
	for s in hm._sims:
		cols = s.colliders
	for key in CAPS:
		if not cols.has(key):
			continue
		var cd: Dictionary = cols[key]
		var tt: Transform3D = (cd["node"] as Node3D).get_global_transform_interpolated()
		caps.append([tt * (cd["a"] as Vector3), tt * (cd["b"] as Vector3), float(cd["r"]) * tt.basis.get_scale().x - 0.01])
	var n := 0
	for s in hm._sims:
		if s.name == "Cape":
			continue
		var sk: Skeleton3D = s.skel
		var gt := sk.global_transform
		for ci in range(s.chain_count()):
			var c: Dictionary = s.chain(ci)
			var pts: PackedVector3Array = c["p"]
			var bones: PackedInt32Array = c["bones"]
			for j in range(bones.size()):
				var bp := sk.get_bone_global_pose(bones[j])
				var seg := pts[j + 1] - pts[j]
				var a := gt * bp.origin
				var b := gt * (bp.origin + bp.basis * seg)
				rec["swing"] = maxf(rec["swing"], (bp.basis * seg).angle_to(seg))
				# (a root on the body it hangs from is where it's sewn on, not a clip)
				var a2 := a.lerp(b, 0.25)
				for cap in caps:
					var st := SpringChains._closest_segments(a2, b, cap[0], cap[1])
					var depth: float = float(cap[2]) - (st[0] as Vector3).distance_to(st[1])
					if depth > 0.0:
						n += 1
						rec["pen_worst"] = maxf(rec["pen_worst"], depth)
	rec["frames"] += 1
	if n > 0:
		rec["pen_frames"] += 1
		rec["pen_n"] += n


func _grab() -> void:
	if pending == "" or run < 0 or run >= runs.size():
		return
	var img := root.get_texture().get_image()
	var sz := img.get_size()
	var w := mini(CROP.x * sz.y / 360, sz.x)
	var h := mini(CROP.y * sz.y / 360, sz.y)
	var cut := img.get_region(Rect2i((sz.x - w) / 2, (sz.y - h) / 2, w, h))
	cut.resize(CROP.x, CROP.y, Image.INTERPOLATE_NEAREST)
	shots["%d/%s" % [run, pending]] = cut
	pending = ""


func _sheets() -> void:
	for lk in looks:
		var sheet := Image.create(CROP.x * MOMENTS.size(), CROP.y * 2, false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0.1, 0.1, 0.12))
		for ri in range(runs.size()):
			var r: Array = runs[ri]
			if r[0] != lk:
				continue
			for mi in range(MOMENTS.size()):
				var key := "%d/%s" % [ri, MOMENTS[mi][0]]
				if shots.has(key):
					var im: Image = shots[key]
					sheet.blit_rect(im.duplicate() if im.get_format() == Image.FORMAT_RGBA8 else _rgba(im), Rect2i(Vector2i.ZERO, CROP), Vector2i(mi * CROP.x, (1 if r[1] else 0) * CROP.y))
		sheet.save_png(out_dir + "/sheet_%s.png" % lk)


func _rgba(im: Image) -> Image:
	var c := im.duplicate()
	c.convert(Image.FORMAT_RGBA8)
	return c
