extends "res://tools/dev/t/fauna/_creature_case.gd"
## Thorn-backed boars (fauna/thorn_boar.gd, 1.30): in the forest's pool; it comes for a captain near it, paws (its
## tell) and charges; a blow on its thorny back mostly turns, one to its face doesn't; dies dropping haunch or tusk; sleeps far.


func case() -> Dictionary:
	return {"theme": "forest", "kind": "thorn_boar", "at": Vector3(0, 0, -6.0),
		"prep": func(c):
			var back := HitData.new()
			back.damage = 10.0
			var hp0: float = c.health.current_health
			c._on_hit(back, _behind(c))
			var lost_back: float = hp0 - c.health.current_health
			hp0 = c.health.current_health
			c._on_hit(back, p)
			check("...its thorny back turns a blow (%.1f) its face doesn't (%.1f)" % [lost_back, hp0 - c.health.current_health], lost_back < (hp0 - c.health.current_health) * 0.7)}


func _behind(c) -> Node3D:
	var n := Node3D.new()
	stage.add_child(n)
	n.global_position = c.global_position - c._fwd() * 3.0
	return n
