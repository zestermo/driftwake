extends SceneTree
## BodyBuilder.one_skin (one skeleton per body) changes nothing you can see: the same looks built both ways and
## posed the same (random joint turns, the head's scale), CPU-skinned into world space, give the same vertices per
## material (position, normal, uv, colour); every rigid part rides the one skeleton (the joints carry no meshes);
## fewer draws; the player's rig (swappable hands) keeps the old path.
const TK := preload("res://tools/dev/test_kit.gd")
const SC := preload("res://tools/dev/t/world/_skin_cmp.gd")
const LOOKS := 28
var fails := 0
var step := 0


func _initialize() -> void:
	TK.seed_of(self)


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


## Meshes left on joints (not on the skeleton, a spring chain or a weapon).
func stray(h: Humanoid) -> Array:
	var out := []
	for mi in h.find_children("*", "MeshInstance3D", true, false):
		var p := (mi as Node).get_parent()
		if p is LowerBody or mi == h.weapon or mi == h.offhand:
			continue
		var q := p
		while q and q != h and not q is SpringChains:
			q = q.get_parent()
		if not q is SpringChains:
			out.append("%s/%s" % [p.name, mi.name])
	return out


func _process(_d: float) -> bool:
	match step:
		0:
			var bad := 0
			var worst := ""
			var od := 0
			var nd := 0
			var strays := []
			var nverts := 0
			for i in range(LOOKS):
				var lk := SC.look_of(i)
				var a := SC.rig(self, lk, false)
				var b := SC.rig(self, lk, true)
				SC.pose(a, i)
				SC.pose(b, i)
				var r := SC.misses(SC.verts(a), SC.verts(b))
				nverts += int(r[1])
				if int(r[0]) > 0:
					bad += 1
					if worst == "":
						worst = "look %d (%s %s hat %s coat %s): %d of %d vertices, first %s" % [i, lk["body"], lk["build"], lk["hat"], lk["coat"], r[0], r[1], r[2]]
				od += SC.draws(a)
				nd += SC.draws(b)
				for s in stray(b):
					if not s in strays:
						strays.append(s)
				if i == 0:
					check("no ArmBody: the arms are on the one skeleton", b.torso.get_node_or_null("ArmBody") == null and b.hips.get_node("LowerBody").has_arms())
				a.free()
				b.free()
			check("%d looks posed alike: the same vertices both ways (%d compared)%s" % [LOOKS, nverts, "" if bad == 0 else ": " + worst], bad == 0)
			check("every rigid part rides the one skeleton (left on joints: %s)" % str(strays), strays.is_empty())
			check("fewer draws (mean %.1f -> %.1f)" % [od / float(LOOKS), nd / float(LOOKS)], nd < od)
			var p := SC.rig(self, SC.look_of(3), true, true)
			check("the player's rig (swappable hands) keeps the old path", p.torso.get_node_or_null("ArmBody") != null)
			p.free()
			return TK.done(fails)
	step += 1
	return false
