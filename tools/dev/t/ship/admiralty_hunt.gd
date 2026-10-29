extends SceneTree
## Bounty as heat (docs/v1_23_plan.md): a wanted crew at sea draws Admiralty patrols, more and heavier by bounty tier.
## They come in from the edge of view along the ship's wake, track it and close; fog and storm shorten how far they
## keep her in sight; lose them by distance and they turn away, the crew hears they've escaped, and the patrol is
## gone once out of every captain's sight.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ship
var adm
var step := 0
var until := 0
var fails := 0
var started := 0
var escaped := 0
var d0 := 0.0
var pat: Array = []


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var A = load("res://scripts/ship/admiralty.gd")
	match step:
		0:
			p = stage.player
			ship = stage.ship
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			p.global_position = ship.to_global(Vector3(0.5, 0.6, 3.0))
			p.reset_physics_interpolation()
			p.bounty = 70000
			adm = A.ensure(self)
			adm.hunt_started.connect(func(): started += 1)
			adm.escaped.connect(func(): escaped += 1)
			check("no patrols for a crew with no bounty or only Wanted, more and heavier as it rises",
				A.PATROL_EVERY[0] == 0.0 and A.PATROL_EVERY[1] == 0.0 and A.PATROL_KINDS[1].size() < A.PATROL_KINDS[4].size() and A.PATROL_EVERY[4] < A.PATROL_EVERY[2] and "frigate" in A.PATROL_KINDS[3])
			var w = root.get_node("Weather")
			var f0: float = w.fog
			var s0: float = w.storm
			w.fog = 1.0
			var fogged: float = A.sight_k(self, ship.global_position)
			w.fog = f0
			w.storm = 1.0
			var stormy: float = A.sight_k(self, ship.global_position)
			w.storm = s0
			check("fog and storm hide her (%.2f, %.2f of clear sight)" % [fogged, stormy], fogged < 0.6 and stormy < 0.75)
			ship.sail = 1.0
			ship.sail_shown = 1.0
			until = TK.wait_secs(30.0)
		1:
			check("at sea her wake is laid down (%d points)" % adm.wake.size(), adm.wake.size() >= 4)
			ship.sail = 1.0 / 3.0
			adm.send_patrol(ship, 3)
			pat = adm.get_children().filter(func(c): return c.get("role") == "patrol")
			var fwd: Vector3 = -ship.global_basis.z
			print("   patrol: %s" % [pat.map(func(s): return "%s %dm" % [s.kind, int(s.global_position.distance_to(ship.global_position))])])
			check("an Infamous crew draws a frigate and a cutter (%d)" % pat.size(), pat.size() == 2 and pat.any(func(s): return s.kind == "frigate"))
			check("...from the edge of view, back along her wake", pat.all(func(s): return s.global_position.distance_to(ship.global_position) > 250.0 and (s.global_position - ship.global_position).dot(fwd) < 0.0))
			check("...tracking her wake", pat.all(func(s): return s.state == s.S.TRACK))
			d0 = pat[0].global_position.distance_to(ship.global_position)
			until = TK.wait_secs(25.0)
		2:
			var d: float = pat[0].global_position.distance_to(ship.global_position)
			print("   %s: %.0f m -> %.0f m (%s)" % [pat[0].kind, d0, d, pat[0].S.keys()[pat[0].state]])
			check("they close on her", d < d0 - 40.0)
			check("...hunted: the crew hears it once", adm.hunted and started == 1)
			# she shows them a clean pair of heels: far beyond their sight
			var to: Vector3 = ship.global_position - ship.global_basis.z * 900.0
			ship.place(to, ship.global_rotation.y)
			until = TK.wait_ticks(2)
		3:
			p.global_position = ship.to_global(Vector3(0.5, 0.6, 3.0))
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			until = TK.wait_secs(4.0)
		4:
			check("lost by distance: they turn away (%s)" % [pat.filter(func(s): return is_instance_valid(s)).map(func(s): return s.S.keys()[s.state])], pat.all(func(s): return not is_instance_valid(s) or not s.pursuing()))
			check("...the crew hears they've escaped", not adm.hunted and escaped == 1)
			check("...and the sea goes quiet: no patrol for a while (%.0f s)" % (adm._quiet_until - adm.clock), adm._quiet_until - adm.clock > A.QUIET - 10.0)
			check("...and out of sight they're gone (%s; the captain %.0f m from her ship)" % [adm.specs.keys(), p.global_position.distance_to(ship.global_position)], adm.specs.is_empty())
			return TK.done(fails)
	step += 1
	return false
