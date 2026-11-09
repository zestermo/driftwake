extends SceneTree
## (1.31) Reviving takes F over every other interaction: with a downed crewmate in reach and a chest right there,
## the chest's prompt stands aside, holding F gets the crewmate up (not the chest), and once they're up the chest
## is F's again.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var mate
var ic
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"chest": [["rum", 1]], "crew": [{"name": "Mate", "at": Vector3(1.6, 0, 0.8)}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			mate = stage.crew[0]
			ic = p.get_node("InteractionComponent")
			var net = root.get_node("Net")
			net.active = true
			net.roster = {1: {}, 2: {}}
			net.players = {1: p, 2: mate}
			net.local_player = p
			# the captain between the chest (3 m east) and the downed mate, nearer the chest
			p.global_position = Vector3(2.2, p.global_position.y, 0.3)
			p.reset_physics_interpolation()
			mate._net_flags = mate._net_flags | mate.NF_BLEED
			until = TK.wait_secs(0.5)
		1:
			check("a downed crewmate in reach: reviving (%s)" % p.reviving(), p.reviving())
			check("...the chest's prompt stands aside", ic.current_interactable == null)
			TK.press("interact")
			until = TK.wait_secs(0.6)
		2:
			check("holding F gets them up, not the chest (%.2f s in)" % p._revive_t, p._revive_t > 0.3)
			TK.release("interact")
			mate._net_flags = mate._net_flags & ~mate.NF_BLEED
			until = TK.wait_secs(0.5)
		3:
			check("they're up: the chest is F's again", not p.reviving() and ic.current_interactable != null)
			return TK.done(fails)
	step += 1
	return false
