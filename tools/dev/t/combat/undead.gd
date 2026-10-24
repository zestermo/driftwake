extends SceneTree
## The fog isles' dead (1.20): a drowned sailor shrugs off shot (a share of the damage, never knocked down) and
## carries no gun (a rifleman's post is a blade's), bleeds no blood, gets back up once when cut down and stays
## down the second time; a ghost takes no harm at all from shot but a blade still finds it, glows all over and
## doesn't rise.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0
var d
var g


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func spawn(path: String, s: int, at: Vector3, role := "sword") -> Node:
	var e = load(path).new().setup({"post": at, "seed": s, "role": role})
	e.level = 3
	stage.add_child(e)
	e.global_position = at
	return e


func hit(dmg: float, shot: bool) -> HitData:
	var h := HitData.new()
	h.damage = dmg
	h.knockback_force = 6.0
	if shot:
		h.impact = "shot"
		h.ranged = true
	else:
		h.impact = "slice"
		h.unblockable = true
	return h


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var far: Vector3 = stage.player.global_position + Vector3(18, 0, 18)
	match step:
		0:
			d = spawn("res://scripts/enemies/drowned.gd", 11, far, "rifle")
			g = spawn("res://scripts/enemies/ghost.gd", 12, far + Vector3(6, 0, 0))
			until = TK.wait_ticks(10)
		1:
			check("a drowned rifleman's post is a blade's (%s)" % d.role, d.role == "sword")
			var skin: Color = d.look["skin"]
			check("the drowned are grey-green (%s)" % str(skin), skin.g > skin.r and skin.r < 0.6)
			var glow := true
			for mi in g.humanoid.find_children("*", "MeshInstance3D", true, false):
				if (mi as MeshInstance3D).material_override == null:
					glow = false
			check("a ghost glows all over", glow)
			var hp0: float = d.health.current_health
			d._on_hit(hit(30.0, true), stage.player)
			var lost: float = hp0 - d.health.current_health
			check("a shot does a share of its damage to the drowned (%.1f of 30)" % lost, lost > 3.0 and lost < 15.0)
			check("...and never knocks him down (%s)" % d.state, d.state != d.S.DOWN)
			var ghp: float = g.health.current_health
			g._on_hit(hit(30.0, true), stage.player)
			check("a shot passes through a ghost (%.1f -> %.1f)" % [ghp, g.health.current_health], g.health.current_health == ghp)
			g._on_hit(hit(30.0, false), stage.player)
			check("...a blade finds it (%.1f -> %.1f)" % [ghp, g.health.current_health], g.health.current_health < ghp - 10.0)
			# cut the drowned down
			d._on_hit(hit(9999.0, false), stage.player)
			until = TK.wait_ticks(3)
		3:
			check("cut down, the drowned isn't dead (%s, hp %.0f)" % [d.state, d.health.current_health], d.state == d.S.DOWN and d.risen() and d.health.current_health > 0.0)
			until = TK.wait_secs(6.0)
		4:
			check("...he gets back up (%s)" % d.state, d.state != d.S.DOWN and d.state != d.S.DEAD and d.state != d.S.GETUP)
			d._on_hit(hit(9999.0, false), stage.player)
			check("the second time he stays down (%s)" % d.state, d.state == d.S.DEAD)
			g._on_hit(hit(9999.0, false), stage.player)
			check("a ghost cut down doesn't rise (%s)" % g.state, g.state == g.S.DEAD)
			return TK.done(fails)
	step += 1
	return false
