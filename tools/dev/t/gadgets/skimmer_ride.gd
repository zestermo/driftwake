extends SceneTree
## The skimmer (1.28.1): refused on land with no water ahead; at the shore's edge facing the sea it hops you out onto
## the water, riding the swell with the board under you (the snapshot flags it for crewmates); held steering takes it
## up to its top speed and turns it to the stick's way; across the wind it's faster than into it; a blow knocks you
## off into the water; launched again from swimming, F stows it (swimming, the board gone); run into the shore's
## rock at speed and you're thrown off.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var st
var step := 0
var until := 0
var fails := 0
var into := 0.0
var beam := 0.0
var wind_yaw := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "water": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _yaw_of(v: Vector3) -> float:
	return atan2(-v.x, -v.z)


func _steer(yaw: float) -> void:
	stage.camera_rig.rotation.y = yaw
	TK.press("move_forward")


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			st = p.get_node("StateMachine/Skimmer")
			p.gadgets.give("skimmer", 0)
			check("on land with no water ahead it won't launch", not p.gadgets.fire() and p.current_state_name() != "Skimmer")
			p.global_position = Vector3(stage.SHORE_X - 1.5, stage.GROUND_Y + 0.05, 0)
			p.reset_physics_interpolation()
			p.player_model.rotation.y = _yaw_of(Vector3.RIGHT)
			p.gadgets.ready_at.clear()
			until = TK.wait_ticks(6)
		1:
			check("at the shore's edge facing the sea it launches", p.gadgets.fire() and p.current_state_name() == "Skimmer")
			until = TK.wait_secs(1.0)
		2:
			var surf: float = p.water_surface()
			check("out on the water (x %.1f)" % p.global_position.x, p.global_position.x > stage.SHORE_X + 1.0)
			check("riding the swell (%.2f over the surface)" % (p.global_position.y - surf), absf(p.global_position.y - surf - st.RIDE_H) < 0.35)
			check("the board under the captain", p.lean.get_node_or_null("Skimmer") != null)
			check("crewmates are told (the snapshot's flag)", (int(p.net_pack()[8]) & p.NF_SKIM) >> p.NF_SKIM_SHIFT == 1)
			root.get_node("Weather").wind = 1.0
			var wd: Vector2 = root.get_node("Weather").wind_dir()
			wind_yaw = _yaw_of(Vector3(wd.x, 0, wd.y))
			_steer(_yaw_of(Vector3.RIGHT))
			until = TK.wait_secs(3.0)
		3:
			check("held steering, it's up to its top speed (%.1f of %.1f m/s)" % [st.speed, st.top_speed()], st.speed > st.top_speed() * 0.9)
			check("...the top speed is the tier's 11 m/s by the wind (%.1f)" % st.top_speed(), st.top_speed() <= 11.01 and st.top_speed() > 3.0)
			_steer(wind_yaw + PI)
			until = TK.wait_secs(3.5)
		4:
			check("steering turns the board to the stick's way", absf(angle_difference(st.heading, wind_yaw + PI)) < 0.08)
			into = st.speed
			var b := wind_yaw + PI * 0.5
			if -sin(b) < 0.0:
				b = wind_yaw - PI * 0.5
			_steer(b)
			until = TK.wait_secs(3.5)
		5:
			beam = st.speed
			print("   into the wind %.1f m/s, across it %.1f m/s" % [into, beam])
			check("across the wind it's faster than into it (%.1f > %.1f)" % [beam, into], beam > into * 1.6)
			check("...across it, the full 11 m/s", beam > 9.8)
			TK.release("move_forward")
			var hit := HitData.new()
			hit.damage = 4.0
			p.hurtbox.take_hit(hit, null)
			until = TK.wait_ticks(3)
		6:
			check("a blow knocks you off into the water", p.current_state_name() == "Swim" and st.last_end == "hit")
			check("...the board gone", p.lean.get_node_or_null("Skimmer") == null)
			until = TK.wait_secs(3.2)
		7:
			check("swimming, it launches where you are", p.gadgets.fire() and p.current_state_name() == "Skimmer")
			until = TK.wait_secs(0.6)
		8:
			TK.act("interact")
			until = TK.wait_ticks(3)
		9:
			check("F stows it: swimming again", p.current_state_name() == "Swim" and st.last_end == "stow")
			check("...the board put away", p.lean.get_node_or_null("Skimmer") == null)
			p.global_position = Vector3(stage.SHORE_X + 7.0, 0.0, 0)
			p.reset_physics_interpolation()
			until = TK.wait_secs(3.2)
		10:
			check("launched again", p.gadgets.fire() and p.current_state_name() == "Skimmer")
			st.heading = _yaw_of(Vector3.LEFT)
			st.speed = 10.0
			_steer(_yaw_of(Vector3.LEFT))
			until = TK.wait_secs(1.5)
		11:
			TK.release("move_forward")
			check("run into the shore's rock at speed, you're thrown off (%s)" % st.last_end, p.current_state_name() == "Swim" and st.last_end == "crash")
			return TK.done(fails)
	step += 1
	return false
