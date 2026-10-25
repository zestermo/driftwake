extends SceneTree
## The capital's arena (1.21 piece 3): walked in through its west gate and the cut in the stands, the sand at the ground
## you stand on, the podium wall round it; the crowd in the stands; the arena master on the sand. Bouts (ArenaBout,
## solo: the host's): a rival steps out, beaten under a tenth of their health the captain wins the purse and moves up
## the ladder; beating the champion gives the title and the Champion's Sabre; a lost bout changes nothing but the
## captain stands again; the title defended once a day.
const TK := preload("res://tools/dev/test_kit.gd")
const AT := Vector3(0, 0, 4000)
var stage
var step := 0
var until := 0
var fails := 0
var w
var isl
var bout
var gold0 := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _ray(a: Vector3, b: Vector3) -> Dictionary:
	return root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a, b))


func _gold() -> int:
	return stage.player.inventory_component.count("gold")


## A bout for the captain, its rival brought under END_AT (won) or the captain (lost) once it's out.
func _bout(kind: String, rank: int) -> void:
	var p = stage.player
	p.global_position = isl.city_global(P().ARENA_C + Vector2(-5.0, 0), P().PLAZA_Y + 0.5)
	p.reset_physics_interpolation()
	gold0 = _gold()
	bout = AB().start(p, kind, rank, isl, isl.arena_sand())


## (loaded, not named: naming it compiles Player and the autoloads before they exist)
func AB():
	return load("res://scripts/game/arena_bout.gd")


func P():
	return load("res://scripts/island/capital_plan.gd")


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var Pl = P()
	var p = stage.player
	match step:
		0:
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			until = TK.wait_ticks(2)
		1:
			isl = w.build_capital(AT)
			until = TK.wait_ticks(4)
		2:
			var y: float = Pl.PLAZA_Y
			check("the arena's west gate and the cut through the stands are open",
				_ray(isl.city_global(Vector2(60.0, 0), y + 1.5), isl.city_global(Pl.ARENA_C - Vector2(6.0, 0), y + 1.5)).is_empty())
			var hit := _ray(isl.city_global(Pl.ARENA_C + Vector2(0, 4.0), y + 3.0), isl.city_global(Pl.ARENA_C + Vector2(0, 4.0), y - 3.0))
			var sy: float = isl.to_local(hit["position"]).y if not hit.is_empty() else -INF
			check("the sand is the ground you stand on (%.2f)" % sy, absf(sy - y) < 0.2)
			check("the podium wall closes the sand", not _ray(isl.city_global(Pl.ARENA_C + Vector2(0, -10.0), y + 1.0), isl.city_global(Pl.ARENA_C + Vector2(0, -24.0), y + 1.0)).is_empty())
			check("the crowd in the stands", isl.city.get_node_or_null("ArenaCrowd") != null)
			check("the arena master's place", isl.spots.has("arena_master"))
			check("the capital answers for its sand", isl.is_in_group("capital") and isl.has_method("arena_sand"))
			p.arena_rank = 0
			_bout("ladder", 0)
			check("a rookie steps out against the captain", bout != null and is_instance_valid(bout.rival) and bout.rival.is_in_group("rivals"))
			until = TK.wait_ticks(10)
		3:
			bout.rival.health_component.current_health = bout.rival.health_component.max_health * 0.05
			until = TK.wait_ticks(6)
		4:
			check("beaten: the captain moves up the ladder (%d)" % p.arena_rank, p.arena_rank == 1)
			check("...and is paid the purse (%d)" % (_gold() - gold0), _gold() - gold0 == AB().PURSES[0])
			until = TK.wait_secs(4.0)
		5:
			check("the rival leaves the sand", get_nodes_in_group("arena_bouts").is_empty())
			p.arena_rank = 5
			_bout("ladder", 5)
			until = TK.wait_ticks(10)
		6:
			bout.rival.health_component.current_health = 0.0
			until = TK.wait_ticks(6)
		7:
			check("the champion beaten: the title (%d)" % p.arena_rank, p.arena_rank == AB().FIGHTERS.size())
			check("...the Champion's Sabre", p.inventory_component.count(AB().TROPHY) == 1)
			check("...and the champion's purse", _gold() - gold0 == AB().PURSES[5])
			until = TK.wait_secs(4.0)
		8:
			_bout("defend", AB().FIGHTERS.size())
			until = TK.wait_ticks(10)
		9:
			p.health_component.current_health = p.health_component.max_health * 0.05
			until = TK.wait_ticks(6)
		10:
			check("a lost defence keeps the title but pays nothing", p.arena_rank == AB().FIGHTERS.size() and _gold() == gold0 and p.arena_defended_day != int(root.get_node("Weather").day()))
			check("...and the captain stands", p.is_standing())
			p.health_component.current_health = p.health_component.max_health
			until = TK.wait_secs(4.0)
		11:
			_bout("defend", AB().FIGHTERS.size())
			until = TK.wait_ticks(10)
		12:
			bout.rival.health_component.current_health = 0.0
			until = TK.wait_ticks(6)
		13:
			check("the title defended: once today (%d)" % p.arena_defended_day, p.arena_defended_day == int(root.get_node("Weather").day()))
			check("...for the defence's purse", _gold() - gold0 == AB().DEFEND_PURSE)
			isl.queue_free()
			return TK.done(fails)
	step += 1
	return false
