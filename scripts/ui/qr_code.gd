extends RefCounted
## A small QR code encoder: byte mode, error correction M, versions 1-4 (up to 62 bytes).
## encode() gives a Grid (modules: size*size, row-major, 1 = dark); image() draws it.

## [total codewords, EC codewords per block, blocks] for versions 1-4 at level M.
const VERSIONS := [[26, 10, 1], [44, 16, 1], [70, 26, 1], [100, 18, 2]]


class Grid:
	var version := 0
	var size := 0
	var mask := 0
	var modules := PackedByteArray()
	var fn := PackedByteArray()


static func encode(text: String, mask: int = -1) -> Grid:
	var bytes := text.to_utf8_buffer()
	var version := 0
	for v in range(1, VERSIONS.size() + 1):
		if bytes.size() <= _data_codewords(v) - 2:
			version = v
			break
	assert(version > 0, "QR: %d bytes is too long for version 4-M" % bytes.size())
	var size := version * 4 + 17
	var qr := Grid.new()
	qr.version = version
	qr.size = size
	qr.modules.resize(size * size)
	qr.fn.resize(size * size)
	_draw_function_patterns(qr)
	_draw_codewords(qr, _add_ec(_data_bits(bytes, version), version))
	if mask < 0:
		var best := -1
		for m in 8:
			_apply_mask(qr, m)
			_draw_format(qr, m)
			var pen := penalty(qr)
			if best < 0 or pen < best:
				best = pen
				mask = m
			_apply_mask(qr, m)
	_apply_mask(qr, mask)
	_draw_format(qr, mask)
	qr.mask = mask
	return qr


## Black on white, `quiet` light modules of border all round, one pixel per module.
static func image(qr: Grid, quiet: int = 4) -> Image:
	var n: int = qr.size
	var img := Image.create(n + quiet * 2, n + quiet * 2, false, Image.FORMAT_L8)
	img.fill(Color.WHITE)
	for y in n:
		for x in n:
			if qr.modules[y * n + x]:
				img.set_pixel(x + quiet, y + quiet, Color.BLACK)
	return img


static func _data_codewords(version: int) -> int:
	var t: Array = VERSIONS[version - 1]
	return t[0] - t[1] * t[2]


static func _data_bits(bytes: PackedByteArray, version: int) -> PackedByteArray:
	var bits: Array[int] = []
	var push := func(val: int, n: int):
		for i in range(n - 1, -1, -1):
			bits.append((val >> i) & 1)
	push.call(0b0100, 4)
	push.call(bytes.size(), 8)
	for b in bytes:
		push.call(b, 8)
	var cap := _data_codewords(version) * 8
	push.call(0, mini(4, cap - bits.size()))
	push.call(0, (8 - bits.size() % 8) % 8)
	var out := PackedByteArray()
	for i in range(0, bits.size(), 8):
		var b := 0
		for j in 8:
			b = (b << 1) | bits[i + j]
		out.append(b)
	var pad := 0
	while out.size() < _data_codewords(version):
		out.append(0xEC if pad % 2 == 0 else 0x11)
		pad += 1
	return out


## Split into blocks, add each block's Reed-Solomon codewords, interleave.
static func _add_ec(data: PackedByteArray, version: int) -> PackedByteArray:
	var t: Array = VERSIONS[version - 1]
	var ec_len: int = t[1]
	var blocks: int = t[2]
	var per := data.size() / blocks
	var div := rs_divisor(ec_len)
	var dat: Array[PackedByteArray] = []
	var ecs: Array[PackedByteArray] = []
	for b in blocks:
		var d := data.slice(b * per, (b + 1) * per)
		dat.append(d)
		ecs.append(rs_remainder(d, div))
	var out := PackedByteArray()
	for i in per:
		for b in blocks:
			out.append(dat[b][i])
	for i in ec_len:
		for b in blocks:
			out.append(ecs[b][i])
	return out


static func _gf_mul(x: int, y: int) -> int:
	var z := 0
	for i in range(7, -1, -1):
		z = (z << 1) ^ ((z >> 7) * 0x11D)
		z ^= ((y >> i) & 1) * x
	return z


static func rs_divisor(degree: int) -> PackedByteArray:
	var r := PackedByteArray()
	r.resize(degree)
	r[degree - 1] = 1
	var root := 1
	for i in degree:
		for j in degree:
			r[j] = _gf_mul(r[j], root)
			if j + 1 < degree:
				r[j] ^= r[j + 1]
		root = _gf_mul(root, 2)
	return r


static func rs_remainder(data: PackedByteArray, divisor: PackedByteArray) -> PackedByteArray:
	var r := PackedByteArray()
	r.resize(divisor.size())
	for b in data:
		var factor := b ^ r[0]
		r.remove_at(0)
		r.append(0)
		for i in divisor.size():
			r[i] ^= _gf_mul(divisor[i], factor)
	return r


static func _set_fn(qr: Grid, x: int, y: int, dark: bool) -> void:
	var i: int = y * qr.size + x
	qr.modules[i] = 1 if dark else 0
	qr.fn[i] = 1


static func _draw_function_patterns(qr: Grid) -> void:
	var n: int = qr.size
	for i in n:
		_set_fn(qr, 6, i, i % 2 == 0)
		_set_fn(qr, i, 6, i % 2 == 0)
	for c in [Vector2i(3, 3), Vector2i(n - 4, 3), Vector2i(3, n - 4)]:
		for dy in range(-4, 5):
			for dx in range(-4, 5):
				var x: int = c.x + dx
				var y: int = c.y + dy
				if x >= 0 and x < n and y >= 0 and y < n:
					var dist := maxi(absi(dx), absi(dy))
					_set_fn(qr, x, y, dist != 2 and dist != 4)
	if qr.version >= 2:
		var a := n - 7
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				_set_fn(qr, a + dx, a + dy, maxi(absi(dx), absi(dy)) != 1)
	_draw_format(qr, 0)


## The 15 format bits (level M, the mask, BCH, XOR 0x5412) twice, and the dark module.
static func _draw_format(qr: Grid, mask: int) -> void:
	var n: int = qr.size
	var bits := format_bits(mask)
	var bit := func(i: int) -> bool: return (bits >> i) & 1 == 1
	for i in range(0, 6):
		_set_fn(qr, 8, i, bit.call(i))
	_set_fn(qr, 8, 7, bit.call(6))
	_set_fn(qr, 8, 8, bit.call(7))
	_set_fn(qr, 7, 8, bit.call(8))
	for i in range(9, 15):
		_set_fn(qr, 14 - i, 8, bit.call(i))
	for i in range(0, 8):
		_set_fn(qr, n - 1 - i, 8, bit.call(i))
	for i in range(8, 15):
		_set_fn(qr, 8, n - 15 + i, bit.call(i))
	_set_fn(qr, 8, n - 8, true)


static func format_bits(mask: int) -> int:
	var data := mask   # (level M's two bits are 00)
	var rem := data
	for i in 10:
		rem = (rem << 1) ^ ((rem >> 9) * 0x537)
	return ((data << 10) | (rem & 0x3FF)) ^ 0x5412


## Up and down two-column strips from the right, skipping the timing column.
static func _draw_codewords(qr: Grid, data: PackedByteArray) -> void:
	var n: int = qr.size
	var i := 0
	var right := n - 1
	while right >= 1:
		if right == 6:
			right = 5
		for vert in n:
			for j in 2:
				var x := right - j
				var y := n - 1 - vert if ((right + 1) & 2) == 0 else vert
				if not qr.fn[y * n + x] and i < data.size() * 8:
					qr.modules[y * n + x] = (data[i >> 3] >> (7 - (i & 7))) & 1
					i += 1
		right -= 2


static func _mask_hit(m: int, x: int, y: int) -> bool:
	match m:
		0: return (x + y) % 2 == 0
		1: return y % 2 == 0
		2: return x % 3 == 0
		3: return (x + y) % 3 == 0
		4: return (x / 3 + y / 2) % 2 == 0
		5: return x * y % 2 + x * y % 3 == 0
		6: return (x * y % 2 + x * y % 3) % 2 == 0
		_: return ((x + y) % 2 + x * y % 3) % 2 == 0


## XOR the mask over the data modules (applying it twice undoes it).
static func _apply_mask(qr: Grid, m: int) -> void:
	var n: int = qr.size
	for y in n:
		for x in n:
			var i := y * n + x
			if not qr.fn[i] and _mask_hit(m, x, y):
				qr.modules[i] ^= 1


## The spec's four penalty rules (runs, 2x2 blocks, finder look-alikes, dark balance), scored as segno does.
static func penalty(qr: Grid) -> int:
	var n: int = qr.size
	var mods: PackedByteArray = qr.modules
	var pen := 0
	for horiz in [true, false]:
		for y in n:
			var line := PackedByteArray()
			for x in n:
				line.append(mods[y * n + x] if horiz else mods[x * n + y])
			var run := 1
			for x in range(1, n + 1):
				if x < n and line[x] == line[x - 1]:
					run += 1
					continue
				if run >= 5:
					pen += 3 + run - 5
				run = 1
			pen += _finder_hits(line)
	var dark := 0
	for y in n:
		for x in n:
			dark += mods[y * n + x]
			if x < n - 1 and y < n - 1:
				var c := mods[y * n + x]
				if c == mods[y * n + x + 1] and c == mods[(y + 1) * n + x] and c == mods[(y + 1) * n + x + 1]:
					pen += 3
	pen += 10 * int(absf(100.0 * dark / (n * n) - 50.0) / 5.0)
	return pen


## Rule 3: dark-light-dark-dark-dark-light-dark with 4 light modules before or after it (past the edge is the
## light quiet zone).
static func _finder_hits(line: PackedByteArray) -> int:
	const PAT := [1, 0, 1, 1, 1, 0, 1]
	var n := line.size()
	var hits := 0
	var i := 0
	while i <= n - 7:
		var found := true
		for k in 7:
			if line[i + k] != PAT[k]:
				found = false
				break
		if not found:
			i += 1
			continue
		var before := true
		for k in range(maxi(i - 4, 0), i):
			before = before and line[k] == 0
		var after := true
		for k in range(i + 7, mini(i + 11, n)):
			after = after and line[k] == 0
		if before or after:
			hits += 40
			i += 7
		else:
			i += 4
	return hits
