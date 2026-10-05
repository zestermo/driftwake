extends SceneTree
var hs := []
var chains := 0
var done := false
func _initialize():
	var cam := Camera3D.new(); root.add_child(cam); cam.current = true
	var rng := RandomNumberGenerator.new()
	for i in range(12):
		rng.seed = i
		var lk := CharacterLook.random_look(rng)
		lk["hair"] = ["long", "ponytail", "braids"][i % 3]; lk["coat"] = "longcoat" if i % 2 == 0 else "none"
		lk["legs"] = "skirt" if i % 2 == 1 else "trousers"; lk["belt"] = "belt_sash"; lk["hat"] = "bandana" if i % 4 == 0 else "none"
		var h := Humanoid.new(); h.setup(lk); root.add_child(h); h.position = Vector3(i, 0, -3); h.set_process(false)
		h.ground_speed = 5.0
		hs.append(h)
		for s in h._sims: chains += s.chain_count()
func _process(_d):
	if done: return false
	done = true
	var t0 := Time.get_ticks_usec()
	for f in range(300):
		for h in hs:
			h.position.x += 0.08
			h._process(1.0 / 60.0)
	var per_frame := (Time.get_ticks_usec() - t0) / 300.0
	print("visible_in_tree=", hs[0].is_visible_in_tree(), " inside=", hs[0].is_inside_tree(), " last_origin=", hs[0]._sims[0]._last_origin, " pivot=", hs[0].pivot != null)
	print("12 characters, %d chains: %.2f ms per frame (animation + physics)" % [chains, per_frame / 1000.0])
	for h in hs: h._sims.clear()
	var t1 := Time.get_ticks_usec()
	for f in range(300):
		for h in hs:
			h._process(1.0 / 60.0)
	print("same without physics: %.2f ms per frame" % ((Time.get_ticks_usec() - t1) / 300.0 / 1000.0))
	quit()
	return false
