extends SceneTree
## The storm eel (1.28 leviathan): it stays down in fair weather and rises in a storm; its lightning on the mast tears
## her sail, sets a fire at the mast's foot and floors a captain by the mast; its burst from below breaches her side
## and floors a captain on the spot, its head left on the deck. Killed, it's dead.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var s
var eel
var wx
var step := 0
var until := 0
var fails := 0
var b0 := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true, "weather": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func hp() -> float:
	return p.health_component.current_health


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
			wx.force(0)
			p.global_position = s.to_global(Vector3(0.5, 0.6, 3.0))
			p.reset_physics_interpolation()
			eel = load("res://scripts/enemies/leviathan.gd").make("eel", Vector2(s.global_position.x + 30.0, s.global_position.z), 14)
			stage.add_child(eel)
			until = TK.wait_secs(3.0)
			step = 1
		1:
			check("fair weather: it stays down", eel.state == 0)
			wx.force(3)
			until = TK.wait_secs(8.0)
			step = 2
		2:
			check("a storm (%.2f): it's risen and fighting (%d)" % [wx.storm, eel.state], eel.state == 2)
			# by the mast for its lightning
			p.global_position = s.to_global(Vector3(0.8, 0.6, eel.MAST_Z + 0.5))
			p.reset_physics_interpolation()
			eel._go_a(1)
			b0 = s.fires.size()
			until = TK.wait_secs(2.2)
			step = 3
		3:
			check("lightning on the mast sets a fire (%d)" % s.fires.size(), s.fires.size() > b0)
			check("...tears her sail", s.torn.size() >= 1)
			check("...and floors a captain by the mast", p.current_state_name() in ["Downed", "Knockdown", "Ragdoll"] or hp() < 9999.0)
			p.health_component.current_health = 9999.0
			until = TK.wait_secs(2.5)
			step = 4
		4:
			# from below, right where the captain stands
			p.global_position = s.to_global(Vector3(-0.8, 0.6, 1.0))
			p.reset_physics_interpolation()
			eel._below_at = Vector3(-0.8, s.DECK_Y, 1.0)
			b0 = s.breaches.size()
			eel._go_a(3)
			until = TK.wait_secs(3.2)
			step = 5
		5:
			check("it burst up through her: a breach (%d)" % s.breaches.size(), s.breaches.size() > b0)
			check("...a blow for the captain on the spot (%.0f)" % hp(), hp() < 9999.0)
			check("...its head on the deck", eel._a == 5 and eel.core.global_position.distance_to(s.to_global(Vector3(-0.8, s.DECK_Y, 1.0))) < 2.5)
			var hd := HitData.new()
			hd.damage = 999999.0
			eel.hurtbox.take_hit(hd, p)
			until = TK.wait_ticks(4)
			step = 6
		6:
			check("killed", eel.is_dead())
			wx.force(-1)
			print("RESULT OK" if fails == 0 else "RESULT FAILED (%d)" % fails)
			quit(1 if fails else 0)
			step = 7
	return false
