class_name ShoreMap
extends RefCounted
## Where the sea meets an island, for the swell (OceanManager and ocean.gdshader
## read the same texels): baked once from the island's height grid, a texel per
## grid vertex, RGBA half floats:
##   r: depth below the mean sea (m; negative on land)
##   g: the shore swell's phase distance (m offshore, shortened over the shallows)
##   b: how far the swell has turned to the shore (0 at sea .. 1 on the coast)
##   a: the shore swell's height for how exposed the coast is to the swell
## Pure numbers: safe on a worker thread; the texture is made on first use.

const DEEP := 40.0
const LAND := -8.0
## q is kept in [INLAND, FAR] (half floats stay fine there).
const FAR := 64.0
const INLAND := -16.0
## The swell turns to the shore inside BAND.x m of it, none past BAND.y.
const BAND := Vector2(14.0, 56.0)
## Waves shorten over the last SHOAL_RUN m (their wavelength / (1 + SHOAL_K) at the waterline).
const SHOAL_RUN := 30.0
const SHOAL_K := 0.6
## The distance field is smoothed over about this many metres (no kinks in the crests).
const SMOOTH := 9.0
## b fades out over the map's last EDGE m (the open sea round it, no seam).
const EDGE := 24.0
## Open water upwind (m) for a full swell; a lee shore keeps LEE of it.
const FETCH := Vector2(30.0, 260.0)
const LEE := 0.45
## The depth is kept this much shallower than the ground everywhere (a little room on top of _lifted).
const LIFT := 0.03
## Off every map: deep, far from any shore, the open swell.
const NONE := Vector4(1000.0, FAR, 0.0, 1.0)

var n: int
var cell: float
## World (x0, z0, size, 1): texel centres at x0 + (i + 0.5) * cell.
var rect := Vector4.ZERO
var data := PackedFloat32Array()
var image: Image
var _origin := Vector2.ZERO
var _tex: ImageTexture


## From a square height grid (n x n vertices `cell` apart, the first at `origin` in the island's
## space); `swell` is the direction the open swell travels (OceanManager.swell_dir()).
static func bake(heights: PackedFloat32Array, size: int, spacing: float, origin: Vector2, swell: Vector2) -> ShoreMap:
	var m := ShoreMap.new()
	m.n = size
	m.cell = spacing
	m._origin = origin
	m._bake(heights, swell)
	m.place(Vector2.ZERO)
	return m


## Another of the same map (its texels shared) to put somewhere else.
func clone() -> ShoreMap:
	var m := ShoreMap.new()
	m.n = n
	m.cell = cell
	m.data = data
	m.image = image
	m._origin = _origin
	m._tex = texture()
	return m


## Puts the map at the island's world position.
func place(at: Vector2) -> void:
	rect = Vector4(at.x + _origin.x - cell * 0.5, at.y + _origin.y - cell * 0.5, n * cell, 1.0)


func texture() -> ImageTexture:
	if _tex == null:
		_tex = ImageTexture.create_from_image(image)
	return _tex


## The texel data at world (x, z), filtered like the GPU's (bilinear, clamped); NONE off the map.
func sample(x: float, z: float) -> Vector4:
	var u := (x - rect.x) / rect.z
	var v := (z - rect.y) / rect.z
	if u <= 0.0 or v <= 0.0 or u >= 1.0 or v >= 1.0:
		return NONE
	var fx := u * n - 0.5
	var fz := v * n - 0.5
	var ix := floori(fx)
	var iz := floori(fz)
	var tx := fx - ix
	var tz := fz - iz
	var x0 := clampi(ix, 0, n - 1) * 4
	var x1 := clampi(ix + 1, 0, n - 1) * 4
	var r0 := clampi(iz, 0, n - 1) * n * 4
	var r1 := clampi(iz + 1, 0, n - 1) * n * 4
	var out := Vector4()
	for c in range(4):
		var a := lerpf(data[r0 + x0 + c], data[r0 + x1 + c], tx)
		var b := lerpf(data[r1 + x0 + c], data[r1 + x1 + c], tx)
		out[c] = lerpf(a, b, tz)
	return out


func _bake(heights: PackedFloat32Array, swell: Vector2) -> void:
	var nn := n * n
	var land_f := PackedFloat32Array()
	var sea_f := PackedFloat32Array()
	land_f.resize(nn)
	sea_f.resize(nn)
	# (float32 keeps whole numbers exact under 2^24: the distances stay exact under this)
	var big := 1e7
	for i in range(nn):
		var dry := heights[i] >= 0.0
		land_f[i] = 0.0 if dry else big
		sea_f[i] = big if dry else 0.0
	var to_land := _edt(land_f)
	var to_sea := _edt(sea_f)
	# signed distance to the waterline (half a texel in from the last wet or dry one)
	var s := PackedFloat32Array()
	s.resize(nn)
	for i in range(nn):
		if heights[i] >= 0.0:
			s[i] = maxf(-(sqrt(to_sea[i]) - 0.5) * cell, INLAND - SMOOTH)
		else:
			s[i] = minf((sqrt(to_land[i]) - 0.5) * cell, FAR + SMOOTH)
	var r := maxi(1, roundi(SMOOTH / cell * 0.5))
	s = _blur(_blur(s, r), r)
	var fetch := _fetch(heights, swell)
	fetch = _blur(fetch, r)
	var top := _lifted(heights)
	var out := PackedFloat32Array()
	out.resize(nn * 4)
	for z in range(n):
		for x in range(n):
			var i := z * n + x
			var sd := s[i]
			var gx := (s[z * n + mini(x + 1, n - 1)] - s[z * n + maxi(x - 1, 0)]) / (cell * float(mini(x + 1, n - 1) - maxi(x - 1, 0)))
			var gz := (s[mini(z + 1, n - 1) * n + x] - s[maxi(z - 1, 0) * n + x]) / (cell * float(mini(z + 1, n - 1) - maxi(z - 1, 0)))
			var q := sd
			if sd < SHOAL_RUN:
				q = sd - SHOAL_K * (SHOAL_RUN - sd) * (SHOAL_RUN - sd) / (2.0 * SHOAL_RUN)
			var edge := minf(minf(x, z), minf(n - 1 - x, n - 1 - z)) * cell
			var w := (1.0 - smoothstep(BAND.x, BAND.y, sd)) * smoothstep(0.35, 0.7, Vector2(gx, gz).length()) * smoothstep(0.0, EDGE, edge)
			out[i * 4] = clampf(-top[i], LAND, DEEP)
			out[i * 4 + 1] = clampf(q, INLAND, FAR)
			out[i * 4 + 2] = w
			out[i * 4 + 3] = lerpf(LEE, 1.0, smoothstep(FETCH.x, FETCH.y, fetch[i]))
	var full := Image.create_from_data(n, n, false, Image.FORMAT_RGBAF, out.to_byte_array())
	full.convert(Image.FORMAT_RGBAH)
	image = full
	# (the CPU reads exactly the half floats the GPU does)
	var back := full.duplicate() as Image
	back.convert(Image.FORMAT_RGBAF)
	data = back.get_data().to_float32_array()


## Squared euclidean distance (in texels) to the nearest texel where f is 0 (Felzenszwalb & Huttenlocher).
func _edt(f: PackedFloat32Array) -> PackedFloat32Array:
	var g := PackedFloat32Array()
	g.resize(n * n)
	var line := PackedFloat32Array()
	line.resize(n)
	var d := PackedFloat32Array()
	d.resize(n)
	var v := PackedInt32Array()
	v.resize(n)
	var zz := PackedFloat32Array()
	zz.resize(n + 1)
	for z in range(n):
		for x in range(n):
			line[x] = f[z * n + x]
		_edt1(line, d, v, zz)
		for x in range(n):
			g[z * n + x] = d[x]
	for x in range(n):
		for z in range(n):
			line[z] = g[z * n + x]
		_edt1(line, d, v, zz)
		for z in range(n):
			g[z * n + x] = d[z]
	return g


func _edt1(f: PackedFloat32Array, d: PackedFloat32Array, v: PackedInt32Array, zz: PackedFloat32Array) -> void:
	var k := 0
	v[0] = 0
	zz[0] = -INF
	zz[1] = INF
	for q in range(1, n):
		var fq := f[q] + q * q
		var s := (fq - (f[v[k]] + v[k] * v[k])) / float(2 * q - 2 * v[k])
		while s <= zz[k]:
			k -= 1
			s = (fq - (f[v[k]] + v[k] * v[k])) / float(2 * q - 2 * v[k])
		k += 1
		v[k] = q
		zz[k] = s
		zz[k + 1] = INF
	k = 0
	for q in range(n):
		while zz[k + 1] < q:
			k += 1
		d[q] = (q - v[k]) * (q - v[k]) + f[v[k]]


## The heights raised just enough that filtered (bilinear) they're never under the terrain's
## triangles anywhere in a cell: the two differ by at most a quarter of the cell's twist
## |h00 - h10 - h01 + h11|, so each vertex is raised by the most of its cells'. (Steep edges only;
## a smooth beach hardly moves.)
func _lifted(heights: PackedFloat32Array) -> PackedFloat32Array:
	var twist := PackedFloat32Array()
	twist.resize(n * n)
	for z in range(n - 1):
		for x in range(n - 1):
			var i := z * n + x
			twist[i] = absf(heights[i] - heights[i + 1] - heights[i + n] + heights[i + n + 1]) * 0.25
	var out := heights.duplicate()
	for z in range(n):
		for x in range(n):
			var m := 0.0
			for cz in range(maxi(z - 1, 0), mini(z + 1, n - 1)):
				for cx in range(maxi(x - 1, 0), mini(x + 1, n - 1)):
					m = maxf(m, twist[cz * n + cx])
			out[z * n + x] += m + LIFT
	return out


## A box blur of radius r texels, rows then columns (edges clamped).
func _blur(src: PackedFloat32Array, r: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(n * n)
	var out := PackedFloat32Array()
	out.resize(n * n)
	var k := 1.0 / float(2 * r + 1)
	for z in range(n):
		var row := z * n
		var acc := 0.0
		for i in range(-r, r + 1):
			acc += src[row + clampi(i, 0, n - 1)]
		for x in range(n):
			tmp[row + x] = acc * k
			acc += src[row + mini(x + r + 1, n - 1)] - src[row + maxi(x - r, 0)]
	for x in range(n):
		var acc := 0.0
		for i in range(-r, r + 1):
			acc += tmp[clampi(i, 0, n - 1) * n + x]
		for z in range(n):
			out[z * n + x] = acc * k
			acc += tmp[mini(z + r + 1, n - 1) * n + x] - tmp[maxi(z - r, 0) * n + x]
	return out


## Open water upwind of each texel (m, up the swell's direction): a sweep with the swell, reset on land.
func _fetch(heights: PackedFloat32Array, swell: Vector2) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n * n)
	var sx := 1 if swell.x >= 0.0 else -1
	var sz := 1 if swell.y >= 0.0 else -1
	var ax := absf(swell.x)
	var az := absf(swell.y)
	# (a step back up the swell, a whole texel along its longer axis, lands between a straight and a diagonal neighbour)
	var r := minf(ax, az) / maxf(ax, az)
	var wx := 1.0 - r if ax >= az else 0.0
	var wz := 0.0 if ax >= az else 1.0 - r
	var wd := r
	var step := cell * sqrt(1.0 + r * r)
	var open := FETCH.y * 2.0
	for zi in range(n):
		var z := zi if sz > 0 else n - 1 - zi
		for xi in range(n):
			var x := xi if sx > 0 else n - 1 - xi
			var i := z * n + x
			if heights[i] >= 0.0:
				out[i] = 0.0
				continue
			var bx := x - sx
			var bz := z - sz
			var fx := out[z * n + bx] if bx >= 0 and bx < n else open
			var fz := out[bz * n + x] if bz >= 0 and bz < n else open
			var fd := out[bz * n + bx] if bx >= 0 and bx < n and bz >= 0 and bz < n else open
			out[i] = minf(fx * wx + fz * wz + fd * wd + step, open)
	return out
