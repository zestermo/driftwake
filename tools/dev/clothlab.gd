extends SceneTree
## The cloth lab: the cape's net on everything else (1.24). The captain in a look (long flowing hair; twin tails and a
## skirt; a long coat with long hair and a sash; a bandana, a braid and an apron) runs the cape lab's fixed script
## (walk, run, a sharp 180 turn, a dead stop, a jump, the cutlass combo's spin) twice, the net off
## (BodyBuilder.cloth_net false: the plain chains) and on, filmed at the PSX pixel grid at the key moments. Run it at a
## fixed frame rate so the two runs line up frame for frame:
##   & $env:GODOT --path . --fixed-fps 144 --script res://tools/dev/clothlab.gd
## Args: [out_dir=res://tools/dev/out/clothlab] [looks=hair,twin,coat,ties] (also duster, skirt, drape, drape_jacket:
## coats worn over the shoulders, 1.29). Env CL_NEAR: a close
## look; CL_GD: the GDScript solver instead of the native one.
## Writes sheet_<look>.png (net off on top, on below; a column a moment) and metrics.txt (also printed): for every
## frame drawn, the chains' segments (as the bones draw them) inside the legs', hips' and torso's capsules, and the
## most any segment swung off its rest direction.
const TK := preload("res://tools/dev/test_kit.gd")
const CROP := Vector2i(200, 250)
const EVENTS := [[2.0, "walk"], [3.2, "run"], [4.4, "turn"], [5.3, "stop"], [7.3, "jump"], [8.6, "draw"],
	[9.3, "attack"], [9.75, "attack"], [10.35, "attack"], [12.0, "end"]]
## (env CL_FRONT: the moments from the front three-quarters and the side instead, where a draped coat meets the arms)
const MOMENTS_FRONT := [["walk", 2.9, "f3"], ["walk2", 3.05, "side"], ["run", 4.0, "f3"], ["run2", 4.25, "side"], ["swing1", 9.45, "f3"],
	["swing2", 9.9, "f3"], ["swing3", 10.5, "side"], ["spin", 10.8, "f3"]]
var moments: Array = MOMENTS_BACK if OS.get_environment("CL_BACK") != "" else (MOMENTS_FRONT if OS.get_environment("CL_FRONT") != "" else MOMENTS)
## (1.30.3, env CL_BACK) backpedalling in the combat stance, Zach's "walking backwards is janky": the cutlass drawn,
## backwards, a stop, backwards again
const EVENTS_BACK := [[2.0, "draw"], [3.0, "back"], [6.0, "backstop"], [7.5, "back"], [9.5, "backstop"], [10.5, "end"]]
const MOMENTS_BACK := [["back1", 3.6, "side"], ["back2", 4.1, "q3"], ["back3", 4.6, "f3"], ["back4", 5.2, "behind"],
	["stop", 6.25, "side"], ["back5", 8.2, "f3"], ["back6", 8.7, "side"], ["back7", 9.2, "q3"]]
var events: Array = EVENTS_BACK if OS.get_environment("CL_BACK") != "" else EVENTS
const MOMENTS := [["run", 4.2, "behind"], ["turn1", 4.55, "q3"], ["turn2", 4.8, "behind"], ["stop1", 5.4, "side"],
	["stop2", 5.8, "behind"], ["jump", 7.65, "side"], ["spin1", 10.6, "q3"], ["spin2", 10.85, "behind"]]
const CAPS := ["thigh_l", "thigh_r", "shin_l", "shin_r", "hips", "torso", "arm_l", "arm_r", "fore_l", "fore_r"]
const LOOKS := {
	"hair": {"body": "fem", "hair": "cascade", "coat": "none"},
	"twin": {"body": "fem", "hair": "twintails", "legs": "skirt", "coat": "none"},
	"coat": {"hair": "long", "coat": "longcoat", "belt": "sash"},
	"duster": {"hair": "short", "coat": "duster", "belt": "wide_belt"},
	"skirt": {"body": "fem", "hair": "short", "legs": "skirt", "coat": "none"},
	"jacket": {"hair": "short", "hat": "none", "coat": "jacket", "coat_color": Color(0.36, 0.12, 0.1)},
	"captain": {"hair": "short", "coat": "captain", "coat_color": Color(0.66, 0.14, 0.12)},
	"great": {"hair": "short", "coat": "greatcoat", "coat_color": Color(0.1, 0.09, 0.09)},
	"ties": {"hair": "braid", "hat": "bandana", "apron": true, "coat": "none"},
	"drape": {"hair": "short", "hat": "none", "coat": "longcoat", "coat_color": Color(0.9, 0.88, 0.8), "coat_drape": true, "belt": "sash"},
	"drape_great": {"hair": "short", "hat": "none", "coat": "greatcoat", "coat_color": Color(0.1, 0.09, 0.09), "coat_drape": true, "top": "bare"},
	"drape_captain": {"hair": "long", "coat": "captain", "coat_color": Color(0.66, 0.14, 0.12), "coat_drape": true},
	"drape_haori": {"hair": "topknot", "hat": "none", "top": "kimono", "coat": "haori", "coat_color": Color(0.1, 0.09, 0.09), "coat_drape": true},
	"pack": {"hair": "ponytail", "hat": "none", "coat": "none", "backpack": true, "backpack_color": Color(0.62, 0.52, 0.38)},
	"pack_drape": {"hair": "short", "coat": "longcoat", "coat_color": Color(0.14, 0.18, 0.34), "coat_drape": true, "backpack": true},
	"drape_jacket": {"body": "fem", "hair": "ponytail", "coat": "jacket", "coat_color": Color(0.2, 0.32, 0.62), "coat_drape": true},
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
## Env CL_NEAR: a close look (half the field of view, no pixel grid, shots twice the size) for judging the cloth's shape.
var near := OS.get_environment("CL_NEAR") != ""
var out_crop := CROP * 2 if near else CROP


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
	if OS.get_environment("CL_SPLIT") != "":
		BodyBuilder.sew_split = int(OS.get_environment("CL_SPLIT"))
	if OS.get_environment("CL_OLDPROBE") != "":
		BodyBuilder.seam_probes = false
	if OS.get_environment("CL_NOSEWNET") != "":
		SpringChains.sew_net = false
	if OS.get_environment("CL_SEWN") != "":
		BodyBuilder.cloth_sewn = true
		print("CLOTH SEWN on")
	if OS.get_environment("CL_LATTICE") != "":
		BodyBuilder.cloth_lattice = true
		print("CLOTH LATTICE on")
	if OS.get_environment("CL_HAIRFEEL") != "":
		BodyBuilder.hair_feel = int(OS.get_environment("CL_HAIRFEEL"))
	if OS.get_environment("CL_FEEL") != "":
		BodyBuilder.cloth_feel = int(OS.get_environment("CL_FEEL"))
		print("CLOTH FEEL %s" % BodyBuilder.CLOTH_FEELS[BodyBuilder.cloth_feel][0])
	stage = TK.stage(self, {"hud": false, "weapon": "cutlass"})
	RenderingServer.frame_post_draw.connect(_grab)


func _process(_d: float) -> bool:
	if not stage.up:
		# (a windowed run with no save opens the first-launch creator, which holds the captain)
		for n in root.find_children("*", "CharacterCreator", true, false):
			n._finish(true)
		return false
	if run < 0:
		var st = root.get_node("Settings")
		st.set_value("video", "pixelate", not near, false)
		st.set_value("video", "dither", true, false)
		p = stage.player
		p.health_component.max_health = 99999.0
		p.health_component.current_health = 99999.0
		var rig := Node3D.new()
		var arm := Node3D.new()
		cam = Camera3D.new()
		cam.fov = 34.0 if near else 50.0
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
	while ev < events.size() and t >= float(events[ev][0]) and run == cur:
		ev += 1
		_event(str(events[ev - 1][1]))
	if run >= runs.size():
		return true
	if run != cur:
		return false
	_measure()
	var view := "behind"
	pending = ""
	if mo < moments.size() and t >= float(moments[mo][1]):
		pending = moments[mo][0]
		view = moments[mo][2]
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
	if OS.get_environment("CL_GD") != "":
		for s in hm._sims:
			s.native = false
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
	rec = {"by": {}, "frames": 0, "pen_frames": 0, "pen_n": 0, "pen_worst": 0.0, "swing": 0.0, "jit": {}, "hist": {}}
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
		"back":
			TK.press("move_back")
		"backstop":
			TK.release("move_back")
		"end":
			TK.release("move_forward")
			TK.release("move_back")
			TK.release("sprint")
			var r: Array = runs[run]
			report.append("%-5s net %-5s frames %4d  segments inside the body: %4d in %3d frames (worst %.1f cm)  most swing %.0f deg" % [
				r[0], "on" if r[1] else "off", rec["frames"], rec["pen_n"], rec["pen_frames"], rec["pen_worst"] * 100.0, rad_to_deg(rec["swing"])])
			report.append("      by set > capsule: " + str(rec["by"]))
			var jl := []
			for k in rec["jit"]:
				var jv: Array = rec["jit"][k]
				jl.append("%s mean %.2f mm, worst %.1f mm" % [k, jv[0] / maxf(1.0, jv[1]) * 1000.0, jv[2] * 1000.0])
			report.append("      jitter (chain tips, body space, per frame): " + ", ".join(jl))
			report.append("      cloth pops (a hem point jumping > 5 cm in a frame, hair aside): %d" % int(rec.get("pops", 0)))
			report.append("      sewn seams in the legs at the hem (seam-frames): %d" % int(rec.get("seam", 0)))
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
		"f3":
			cam.look_at_from_position(at - back.rotated(Vector3.UP, 0.7) * 4.0 + Vector3(0, 1.5, 0), aim, Vector3.UP)
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
		# (less the capsules' clearance over the limb, as capelab measures: inside that is inside the body)
		caps.append([tt * (cd["a"] as Vector3), tt * (cd["b"] as Vector3), float(cd["r"]) * tt.basis.get_scale().x - 0.03, key])
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
				# (1.30.3) jitter: the tip's second difference in the skeleton's space (the body's own motion left out)
				if j == bones.size() - 1:
					var tip := bp.origin + bp.basis * seg
					var hk := "%d/%d" % [s.get_instance_id(), ci]
					var hs: Array = rec["hist"].get(hk, [])
					if hs.size() == 2:
						var acc: float = (tip - 2.0 * (hs[1] as Vector3) + (hs[0] as Vector3)).length()
						var sk_name: String = s.get_parent().name
						var jv: Array = rec["jit"].get(sk_name, [0.0, 0, 0.0])
						rec["jit"][sk_name] = [jv[0] + acc, jv[1] + 1, maxf(jv[2], acc)]
						if acc > 0.05 and sk_name != "Head":
							rec["pops"] = int(rec.get("pops", 0)) + 1
						hs = [hs[1], tip]
					else:
						hs.append(tip)
					rec["hist"][hk] = hs
				# (a root segment hangs from where it's sewn on, over a thigh's top or the nape: not a clip)
				if j == 0:
					continue
				for cap in caps:
					var st := SpringChains._closest_segments(a, b, cap[0], cap[1])
					var depth: float = float(cap[2]) - (st[0] as Vector3).distance_to(st[1])
					if depth > 0.0:
						n += 1
						var bk := "%s>%s" % [s.get_parent().name, cap[3]]
						rec["by"][bk] = int(rec["by"].get(bk, 0)) + 1
						rec["pen_worst"] = maxf(rec["pen_worst"], depth)
	# (1.30.3) sewn seams at the hem, skinned as the mesh blends them (half each neighbour's last bone), in the legs
	for s in hm._sims:
		var sk2: Skeleton3D = s.skel
		var gt2 := sk2.get_global_transform_interpolated()
		for ci in range(s.chain_count()):
			var c2: Dictionary = s.chain(ci)
			if not c2.has("sew"):
				continue
			var other: Dictionary = s.chain(int(c2["sew"][0]))
			var spts: PackedVector3Array = c2["sew"][1]
			var ri := spts.size() - 1
			var nb_a := (c2["bones"] as PackedInt32Array).size()
			# (the hem's seam only: a vent's seam stops halfway)
			if ri < nb_a:
				continue
			var rest_pt: Vector3 = spts[ri]
			var ba: int = (c2["bones"] as PackedInt32Array)[nb_a - 1]
			var bb: int = (other["bones"] as PackedInt32Array)[(other["bones"] as PackedInt32Array).size() - 1]
			var pa := sk2.get_bone_global_pose(ba) * sk2.get_bone_global_rest(ba).affine_inverse() * rest_pt
			var pb := sk2.get_bone_global_pose(bb) * sk2.get_bone_global_rest(bb).affine_inverse() * rest_pt
			var wp := gt2 * ((pa + pb) * 0.5)
			for cap in caps:
				if not str(cap[3]).begins_with("thigh") and not str(cap[3]).begins_with("shin"):
					continue
				var ab: Vector3 = cap[1] - cap[0]
				var t := clampf((wp - cap[0]).dot(ab) / ab.length_squared(), 0.0, 1.0)
				if float(cap[2]) - wp.distance_to(cap[0] + ab * t) > 0.0:
					rec["seam"] = int(rec.get("seam", 0)) + 1
	# (1.30.3) the connected sheets: their points (below the pinned top row) inside the capsules, and their hem's jitter
	for sh in hm._cloth:
		# (what's drawn: the bones, in the sheet's space, and those in the world)
		var sg: Transform3D = (sh.skel as Node3D).get_global_transform_interpolated()
		for i in range(sh.nc, sh.x.size()):
			var tip: Vector3 = sh.skel.get_bone_pose(i).origin
			var wp: Vector3 = sg * tip
			# (the row just under the sewn-on top is where the cloth is cut on the body, as a chain's root segment)
			for cap in (caps if i >= 2 * sh.nc else []):
				var ab: Vector3 = cap[1] - cap[0]
				var t := clampf((wp - cap[0]).dot(ab) / ab.length_squared(), 0.0, 1.0)
				var depth: float = float(cap[2]) - wp.distance_to(cap[0] + ab * t)
				if depth > 0.0:
					n += 1
					var bk := "Sheet>%s" % cap[3]
					rec["by"][bk] = int(rec["by"].get(bk, 0)) + 1
					rec["pen_worst"] = maxf(rec["pen_worst"], depth)
			if i >= sh.x.size() - sh.nc:
				var hk := "sheet%d/%d" % [sh.get_instance_id(), i]
				var hs: Array = rec["hist"].get(hk, [])
				if hs.size() == 2:
					var acc: float = (tip - 2.0 * (hs[1] as Vector3) + (hs[0] as Vector3)).length()
					var jv: Array = rec["jit"].get("Sheet", [0.0, 0, 0.0])
					rec["jit"]["Sheet"] = [jv[0] + acc, jv[1] + 1, maxf(jv[2], acc)]
					if acc > 0.05:
						rec["pops"] = int(rec.get("pops", 0)) + 1
					hs = [hs[1], tip]
				else:
					hs.append(tip)
				rec["hist"][hk] = hs
	rec["frames"] += 1
	if n > 0:
		rec["pen_frames"] += 1
		rec["pen_n"] += n


func _grab() -> void:
	if pending == "" or run < 0 or run >= runs.size():
		return
	var img := root.get_texture().get_image()
	var sz := img.get_size()
	var w := mini(int(CROP.x * sz.y / 360 * (1.4 if near else 1.0)), sz.x)
	var h := mini(int(CROP.y * sz.y / 360 * (1.4 if near else 1.0)), sz.y)
	var cut := img.get_region(Rect2i((sz.x - w) / 2, (sz.y - h) / 2, w, h))
	cut.resize(out_crop.x, out_crop.y, Image.INTERPOLATE_NEAREST)
	shots["%d/%s" % [run, pending]] = cut
	pending = ""


func _sheets() -> void:
	for lk in looks:
		var sheet := Image.create(out_crop.x * moments.size(), out_crop.y * 2, false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0.1, 0.1, 0.12))
		for ri in range(runs.size()):
			var r: Array = runs[ri]
			if r[0] != lk:
				continue
			for mi in range(moments.size()):
				var key := "%d/%s" % [ri, moments[mi][0]]
				if shots.has(key):
					var im: Image = shots[key]
					sheet.blit_rect(im.duplicate() if im.get_format() == Image.FORMAT_RGBA8 else _rgba(im), Rect2i(Vector2i.ZERO, out_crop), Vector2i(mi * out_crop.x, (1 if r[1] else 0) * out_crop.y))
		sheet.save_png(out_dir + "/sheet_%s.png" % lk)


func _rgba(im: Image) -> Image:
	var c := im.duplicate()
	c.convert(Image.FORMAT_RGBA8)
	return c
