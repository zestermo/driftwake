extends SceneTree
## 1.23 (Zach: "falling through the ground and into the water level underneath the terrain"): a captain who slipped
## through an island's ground and is swimming in the sea under it is put back on top (GroundNet), and one swimming
## in open water where the ground is under the sea is left alone.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ground := -20.0
var top := -99.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"water": true, "hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if p:
		top = maxf(top, p.global_position.y)
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			# the island's ground as GroundNet reads it (first: open water, the seabed far below)
			GroundNet.height_override = func(_at: Vector3) -> float: return ground
			p.global_position = Vector3(p.global_position.x + 30.0, -1.2, p.global_position.z)
			p.reset_physics_interpolation()
			until = TK.wait_secs(1.0)
		1:
			check("(swimming in the sea: %s)" % p.current_state_name(), p.is_swimming())
			until = TK.wait_ticks(20)
		2:
			check("in open water it's left alone (y %.1f)" % p.global_position.y, p.is_swimming() and p.global_position.y < 0.5)
			top = -99.0
			ground = 5.0   # now an island's ground stands over the swimmer (its collider "missed")
			until = TK.wait_ticks(20)
		3:
			check("under the island's ground it's put back on top (up to y %.1f, ground %.1f)" % [top, ground],
				top > ground - 0.2 and not p.is_swimming())
			GroundNet.height_override = Callable()
			return TK.done(fails)
	step += 1
	return false
