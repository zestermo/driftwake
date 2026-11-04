extends SceneTree
## The Commodore's vault (1.30, playtest 2026-11-02 row 5): once the keep's seal falls the vault chest stands on the
## Command Hall's floor where a captain can walk to it (not inside the dais), marked on the map, holding the stronghold's
## legendary and its Driftfruit (a free legendary from the pool, the same on a second look). Every legendary resolves.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var w
var isl
var bnode
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


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var p = stage.player
	var gm = root.get_node("GameManager")
	match step:
		0:
			var bad: Array = []
			for l in load("res://scripts/island/stronghold_boss.gd").LEGENDARIES:
				if ItemDB.with_trait("%s@%d" % [str(l[1]), ItemData.Rarity.LEGENDARY], str(l[2])) == null:
					bad.append(l[1])
			check("every vault legendary is a real weapon %s" % [bad], bad.is_empty())
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			until = TK.wait_ticks(2)
		1:
			isl = w.build_stronghold(Vector3(900, 0, 900))
			p.global_position = Vector3(900, 2, 1400)
			p.reset_physics_interpolation()
			until = TK.wait_secs(8.0)
		2:
			bnode = isl.city.get_node("Boss_vane")
			root.get_node("Net").world_flag("sh_seal_keep")
			root.get_node("Net").world_flag("sh_vault_unlocked")
			until = TK.wait_ticks(10)
		3:
			var key := "sh_vault_%d" % int(gm.chain_seed)
			var bag = bnode.get_node_or_null("Cache_" + key)
			check("the keep's seal falls: the vault chest is there", bag != null)
			if bag == null:
				return TK.done(fails)
			var space = bnode.get_world_3d().direct_space_state
			var ex: Array = [bag.get_rid()] if bag is CollisionObject3D else []
			var top: Vector3 = bag.global_position + Vector3.UP * 0.4
			var q := PhysicsRayQueryParameters3D.create(bnode.to_global(Vector3(0, 1.0, 0)), top, 1, ex)
			var hit: Dictionary = space.intersect_ray(q)
			check("...seen from the hall's middle with nothing in the way %s" % [hit.get("position", "")], hit.is_empty())
			q = PhysicsRayQueryParameters3D.create(top + Vector3.UP * 3.0, top + Vector3.DOWN * 3.0, 1, ex)
			hit = space.intersect_ray(q)
			var floor_y: float = hit.get("position", Vector3.INF).y - bnode.global_position.y
			check("...standing on the hall's floor, not in the dais (%.2f m up)" % floor_y, hit.has("position") and absf(floor_y) < 0.3)
			check("...marked on the map", MapMarks.marks.has("cache_" + key))
			var fruits: Array = bag.contents.filter(func(s): return s.item and str(s.item.devil_fruit) != "")
			var fid: String = str(fruits[0].item.devil_fruit) if not fruits.is_empty() else ""
			check("...the vault's Driftfruit in it (%s), a legendary one" % fid, fruits.size() == 1 and FruitPool.TIERS.get(fid, "") == "legendary")
			check("...reserved in the pool, and the same on a second look", FruitPool.taken(self, fid) and FruitPool.vault(self, int(gm.chain_seed)) == fid)
			var legend: Array = bag.contents.filter(func(s): return s.item and str(s.item.weapon_trait) != "" and int(s.item.rarity) == ItemData.Rarity.LEGENDARY)
			check("...and the stronghold's legendary", legend.size() == 1)
			return TK.done(fails)
	step += 1
	return false
