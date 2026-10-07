extends SceneTree
## How long each stage of building one character takes (BodyBuilder._run,
## stage by stage), for a few looks. Headless.
func _initialize():
	var CL = load("res://scripts/npc/character_look.gd")
	var looks := [CL.default_look()]
	var rng := RandomNumberGenerator.new()
	for i in range(3):
		rng.seed = 100 + i
		looks.append(CL.random_look(rng) if CL.has_method("random_look") else CL.default_look())
	for lk in looks:
		var h := Humanoid.new()
		var b := BodyBuilder.new()
		var stages := ["_skeleton", "_colliders", "_legs", "_lower_body", "_torso", "_arms", "_head", "_clothes", "_accessories", "_commit_parts"]
		# (the preamble of _run, then each stage timed)
		h.look = lk
		b.h = h
		b.lk = lk
		var us := Time.get_ticks_usec()
		b.st = b.STYLES.get(str(lk.get("style", b.current_style())), b.STYLES[b.DEFAULT_STYLE])
		b.fem = str(lk.get("body", "masc")) == "fem"
		b.bf = b.BUILD_F.get(str(lk.get("build", "average")), b.BUILD_F["average"])
		var ex := 0.45 if b.fem else 1.0
		b.sh = b.bf["sh"] * (1.0 + (float(b.st["sh"]) - 1.0) * ex)
		b.ch = b.bf["ch"] * (1.0 + (float(b.st["ch"]) - 1.0) * ex)
		b.wa = b.bf["wa"] * float(b.st["wa"])
		b.hp = b.bf["hp"]
		b.de = b.bf["de"]
		b.limb = b.bf["limb"] * float(b.st["limb"]) * (0.86 if b.fem else 1.0)
		b.T = float(b.st["torso"])
		b.Ls = float(b.st["leg"]) * (1.03 if b.fem else 1.0)
		b.A = float(b.st["arm"]) * (0.97 if b.fem else 1.0)
		b.Hk = float(b.st["hand"]) * (0.84 if b.fem else 1.0)
		b.Fk = float(b.st["foot"]) * (0.86 if b.fem else 1.0)
		b.m_skin = PSXMat.flat(b._col("skin"))
		b.m_hair = PSXMat.lit("hair", b._col("hair_color"), {"pull": 0.01})
		var line := ""
		var total := 0.0
		for s in stages:
			var t0 := Time.get_ticks_usec()
			b.call(s)
			var dt := (Time.get_ticks_usec() - t0) / 1000.0
			total += dt
			line += "%s %.1f  " % [s.trim_prefix("_"), dt]
		var t0 := Time.get_ticks_usec()
		for s in b._sims.values():
			(s as SpringChains).finalize()
		line += "sims %.1f" % ((Time.get_ticks_usec() - t0) / 1000.0)
		print("total %.1f ms: %s" % [total, line])
		var us2 := Time.get_ticks_usec()
		var h2 := Humanoid.new()
		h2.setup(lk)
		print("   full setup() %.1f ms" % ((Time.get_ticks_usec() - us2) / 1000.0))
		# inside the head: the painted face (cached per face) vs the hair
		var hs := str(lk.get("hair", "short"))
		var lk2: Dictionary = lk.duplicate()
		lk2["eyes"] = 99  # (a face not in the cache)
		var t1 := Time.get_ticks_usec()
		FacePainter.material(lk2, 1.0, [] if hs == "bald" else BodyBuilder.hairline_for(hs))
		var t2 := Time.get_ticks_usec()
		var hmb := MeshBuilder.new()
		b._hair(hmb)
		var t3 := Time.get_ticks_usec()
		print("   face paint %.1f ms   hair %.1f ms (%s)" % [(t2 - t1) / 1000.0, (t3 - t2) / 1000.0, hs])
		h.free()
		h2.free()
	quit()
