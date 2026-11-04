extends SceneTree
## (1.30, the collision audit) A pier's rope rail and piles are solid: walking at the rail between two posts a captain
## is stopped (a ray across it at knee and waist height hits), but not where the rail has a break; a pile stops a
## wader or swimmer from a wader's depth (1.2 m under the sea) up, and deeper down it's passable.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0
var body: StaticBody3D
const AT := Vector3(300, 0, 0)


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _hits(a: Vector3, b: Vector3) -> bool:
	return not root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(AT + a, AT + b)).is_empty()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			var HM = load("res://scripts/island/kit/kit_harbour_models.gd")
			body = StaticBody3D.new()
			body.position = AT
			stage.add_child(body)
			# posts along x at the deck (y 2), a break after the second
			HM.rail_cols(body, PackedVector3Array([Vector3(0, 2, 0), Vector3(2, 2, 0), Vector3(4, 2, 0), Vector3(6, 2, 0)]), [1])
			HM.pile_cols(body, [[Vector3(10, -4, 0), Vector3(10, 1.9, 0), 0.15]])
			until = TK.wait_ticks(3)
		1:
			for y in [2.3, 2.8]:
				check("the rail stops a captain between its posts at %.1f m" % y, _hits(Vector3(1, y, -1), Vector3(1, y, 1)) and _hits(Vector3(5, y, -1), Vector3(5, y, 1)))
			check("...but not across the break", not _hits(Vector3(3, 2.5, -1), Vector3(3, 2.5, 1)))
			check("a pile stops a wader at the surface and 1 m under", _hits(Vector3(10, 0, -1), Vector3(10, 0, 1)) and _hits(Vector3(10, -1.0, -1), Vector3(10, -1.0, 1)))
			check("...and deeper down it's passable", not _hits(Vector3(10, -2.5, -1), Vector3(10, -2.5, 1)))
			return TK.done(fails)
	step += 1
	return false
