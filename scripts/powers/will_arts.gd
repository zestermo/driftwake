class_name WillArts
## The 1.24 Will paths' skills, run by TechniqueState (`s`: its helpers and timeline); enter() and update() return false
## for ids that aren't theirs. What the paths change outside a skill is WillPowers'.
##   will_still_point  Tempo: a held breath, then the world round you slows (StillPoint, every machine)
##   will_berserk      Fury: a roar, then WillPowers' berserk buff

const STILL_REACH := 20.0
const STILL_SECS := 3.0
const STILL_COL := Color(0.75, 0.85, 1.0)


static func _net() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Net")


static func enter(s, id: String) -> bool:
	var p: Player = s.player
	var net := _net()
	match id:
		"will_still_point":
			s.dur = 0.6
			p.body_model.play("foresight", s.dur)
			net.fx("gather", [p.global_position + Vector3(0, 1.2, 0), 1.6, STILL_COL, 0.3, 14])
			net.fx("sfx", ["blip_high", p.global_position, -6.0, 0.0, 0.5])
		"will_berserk":
			s.dur = 0.75
			p.body_model.play("berserk_roar", s.dur)
			net.fx("gather", [p.global_position + Vector3(0, 1.2, 0), 1.2, WillPowers.FURY, 0.25, 12])
		_:
			return false
	return true


static func update(s, delta: float) -> bool:
	var p: Player = s.player
	var net := _net()
	match s.id:
		"will_still_point":
			s._rooted(delta, 0.0)
			if s._once("still", 0.3):
				var at := p.global_position
				net.everyone("_all_will", ["still", [at, STILL_REACH, STILL_SECS]])
				net.fx("ring", [at + Vector3(0, 0.2, 0), Vector3.UP, STILL_REACH, STILL_COL, 0.6, 0.1])
				net.fx("ring", [at + Vector3(0, 1.2, 0), Vector3.UP, 3.0, Color.WHITE, 0.3, 0.12])
				net.fx("star_glint", [at + Vector3(0, 1.6, 0), 1.4, STILL_COL, 0.4])
				net.fx("sfx", ["whoosh_big", at, -4.0, 0.0, 0.45])
				p.cam_kick(0.15, 0.6)
		"will_berserk":
			s._rooted(delta, 0.0)
			if s._once("roar", 0.25):
				p.power.will.berserk()
		_:
			return false
	return true
