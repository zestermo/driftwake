extends SceneTree
## 1.23 beast pass, roamers: fewer (about half the islands past a chain's first have none; the first islands always do),
## heard before they're seen (a roar and birds once a captain's within 95 m), and each with a temper: the Thornback
## warns a captain off (posture and roar, 2 s: back off and it settles; stay and it charges), the Dune Strider bolts,
## the Wild Hunt stalks a captain at their back by night and charges when it has had it a while.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var b
var step := 0
var until := 0
var fails := 0
var at0 := Vector3.ZERO
var bx := -36.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func spawn(theme: String, kind: String, dist: float):
	if b and is_instance_valid(b):
		b.queue_free()
	var th = load("res://scripts/island/themes/island_themes.gd").of(theme)
	# (each on its own spot: one put down inside the last one's body is pushed out through the floor)
	bx += 18.0
	var at: Vector3 = Vector3(bx, p.global_position.y, -dist - 30.0)
	var x = load(th.beasts[kind]["script"]).new()
	x.setup({"post": at, "yaw": 0.0, "level": 6, "name": kind})
	stage.add_child(x)
	x.global_position = at
	return x


func put(z: float) -> void:
	p.global_position = Vector3(bx, p.global_position.y, z - 30.0)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			p.get_node("HealthComponent").max_health = 99999.0
			p.get_node("HealthComponent").current_health = 99999.0
			var ChainK = load("res://scripts/world/chain.gd")
			var none := 0
			var rest := 0
			var firsts_ok := true
			for s in range(1, 21):
				var c = ChainK.make(s * 7919, Vector2.ZERO, Vector2(1, 0))
				for n in c.nodes:
					if c.start_next.has(n["id"]):
						firsts_ok = firsts_ok and str(n["roamer"]) != ""
					else:
						rest += 1
						none += 1 if str(n["roamer"]) == "" else 0
			check("fewer roamers: %d of %d islands past the first have none" % [none, rest], rest > 20 and none > rest * 0.3 and none < rest * 0.7)
			check("...a chain's first islands always have one", firsts_ok)
			put(80.0)
			b = spawn("jungle", "behemoth", 0.0)
			until = TK.wait_secs(2.0)
		1:
			check("it's heard before it's seen: a roar and birds once a captain's within 95 m", b._heard)
			put(14.0)
			until = TK.wait_secs(0.6)
		2:
			check("the Thornback warns a captain off (mood %d, %s)" % [b.mood, b.state_name()], b.mood == 1 and b.asleep())
			put(34.0)
			until = TK.wait_secs(2.2)
		3:
			check("...backed off: it settles (mood %d, %s)" % [b.mood, b.state_name()], b.mood == 0 and b.asleep())
			put(14.0)
			until = TK.wait_secs(2.6)
		4:
			check("...stayed: it comes for them (%s)" % b.state_name(), b.in_combat())
			b = spawn("desert", "dune_strider", 0.0)
			put(60.0)
			until = TK.wait_secs(1.0)
		5:
			at0 = b.global_position
			put(16.0)
			until = TK.wait_secs(2.4)
		6:
			var ran: float = b.global_position.distance_to(at0)
			check("the Dune Strider bolts (mood %d, %.1f m off from where it stood)" % [b.mood, ran], ran > 6.0 and b.asleep() and b.global_position.y > p.global_position.y - 2.0)
			root.get_node("Weather").night = 1.0
			b = spawn("forest", "wild_hunt", 0.0)
			put(30.0)
			# (the captain faces away from it: +z)
			p.get("player_model").rotation.y = 0.0
			until = TK.wait_secs(1.2)
		7:
			check("the Wild Hunt stalks a captain by night (mood %d)" % b.mood, b.mood == 3 or b.in_combat())
			p.get("player_model").rotation.y = 0.0
			until = TK.wait_secs(4.0)
		8:
			check("...and charges once it's had their back a while (%s, mood %d, %.1f s, gone %s, %.1f m)" % [b.state_name(), b.mood, b._mood_t, b._gone, b.global_position.distance_to(p.global_position)], b.in_combat())
			return TK.done(fails)
	step += 1
	return false
