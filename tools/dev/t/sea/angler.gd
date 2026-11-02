extends SceneTree
## The abyssal angler (1.28 leviathan): it stays down by day and rises by night, its lure lit and drifting round her;
## blows on the lure count double and enough of them drag it up stunned at the surface; its jaws from below (the lure
## dark first) crack her hull and floor a captain on her deck. Killed, it's dead.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var s
var an
var wx
var step := 0
var until := 0
var fails := 0
var h0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true, "weather": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func blow(hb, dmg: float) -> void:
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
			wx = root.get_node("Weather")
			p.global_position = s.to_global(Vector3(0.5, 0.6, 3.0))
			p.reset_physics_interpolation()
			an = load("res://scripts/enemies/leviathan.gd").make("angler", Vector2(s.global_position.x + 30.0, s.global_position.z), 14)
			stage.add_child(an)
			until = TK.wait_secs(2.0)
			step = 1
		1:
			check("by day it stays down (night %.2f)" % wx.night, wx.night > 0.5 or an.state == 0)
			# to midnight
			wx.skip_to(0.0)
			until = TK.wait_secs(4.0)
			step = 2
		2:
			check("by night (%.2f) it's risen (%d)" % [wx.night, an.state], an.state == 2)
			check("its lure's lit near her", an.lure_on and an.lure_at.distance_to(s.global_position) < 30.0)
			h0 = an.hp
			blow(an.lure_box, 50.0)
			check("a blow on the lure counts double (%.0f)" % (h0 - an.hp), absf((h0 - an.hp) - 100.0) < 1.0)
			blow(an.lure_box, 200.0)
			until = TK.wait_ticks(3)
			step = 3
		3:
			check("enough on the lure: it's stunned at the surface (%d, y %.1f)" % [an._a, an.core.global_position.y], an._a == 4 and an.core.global_position.y > -1.0)
			until = TK.wait_secs(5.0)
			step = 4
		4:
			p.health_component.current_health = 9999.0
			an._next = 0.0
			h0 = s.hull
			until = TK.wait_secs(0.5)
			step = 5
		5:
			check("the lure's gone dark before the jaws", not an.lure_on)
			until = TK.wait_secs(2.8)
			step = 6
		6:
			check("the jaws crack her hull (%.0f -> %.0f)" % [h0, s.hull], s.hull < h0)
			check("...and floor a captain on her deck", p.health_component.current_health < 9999.0)
			blow(an.hurtbox, 999999.0)
			until = TK.wait_ticks(4)
			step = 7
		7:
			check("killed", an.is_dead())
			print("RESULT OK" if fails == 0 else "RESULT FAILED (%d)" % fails)
			quit(1 if fails else 0)
			step = 8
	return false
