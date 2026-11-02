extends SceneTree
## The colossal squid (1.28 leviathan): it lurks until the crew's ship comes by manned, then rises beside her; a grab
## puts an arm on her rail (she's held back: Ship.held_k), an arm cut away by hand lets go and hurts the beast; the
## harpoon reels it alongside (REELED: it lets go of everything, hand blows x2); killed, it sinks and leaves a hoard
## with leviathan scales. Cannonballs strike its mantle (struck).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var s
var sq
var step := 0
var until := 0
var fails := 0
var hp0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func hit(hb, dmg: float) -> void:
	var hd := HitData.new()
	hd.damage = dmg
	hb.take_hit(hd, p)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			p.health_component.max_health = 9999.0
			p.health_component.current_health = 9999.0
			s = stage.ship
			var L = load("res://scripts/enemies/leviathan.gd")
			sq = L.make("squid", Vector2(s.global_position.x + 40.0, s.global_position.z), 14)
			stage.add_child(sq)
			until = TK.wait_ticks(10)
			step = 1
		1:
			check("lurking while nobody's aboard", sq.state == 0 and not sq.visible)
			p.global_position = s.to_global(Vector3(0.5, 0.6, 3.0))
			p.reset_physics_interpolation()
			until = TK.wait_secs(3.5)
			step = 2
		2:
			check("a manned ship near: it's risen and fighting (%d)" % sq.state, sq.state == 2 and sq.visible)
			check("beside her", sq.core.global_position.distance_to(s.global_position) < 30.0)
			check("a cannonball's line through the mantle strikes it", sq.struck(sq.core.global_position + Vector3(0, 2, 30), sq.core.global_position + Vector3(0, 2, -30)) != Vector3.INF)
			# a grab now: the arm comes down on her rail
			sq._next = 0.0
			sq._pending.clear()
			until = TK.wait_secs(2.0)
			step = 3
		3:
			check("an arm holds her rail", sq.arm_on.count(true) == 1)
			check("she's held back (%.2f)" % s.held_k, s.held_k < 0.9)
			var i: int = sq.arm_on.find(true)
			check("the arm's end can be hit", sq._arm_boxes[i].monitorable)
			hp0 = sq.hp
			hit(sq._arm_boxes[i], 9999.0)
			check("cut away, it lets go", not sq.arm_on[i])
			check("...and the beast is hurt (%.0f)" % (hp0 - sq.hp), hp0 - sq.hp >= sq.CUT_HURT - 1.0)
			# another grab, then the harpoon
			sq._next = 0.0
			until = TK.wait_secs(2.0)
			step = 4
		4:
			check("another arm on her", sq.arm_on.count(true) >= 1)
			check("the harpoon bites", HarpoonCannon.harpoon(s, sq, 2))
			until = TK.wait_secs(1.0)
			step = 5
		5:
			check("reeled alongside (%d)" % sq.state, sq.state == 3)
			check("...it lets go of her", sq.arm_on.count(true) == 0)
			hp0 = sq.hp
			hit(sq.hurtbox, 50.0)
			check("its guard's down: a blow x2 (%.0f)" % (hp0 - sq.hp), absf((hp0 - sq.hp) - 100.0) < 1.0)
			hit(sq.hurtbox, 999999.0)
			until = TK.wait_ticks(5)
			step = 6
		6:
			check("killed", sq.state == 5 and sq.is_dead())
			var bag = stage.get_tree().current_scene.find_child("LeviathanHoard", true, false) if stage.get_tree().current_scene else null
			if bag == null:
				for n in root.find_children("LeviathanHoard", "", true, false):
					bag = n
			var scales := 0
			if bag:
				for st in bag.contents:
					if st.item.id == "leviathan_scale":
						scales += st.quantity
			check("its hoard floats up with leviathan scales (%d)" % scales, bag != null and scales >= 2)
			print("RESULT OK" if fails == 0 else "RESULT FAILED (%d)" % fails)
			quit(1 if fails else 0)
			step = 7
	return false
