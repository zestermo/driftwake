extends SceneTree
## 1.23 breakable places (Breakable): a crate knocked by a light hit stays whole; a heavy blow smashes it (its mesh and
## collider gone); striking it gives no energy (no farming the furniture); it comes back once no captain is near.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var crate
var br
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func hit(dmg: float, down: bool) -> HitData:
	var h := HitData.new()
	h.damage = dmg
	h.knockdown = down
	return h


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			crate = load("res://scripts/props/props.gd").crate(0.8)
			stage.add_child(crate)
			crate.global_position = p.global_position + Vector3(2.0, 0.0, 0.0)
			br = crate.get_node("Breakable")
			check("a crate is breakable (on the enemies' hurtbox layer)", br != null and br.collision_layer == 32 and crate.is_in_group("breakables"))
			br.take_hit(hit(8.0, false), p)
			check("a light hit leaves it whole", not br.broken)
			var e0: float = p.power.energy
			p.power.on_sword_hit(crate, hit(8.0, false))
			check("striking it gives no energy (%.1f -> %.1f)" % [e0, p.power.energy], is_equal_approx(p.power.energy, e0))
			br.take_hit(hit(30.0, true), p)
			until = TK.wait_ticks(3)
		1:
			var mesh_on := false
			var col_on := false
			for c in crate.get_children():
				if c is MeshInstance3D and c.visible:
					mesh_on = true
				if c is CollisionShape3D and not c.disabled:
					col_on = true
			check("a heavy blow smashes it: mesh and collider gone", br.broken and not mesh_on and not col_on)
			br._back_t = 0.0
			p.global_position += Vector3(200, 0, 0)
			until = TK.wait_ticks(4)
		2:
			check("...and it comes back with no captain near", not br.broken)
			return TK.done(fails)
	step += 1
	return false
