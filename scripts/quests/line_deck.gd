class_name LineDeck
extends RefCounted
## An island's lines, dealt so no two people on it say the same thing: each pool is shuffled from the
## island's seed and dealt from the top, and a line dealt once (from any pool) is never dealt again. A
## pool that runs dry deals nothing more (that person just has fewer lines). The same seed and the same
## order of deals give the same lines on every machine.

var _seed: int
var _decks := {}
var _used := {}


func _init(seed_value: int) -> void:
	_seed = seed_value


## Up to `n` lines from `pool` (its deck named `key`) nobody on the island has yet.
func deal(key: String, pool: Array, n: int) -> Array:
	if not _decks.has(key):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([_seed, key])
		var d := pool.duplicate()
		for i in range(d.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t = d[i]
			d[i] = d[j]
			d[j] = t
		_decks[key] = d
	var d: Array = _decks[key]
	var out: Array = []
	while out.size() < n and not d.is_empty():
		var line := str(d.pop_front())
		if not _used.has(line):
			_used[line] = true
			out.append(line)
	return out


## One line ("" once the pool's dry).
func one(key: String, pool: Array) -> String:
	var l := deal(key, pool, 1)
	return l[0] if not l.is_empty() else ""


func used(line: String) -> bool:
	return _used.has(line)
