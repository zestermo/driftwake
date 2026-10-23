extends SceneTree
## Flipbook particles (FX.flipbook): a burst plays a 4x4 sprite sheet once over each particle's life
## (the sheets change frame to frame) and frees itself; FX.flipbooks picks the sprite sheets or the
## old particles; a real cannon shot puts a flare and smoke at the muzzle and a column of white water
## where the ball meets the sea; a katana's heavy slam kicks up flipbook dust.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var fx
var burst
var cannon
var muzzle := Vector3.ZERO
var flips: Dictionary = {}
var tracking := false
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true, "weapon": "katana"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _bursts() -> Array:
	return stage.find_children("*", "CPUParticles3D", true, false)


## The sheet a burst plays ("" for a plain burst).
func _sheet_of(b: CPUParticles3D) -> String:
	var m = b.mesh.material if b.mesh else null
	if m is StandardMaterial3D and m.particles_anim_h_frames == 4 and m.albedo_texture:
		return m.albedo_texture.resource_path.get_file().trim_prefix("flip_").trim_suffix(".png")
	return ""


func _new_flips(old: Dictionary) -> Array:
	var out: Array = []
	for b in _bursts():
		if not old.has(b.get_instance_id()) and _sheet_of(b) != "":
			out.append(_sheet_of(b))
	return out


## Track only bursts made from now on (those already out are marked with no sheet).
func _reset_flips() -> void:
	flips.clear()
	for b in _bursts():
		flips[b.get_instance_id()] = ["", b.global_position]


func _ids() -> Dictionary:
	var d := {}
	for b in _bursts():
		d[b.get_instance_id()] = true
	return d


## Opaque pixels in frame i of a 4x4 sheet of 64 px frames.
func _cover(img: Image, i: int) -> int:
	var n := 0
	for y in range(64):
		for x in range(64):
			if img.get_pixel((i % 4) * 64 + x, (i / 4) * 64 + y).a > 0.1:
				n += 1
	return n


func _process(_d: float) -> bool:
	if tracking:
		for b in _bursts():
			if _sheet_of(b) != "" and not flips.has(b.get_instance_id()):
				flips[b.get_instance_id()] = [_sheet_of(b), b.global_position]
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			fx = root.get_node("FX")
			fx.flipbooks = true
			for s in ["smoke", "explosion"]:
				var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/textures/fx/flip_%s.png" % s))
				check("the %s sheet is 4x4 frames of 64 px" % s, img.get_size() == Vector2i(256, 256))
				var c := []
				for i in [0, 4, 8, 15]:
					c.append(_cover(img, i))
				print("  %s coverage at frames 0/4/8/15: %s" % [s, str(c)])
				check("the %s sheet changes as it plays (frames 0, 4, 8, 15 all differ)" % s, c[0] != c[1] and c[1] != c[2] and c[2] != c[3])
			burst = fx.flipbook(p.global_position + Vector3(0, 1.0, -3.0), "smoke", 4, 1.0, 0.6, {"start": 0.1, "spin": 20.0})
			check("flipbook makes a burst", burst != null and burst.emitting and burst.amount == 4)
			var m: StandardMaterial3D = burst.mesh.material
			check("it plays the 16 frames once (4x4, no loop, one sheet per life)", m.particles_anim_h_frames == 4
				and m.particles_anim_v_frames == 4 and not m.particles_anim_loop and burst.anim_speed_min == 1.0 and burst.anim_speed_max == 1.0)
			check("it starts each particle up to 10% in, rolled up to 20 degrees", is_equal_approx(burst.anim_offset_max, 0.1)
				and is_equal_approx(burst.angle_max, 20.0) and is_equal_approx(burst.angle_min, -20.0))
			check("its sheet stays hard-edged (nearest, with mipmaps) and billboards", m.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
				and m.billboard_mode == BaseMaterial3D.BILLBOARD_PARTICLES)
			check("its colour fades out over its life", burst.color_ramp != null and burst.color_ramp.sample(1.0).a < 0.01 and burst.color_ramp.sample(0.3).a > 0.9)
			until = TK.wait_secs(0.3)
		1:
			check("half way through its life it's still playing", is_instance_valid(burst) and burst.emitting)
			until = TK.wait_secs(1.0)
		2:
			check("once its life is over it frees itself", not is_instance_valid(burst))
			var at: Vector3 = p.global_position + Vector3(0, 1.5, -4.0)
			fx.flipbooks = false
			var old := _ids()
			fx.cannon_fire(at, Vector3.FORWARD)
			fx.heavy_dust(at, 16, 1.0)
			check("flipbooks off: the cannon and the heavy dust are the old particles", _new_flips(old).is_empty())
			fx.flipbooks = true
			old = _ids()
			fx.cannon_fire(at, Vector3.FORWARD)
			var made := _new_flips(old)
			check("flipbooks on: the cannon fires a muzzle flare and a smoke sheet (%s)" % str(made), made.has("dither_muzzle") and made.has("smoke"))
			old = _ids()
			root.get_node("Net").fx("heavy_dust", [at, 16, 1.0])
			check("flipbooks on: heavy dust through Net.fx is a dust sheet", _new_flips(old).has("dust"))
			for c in stage.ship.cannons:
				if c.shot_velocity().x > 0.0:
					cannon = c
					break
			cannon.cool = 0.0
			muzzle = cannon.muzzle()
			_reset_flips()
			tracking = true
			check("the ship's cannon fires", cannon.fire(p))
			until = TK.wait_secs(4.0)
		3:
			var at_muzzle := []
			var far := []
			for v in flips.values():
				var flat: Vector3 = (v[1] as Vector3) - muzzle
				flat.y = 0.0
				if flat.length() < 3.0:
					at_muzzle.append(v[0])
				elif flat.length() > 12.0 and (v[1] as Vector3).y < 2.0:
					far.append(v[0])
			print("  flipbooks at the muzzle %s, out at sea %s" % [str(at_muzzle), str(far)])
			check("a real shot: a flare and smoke at the muzzle", at_muzzle.has("dither_muzzle") and at_muzzle.has("smoke"))
			check("a real shot: a column of white water where the ball meets the sea", far.has("splash"))
			_reset_flips()
			p.state_machine.force_state("HeavyAttack", {})
			until = TK.wait_secs(1.2)
		4:
			var dust := 0
			for v in flips.values():
				if v[0] == "dust" and (v[1] as Vector3).distance_to(p.global_position) < 4.0:
					dust += 1
			check("a katana's heavy slam kicks up flipbook dust (%d)" % dust, dust > 0)
			tracking = false
			return TK.done(fails)
	step += 1
	return false
