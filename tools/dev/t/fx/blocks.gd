extends SceneTree
## The flipbook blocks (FX.puff, puff_ring, plume, flash, blast, lick, flip_emitter): each one-shot block is
## one burst that frees itself once its life is over and blast is its three; an emitter keeps going until
## freed; lit matter is dimmed at night (emitters follow the night as it goes) and light isn't; the switch
## off reproduces the old geometry effects' bursts (cannon_fire, heavy_dust), on it costs no more particles.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var fx
var wx
var step := 0
var until := 0
var fails := 0
var made: Array = []
var emitter
var holder: Node3D
var at := Vector3.ZERO


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


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


func _ids() -> Dictionary:
	var d := {}
	for b in _bursts():
		d[b.get_instance_id()] = true
	return d


func _new(old: Dictionary) -> Array:
	var out: Array = []
	for b in _bursts():
		if not old.has(b.get_instance_id()):
			out.append(b)
	return out


func _sheets(bursts: Array) -> Array:
	var out: Array = []
	for b in bursts:
		out.append(_sheet_of(b))
	out.sort()
	return out


func _particles(bursts: Array) -> int:
	var n := 0
	for b in bursts:
		n += b.amount
	return n


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			fx = root.get_node("FX")
			wx = root.get_node("Weather")
			fx.flipbooks = true
			wx.night = 0.0
			at = stage.player.global_position + Vector3(0, 1.0, -3.0)
			var old := _ids()
			var p1 = fx.puff(at, "dust", 2, 0.6, 0.5)
			check("puff: one burst of the dust sheet, 2 particles, one shot", _new(old).size() == 1 and _sheet_of(p1) == "dust"
				and p1.amount == 2 and p1.one_shot)
			old = _ids()
			var p2 = fx.puff_ring(at, "dust_low", 6, 0.3, 1.0, 0.5)
			check("puff_ring: one burst on a ring, racing out", _new(old).size() == 1 and _sheet_of(p2) == "dust_low"
				and p2.emission_shape == CPUParticles3D.EMISSION_SHAPE_RING and p2.radial_accel_max > 0.0)
			old = _ids()
			var p3 = fx.plume(at, Vector3.FORWARD, "smoke", 3, 1.0, 0.5)
			check("plume: one burst pushed along the direction, growing", _new(old).size() == 1 and _sheet_of(p3) == "smoke"
				and p3.direction.is_equal_approx(Vector3.FORWARD) and p3.scale_amount_curve == fx._curve("grow"))
			old = _ids()
			var p4 = fx.flash(at, 0.9, Color(0.3, 0.7, 1.0))
			check("flash: one glint, still, tinted, additive", _new(old).size() == 1 and _sheet_of(p4) == "glint"
				and p4.initial_velocity_max == 0.0 and p4.color_ramp.sample(0.0).is_equal_approx(Color(0.3, 0.7, 1.0))
				and p4.mesh.material.blend_mode == BaseMaterial3D.BLEND_MODE_ADD)
			old = _ids()
			fx.blast(at, Vector3.UP, 1.0, true)
			var hot := _sheets(_new(old))
			check("blast: three bursts, the flare, a fireball and smoke (%s)" % str(hot), hot == ["fireball", "muzzle", "smoke"])
			old = _ids()
			fx.blast(at, Vector3.UP, 1.0, false)
			check("a cold blast has no fireball", _sheets(_new(old)) == ["muzzle", "smoke"])
			made = [p1, p2, p3, p4]
			holder = Node3D.new()
			stage.add_child(holder)
			holder.global_position = at
			old = _ids()
			emitter = fx.lick(holder, 0.3, 6, 0.5, 0.6)
			check("lick: one emitter of fire licks that keeps going", _new(old).size() == 1 and _sheet_of(emitter) == "fire"
				and not emitter.one_shot and emitter.emitting and emitter.visibility_range_end > 0.0)
			until = TK.wait_secs(1.5)
		1:
			var gone := true
			for b in made:
				gone = gone and not is_instance_valid(b)
			check("every one-shot block freed itself once its life was over", gone)
			check("the lick is still burning", is_instance_valid(emitter) and emitter.emitting)
			wx.night = 0.0
			var day = fx.puff(at, "smoke", 1, 0.5, 0.4)
			var light_day = fx.flash(at, 0.5, Color.WHITE)
			wx.night = 1.0
			var night = fx.puff(at, "smoke", 1, 0.5, 0.4)
			var light_night = fx.flash(at, 0.5, Color.WHITE)
			var cd: Color = day.color_ramp.sample(0.0)
			var cn: Color = night.color_ramp.sample(0.0)
			check("lit matter dims at night (%.2f -> %.2f)" % [cd.r, cn.r], is_equal_approx(cd.r, 1.0) and cn.r < cd.r * 0.5)
			check("light doesn't", light_night.color_ramp.sample(0.0).is_equal_approx(light_day.color_ramp.sample(0.0)))
			var wisp = fx.flip_emitter(holder, "wisp", 4, 0.5, 1.0, {})
			check("a lit emitter made at night starts dim", wisp.color.r < 0.5)
			wx.night = 0.0
			fx._dim_emitters()
			check("and brightens as the night goes (the 2 s timer)", is_equal_approx(wisp.color.r, 1.0))
			wisp.queue_free()
			fx.flipbooks = false
			var old := _ids()
			fx.cannon_fire(at, Vector3.FORWARD)
			var off_fire := _new(old)
			old = _ids()
			fx.heavy_dust(at, 12, 0.8)
			var off_dust := _new(old)
			var plain := true
			for b in off_fire + off_dust:
				plain = plain and _sheet_of(b) == ""
			check("switch off: cannon_fire is the old 3 bursts, heavy_dust the old 1, no sheets (%d, %d)" % [off_fire.size(), off_dust.size()],
				off_fire.size() == 3 and off_dust.size() == 1 and plain)
			fx.flipbooks = true
			old = _ids()
			fx.cannon_fire(at, Vector3.FORWARD)
			var on_fire := _new(old)
			old = _ids()
			fx.heavy_dust(at, 12, 0.8)
			var on_dust := _new(old)
			check("switch on: the cannon is no more bursts (%d -> %d), heavy dust at most one more (%d -> %d)" % [off_fire.size(),
				on_fire.size(), off_dust.size(), on_dust.size()], on_fire.size() <= off_fire.size() and on_dust.size() <= off_dust.size() + 1)
			check("and no more particles (cannon %d -> %d, heavy dust %d -> %d)" % [_particles(off_fire), _particles(on_fire),
				_particles(off_dust), _particles(on_dust)], _particles(on_fire) <= _particles(off_fire) and _particles(on_dust) <= _particles(off_dust))
			emitter.queue_free()
			_rollout()
			return TK.done(fails)
	step += 1
	return false


## Every effect moved onto the sheets: with the switch on it makes no more bursts (heavy_dust one more: its
## two layers) and no more particles than the geometry it replaced, and some of it plays a sheet.
func _rollout() -> void:
	var d := Vector3(1, 0.3, 0).normalized()
	var effects := {
		"dust": func(): fx.dust(at, 6, 0.6),
		"dust_ring": func(): fx.dust_ring(at, 12, 0.7),
		"smoke": func(): fx.smoke(at, 6, 0.8),
		"blood": func(): fx.blood(at, d, 12),
		"splash": func(): fx.splash(at, 6, 0.8),
		"spray": func(): fx.spray(at, d, 12),
		"impact": func(): fx.impact(at),
		"parry_sparks": func(): fx.parry_sparks(at, d),
		"glint": func(): fx.glint(at),
		"gather": func(): fx.gather(at),
		"motes": func(): fx.motes(at, d),
		"elem_hit dual": func(): fx.elem_hit("dual", at, d),
		"element axe": func(): fx.element("axe", at, d),
		"flame": func(): fx.flame(at),
		"fire_ring": func(): fx.fire_ring(at),
		"fire_pillar": func(): fx.fire_pillar(at),
		"powder_burst": func(): fx.powder_burst(at, d),
		"cannon_blast": func(): fx.cannon_blast(at, 1.5, Color(1, 0.3, 0.2)),
		"cannon_hit": func(): fx.cannon_hit(at, Vector3.UP),
		"cannon_splash": func(): fx.cannon_splash(at),
		"heavy_dust": func(): fx.heavy_dust(at, 12, 0.8),
		"flame_emitter": func(): fx.flame_emitter(holder, 0.3, 16, 0.5, 0.6),
		"chimney_smoke": func(): fx.chimney_smoke(holder, Vector3.ZERO),
	}
	for name in effects:
		var cost := []
		for on in [false, true]:
			fx.flipbooks = on
			var old := _ids()
			effects[name].call()
			var made := _new(old)
			var sheets := 0
			for b in made:
				if _sheet_of(b) != "":
					sheets += 1
			cost.append([made.size(), _particles(made), sheets])
			for b in made:
				b.queue_free()
		var extra := 1 if name == "heavy_dust" else 0
		check("%s: bursts %d -> %d, particles %d -> %d, %d plays a sheet" % [name, cost[0][0], cost[1][0], cost[0][1], cost[1][1], cost[1][2]],
			cost[1][0] <= cost[0][0] + extra and cost[1][1] <= cost[0][1] and cost[1][2] > 0 and cost[0][2] == 0)
	fx.flipbooks = true
	holder.queue_free()
