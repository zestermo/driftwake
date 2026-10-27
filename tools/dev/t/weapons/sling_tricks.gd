extends SceneTree
## The slingshot's trick ammo, each a technique fired at a grunt down range: the fire pellet sets it burning, the smoke
## pellet blinds it (a long stagger), the sticky pellet roots it where it stands, the blast pellet knocks it down; Trick
## Pouch puts a trick in every fifth plain stone.
const TK := preload("res://tools/dev/test_kit.gd")
const TRICKS := ["fire_pellet", "smoke_pellet", "sticky_pellet", "blast_pellet"]
var stage
var p
var g
var hits := 0
var last
var longest := 0.0
var down := false
var ti := 0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [{"post": Vector3(0, 0, -7.0), "yaw": PI, "mode": "stand", "seed": 11}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			var it = ItemDB.get_item("slingshot")
			p.inventory_component.add_item(it, 1)
			p.equip_weapon(it)
			p.draw_weapon(true)
			g = stage.camp.grunts[0]
			g.health.max_health = 5000.0
			g.health.current_health = 5000.0
			g.hurtbox.hit_received.connect(func(h, _a):
				hits += 1
				longest = maxf(longest, h.stagger_duration)
				down = down or h.knockdown
				last = h)
			p.progression.master_all()
			until = TK.wait_secs(0.7)
		1:
			if not p.is_free():
				return false
			# (the reticle laid on the grunt, as a player aims)
			var ray: Array = p.reticle_ray()
			var r: Vector3 = ray[1]
			var d: Vector3 = (g.global_position + Vector3(0, 1.1, 0) - (ray[0] as Vector3)).normalized()
			stage.camera_rig.rotation.y += atan2(-d.x, -d.z) - atan2(-r.x, -r.z)
			stage.camera_rig.get_node("SpringArm3D").rotation.x += asin(d.y) - asin(r.y)
			hits = 0
			last = null
			longest = 0.0
			down = false
			p.power.energy = 999.0
			p.state_machine.force_state("Technique", {"id": TRICKS[ti], "slot": 0})
			until = TK.wait_secs(0.9)
		2:
			match TRICKS[ti]:
				"fire_pellet":
					check("the fire pellet bursts and sets them burning (%d)" % hits, hits >= 1 and g.get_node_or_null("Burn") != null)
				"smoke_pellet":
					check("the smoke pellet blinds them: a long stagger (%.1f s, %d blows)" % [longest, hits], longest >= 1.5)
				"sticky_pellet":
					check("the sticky pellet roots them where they stand (%.1f s)" % float(g._stagger_len), hits >= 1 and float(g._stagger_len) >= 2.5)
				"blast_pellet":
					check("the blast pellet knocks them down (%d blows)" % hits, down)
			ti += 1
			if ti < TRICKS.size():
				step = 1
				until = TK.wait_secs(3.0)
				return false
			var SA = load("res://scripts/weapons/sling_arts.gd")
			p.set_meta("sling_n", 0)
			var loads: Array = []
			for i in 5:
				loads.append(SA._pouch_trick(p))
			check("Trick Pouch: the fifth stone carries a trick at half strength %s" % str(loads),
				loads.slice(0, 4).all(func(x): return x == "") and str(loads[4]).get_slice("@", 0) in SA.TRICKS and str(loads[4]).ends_with("@0.50"))
			return TK.done(fails)
	step += 1
	return false
