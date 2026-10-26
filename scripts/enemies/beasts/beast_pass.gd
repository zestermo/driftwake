class_name BeastPass
extends RefCounted
## The 1.23 beast pass on a JungleBeast boss (docs/v1_23_previews.md section 6), opt-in by kind (_pass_moves() not
## empty: the Sand King, the Bear King; the rest later). What it adds to the kind's own brain and body:
##   phases     each adds moves it didn't have (the kind's _pass_moves(): phase 1's, 2's, 3's), its openings shorten
##              (OPEN_K on the kind's own recoveries) and it chains moves (CHAIN: one, a pair, three with a long opening
##              after); a phase change is a moment (move "moment": it reels, rears up roaring, a ring pushes everyone
##              back, BeastFX.moment on every screen) and its look changes (the kind's _on_look)
##   poise      Poise "beast_boss" (400, +25% a phase); blows in an opening count double; broken: the stagger pose for
##              REEL_S and double damage for VULN_S; never knocked down or juggled
##   parts      BeastParts: a break drops its item for every captain, drains PART_POISE and takes away the moves the
##              kind's _part_takes() names (or weakens one: the kind reads parts.broken())
##   motion     BeastMotion for the kind's _animate (head tracking, hit springs, breath, the reel's sway, springs)
## The beast calls in at begin / end_move / pick / its hits / its phase check; the rest is the kind's.

const OPEN_K := [1.0, 0.8, 0.6]
const CHAIN := [1, 2, 3]
const CHAIN_GAP := 0.15
const CHAIN_END := 0.45
const REEL_S := 2.4
const VULN_S := 3.0
const VULN_K := 2.0
## The phase change: reels until MOMENT_REAR, the roar's ring at MOMENT_RING, over by MOMENT_S.
const MOMENT_REAR := 0.5
const MOMENT_RING := 1.3
const MOMENT_S := 2.2
const MOMENT_R := 9.5
const PART_POISE := 120.0

var beast: Node
var poise: Poise
var motion := BeastMotion.new()
var parts := BeastParts.new()
var chain_left := 0
var in_chain := false
var picked := false
var _vuln_until := -1


func _init(b: Node) -> void:
	beast = b
	poise = Poise.make("beast_boss")


## The moves its phase allows, less what broken parts took away.
func moves() -> Array:
	var by: Array = beast.call("_pass_moves")
	var out: Array = []
	for i in range(mini(int(beast.get("phase")), by.size())):
		out.append_array(by[i])
	var takes: Dictionary = beast.call("_part_takes")
	for n in takes.keys():
		if parts.broken(n):
			for m in takes[n]:
				out.erase(m)
	return out


## Every move any phase has (what chains and openings apply to: the kind's sub-moves aren't in it).
func all_moves() -> Array:
	var out: Array = []
	for ms in beast.call("_pass_moves"):
		out.append_array(ms)
	return out


## Allowed now: one of its phase's moves (or a sub-move no phase lists).
func allows(m: String) -> bool:
	return m in moves() or not m in all_moves()


## A move begun from the brain (picked: pick() said so), not a move's own follow-on (a slam's dive): a chain starts
## here unless it's the chain's next.
func began(m: String) -> void:
	if not picked or not m in all_moves():
		return
	picked = false
	if in_chain:
		in_chain = false
	else:
		chain_left = CHAIN[int(beast.get("phase")) - 1] - 1


## A move over: the opening after it (the kind's own times OPEN_K), or straight on into the chain's next.
func opening(m: String, secs: float) -> float:
	if not m in all_moves():
		return secs
	var ph := int(beast.get("phase"))
	if chain_left > 0:
		chain_left -= 1
		in_chain = true
		return CHAIN_GAP
	return secs * OPEN_K[ph - 1] + (CHAIN_END if CHAIN[ph - 1] >= 3 else 0.0)


## Nothing in reach to carry a chain on with: it's over.
func chain_over() -> void:
	chain_left = 0
	in_chain = false


func phase_up(ph: int) -> void:
	poise = Poise.make("beast_boss", pow(1.25, ph - 1))
	chain_over()


func vulnerable() -> bool:
	return Engine.get_physics_frames() < _vuln_until


## Its poise broke: double damage from now for VULN_S.
func broke() -> void:
	_vuln_until = Engine.get_physics_frames() + int(VULN_S * Engine.physics_ticks_per_second)
	chain_over()


func reset() -> void:
	poise = Poise.make("beast_boss")
	parts.restore()
	_vuln_until = -1
	chain_over()
