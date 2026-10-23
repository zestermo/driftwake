extends SceneTree
## A rival crew's duels pair each captain with a mate who fights with that captain's own weapon kind (in co-op each
## captain gets their own match, not one for the host's weapon), else the first mate waiting; the crew's captain still
## comes last, after every mate (RivalEncounter._next_up).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var e
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


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
			root.get_node("GameManager").rivals.clear()
			# (notorious: a bigger crew, so there's a choice of mates)
			p.bounty = 25000
			e = load("res://scripts/ai/rival_encounter.gd").start(p, "gilded_gulls")
			until = TK.wait_secs(0.4)
		1:
			var cs = load("res://scripts/dialogue/cutscene.gd").active
			if cs:
				cs.end(true)
			var mates: Array = e.rivals.slice(0, e.rivals.size() - 1)
			var kinds: Array = mates.map(func(r): return r.style())
			print("mates' weapons: ", kinds, " rolled: ", e.info.map(func(m): return m["weapon"]), " held: ", mates.map(func(r): return r.equipped_weapon.id if r.equipped_weapon else "none"))
			# a mate later in the queue whose kind the first doesn't share
			var want = null
			for i in range(1, mates.size()):
				if kinds[i] != kinds[0]:
					want = mates[i]
					break
			check("the crew has mates with different weapons to choose from (%s)" % str(kinds), want != null)
			if want == null:
				return TK.done(fails)
			e._active.clear()
			e._queue = mates.duplicate()
			e._queue.append(e.rivals[-1])
			var wi: int = e.rivals.find(want)
			p.equip_weapon(ItemDB.get_item(str(e.info[wi]["weapon"])), false)
			var got = e._next_up(p)
			check("a captain with a %s gets the mate who fights with one (%s), not the first in line (%s)" % [p.style(),
				got.style() if got else "none", kinds[0]], got == want)
			p.unequip_weapon()
			var first_waiting = e._queue[0]
			var none = e._next_up(p)
			check("with no mate to match, the first still waiting (%s)" % (none.name if none else "none"), none == first_waiting and none != e.rivals[-1])
			# drain the mates: the crew's captain only once they've all had their turn
			var last = null
			var n := 0
			while true:
				var r = e._next_up(p)
				if r == null:
					break
				last = r
				n += 1
			check("their captain comes last, after every mate (%s)" % (last.name if last else "none"), last == e.rivals[-1])
			return TK.done(fails)
	step += 1
	return false
