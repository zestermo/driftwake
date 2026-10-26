class_name BeastParts
extends RefCounted
## A beast boss's breakable parts (1.23 beast pass): tusks, fists, plates, mandibles, claws, hide. Each is somewhere on
## the body (one node or several: both fists), takes the blows that land near it (where a blow lands is guessed from
## the attacker: its reach toward the beast) and breaks after `hp` of them; a broken part takes a move away or weakens
## it, drops its material and changes the look. A part can be in reach only at times (`opens`: fists down in the
## ground). Host-run; the broken ones ride the snapshot as a bit mask (mask / set_mask).

## name -> [hp left, nodes, reach (m), item id, colour, bit, hp whole]
var parts := {}
## name -> Callable() -> bool: in reach right now (parts not listed always are).
var opens := {}


func add(n: String, hp: float, nodes: Array, reach: float, item: String, col: Color) -> void:
	parts[n] = [hp, nodes, reach, item, col, 1 << parts.size(), hp]


## Whole again (the fight reset).
func restore() -> void:
	for n in parts.keys():
		parts[n][0] = parts[n][6]


func broken(n: String) -> bool:
	return parts.has(n) and float(parts[n][0]) <= 0.0


func count_broken() -> int:
	var c := 0
	for n in parts.keys():
		if broken(n):
			c += 1
	return c


func item(n: String) -> String:
	return parts[n][3]


func color(n: String) -> Color:
	return parts[n][4]


## Where part `n` is (its nearest node to `from`, or its first).
func where(n: String, from: Vector3 = Vector3.INF) -> Vector3:
	var best := Vector3.INF
	for node in parts[n][1]:
		var p := (node as Node3D).global_position
		if best == Vector3.INF or (from != Vector3.INF and p.distance_to(from) < best.distance_to(from)):
			best = p
	return best


## Where a blow from `attacker` lands on a body standing at `body`: its reach toward the body, at its chest's height.
static func blow_at(attacker: Node3D, body: Vector3) -> Vector3:
	var to := body - attacker.global_position
	to.y = 0.0
	return attacker.global_position + Vector3.UP * 1.1 + to.normalized() * minf(to.length(), 1.6)


## The unbroken part in reach nearest `at`, else "".
func near(at: Vector3) -> String:
	var best := ""
	var bd := INF
	for n in parts.keys():
		if broken(n) or (opens.has(n) and not bool((opens[n] as Callable).call())):
			continue
		var d := where(n, at).distance_to(at)
		if d < float(parts[n][2]) and d < bd:
			bd = d
			best = n
	return best


## `dmg` lands on part `n`: true the moment it breaks.
func hurt(n: String, dmg: float) -> bool:
	if n == "" or broken(n):
		return false
	parts[n][0] = float(parts[n][0]) - dmg
	return broken(n)


func mask() -> int:
	var m := 0
	for n in parts.keys():
		if broken(n):
			m |= int(parts[n][5])
	return m


## A puppet: the host's mask. Returns the parts that broke since the last one (or were mended: a reset).
func set_mask(m: int) -> Array:
	var now: Array = []
	for n in parts.keys():
		var b := (m & int(parts[n][5])) != 0
		if b != broken(n):
			parts[n][0] = 0.0 if b else parts[n][6]
			now.append(n)
	return now
