class_name CapitalDistrict
extends RefCounted
## The royal capital's core district (docs/capital_plan.md, piece 2), built over CapitalShell: every house that fronts
## a walkable floor (and the ground kept round the plaza) as a town house with its shopfront, door and steps; the
## inn, the curio dealer's, the guild hall and the shut counting house on the plaza; the fountain, the market stalls,
## benches, trees and lamps; the market street's awnings, barrows and bunting; the quay's cargo, cranes, fish market
## and boats; the avenue's statues; the arena street's posters and booth; the slum alley's laundry and the yard's
## shacks and fire. All in CapitalPlan's frame, merged a mesh an area (fold_tints), built on the worker; colliders as
## data; the real lights and the places the people stand (piece 3) as lists.

const P := preload("res://scripts/island/capital_plan.gd")
const M := preload("res://scripts/island/capital_models.gd")
const RANGE := 320.0
const FAR := 900.0
const SHOP_KINDS := ["baker", "cloth", "spice", "potter", "jeweller", "chart", "fruit", "wine", "tailor", "books"]
const AWNINGS := ["awning_blue", "awning_red", "awning_gold", "awning_green"]
## Door paints (a door leaf keeps its picture exact, so each paint is a surface of its own: a few only).
const DOORS := [Color(0.42, 0.3, 0.22), Color(0.2, 0.3, 0.46), Color(0.22, 0.36, 0.3), Color(0.5, 0.2, 0.16)]
## Out: {"pieces": [...as CapitalShell's], "lights": [[frame Vector3, energy, range, always]], "spots": {name: [frame Vector3, yaw]}}


static func build(build_ms: Dictionary) -> Dictionary:
	var out := {"pieces": [], "lights": [], "spots": {}, "doors": [], "cells": P.lots().map(func(l): return l["cell"])}
	for step in [["houses", _houses], ["specials", _specials], ["plaza", _plaza], ["street", _street], ["quay", _quay],
			["avenue", _avenue], ["slum", _slum], ["docks", _docks], ["terrace", _terrace], ["palace", _throne]]:
		var t0 := Time.get_ticks_usec()
		(step[1] as Callable).call(out)
		build_ms["district " + str(step[0])] = int((Time.get_ticks_usec() - t0) / 1000)
	return out


static func _piece(out: Dictionary, piece_name: String, mb: MeshBuilder, cols: Array, range_end := RANGE, shadow := true) -> void:
	mb.fold_tints()
	var split := Occluders.take(cols)
	(out["pieces"] as Array).append({"name": piece_name, "mesh": mb.commit(), "range": range_end, "shadow": shadow, "cols": split[0], "faces": [], "occ": split[1]})


static func _light(out: Dictionary, at: Vector3, energy := 1.6, rng_ := 11.0, always := false) -> void:
	(out["lights"] as Array).append([at, energy, rng_, always])


static func _spot(out: Dictionary, spot_name: String, q: Vector2, y: float, face: Vector2) -> void:
	out["spots"][spot_name] = [M.v3(q, y), M.yaw_of(face)]


static func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


## A node an existing builder made (Buildings.stall, Props...), folded into `mb` at frame transform `t`: its meshes
## merged, its colliders kept as shapes; the node itself freed.
static func absorb(mb: MeshBuilder, cols: Array, node: Node3D, t: Transform3D) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var sub := MeshBuilder.from_mesh((mi as MeshInstance3D).mesh)
		sub.rebind(t * _rel(mi, node), 0)
		mb.merge(sub)
	for cs in node.find_children("*", "CollisionShape3D", true, false):
		cols.append({"shape": (cs as CollisionShape3D).shape, "xf": t * _rel(cs, node)})
	node.free()


static func _rel(n: Node, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c := n
	while c != root:
		t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


# --------------------------------------------------------------------------
# Town houses
# --------------------------------------------------------------------------
## The houses piece 1 left as massing for the district: the lots that front a floor or stand on kept ground, but
## not under a special building.
static func lots() -> Array:
	return P.lots().filter(func(l): return (l["front"] or l["keep"]) and not P.special_hit(l["cell"]))


static func _houses(out: Dictionary) -> void:
	var by_floor := {}
	for l in lots():
		var key := _area(l)
		if not by_floor.has(key):
			by_floor[key] = []
		by_floor[key].append(l)
	var keys := by_floor.keys()
	keys.sort()
	for key in keys:
		var mb := MeshBuilder.new()
		var cols: Array = []
		var i := 0
		for l in by_floor[key]:
			var kind := ""
			if key in ["street", "plaza", "arena_st", "avenue"] and l["front"]:
				kind = SHOP_KINDS[(int(l["seed"]) >> 3) % SHOP_KINDS.size()] if i % 3 != 2 else ""
			var d := warehouse(mb, cols, l) if key == "docks" else townhouse(mb, cols, l, kind, key == "slum")
			var at: Vector3 = d["at"]
			if l["front"] and P.in_floor(Vector2(at.x, at.z)):
				(out["doors"] as Array).append(d)
			i += 1
		_piece(out, "Town_" + str(key), mb, cols)


## Which part of the district a lot belongs to (its mesh), by the floor it fronts or the nearest one.
static func _area(l: Dictionary) -> String:
	var c: Vector2 = l["c"]
	var best := ""
	var bd := INF
	for f in P.FLOORS:
		var r: Rect2 = f[1]
		var d := Vector2(maxf(maxf(r.position.x - c.x, c.x - r.end.x), 0.0), maxf(maxf(r.position.y - c.y, c.y - r.end.y), 0.0)).length()
		if d < bd:
			bd = d
			best = str(f[0])
	if best in ["alley", "yard", "postern"]:
		return "slum"
	if best in ["wharf", "e_postern"]:
		return "docks"
	if best == "terrace_step":
		return "terrace"
	if best == "gate":
		return "street"
	return best


## The frame transform of a lot's house: its middle on the ground plane, local +z toward its street; and its frontage
## width and depth.
static func lot_frame(l: Dictionary) -> Array:
	var r: Rect2 = l["r"]
	var face: Vector2 = l["face"]
	var w := r.size.x if absf(face.y) > 0.5 else r.size.y
	var d := r.size.y if absf(face.y) > 0.5 else r.size.x
	return [M.xf(M.v3(r.get_center(), 0.0), M.yaw_of(face)), w, d]


static func _ground_span(r: Rect2) -> Vector2:
	var low := INF
	var top := -INF
	for p in [r.position, r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y), r.get_center()]:
		low = minf(low, minf(P.terrain(p), P.ground(p) - P.FLOOR_DROP))
		top = maxf(top, P.ground(p))
	return Vector2(low, top)


## A town house: a stone plinth, the ground floor taller with its front a shopfront (a shop window under an awning
## and a hanging sign, or a second window) and a recessed door up two steps, a string course, facade storeys over
## it (a balcony on some), a cornice and its roof. `shabby`: the slum's (stained, no awning, a shutter hanging).
## Returns its door: {"at": frame Vector3 on the step's foot, "face", "kind"}.
static func townhouse(mb: MeshBuilder, cols: Array, l: Dictionary, kind: String, shabby := false) -> Dictionary:
	var fr := lot_frame(l)
	var t: Transform3D = fr[0]
	var w: float = fr[1]
	var d: float = fr[2]
	var gs := _ground_span(l["r"])
	var low := gs.x - 0.5
	var top := gs.y
	var rng := _rng(int(l["seed"]))
	var col: Color = M.WALLS[rng.randi() % M.WALLS.size()]
	if shabby:
		col = col * Color(0.82, 0.78, 0.72)
	var rcol: Color = M.ROOFS[rng.randi() % M.ROOFS.size()]
	var fac := M.mat("facade_b") if rng.randf() < 0.4 else M.mat("facade_a")
	var lime := M.mat("lime")
	var wash := M.mat("wash")
	var g1 := 3.8
	var sill := top + 0.32
	var floors: int = maxi(int(l["floors"]), 2)
	var eaves := sill + g1 + float(floors - 1) * M.STOREY
	mb.add_box(lime, t * Transform3D(Basis(), Vector3(0, (low + sill) * 0.5, 0)), Vector3(w + 0.1, sill - low, d + 0.1), 0.5, Color(0.9, 0.88, 0.84), true, true)
	M.facade_box(mb, fac, t, w, d, sill + g1, eaves - sill - g1, col)
	# the ground floor's back and sides, and the string course over it
	var hw := w * 0.5
	var hd := d * 0.5
	for s in [-1.0, 1.0]:
		M.facade_quad(mb, fac, t * Vector3(s * hw, sill, -s * hd), t * Vector3(s * hw, sill, s * hd), g1, (t.basis * Vector3(s, 0, 0)).normalized(), col * 0.96, g1)
	M.facade_quad(mb, fac, t * Vector3(hw, sill, -hd), t * Vector3(-hw, sill, -hd), g1, (t.basis * Vector3.FORWARD).normalized(), col * 0.96, g1)
	mb.add_box(lime, t * Transform3D(Basis(), Vector3(0, sill + g1, 0)), Vector3(w + 0.16, 0.22, d + 0.16), 0.6, Color(0.9, 0.88, 0.84), false)
	mb.add_box(lime, t * Transform3D(Basis(), Vector3(0, eaves + 0.12, 0)), Vector3(w + 0.3, 0.24, d + 0.3), 0.6, Color(0.95, 0.93, 0.9), false)
	M.roof(mb, str(l["roof"]), t, w, d, eaves + 0.24, rcol, rng)
	var cell: Rect2 = l["cell"]
	M.box(cols, M.xf(M.v3(cell.get_center(), (low + eaves) * 0.5)), Vector3(cell.size.x, eaves - low, cell.size.y))
	# (behind the door's niche)
	Occluders.box(cols, t * Transform3D(Basis(), Vector3(0, (low + eaves) * 0.5, -0.4)), Vector3(w, eaves - low, d - 0.8))
	# the front: a recessed door, a shop window or a window, pilasters at the corners
	var door_x := clampf(rng.randf_range(-hw * 0.4, hw * 0.4), -hw + 1.4, hw - 1.4)
	var dw := 1.3
	var nd := 0.7
	var z := hd
	var segs := [[-hw, door_x - dw * 0.5 - 0.25], [door_x + dw * 0.5 + 0.25, hw]]
	for sg in segs:
		var a: float = sg[0]
		var b: float = sg[1]
		if b - a < 0.05:
			continue
		mb.add_quad(wash, t * Vector3(a, sill, z), t * Vector3(b, sill, z), t * Vector3(b, sill + g1, z), t * Vector3(a, sill + g1, z),
			Vector2(a * 0.5, g1 * 0.5), Vector2(b * 0.5, g1 * 0.5), Vector2(b * 0.5, 0), Vector2(a * 0.5, 0), col, (t.basis * Vector3.BACK).normalized())
	var top_d := 2.7
	mb.add_quad(wash, t * Vector3(door_x - dw * 0.5 - 0.25, sill + top_d + 0.3, z), t * Vector3(door_x + dw * 0.5 + 0.25, sill + top_d + 0.3, z), t * Vector3(door_x + dw * 0.5 + 0.25, sill + g1, z),
		t * Vector3(door_x - dw * 0.5 - 0.25, sill + g1, z), Vector2.ZERO, Vector2(1, 0), Vector2(1, 0.5), Vector2(0, 0.5), col, (t.basis * Vector3.BACK).normalized())
	# the niche: jambs, a soffit, the door at its back, the steps up to it
	var nt := t * Transform3D(Basis(), Vector3(door_x, 0, z))
	for s in [-1.0, 1.0]:
		mb.add_box(lime, nt * Transform3D(Basis(), Vector3(s * (dw * 0.5 + 0.125), sill + (top_d + 0.3) * 0.5, -nd * 0.5 + 0.02)), Vector3(0.25, top_d + 0.3, nd + 0.04), 0.6, Color(0.92, 0.9, 0.86))
	mb.add_box(lime, nt * Transform3D(Basis(), Vector3(0, sill + top_d + 0.15, -nd * 0.5 + 0.02)), Vector3(dw + 0.5, 0.3, nd + 0.04), 0.6, Color(0.86, 0.84, 0.8), false)
	mb.add_box(lime, nt * Transform3D(Basis(), Vector3(0, sill + top_d + 0.42, 0.06)), Vector3(dw + 0.8, 0.22, 0.14), 0.6, Color(0.95, 0.93, 0.9), false)
	var paint: Color = DOORS[(int(l["seed"]) >> 5) % DOORS.size()] if not shabby else DOORS[0]
	Buildings.panel_door(mb, nt * Transform3D(Basis(), Vector3(0, sill, -nd)), dw - 0.1, top_d - 0.1, Buildings.door_leaf(paint), lime, M.mat("window"))
	for k in range(2):
		var sy := top + (sill - top) * (k + 1) / 3.0
		mb.add_box(lime, nt * Transform3D(Basis(), Vector3(0, (sy + low) * 0.5, -nd + 0.15 + (1 - k) * 0.28)), Vector3(dw, sy - low, 0.3 + (1 - k) * 0.28), 0.6, Color(0.86, 0.84, 0.8), true, false)
	for s in [-1.0, 1.0]:
		mb.add_box(lime, t * Transform3D(Basis(), Vector3(s * (hw - 0.18), sill + g1 * 0.5, hd + 0.06)), Vector3(0.36, g1, 0.12), 0.6, Color(0.93, 0.91, 0.87))
	var wx := hw * 0.5 if door_x < 0.0 else -hw * 0.5
	var ww := minf(2.2, hw - 0.9)
	if ww > 0.8:
		var wt := t * Transform3D(Basis(), Vector3(wx, sill + 0.9, z + 0.02))
		mb.add_box_unit_uv(M.mat("window"), wt * Transform3D(Basis(), Vector3(0, 0.85, 0)), Vector3(ww, 1.7, 0.04))
		mb.add_box(lime, wt * Transform3D(Basis(), Vector3(0, -0.06, 0.08)), Vector3(ww + 0.3, 0.12, 0.2), 0.6, Color(0.88, 0.86, 0.82), false)
		mb.add_box(lime, wt * Transform3D(Basis(), Vector3(0, 1.78, 0.05)), Vector3(ww + 0.24, 0.16, 0.12), 0.6, Color(0.9, 0.88, 0.84), false)
		if kind != "" and not shabby:
			_awning(mb, wt * Transform3D(Basis(), Vector3(0, 2.15, 0)), ww + 0.8, 1.3, AWNINGS[rng.randi() % AWNINGS.size()])
			_wares(mb, wt * Transform3D(Basis(), Vector3(0, -0.9 + 0.05, 0.6)), ww, kind, rng)
			_sign(mb, t * Transform3D(Basis(), Vector3(door_x + (0.9 if door_x < wx else -0.9), sill + g1 - 0.2, z)), kind, rng)
	if not shabby and rng.randf() < 0.45 and floors >= 3:
		_balcony(mb, t * Transform3D(Basis(), Vector3(0, sill + g1 + 0.1, hd)), minf(w - 1.2, 4.5))
	if shabby and rng.randf() < 0.5:
		mb.add_box(M.mat("dark"), t * Transform3D(Basis(Vector3.BACK, 0.4), Vector3(wx - 1.0, sill + g1 + 1.4, hd + 0.06)), Vector3(0.5, 1.4, 0.05), 1.0, Color(0.5, 0.42, 0.34), false)
	return {"at": t * Vector3(door_x, top, hd + 0.9), "face": (Vector2((t.basis * Vector3.BACK).x, (t.basis * Vector3.BACK).z)).normalized(), "kind": kind}


## A sloped cloth awning `w` wide, reaching `out`, on two iron rods (frame `t`: its top edge on the wall, +z out).
static func _awning(mb: MeshBuilder, t: Transform3D, w: float, out: float, tex: String) -> void:
	var m := PSXMat.lit(tex, Color.WHITE, {"affine": 0.6})
	var a := t * Vector3(-w * 0.5, 0, 0.02)
	var b := t * Vector3(w * 0.5, 0, 0.02)
	var c := t * Vector3(w * 0.5, -0.55, out)
	var e := t * Vector3(-w * 0.5, -0.55, out)
	var n := (t.basis * Vector3(0, out, 0.55)).normalized()
	mb.add_quad(m, a, b, c, e, Vector2(0, 0), Vector2(w * 0.8, 0), Vector2(w * 0.8, 1), Vector2(0, 1), Color.WHITE, n)
	mb.add_quad(m, a, e, c, b, Vector2(0, 0), Vector2(0, 1), Vector2(w * 0.8, 1), Vector2(w * 0.8, 0), Color(0.65, 0.65, 0.65), -n)
	for s in [-1.0, 1.0]:
		mb.add_quad(m, t * Vector3(s * w * 0.5, -0.55, out), t * Vector3(s * w * 0.5, -0.8, out), t * Vector3(-s * w * 0.5, -0.8, out), t * Vector3(-s * w * 0.5, -0.55, out),
			Vector2(0, 0), Vector2(0, 0.3), Vector2(w * 0.8, 0.3), Vector2(w * 0.8, 0), Color(0.9, 0.9, 0.9), (t.basis * Vector3(0, 0, s)).normalized())
		Buildings.beam_between(mb, M.mat("iron"), t * Vector3(s * (w * 0.5 - 0.1), -0.9, 0.02), t * Vector3(s * (w * 0.5 - 0.1), -0.5, out - 0.05), 0.04)


## What a shop sets out under its awning: a trestle with goods of its kind.
static func _wares(mb: MeshBuilder, t: Transform3D, w: float, kind: String, rng: RandomNumberGenerator) -> void:
	var wood := PSXMat.lit("planks")
	mb.add_box(wood, t * Transform3D(Basis(), Vector3(0, 0.78, 0)), Vector3(w, 0.07, 0.7), 1.0, Color.WHITE, false)
	for s in [-1.0, 1.0]:
		mb.add_box(M.mat("dark"), t * Transform3D(Basis(), Vector3(s * (w * 0.5 - 0.1), 0.39, 0)), Vector3(0.07, 0.78, 0.6), 1.0)
	var goods: Array = CapitalStyle.STYLE["goods"]
	match kind:
		"cloth", "tailor":
			for k in range(int(w / 0.4)):
				mb.add_cylinder(PSXMat.lit("fabric"), t * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-w * 0.5 + 0.25 + k * 0.4, 0.92, -0.3)), 0.11, 0.11, 0.6, 6, 1.0,
					(M.WALLS[k % M.WALLS.size()] as Color) * (goods[k % goods.size()] as Color))
		"potter", "wine":
			for k in range(int(w / 0.32)):
				var ht := rng.randf_range(0.22, 0.42)
				mb.add_cylinder(PSXMat.lit("plaster", Color(0.72, 0.42, 0.24) if kind == "potter" else Color(0.3, 0.42, 0.28)), t * Transform3D(Basis(), Vector3(-w * 0.5 + 0.2 + k * 0.32, 0.82, rng.randf_range(-0.2, 0.2))), 0.11, 0.06, ht, 6, 1.0)
		"books", "chart":
			for k in range(int(w / 0.25)):
				mb.add_box(PSXMat.lit("leather"), t * Transform3D(Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)), Vector3(-w * 0.5 + 0.15 + k * 0.25, 0.85, rng.randf_range(-0.15, 0.15))),
					Vector3(0.2, 0.06 + 0.04 * float(k % 3), 0.28), 1.0, (goods[k % goods.size()] as Color) * 0.8)
		"jeweller":
			mb.add_box(PSXMat.lit("fabric", Color(0.25, 0.14, 0.3)), t * Transform3D(Basis(), Vector3(0, 0.83, 0)), Vector3(w - 0.1, 0.03, 0.62), 1.0)
			for k in range(int(w / 0.2)):
				mb.add_blob(M.mat("gold"), t * Transform3D(Basis(), Vector3(-w * 0.5 + 0.12 + k * 0.2, 0.88, rng.randf_range(-0.2, 0.2))), Vector3.ONE * 0.05, rng, 0.2, 2, 4, 1.0)
		_:
			var basket := PSXMat.lit("straw")
			for k in range(int(w / 0.55)):
				var bp := Vector3(-w * 0.5 + 0.3 + k * 0.55, 0.82, 0)
				mb.add_cylinder(basket, t * Transform3D(Basis(), bp), 0.22, 0.25, 0.16, 6, 1.0)
				var g: Color = goods[(k + rng.randi()) % goods.size()]
				if kind == "baker":
					g = Color(0.82, 0.6, 0.32)
				for j in range(4):
					mb.add_blob(PSXMat.flat(Color.WHITE), t * Transform3D(Basis(), bp + Vector3(rng.randf_range(-0.1, 0.1), 0.17 + (j / 3) * 0.07, rng.randf_range(-0.1, 0.1))),
						Vector3.ONE * (0.08 if kind == "baker" else 0.065), rng, 0.15, 2, 4, 1.0, g)


## A hanging shop sign on an iron bracket out from the wall (frame `t`: on the wall face, +z out).
static func _sign(mb: MeshBuilder, t: Transform3D, kind: String, rng: RandomNumberGenerator) -> void:
	var iron := M.mat("iron")
	mb.add_box(iron, t * Transform3D(Basis(), Vector3(0, 0, 0.45)), Vector3(0.06, 0.06, 0.9), 1.0, Color.WHITE, false)
	Buildings.beam_between(mb, iron, t * Vector3(0, -0.35, 0.02), t * Vector3(0, 0, 0.6), 0.04)
	var tex := "sign_tavern" if kind == "wine" else ("sign_fish" if kind == "fruit" else "")
	var col: Color = (CapitalStyle.STYLE["pennants"] as Array)[rng.randi() % 4]
	var board := t * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, -0.45, 0.62))
	if tex != "":
		mb.add_box_unit_uv(PSXMat.lit(tex, Color.WHITE, {"vertex_color": false}), board, Vector3(0.75, 0.62, 0.05))
	else:
		mb.add_box(PSXMat.lit("planks", col), board, Vector3(0.75, 0.62, 0.05), 1.0, Color.WHITE, false)
		mb.add_box(M.mat("gold"), board * Transform3D(Basis(), Vector3(0, 0, 0.0)), Vector3(0.4, 0.3, 0.07), 1.0, Color.WHITE, false)


## A balcony: a stone slab on brackets and an iron railing (frame `t` at the wall face, its floor level, +z out).
static func _balcony(mb: MeshBuilder, t: Transform3D, w: float) -> void:
	var lime := M.mat("lime")
	var iron := M.mat("iron")
	mb.add_box(lime, t * Transform3D(Basis(), Vector3(0, 0, 0.45)), Vector3(w, 0.16, 0.9), 0.6, Color(0.9, 0.88, 0.84), false)
	for x in [-w * 0.4, w * 0.4]:
		mb.add_box(lime, t * Transform3D(Basis(), Vector3(x, -0.25, 0.25)), Vector3(0.18, 0.4, 0.5), 0.6, Color(0.86, 0.84, 0.8), false)
	mb.add_box(iron, t * Transform3D(Basis(), Vector3(0, 0.95, 0.86)), Vector3(w, 0.05, 0.05), 1.0, Color.WHITE, false)
	for s in [-1.0, 1.0]:
		mb.add_box(iron, t * Transform3D(Basis(), Vector3(s * w * 0.5, 0.95, 0.43)), Vector3(0.05, 0.05, 0.86), 1.0, Color.WHITE, false)
	var n := int(w / 0.18)
	for k in range(n + 1):
		mb.add_box(iron, t * Transform3D(Basis(), Vector3(-w * 0.5 + w * k / n, 0.5, 0.86)), Vector3(0.025, 0.9, 0.025), 1.0, Color.WHITE, false)


# --------------------------------------------------------------------------
# The plaza's own buildings
# --------------------------------------------------------------------------
static func _specials(out: Dictionary) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	var lime := M.mat("lime")
	for key in P.SPECIAL.keys():
		var sp: Array = P.SPECIAL[key]
		var r: Rect2 = sp[0]
		var face: Vector2 = sp[1]
		if key in ["bell", "yardhall", "outfitter"]:
			continue
		var l := {"r": r, "cell": r, "c": r.get_center(), "face": face, "seed": hash(key), "floors": 3, "roof": "hip"}
		var fr := lot_frame(l)
		var t: Transform3D = fr[0]
		var w: float = fr[1]
		var d: float = fr[2]
		var gs := _ground_span(r)
		var top := gs.y
		var low := gs.x - 0.5
		match key:
			"inn":
				var y1 := top + 0.03
				var eaves := y1 + 4.2 + 2.0 * M.STOREY
				mb.add_box(lime, t * Transform3D(Basis(), Vector3(0, (low + y1) * 0.5, 0)), Vector3(w + 0.1, y1 - low, d + 0.1), 0.5, Color(0.9, 0.88, 0.84), true, true)
				M.facade_box(mb, M.mat("facade_b"), t, w, d, y1 + 4.2, eaves - y1 - 4.2, Color(0.99, 0.93, 0.8))
				# the arcade along the front, its loggia behind (the inn's terrace in its shade)
				var n := 5
				for k in range(n):
					var x := -w * 0.5 + w * (k + 0.5) / n
					M.arch_wall(mb, lime, t * Transform3D(Basis(), Vector3(x, y1, d * 0.5 - 0.3)), w / n + 0.01, 4.2, 0.6, w / n * 0.62, 2.3, Color(0.96, 0.94, 0.9))
				var back := t * Transform3D(Basis(), Vector3(0, 0, d * 0.5 - 3.2))
				M.facade_quad(mb, M.mat("facade_a"), back * Vector3(-w * 0.5, y1, 0), back * Vector3(w * 0.5, y1, 0), 4.2, (t.basis * Vector3.BACK).normalized(), Color(0.95, 0.88, 0.76), 4.2)
				mb.add_box(lime, t * Transform3D(Basis(), Vector3(0, y1 + 4.2, 0)), Vector3(w + 0.2, 0.25, d + 0.2), 0.6, Color(0.9, 0.88, 0.84), false)
				mb.add_quad(M.mat("slabs"), t * Vector3(-w * 0.5, y1 + 0.02, d * 0.5), t * Vector3(w * 0.5, y1 + 0.02, d * 0.5), t * Vector3(w * 0.5, y1 + 0.02, d * 0.5 - 3.2),
					t * Vector3(-w * 0.5, y1 + 0.02, d * 0.5 - 3.2), Vector2.ZERO, Vector2(w * 0.5, 0), Vector2(w * 0.5, 1.6), Vector2(0, 1.6), Color(0.85, 0.83, 0.8), Vector3.UP)
				for s in [-1.0, 1.0]:
					M.facade_quad(mb, M.mat("facade_a"), t * Vector3(s * w * 0.5, y1, -s * d * 0.5), t * Vector3(s * w * 0.5, y1, s * d * 0.5), 4.2, (t.basis * Vector3(s, 0, 0)).normalized(), Color(0.95, 0.88, 0.76), 4.2)
				M.facade_quad(mb, M.mat("facade_a"), t * Vector3(w * 0.5, y1, -d * 0.5), t * Vector3(-w * 0.5, y1, -d * 0.5), 4.2, (t.basis * Vector3.FORWARD).normalized(), Color(0.95, 0.88, 0.76), 4.2)
				mb.add_box(lime, t * Transform3D(Basis(), Vector3(0, eaves + 0.12, 0)), Vector3(w + 0.3, 0.24, d + 0.3), 0.6, Color(0.95, 0.93, 0.9), false)
				M._hip(mb, t * Transform3D(Basis(), Vector3(0, eaves + 0.24, 0)), w, d, 4.5, 0.4, Color(0.96, 0.88, 0.82))
				M.box(cols, t * Transform3D(Basis(), Vector3(0, (low + eaves) * 0.5, -1.6)), Vector3(w, eaves - low, d - 3.2))
				Occluders.box(cols, t * Transform3D(Basis(), Vector3(0, (low + eaves) * 0.5, -1.6)), Vector3(w, eaves - low, d - 3.2))
				M.box(cols, t * Transform3D(Basis(), Vector3(0, (low + y1) * 0.5, d * 0.5 - 1.6)), Vector3(w, y1 - low, 3.2))
				for k in range(n + 1):
					var x := -w * 0.5 + w * k / n
					M.box(cols, t * Transform3D(Basis(), Vector3(clampf(x, -w * 0.5 + 0.8, w * 0.5 - 0.8), y1 + 1.2, d * 0.5 - 0.3)), Vector3(1.6, 2.4, 0.6))
				var door := t * Transform3D(Basis(), Vector3(0, y1, d * 0.5 - 3.2))
				Buildings.panel_door(mb, door, 1.8, 2.6, Buildings.door_leaf(DOORS[3]), lime, M.mat("window"))
				_lantern(mb, door * Transform3D(Basis(), Vector3(1.6, 2.4, 0)))
				_lantern(mb, door * Transform3D(Basis(), Vector3(-1.6, 2.4, 0)))
				_light(out, door * Vector3(0, 2.6, 0.8), 1.4, 9.0)
				var sign := t * Transform3D(Basis(), Vector3(w * 0.5 - 1.0, y1 + 4.0, d * 0.5 + 0.02))
				_sign(mb, sign, "wine", _rng(5))
				# (the tables kept off the door's way)
				var tx := [-0.34 * w, -0.16 * w, 0.3 * w]
				for k in range(3):
					var tq := t * Transform3D(Basis(), Vector3(tx[k], y1, d * 0.5 - 1.6))
					absorb(mb, cols, Props.table(), tq)
				_spot(out, "innkeeper", _q(door * Vector3(-2.0, 0, 1.0)), y1, _fd(t))
				_spot(out, "inn_door", _q(door * Vector3(0, 0, 1.2)), y1, _fd(t))
				for k in range(3):
					_spot(out, "inn_patron%d" % k, _q(t * Vector3(float(tx[k]) + 1.05, 0, d * 0.5 - 1.6)), y1, Vector2(0, 0) - Vector2((t.basis * Vector3.RIGHT).x, (t.basis * Vector3.RIGHT).z))
			"curio":
				var l2 := l.duplicate()
				l2["floors"] = 3
				l2["seed"] = 77101
				var dd := townhouse(mb, cols, l2, "jeweller")
				var counter := t * Transform3D(Basis(), Vector3(-w * 0.15, top, d * 0.5 + 1.4))
				mb.add_box(PSXMat.lit("planks_dark"), counter * Transform3D(Basis(), Vector3(0, 0.5, 0)), Vector3(2.4, 1.0, 0.8), 1.0, Color(0.7, 0.6, 0.5))
				mb.add_box(PSXMat.lit("fabric", Color(0.18, 0.4, 0.3)), counter * Transform3D(Basis(), Vector3(0, 1.01, 0)), Vector3(2.5, 0.03, 0.9), 1.0)
				var rng := _rng(99)
				for k in range(6):
					var gp := counter * Vector3(-1.0 + k * 0.4, 1.12, rng.randf_range(-0.2, 0.2))
					if k % 2 == 0:
						mb.add_box(M.mat("gold"), M.xf(gp, rng.randf()), Vector3(0.22, 0.16, 0.16), 1.0)
					else:
						mb.add_blob(PSXMat.flat(Color(0.3, 0.55, 0.85)), M.xf(gp), Vector3.ONE * 0.08, rng, 0.2, 2, 4, 1.0)
				M.box(cols, counter * Transform3D(Basis(), Vector3(0, 0.5, 0)), Vector3(2.4, 1.0, 0.8))
				_awning(mb, t * Transform3D(Basis(), Vector3(-w * 0.15, top + 3.5, d * 0.5)), 3.4, 2.4, "awning_green")
				_spot(out, "curio", _q(counter * Vector3(0, 0, -0.9)), top, _fd(t))
				_spot(out, "curio_customer", _q(counter * Vector3(0, 0, 1.1)), top, -_fd(t))
				out["spots"]["curio_door"] = [dd["at"], M.yaw_of(dd["face"])]
			"guild", "bank":
				# (their ground rises up the avenue behind: the steps start from the plaza at their front)
				top = P.ground(_q(t * Vector3(0, 0, d * 0.5)))
				var y1 := top + 0.9
				var h := 13.5 if key == "guild" else 11.0
				mb.add_box(lime, t * Transform3D(Basis(), Vector3(0, (low + y1) * 0.5, -1.5)), Vector3(w + 0.2, y1 - low, d - 3.0), 0.5, Color(0.9, 0.88, 0.84), true, true)
				var body_t := t * Transform3D(Basis(), Vector3(0, 0, -2.0))
				M.facade_box(mb, M.mat("facade_b"), body_t, w, d - 4.0, y1, h, Color(1.0, 0.99, 0.96) if key == "guild" else Color(0.97, 0.94, 0.86))
				mb.add_box(lime, body_t * Transform3D(Basis(), Vector3(0, y1 + h + 0.2, 0)), Vector3(w + 0.4, 0.4, d - 3.6), 0.6, Color(0.92, 0.9, 0.86), false)
				M._hip(mb, body_t * Transform3D(Basis(), Vector3(0, y1 + h + 0.4, 0)), w, d - 4.0, 3.6, 0.3, Color.WHITE)
				M.box(cols, body_t * Transform3D(Basis(), Vector3(0, (low + y1 + h) * 0.5, 0)), Vector3(w, y1 + h - low, d - 4.0))
				Occluders.box(cols, body_t * Transform3D(Basis(), Vector3(0, (y1 + y1 + h) * 0.5, 0)), Vector3(w, h, d - 4.0))
				# the portico: steps the width of it, columns, an entablature and a pediment
				var front := t * Transform3D(Basis(), Vector3(0, 0, d * 0.5 - 2.0))
				var nc := 6 if key == "guild" else 4
				var pw := w - 2.0 if key == "guild" else w * 0.6
				for k in range(3):
					mb.add_box(lime, front * Transform3D(Basis(), Vector3(0, top + 0.15 + k * 0.25 - 0.4, 1.4 - k * 0.45)), Vector3(pw + 1.6 - k * 0.3, 1.1, 0.9), 0.6, Color(0.92 - 0.03 * k, 0.9 - 0.03 * k, 0.86 - 0.03 * k))
				M.box(cols, front * Transform3D(Basis(), Vector3(0, top + 0.35, 0.9)), Vector3(pw + 1.6, 0.7, 1.8))
				var ch := h * 0.72
				for k in range(nc):
					var x := -pw * 0.5 + pw * k / (nc - 1)
					mb.add_cylinder(lime, front * Transform3D(Basis(), Vector3(x, y1, -0.2)), 0.42, 0.36, ch, 10, 0.6, Color(0.98, 0.96, 0.93))
					mb.add_box(lime, front * Transform3D(Basis(), Vector3(x, y1 + 0.12, -0.2)), Vector3(1.0, 0.24, 1.0), 0.6, Color(0.9, 0.88, 0.84))
					mb.add_box(lime, front * Transform3D(Basis(), Vector3(x, y1 + ch - 0.1, -0.2)), Vector3(1.0, 0.2, 1.0), 0.6, Color(0.9, 0.88, 0.84), false)
					M.cyl(cols, front * Vector3(x, y1, -0.2), 0.42, ch)
				mb.add_box(lime, front * Transform3D(Basis(), Vector3(0, y1 + ch + 0.5, -1.0)), Vector3(pw + 1.2, 1.0, 2.6), 0.6, Color(0.95, 0.93, 0.9), false)
				var ped := PackedVector2Array([Vector2(-pw * 0.5 - 0.6, 0), Vector2(pw * 0.5 + 0.6, 0), Vector2(0, 2.2)])
				mb.add_extrude(lime, front * Transform3D(Basis(), Vector3(0, y1 + ch + 1.0, -1.0)), ped, 2.4, 0.5, Color(0.96, 0.94, 0.9))
				mb.add_box(M.mat("roof"), front * Transform3D(Basis(), Vector3(0, y1 + ch + 1.05, -1.0)), Vector3(pw + 1.3, 0.1, 2.7), 0.5, Color.WHITE, false)
				var dt := front * Transform3D(Basis(), Vector3(0, y1, -2.0))
				Buildings.panel_door(mb, dt, 2.2, 3.4, Buildings.door_leaf(DOORS[0] if key == "guild" else DOORS[1]), lime)
				if key == "bank":
					M.portcullis(mb, [], dt * Transform3D(Basis(), Vector3(0, 0, 0.3)), 2.4, 3.5)
					_spot(out, "bank", _q(front * Vector3(1.6, 0, 2.6)), P.ground(_q(front * Vector3(1.6, 0, 2.6))), _fd(t))
				else:
					for s in [-1.0, 1.0]:
						_banner(mb, front * Transform3D(Basis(), Vector3(s * pw * 0.32, y1 + ch - 0.4, 0.25)), 1.1, ch * 0.6, M.BLUE if s < 0 else Color(0.62, 0.16, 0.14))
					_spot(out, "guild", _q(front * Vector3(-1.6, 0, 2.6)), P.ground(_q(front * Vector3(-1.6, 0, 2.6))), _fd(t))
	_piece(out, "PlazaHalls", mb, cols, FAR)


static func _q(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


static func _fd(t: Transform3D) -> Vector2:
	var b := t.basis * Vector3.BACK
	return Vector2(b.x, b.z).normalized()


## A long cloth banner hanging from a rod (frame `t` at the rod's middle on the wall, +z out).
static func _banner(mb: MeshBuilder, t: Transform3D, w: float, h: float, col: Color) -> void:
	var m := PSXMat.lit("fabric", col)
	mb.add_box(M.mat("iron"), t, Vector3(w + 0.3, 0.06, 0.06), 1.0, Color.WHITE, false)
	var pts := PackedVector2Array([Vector2(-w * 0.5, 0), Vector2(w * 0.5, 0), Vector2(w * 0.5, -h), Vector2(0, -h - w * 0.4), Vector2(-w * 0.5, -h)])
	mb.add_extrude(m, t * Transform3D(Basis(), Vector3(0, 0, 0.05)), pts, 0.04, 1.0)
	mb.add_box(M.mat("gold"), t * Transform3D(Basis(), Vector3(0, -h * 0.4, 0.08)), Vector3(w * 0.45, w * 0.45, 0.02), 1.0, Color.WHITE, false)


## A wall lantern on its bracket (frame `t` on the wall face, +z out): it glows; its light, if any, is the caller's.
static func _lantern(mb: MeshBuilder, t: Transform3D) -> void:
	var iron := M.mat("iron")
	mb.add_box(iron, t * Transform3D(Basis(), Vector3(0, 0.25, 0.2)), Vector3(0.05, 0.05, 0.4), 1.0, Color.WHITE, false)
	mb.add_box(iron, t * Transform3D(Basis(), Vector3(0, 0.12, 0.38)), Vector3(0.26, 0.05, 0.26), 1.0, Color.WHITE, false)
	mb.add_box(M.mat("glow"), t * Transform3D(Basis(), Vector3(0, -0.08, 0.38)), Vector3(0.2, 0.32, 0.2), 1.0, Color.WHITE, false)
	mb.add_box(iron, t * Transform3D(Basis(), Vector3(0, -0.27, 0.38)), Vector3(0.24, 0.05, 0.24), 1.0, Color.WHITE, false)


## The capital's street lamp: a fluted iron post on a stone foot, a crossbar with a lantern each end.
static func lamp_post(mb: MeshBuilder, cols: Array, q: Vector2, y: float, yaw := 0.0) -> Array:
	var iron := M.mat("iron")
	var t := M.xf(M.v3(q, y), yaw)
	mb.add_cylinder(M.mat("lime"), t, 0.32, 0.26, 0.5, 8, 0.8, Color(0.9, 0.88, 0.84))
	mb.add_cylinder(iron, t * Transform3D(Basis(), Vector3(0, 0.5, 0)), 0.09, 0.06, 3.4, 6, 1.0)
	mb.add_box(iron, t * Transform3D(Basis(), Vector3(0, 3.7, 0)), Vector3(1.3, 0.07, 0.07), 1.0, Color.WHITE, false)
	for s in [-1.0, 1.0]:
		var lt := t * Transform3D(Basis(), Vector3(s * 0.62, 3.45, 0))
		mb.add_box(M.mat("glow"), lt, Vector3(0.24, 0.36, 0.24), 1.0, Color.WHITE, false)
		mb.add_pyramid_roof(iron, lt * Transform3D(Basis(), Vector3(0, 0.18, 0)), 0.3, 0.3, 0.2, 0.02, 1.0)
		mb.add_box(iron, lt * Transform3D(Basis(), Vector3(0, -0.2, 0)), Vector3(0.28, 0.04, 0.28), 1.0, Color.WHITE, false)
	M.cyl(cols, M.v3(q, y), 0.3, 3.8)
	return [t * Vector3(0.62, 3.45, 0), t * Vector3(-0.62, 3.45, 0)]


## Bunting from a to b: a sagging line hung with pennants in the capital's colours.
static func bunting(mb: MeshBuilder, a: Vector3, b: Vector3, rng: RandomNumberGenerator) -> void:
	var pts := MeshBuilder.sag_points(a, b, a.distance_to(b) * 0.06, 12)
	mb.add_tube(PSXMat.lit("rope"), pts, 0.015, -1.0, 3)
	var cols: Array = CapitalStyle.STYLE["pennants"]
	var m := PSXMat.lit("canvas")
	var along := (b - a).normalized()
	var n := Vector3(along.z, 0, -along.x).normalized()
	for i in range(1, pts.size() - 1):
		var p: Vector3 = pts[i]
		var c: Color = cols[rng.randi() % cols.size()]
		var l := p - along * 0.18
		var r := p + along * 0.18
		var tip := p + Vector3.DOWN * 0.42
		mb.add_tri(m, l, r, tip, n, n, n, Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 1), c, n)
		mb.add_tri(m, l, tip, r, -n, -n, -n, Vector2(0, 0), Vector2(0.5, 1), Vector2(1, 0), c * 0.8, -n)


## The front face of the lot across a floor from frame point q along `dir` (where bunting ties on): the first
## house wall a ray from q meets, else q + dir * max.
static func _wall_at(out: Dictionary, q: Vector2, dir: Vector2, max_d: float) -> Vector2:
	var cells: Array = out["cells"]
	var d := 0.5
	while d < max_d:
		var p := q + dir * d
		for c in cells:
			if (c as Rect2).has_point(p):
				return p - dir * 0.15
		d += 0.25
	return q + dir * max_d


# --------------------------------------------------------------------------
# The plaza
# --------------------------------------------------------------------------
static func _plaza(out: Dictionary) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	var y := P.PLAZA_Y
	var lime := M.mat("lime")
	var rng := _rng(4001)
	# the fountain: an eight-sided basin, two tiers on a column, the crowned figure on top, water falling
	var c := Vector2.ZERO
	var n := 8
	for k in range(n):
		var a0 := TAU * k / n + PI / n
		var a1 := TAU * (k + 1) / n + PI / n
		var p0 := c + Vector2(cos(a0), sin(a0)) * 4.8
		var p1 := c + Vector2(cos(a1), sin(a1)) * 4.8
		var mid := (p0 + p1) * 0.5
		mb.add_box(lime, M.xf(M.v3(mid, y + 0.3), M.yaw_of(mid.normalized())), Vector3(p0.distance_to(p1) + 0.3, 0.8, 0.6), 0.6, Color(0.94, 0.92, 0.88))
		mb.add_box(lime, M.xf(M.v3(mid * 1.02, y + 0.74), M.yaw_of(mid.normalized())), Vector3(p0.distance_to(p1) + 0.45, 0.1, 0.8), 0.6, Color(0.86, 0.84, 0.8), false)
	var water := PSXMat.lit("water", Color(0.55, 0.8, 0.85), {"emission": Color(0.1, 0.25, 0.3), "emission_energy": 0.4})
	for k in range(n):
		var a0 := TAU * k / n + PI / n
		var a1 := TAU * (k + 1) / n + PI / n
		mb.add_tri(water, M.v3(c, y + 0.55), M.v3(c + Vector2(cos(a0), sin(a0)) * 4.6, y + 0.55), M.v3(c + Vector2(cos(a1), sin(a1)) * 4.6, y + 0.55),
			Vector3.UP, Vector3.UP, Vector3.UP, Vector2(0.5, 0.5), Vector2(cos(a0), sin(a0)) * 0.5 + Vector2(0.5, 0.5), Vector2(cos(a1), sin(a1)) * 0.5 + Vector2(0.5, 0.5), Color.WHITE, Vector3.UP)
	M.cyl(cols, M.v3(c, y - 0.2), 4.9, 1.0)
	mb.add_cylinder(lime, M.xf(M.v3(c, y)), 0.9, 0.7, 2.6, 10, 0.6, Color(0.95, 0.93, 0.9))
	var rings := [[0.0, 0.5, 0.5], [0.25, 2.2, 2.2], [0.45, 2.4, 2.4], [0.5, 2.2, 2.2]]
	mb.add_loft(lime, M.xf(M.v3(c, y + 2.4)), rings, MeshBuilder.profile_circle(12), 0.6, Color(0.93, 0.91, 0.87), true, true)
	mb.add_cylinder(lime, M.xf(M.v3(c, y + 2.9)), 0.5, 0.35, 1.6, 8, 0.6, Color(0.95, 0.93, 0.9))
	var rings2 := [[0.0, 0.3, 0.3], [0.2, 1.2, 1.2], [0.35, 1.3, 1.3], [0.4, 1.2, 1.2]]
	mb.add_loft(lime, M.xf(M.v3(c, y + 4.4)), rings2, MeshBuilder.profile_circle(10), 0.6, Color(0.93, 0.91, 0.87), true, true)
	_figure(mb, M.xf(M.v3(c, y + 4.8), PI), 2.2, true)
	var spray := PSXMat.lit("water", Color(0.75, 0.92, 0.95), {"emission": Color(0.3, 0.45, 0.5), "emission_energy": 0.6, "affine": 0.2})
	for k in range(8):
		var a := TAU * k / 8.0
		mb.add_tube(spray, MeshBuilder.curve_points(M.v3(c + Vector2(cos(a), sin(a)) * 2.3, y + 2.85), M.v3(c + Vector2(cos(a), sin(a)) * 2.9, y + 2.8), M.v3(c + Vector2(cos(a), sin(a)) * 3.2, y + 0.6), 6), 0.05, 0.08, 4)
	M.cyl(cols, M.v3(c, y), 0.9, 6.0)
	# a ring of darker paving round it
	var ring_m := PSXMat.lit("cobbles")
	for k in range(24):
		var a0 := TAU * k / 24.0
		var a1 := TAU * (k + 1) / 24.0
		var i0 := Vector2(cos(a0), sin(a0)) * 5.2
		var i1 := Vector2(cos(a1), sin(a1)) * 5.2
		mb.add_quad(ring_m, M.v3(i0, y + 0.03), M.v3(i1, y + 0.03), M.v3(i1 * 1.45, y + 0.03), M.v3(i0 * 1.45, y + 0.03), i0 * 0.6, i1 * 0.6, i1 * 0.87, i0 * 0.87, Color(0.92, 0.9, 0.88), Vector3.UP)
	# the market: stalls in a broken ring round the fountain (open toward the street, the avenue and the arena street)
	var kinds := ["fruit", "fish", "cloth", "pots", "fruit", "cloth", "pots", "fish"]
	var angles := [0.45, 0.95, 1.25, 2.0, 2.3, 3.6, 4.0, 5.3]
	for k in range(angles.size()):
		var a: float = angles[k]
		var p := c + Vector2(cos(a), sin(a)) * 13.0
		var face := p.normalized()
		var st := Buildings.stall(kinds[k])
		var vendor := (st.get_node("Vendor") as Node3D).position
		var t := M.xf(M.v3(p, y), M.yaw_of(face))
		_spot(out, "stall%d" % k, _q(t * vendor), y, face)
		_spot(out, "stall%d_customer" % k, _q(t * Vector3(0, 0, 1.6)), y, -face)
		absorb(mb, cols, st, t)
	# benches facing the fountain (seats: real nodes, made on the main thread from the spots)
	for k in range(4):
		var a := PI * 0.25 + k * PI * 0.5
		_spot(out, "bench%d" % k, Vector2(cos(a), sin(a)) * 7.6, y, -Vector2(cos(a), sin(a)))
	# trees in round stone planters at the corners, lamps between
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var tp := Vector2(sx * 21.5, sz * 17.5)
			mb.add_cylinder(lime, M.xf(M.v3(tp, y)), 1.3, 1.3, 0.6, 10, 0.6, Color(0.92, 0.9, 0.86), true)
			M.cyl(cols, M.v3(tp, y), 1.3, 0.6)
			_plane_tree(mb, M.v3(tp, y + 0.5), rng)
			M.cyl(cols, M.v3(tp, y), 0.35, 3.0)
			var lp := Vector2(sx * 13.5, sz * 13.5)
			lamp_post(mb, cols, lp, y, PI * 0.25 * sx * sz)
			_light(out, M.v3(lp, y + 3.5), 1.7, 12.0)
	_spot(out, "flower", Vector2(-8.7, 4.6), y, Vector2(0.88, -0.47))
	# the notice board by the street's mouth
	var board := KitVillage.notice_board(_rng(7))
	var bq := Vector2(-9.5, 15.5)
	_spot(out, "board", bq, y, Vector2(0, 1))
	absorb(mb, cols, board, M.xf(M.v3(bq, y), 0.0))
	# flower tubs and a few crates by the stalls
	for k in range(10):
		var a := rng.randf() * TAU
		var p := Vector2(cos(a), sin(a)) * rng.randf_range(15.2, 17.0)
		if absf(p.x) < 7.0 or absf(p.y) < 7.5:
			continue
		var bt := Props.barrel() if k % 2 == 0 else Props.crate(0.7)
		absorb(mb, cols, bt, M.xf(M.v3(p, y), rng.randf() * TAU))
	# bunting from the fountain's top to the plaza's lamps
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			bunting(mb, M.v3(Vector2.ZERO, y + 6.2), M.v3(Vector2(sx * 13.5, sz * 13.5), y + 3.8), rng)
	_piece(out, "Plaza", mb, cols)


## A stylised statue (a king or queen, crowned): plinth-less, at frame `t` (its feet), `h` tall.
static func _figure(mb: MeshBuilder, t: Transform3D, h: float, crowned: bool) -> void:
	var stone := M.mat("lime")
	var k := h / 2.0
	mb.add_loft(stone, t, [[0.0, 0.42 * k, 0.32 * k], [0.9 * k, 0.32 * k, 0.24 * k], [1.3 * k, 0.3 * k, 0.2 * k], [1.5 * k, 0.4 * k, 0.24 * k], [1.62 * k, 0.16 * k, 0.14 * k]],
		MeshBuilder.profile_oct(), 0.6, Color(0.96, 0.95, 0.92), true, true)
	mb.add_blob(stone, t * Transform3D(Basis(), Vector3(0, 1.78 * k, 0)), Vector3(0.17, 0.2, 0.18) * k, _rng(3), 0.0, 3, 6, 0.6, Color(0.96, 0.95, 0.92))
	mb.add_box(stone, t * Transform3D(Basis(Vector3.BACK, 0.5), Vector3(0.38 * k, 1.35 * k, 0.1 * k)), Vector3(0.12, 0.7, 0.12) * k, 0.6, Color(0.94, 0.93, 0.9))
	mb.add_cylinder(stone, t * Transform3D(Basis(), Vector3(-0.42 * k, 0.0, 0.15 * k)), 0.04 * k, 0.04 * k, 1.9 * k, 5, 0.6, Color(0.9, 0.89, 0.86))
	if crowned:
		mb.add_cylinder(M.mat("gold"), t * Transform3D(Basis(), Vector3(0, 1.93 * k, 0)), 0.15 * k, 0.17 * k, 0.12 * k, 6, 1.0)


## A plane tree: a pale trunk and a broad crown of leaf blobs (the plaza's corners).
static func _plane_tree(mb: MeshBuilder, at: Vector3, rng: RandomNumberGenerator) -> void:
	mb.add_cylinder(PSXMat.lit("bark", Color(0.85, 0.8, 0.7)), M.xf(at), 0.3, 0.22, 3.2, 6, 1.0)
	var leaves := PSXMat.lit("leaves", Color(0.6, 0.78, 0.5))
	for k in range(5):
		var o := Vector3(rng.randf_range(-1.2, 1.2), 4.0 + rng.randf_range(0.0, 1.4), rng.randf_range(-1.2, 1.2))
		mb.add_blob(leaves, M.xf(at + o), Vector3(1.8, 1.2, 1.8), rng, 0.2, 3, 6, 0.6, Color(0.55 + 0.1 * float(k % 2), 0.7, 0.5))


# --------------------------------------------------------------------------
# The market street, the gate
# --------------------------------------------------------------------------
static func _street(out: Dictionary) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	var rng := _rng(4101)
	var z := 70.0
	var k := 0
	while z > 26.0:
		var q := Vector2(0.0, z)
		var y := P.ground(q)
		var a := _wall_at(out, q, Vector2(-1, 0), 7.0)
		var b := _wall_at(out, q, Vector2(1, 0), 7.0)
		if z < 66.0:
			bunting(mb, M.v3(a, y + 6.6), M.v3(b, y + 6.4), rng)
		var side := -1.0 if k % 2 == 0 else 1.0
		var wall := a if side < 0.0 else b
		var lt := M.xf(M.v3(wall, y + 3.2), M.yaw_of(Vector2(-side, 0)))
		_lantern(mb, lt)
		if k % 2 == 0:
			_light(out, lt * Vector3(0, 0, 0.6), 1.3, 10.0)
		z -= 12.0
		k += 1
	var barrows := [["fruit", Vector2(-4.6, 62.0), Vector2(1, 0), "awning_red"], ["cloth", Vector2(4.6, 44.0), Vector2(-1, 0), "awning_blue"],
		["fish", Vector2(-4.6, 33.0), Vector2(1, 0), "awning_gold"]]
	for i in range(barrows.size()):
		var e: Array = barrows[i]
		var bq: Vector2 = e[1]
		var bw := KitStreet.barrow(e[0], CapitalStyle.STYLE["goods"], e[3], 501 + i)
		var t := M.xf(M.v3(bq, P.ground(bq)), M.yaw_of(e[2]))
		_spot(out, "barrow%d" % i, _q(t * (bw.get_node("Vendor") as Node3D).position), P.ground(bq), e[2])
		absorb(mb, cols, bw, t)
	# the sea gate's banners, and lamps on the quay side of it
	for s in [-1.0, 1.0]:
		_banner(mb, M.xf(M.v3(Vector2(s * 6.2, P.WALL_Z + 5.05), P.QUAY_Y + 11.5)), 1.6, 6.5, M.BLUE)
		_banner(mb, M.xf(M.v3(Vector2(s * 6.2, P.WALL_Z - 5.05), P.QUAY_Y + 11.0), PI), 1.3, 5.0, Color(0.62, 0.16, 0.14))
		_spot(out, "gate_guard%d" % int(s > 0.0), Vector2(s * 4.2, P.WALL_Z + 6.6), P.QUAY_Y, Vector2(0, 1))
	_piece(out, "Street", mb, cols)


# --------------------------------------------------------------------------
# The quay
# --------------------------------------------------------------------------
static func _quay(out: Dictionary) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	var rng := _rng(4201)
	var y := P.QUAY_Y
	# cargo in stacks along the harbour wall and by the cranes
	var stacks := [Vector2(-128, 86), Vector2(-96, 88), Vector2(-40, 86), Vector2(30, 86), Vector2(62, 87), Vector2(104, 86), Vector2(144, 88),
		Vector2(-70, 112), Vector2(84, 113), Vector2(-112, 114)]
	for sp in stacks:
		var n := rng.randi_range(4, 8)
		for i in range(n):
			var o := Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-1.6, 1.6))
			var item := Props.crate(rng.randf_range(0.7, 1.0)) if rng.randf() < 0.6 else Props.barrel()
			absorb(mb, cols, item, M.xf(M.v3(sp + o, y), rng.randf() * TAU))
		if rng.randf() < 0.6:
			absorb(mb, cols, Props.crate(0.8), M.xf(M.v3(sp, y + 0.85), rng.randf()))
	for cx in [-84.0, 96.0]:
		absorb(mb, cols, Buildings.dock_crane(), M.xf(M.v3(Vector2(cx, P.FRONT_Z - 2.6), y), 0.0))
	# the fish market: a long tiled roof on stone posts over three fish stalls, west of the gate
	var fm := Vector2(-36.0, 104.0)
	for i in range(3):
		var st := Buildings.stall("fish")
		var t := M.xf(M.v3(fm + Vector2(-6.0 + i * 6.0, 0.0), y), 0.0)
		_spot(out, "fish%d" % i, _q(t * (st.get_node("Vendor") as Node3D).position), y, Vector2(0, 1))
		absorb(mb, cols, st, t)
	for sx in [-10.0, -3.0, 3.0, 10.0]:
		for sz in [-2.4, 3.0]:
			mb.add_box(M.mat("lime"), M.xf(M.v3(fm + Vector2(sx, sz), y + 1.9)), Vector3(0.4, 3.8, 0.4), 0.6, Color(0.92, 0.9, 0.86))
			M.box(cols, M.xf(M.v3(fm + Vector2(sx, sz), y + 1.9)), Vector3(0.4, 3.8, 0.4))
	M._hip(mb, M.xf(M.v3(fm + Vector2(0, 0.3), y + 3.8)), 21.0, 6.4, 1.8, 0.5, Color.WHITE)
	for i in range(5):
		absorb(mb, cols, Props.fish_rack() if i % 2 == 0 else Props.net_pile(), M.xf(M.v3(Vector2(-58.0 + i * 3.4, 116.5), y), rng.randf_range(-0.3, 0.3)))
	for i in range(3):
		absorb(mb, cols, Props.rope_coil(), M.xf(M.v3(Vector2(-20.0 + i * 25.0, 118.5), y), rng.randf() * TAU))
	# the harbourmaster's booth by the berth
	var hm := Vector2(48.0, 112.0)
	mb.add_box(M.mat("wash"), M.xf(M.v3(hm, y + 1.4)), Vector3(3.2, 2.8, 2.6), 0.5, Color(0.98, 0.95, 0.88))
	M._hip(mb, M.xf(M.v3(hm, y + 2.8)), 3.2, 2.6, 1.0, 0.35, Color.WHITE)
	mb.add_box_unit_uv(M.mat("window"), M.xf(M.v3(hm + Vector2(0, 1.32), y + 1.5)), Vector3(1.4, 1.0, 0.04))
	M.box(cols, M.xf(M.v3(hm, y + 1.4)), Vector3(3.2, 2.8, 2.6))
	_spot(out, "harbourmaster", hm + Vector2(0, 2.4), y, Vector2(0, 1))
	# lamps along the quay's edge, and boats tied up in the basin
	for i in range(5):
		var lq := Vector2(-110.0 + i * 55.0, P.FRONT_Z - 3.2)
		lamp_post(mb, cols, lq, y)
		if i % 2 == 0:
			_light(out, M.v3(lq, y + 3.5), 1.7, 12.0)
	for bq in [Vector2(-92, 126), Vector2(-88.5, 127), Vector2(-60, 125.6), Vector2(78, 126), Vector2(112, 125.8)]:
		var b := Props.rowboat()
		absorb(mb, [], b, M.xf(M.v3(bq, -0.15), PI * 0.5 + rng.randf_range(-0.2, 0.2)))
	_light(out, M.v3(P.MOLE_E[2], P.MOLE_Y + 28.8), 3.0, 40.0, true)
	_spot(out, "dock", Vector2(P.BERTH.x - 6.0, P.FRONT_Z - 2.5), y, Vector2(0, 1))
	for i in range(4):
		_spot(out, "porter%d" % i, Vector2(-40.0 + i * 46.0, 95.0), y, Vector2(1, 0))
	_piece(out, "Harbour", mb, cols)


# --------------------------------------------------------------------------
# The avenue, the arena street
# --------------------------------------------------------------------------
static func _avenue(out: Dictionary) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	var rng := _rng(4301)
	var lime := M.mat("lime")
	var z := -28.0
	var k := 0
	while z > -60.0:
		for s in [-1.0, 1.0]:
			var q := Vector2(s * 5.6, z)
			var y := P.ground(q)
			if k % 2 == 0:
				mb.add_box(lime, M.xf(M.v3(q, y + 0.8)), Vector3(1.4, 1.6, 1.4), 0.6, Color(0.9, 0.88, 0.84))
				mb.add_box(lime, M.xf(M.v3(q, y + 1.68)), Vector3(1.6, 0.16, 1.6), 0.6, Color(0.95, 0.93, 0.9), false)
				_figure(mb, M.xf(M.v3(q, y + 1.76), M.yaw_of(Vector2(-s, 0))), 2.4, k % 4 == 0)
				M.box(cols, M.xf(M.v3(q, y + 1.6)), Vector3(1.4, 3.2, 1.4))
			else:
				mb.add_cylinder(lime, M.xf(M.v3(q, y)), 0.8, 0.8, 0.5, 8, 0.6, Color(0.92, 0.9, 0.86), true)
				M.cypress(mb, M.v3(q, y + 0.4), rng.randf_range(5.5, 7.0), rng)
				M.cyl(cols, M.v3(q, y), 0.8, 2.0)
		z -= 7.5
		k += 1
	for s in [-1.0, 1.0]:
		var lq := Vector2(s * 5.6, -58.5)
		lamp_post(mb, cols, lq, P.ground(lq))
		_light(out, M.v3(lq, P.ground(lq) + 3.5), 1.6, 11.0)
		_spot(out, "palace_guard%d" % int(s > 0.0), Vector2(s * 3.4, P.PALACE_GATE.y + 6.4), P.ground(Vector2(0, P.PALACE_GATE.y + 6.4)), Vector2(0, 1))
	# the arena street: posters on the walls, a shuttered booth by the arena's gate, banners
	var ay := P.PLAZA_Y
	var booth := Vector2(62.0, -4.6)
	mb.add_box(M.mat("dark"), M.xf(M.v3(booth, ay + 1.3)), Vector3(2.0, 2.6, 1.6), 1.0, Color(0.6, 0.48, 0.36))
	mb.add_box(M.mat("roof"), M.xf(M.v3(booth, ay + 2.7)), Vector3(2.4, 0.15, 2.0), 0.6, Color.WHITE, false)
	mb.add_box(PSXMat.lit("planks", Color(0.5, 0.42, 0.3)), M.xf(M.v3(booth + Vector2(0, 0.82), ay + 1.4), 0.0), Vector3(1.4, 0.9, 0.05), 1.0, Color.WHITE, false)
	M.box(cols, M.xf(M.v3(booth, ay + 1.3)), Vector3(2.0, 2.6, 1.6))
	_spot(out, "arena_crier", booth + Vector2(-1.8, 1.6), ay, Vector2(-1, 0))
	var paper := [Color(0.92, 0.86, 0.66), Color(0.86, 0.3, 0.22), Color(0.94, 0.9, 0.8)]
	for i in range(8):
		var s := -1.0 if i % 2 == 0 else 1.0
		var px := 30.0 + i * 4.3
		var wall := _wall_at(out, Vector2(px, 0.0), Vector2(0, s), 7.5)
		var t := M.xf(M.v3(wall, ay + 1.8), M.yaw_of(Vector2(0, -s)))
		mb.add_box(PSXMat.flat(paper[i % 3]), t * Transform3D(Basis(Vector3.BACK, rng.randf_range(-0.1, 0.1)), Vector3(0, 0, 0.02)), Vector3(0.8, 1.1, 0.02), 1.0, Color.WHITE, false)
		mb.add_box(PSXMat.flat(Color(0.2, 0.15, 0.12)), t * Transform3D(Basis(), Vector3(0, 0.25, 0.035)), Vector3(0.5, 0.18, 0.01), 1.0, Color.WHITE, false)
	var lq2 := Vector2(46.0, 4.6)
	lamp_post(mb, cols, lq2, ay)
	_piece(out, "Avenue", mb, cols)


# --------------------------------------------------------------------------
# The slum: the alley and the yard
# --------------------------------------------------------------------------
static func _slum(out: Dictionary) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	var rng := _rng(4401)
	# laundry strung across the alley, and over the yard between its shacks
	var x := -12.0
	while x > -46.0:
		var a := _wall_at(out, Vector2(x, 52.0), Vector2(0, -1), 4.0)
		var b := _wall_at(out, Vector2(x, 52.0), Vector2(0, 1), 4.0)
		var y := P.ground(Vector2(x, 52.0)) + 4.4 + rng.randf_range(0.0, 1.2)
		_washing(mb, M.v3(a, y), M.v3(b, y), rng)
		x -= 7.0
	for e in [[Vector2(-76.0, 48.0), Vector2(-66.0, 43.0)], [Vector2(-76.0, 60.0), Vector2(-64.0, 66.0)], [Vector2(-53.0, 58.0), Vector2(-62.0, 66.0)]]:
		var y := P.ground(e[0]) + 3.2
		_washing(mb, M.v3(e[0], y), M.v3(e[1], y - 0.3), rng)
	for i in range(9):
		var q := Vector2(rng.randf_range(-44.0, -10.0), 50.5 if i % 2 == 0 else 53.5)
		var item := Props.crate(0.6) if i % 3 == 0 else Props.barrel()
		absorb(mb, cols, item, M.xf(M.v3(q, P.ground(q)), rng.randf() * TAU))
	# the yard: lean-to shacks round its edges, a fire in a barrel, a broken cart, crates
	var yard: Rect2 = P.FLOORS[7][1]
	var shacks := [[Vector2(yard.position.x + 2.2, 44.0), Vector2(1, 0)], [Vector2(yard.position.x + 2.2, 56.0), Vector2(1, 0)],
		[Vector2(yard.position.x + 2.2, 65.0), Vector2(1, 0)], [Vector2(-60.0, yard.position.y + 2.0), Vector2(0, 1)], [Vector2(-52.5, 62.0), Vector2(-1, 0)]]
	for i in range(shacks.size()):
		_shack(mb, cols, shacks[i][0], shacks[i][1], _rng(4410 + i))
	var fire := Vector2(-63.0, 52.0)
	var fy := P.ground(fire)
	var barrel := Props.barrel()
	absorb(mb, cols, barrel, M.xf(M.v3(fire, fy)))
	for k in range(6):
		mb.add_blob(M.mat("glow"), M.xf(M.v3(fire + Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2)), fy + 1.0 + k * 0.08)), Vector3(0.18, 0.22, 0.18) * (1.0 - k * 0.12), rng, 0.3, 2, 4, 1.0,
			Color(1.0, 0.6 + 0.06 * k, 0.25))
	_light(out, M.v3(fire, fy + 1.6), 1.8, 10.0)
	_spot(out, "fire", fire, fy, Vector2(1, 0))
	var cart := KitVillage.handcart()
	absorb(mb, cols, cart, M.xf(M.v3(Vector2(-71.0, 40.0), P.ground(Vector2(-71.0, 40.0))), 0.4) * Transform3D(Basis(Vector3.BACK, 0.2), Vector3.ZERO))
	for i in range(18):
		var q := Vector2(rng.randf_range(yard.position.x + 6.0, yard.end.x - 3.0), rng.randf_range(yard.position.y + 4.0, yard.end.y - 3.0))
		if q.distance_to(fire) < 5.0:
			continue
		var item := Props.crate(rng.randf_range(0.6, 0.9)) if i % 2 == 0 else Props.barrel()
		absorb(mb, cols, item, M.xf(M.v3(q, P.ground(q)), rng.randf() * TAU))
	for i in range(5):
		var a := TAU * i / 5.0 + 0.3
		_spot(out, "ruffian%d" % i, fire + Vector2(cos(a), sin(a)) * rng.randf_range(2.4, 4.0), P.ground(fire), -Vector2(cos(a), sin(a)))
	_spot(out, "slum_door", Vector2(-20.0, 52.2), P.ground(Vector2(-20.0, 52.2)), Vector2(0, -1))
	_piece(out, "Slum", mb, cols)


## A washing line from a to b hung with shirts and sheets, each hanging along the line.
static func _washing(mb: MeshBuilder, a: Vector3, b: Vector3, rng: RandomNumberGenerator) -> void:
	var cloth := PSXMat.lit("canvas")
	var washing: Array = CapitalStyle.STYLE["pennants"]
	var pts := MeshBuilder.sag_points(a, b, 0.3, 8)
	mb.add_tube(PSXMat.lit("rope"), pts, 0.015, -1.0, 3)
	var along := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
	var n := Vector3(along.z, 0, -along.x)
	for i in range(1, pts.size() - 1, 2):
		var p: Vector3 = pts[i]
		var w := rng.randf_range(0.4, 0.8)
		var h := rng.randf_range(0.5, 0.9)
		var c: Color = (washing[rng.randi() % washing.size()] as Color).lerp(Color(0.85, 0.82, 0.75), 0.4)
		var l := p - along * w * 0.5
		var r := p + along * w * 0.5
		mb.add_quad(cloth, l, r, r + Vector3(0, -h, 0) + n * 0.02, l + Vector3(0, -h, 0) + n * 0.02, Vector2.ZERO, Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), c, n)
		mb.add_quad(cloth, l, l + Vector3(0, -h, 0) + n * 0.02, r + Vector3(0, -h, 0) + n * 0.02, r, Vector2.ZERO, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), c * 0.8, -n)


## A lean-to shack of grey boards against the yard's edge, a tarp for a door (`face` out into the yard).
static func _shack(mb: MeshBuilder, cols: Array, q: Vector2, face: Vector2, rng: RandomNumberGenerator) -> void:
	var y := P.ground(q)
	var t := M.xf(M.v3(q, y), M.yaw_of(face))
	var w := rng.randf_range(3.0, 4.2)
	var d := rng.randf_range(2.4, 3.2)
	var boards := PSXMat.lit("planks_weathered")
	var dark := M.mat("dark")
	mb.add_box(boards, t * Transform3D(Basis(), Vector3(0, 1.1, -d * 0.5)), Vector3(w, 2.2 + 0.6, 0.12), 1.0, Color(0.8, 0.78, 0.74))
	for s in [-1.0, 1.0]:
		mb.add_box(boards, t * Transform3D(Basis(), Vector3(s * w * 0.5, 1.0, 0)), Vector3(0.12, 2.0, d), 1.0, Color(0.85, 0.82, 0.78))
		mb.add_box(dark, t * Transform3D(Basis(), Vector3(s * (w * 0.5 - 0.05), 1.1, d * 0.5)), Vector3(0.14, 2.2, 0.14), 1.0)
	Buildings.add_shed_roof(mb, PSXMat.lit("planks_weathered", Color(0.7, 0.66, 0.6)), boards, t * Transform3D(Basis(), Vector3(0, 2.1, 0)), w, d, 0.6, 0.25)
	var tarp := PSXMat.lit("canvas", Color(0.62, 0.52, 0.4))
	mb.add_quad(tarp, t * Vector3(-w * 0.32, 2.0, d * 0.5 + 0.02), t * Vector3(w * 0.12, 2.0, d * 0.5 + 0.02), t * Vector3(w * 0.15, 0.05, d * 0.5 + 0.3), t * Vector3(-w * 0.3, 0.05, d * 0.5 + 0.1),
		Vector2.ZERO, Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Color.WHITE, (t.basis * Vector3.BACK).normalized())
	M.box(cols, t * Transform3D(Basis(), Vector3(0, 1.2, 0)), Vector3(w, 2.4, d))


# --------------------------------------------------------------------------
# The docks (1.21, docs/v1_21_plan.md): the warehouse row, the wharf, the shipwright's hall, the chandler, the fence
# --------------------------------------------------------------------------
const WAREHOUSE := [Color(0.86, 0.72, 0.56), Color(0.78, 0.62, 0.48), Color(0.9, 0.8, 0.66), Color(0.74, 0.66, 0.58)]


## A warehouse on a docks lot: plastered brick under a timber band, a tall gable, big double doors at the street, a
## loading door upstairs with a hoist beam and its hook. Returns its door like townhouse().
static func warehouse(mb: MeshBuilder, cols: Array, l: Dictionary) -> Dictionary:
	var fr := lot_frame(l)
	var t: Transform3D = fr[0]
	var w: float = fr[1]
	var d: float = fr[2]
	var gs := _ground_span(l["r"])
	var low := gs.x - 0.5
	var top := gs.y
	var rng := _rng(int(l["seed"]))
	var col: Color = WAREHOUSE[rng.randi() % WAREHOUSE.size()]
	var wash := M.mat("wash")
	var lime := M.mat("lime")
	var dark := PSXMat.lit("planks_dark")
	var floors := clampi(int(l["floors"]), 2, 3)
	var sill := top + 0.2
	var eaves := sill + 4.4 + float(floors - 1) * 3.2
	var hw := w * 0.5
	var hd := d * 0.5
	mb.add_box(lime, t * Transform3D(Basis(), Vector3(0, (low + sill) * 0.5, 0)), Vector3(w + 0.1, sill - low, d + 0.1), 0.5, Color(0.86, 0.84, 0.8), true, true)
	mb.add_box(wash, t * Transform3D(Basis(), Vector3(0, (sill + eaves) * 0.5, 0)), Vector3(w, eaves - sill, d), 0.5, col, true, true)
	for y in [sill + 4.4, eaves - 0.15]:
		mb.add_box(dark, t * Transform3D(Basis(), Vector3(0, y, 0)), Vector3(w + 0.12, 0.3, d + 0.12), 0.8, Color(0.8, 0.72, 0.62), false)
	for s in [-1.0, 1.0]:
		mb.add_box(dark, t * Transform3D(Basis(), Vector3(s * (hw - 0.12), (sill + eaves) * 0.5, hd + 0.04)), Vector3(0.28, eaves - sill, 0.12), 0.8, Color(0.8, 0.72, 0.62))
	M.roof(mb, "gable", t, w, d, eaves, M.ROOFS[rng.randi() % M.ROOFS.size()], rng)
	var cell: Rect2 = l["cell"]
	M.box(cols, M.xf(M.v3(cell.get_center(), (low + eaves) * 0.5)), Vector3(cell.size.x, eaves - low, cell.size.y))
	Occluders.box(cols, t * Transform3D(Basis(), Vector3(0, (low + eaves) * 0.5, -0.2)), Vector3(w, eaves - low, d - 0.4))
	# the cart doors, the loading door over them, the hoist
	var dw := minf(3.0, w - 1.6)
	Buildings.panel_door(mb, t * Transform3D(Basis(), Vector3(0, sill, hd + 0.03)), dw, 3.4, Buildings.door_leaf(DOORS[(int(l["seed"]) >> 5) % DOORS.size()]), lime)
	var ly := sill + 4.4 + 0.5
	mb.add_box(dark, t * Transform3D(Basis(), Vector3(0, ly + 1.1, hd + 0.04)), Vector3(1.5, 2.2, 0.08), 1.0, Color(0.55, 0.45, 0.36))
	var beam_y := eaves - 0.6
	mb.add_box(dark, t * Transform3D(Basis(), Vector3(0, beam_y, hd + 0.7)), Vector3(0.24, 0.24, 1.6), 1.0, Color(0.7, 0.62, 0.52), false)
	var hook := t * Vector3(0, beam_y - 0.1, hd + 1.35)
	mb.add_tube(PSXMat.lit("rope"), PackedVector3Array([hook, hook + Vector3.DOWN * rng.randf_range(1.5, 3.0)]), 0.025, 0.025, 3, 1.0)
	if rng.randf() < 0.5:
		absorb(mb, cols, Props.crate(0.7), t * Transform3D(Basis(Vector3.UP, rng.randf()), Vector3(hw - 0.9, top, hd + 0.9)))
	return {"at": t * Vector3(0, top, hd + 0.9), "face": (Vector2((t.basis * Vector3.BACK).x, (t.basis * Vector3.BACK).z)).normalized(), "kind": "warehouse"}


static func _docks(out: Dictionary) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	var rng := _rng(7713)
	var lane: Rect2 = P.FLOORS[9][1]
	var wharf: Rect2 = P.FLOORS[10][1]
	# cargo along the lane's edges, kept off the doors, and the handcarts
	for i in range(9):
		var q := Vector2(lane.position.x + 10.0 + i * 12.5, lane.position.y + (1.4 if i % 2 == 0 else lane.size.y - 1.4))
		if _door_near(out, q, 2.6):
			continue
		var y := P.ground(q)
		for k in range(rng.randi_range(2, 4)):
			var item := Props.crate(rng.randf_range(0.65, 0.9)) if rng.randf() < 0.6 else Props.barrel()
			absorb(mb, cols, item, M.xf(M.v3(q + Vector2(rng.randf_range(-1.4, 1.4), rng.randf_range(-0.5, 0.5)), y), rng.randf() * TAU))
	for q in [Vector2(40.0, 57.0), Vector2(92.0, 58.5)]:
		_handcart(mb, cols, M.xf(M.v3(q, P.ground(q)), rng.randf_range(-0.4, 0.4)), rng)
	# the wharf: timber stacks, rope, a capstan, the shipwright's hall with a hull on its stocks, the chandler, the fence
	for j in range(3):
		var tq := Vector2(wharf.position.x + 3.5, wharf.position.y + 6.0 + j * 4.0)
		for k in range(5 - j):
			var lt := M.xf(M.v3(tq + Vector2(0, (k - 2) * 0.42), P.ground(tq) + 0.22 + float(j % 2) * 0.0), 0.0) * Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO)
			mb.add_cylinder(PSXMat.lit("bark"), lt * Transform3D(Basis(), Vector3(0, -2.6, 0)), 0.2, 0.19, 5.2, 6, 0.6)
		M.box(cols, M.xf(M.v3(tq, P.ground(tq) + 0.45)), Vector3(5.2, 0.9, 2.2))
	for i in range(3):
		var rq := wharf.position + Vector2(9.0 + i * 2.2, 33.0)
		absorb(mb, cols, Props.rope_coil(), M.xf(M.v3(rq, P.ground(rq)), rng.randf() * TAU))
	_yard_hall(out, mb, cols)
	_chandler(out, mb, cols, rng)
	_fence(out, mb, cols, rng)
	var lq := Vector2(wharf.position.x + 11.0, wharf.position.y + 20.0)
	lamp_post(mb, cols, lq, P.ground(lq))
	_light(out, M.v3(lq, P.ground(lq) + 3.5), 1.6, 12.0)
	lamp_post(mb, cols, Vector2(64.0, lane.position.y + 1.0), P.ground(Vector2(64.0, lane.position.y + 1.0)))
	# the people's places
	for i in range(3):
		var q := Vector2(24.0 + i * 36.0, lane.get_center().y + (1.5 if i % 2 == 0 else -1.5))
		_spot(out, "docker%d" % i, q, P.ground(q), Vector2(1, 0) if i % 2 == 0 else Vector2(-1, 0))
	var fq := Vector2(wharf.position.x + 8.0, wharf.end.y - 4.0)
	_spot(out, "foreman", fq, P.ground(fq), Vector2(-1, 0))
	var mq := Vector2(wharf.position.x + 2.6, wharf.position.y + 2.4)
	_spot(out, "manifest", mq, P.ground(mq), Vector2(1, 0))
	_piece(out, "Docks", mb, cols)


## Is a town house's or warehouse's doorstep within r of q?
static func _door_near(out: Dictionary, q: Vector2, r: float) -> bool:
	for d in out["doors"]:
		if _q(d["at"]).distance_to(q) < r:
			return true
	return false


## A two-wheeled handcart with a sack or two (frame `t` at its middle, +z its handles).
static func _handcart(mb: MeshBuilder, cols: Array, t: Transform3D, rng: RandomNumberGenerator) -> void:
	var wood := PSXMat.lit("planks")
	var dark := PSXMat.lit("planks_dark")
	mb.add_box(wood, t * Transform3D(Basis(), Vector3(0, 0.7, 0)), Vector3(1.2, 0.08, 1.6), 1.0, Color.WHITE, false)
	for s in [-1.0, 1.0]:
		mb.add_box(wood, t * Transform3D(Basis(), Vector3(s * 0.6, 0.9, 0)), Vector3(0.06, 0.35, 1.6), 1.0)
		mb.add_cylinder(dark, t * Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(s * 0.68, 0.45, -0.1)), 0.45, 0.45, 0.08, 10, 1.0, Color.WHITE, true, true)
		mb.add_box(dark, t * Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(s * 0.42, 0.55, 1.35)), Vector3(0.06, 0.06, 1.2), 1.0)
	for k in range(rng.randi_range(1, 3)):
		var sk := MeshInstance3D.new()
		sk.mesh = Props.sack_mesh()
		var holder := Node3D.new()
		holder.add_child(sk)
		absorb(mb, [], holder, t * Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(rng.randf_range(-0.3, 0.3), 0.74, -0.4 + k * 0.45)))
	M.box(cols, t * Transform3D(Basis(), Vector3(0, 0.6, 0)), Vector3(1.4, 1.2, 1.8))


## The capital shipwright's hall: a long open-fronted boathouse of timber on a stone footing, a hull's ribs on the
## stocks inside, the shipwright's place at its mouth (spot "shipwright").
static func _yard_hall(out: Dictionary, mb: MeshBuilder, cols: Array) -> void:
	var sp: Array = P.SPECIAL["yardhall"]
	var r: Rect2 = sp[0]
	var l := {"r": r, "cell": r, "c": r.get_center(), "face": sp[1], "seed": 4417, "floors": 2, "roof": "gable"}
	var fr := lot_frame(l)
	var t: Transform3D = fr[0]
	var w: float = fr[1]
	var d: float = fr[2]
	var gs := _ground_span(r)
	var top := gs.y
	var low := gs.x - 0.5
	var dark := PSXMat.lit("planks_dark")
	var planks := PSXMat.lit("planks_weathered")
	var lime := M.mat("lime")
	var h := 8.5
	mb.add_box(lime, t * Transform3D(Basis(), Vector3(0, (low + top) * 0.5, 0)), Vector3(w + 0.1, top - low + 0.05, d + 0.1), 0.5, Color(0.86, 0.84, 0.8), true, true)
	M.box(cols, t * Transform3D(Basis(), Vector3(0, (low + top) * 0.5, 0)), Vector3(w, top - low + 0.05, d))
	# back and side walls of boards, the front open between posts
	mb.add_box(planks, t * Transform3D(Basis(), Vector3(0, top + h * 0.5, -d * 0.5 + 0.15)), Vector3(w, h, 0.3), 0.5, Color(0.9, 0.85, 0.78))
	for s in [-1.0, 1.0]:
		mb.add_box(planks, t * Transform3D(Basis(), Vector3(s * (w * 0.5 - 0.15), top + h * 0.5, 0)), Vector3(0.3, h, d), 0.5, Color(0.86, 0.8, 0.72))
		M.box(cols, t * Transform3D(Basis(), Vector3(s * (w * 0.5 - 0.15), top + h * 0.5, 0)), Vector3(0.3, h, d))
	M.box(cols, t * Transform3D(Basis(), Vector3(0, top + h * 0.5, -d * 0.5 + 0.15)), Vector3(w, h, 0.3))
	for k in range(4):
		var x := -w * 0.5 + 0.3 + (w - 0.6) * k / 3.0
		mb.add_box(dark, t * Transform3D(Basis(), Vector3(x, top + h * 0.5, d * 0.5 - 0.2)), Vector3(0.4, h, 0.4), 0.8)
		M.box(cols, t * Transform3D(Basis(), Vector3(x, top + h * 0.5, d * 0.5 - 0.2)), Vector3(0.4, h, 0.4))
	mb.add_box(dark, t * Transform3D(Basis(), Vector3(0, top + h - 0.2, d * 0.5 - 0.2)), Vector3(w, 0.4, 0.45), 0.8, Color.WHITE, false)
	M.roof(mb, "gable", t, w, d, top + h, Color(0.86, 0.8, 0.76), _rng(4418))
	Occluders.box(cols, t * Transform3D(Basis(), Vector3(0, top + h * 0.5, -d * 0.5 + 0.15)), Vector3(w, h, 0.3))
	# the hull on its stocks: a keel along the hall's depth, ribs curving up from it, a stem post
	var keel_y := top + 1.1
	var kl := d - 5.0
	mb.add_box(dark, t * Transform3D(Basis(), Vector3(0, keel_y, -0.6)), Vector3(0.35, 0.35, kl), 0.8)
	for k in range(4):
		mb.add_box(lime, t * Transform3D(Basis(), Vector3(0, top + 0.45, -0.6 - kl * 0.4 + kl * 0.8 * k / 3.0)), Vector3(1.2, 0.9, 0.6), 0.6, Color(0.8, 0.78, 0.74))
	var ribs := 9
	for k in range(ribs):
		var z := -0.6 - kl * 0.42 + kl * 0.84 * k / float(ribs - 1)
		var beam := 2.4 * sin(PI * (0.15 + 0.7 * k / float(ribs - 1)))
		for s in [-1.0, 1.0]:
			var a := t * Vector3(0, keel_y, z)
			var b := t * Vector3(s * beam, keel_y + 3.6, z)
			mb.add_tube(dark, MeshBuilder.curve_points(a, t * Vector3(s * beam * 1.15, keel_y + 0.8, z), b, 5), 0.11, 0.09, 4, 1.0)
	mb.add_tube(dark, MeshBuilder.curve_points(t * Vector3(0, keel_y, -0.6 + kl * 0.5), t * Vector3(0, keel_y + 1.0, -0.6 + kl * 0.5 + 1.4), t * Vector3(0, keel_y + 4.4, -0.6 + kl * 0.5 + 1.6), 5),
		0.16, 0.12, 4, 1.0)
	M.box(cols, t * Transform3D(Basis(), Vector3(0, keel_y + 1.6, -0.6)), Vector3(5.2, 3.2, kl))
	_lantern(mb, t * Transform3D(Basis(), Vector3(-w * 0.5 + 0.8, top + 3.0, d * 0.5 + 0.02)))
	var sign := t * Transform3D(Basis(), Vector3(w * 0.5 - 1.2, top + 4.0, d * 0.5 + 0.02))
	_sign(mb, sign, "chart", _rng(4419))
	_spot(out, "shipwright", _q(t * Vector3(-2.2, 0, d * 0.5 + 1.6)), top, _fd(t))
	_spot(out, "shipwright_hand", _q(t * Vector3(4.2, 0, 1.0)), top, Vector2((t.basis * Vector3.RIGHT).x, (t.basis * Vector3.RIGHT).z))


## The chandler's counter by the wharf's west edge: rope, tar and lanterns under a canvas awning (spot "chandler").
static func _chandler(out: Dictionary, mb: MeshBuilder, cols: Array, rng: RandomNumberGenerator) -> void:
	var wharf: Rect2 = P.FLOORS[10][1]
	var q := Vector2(wharf.position.x + 1.6, wharf.position.y + 26.0)
	var y := P.ground(q)
	var t := M.xf(M.v3(q, y), M.yaw_of(Vector2(1, 0)))
	mb.add_box(PSXMat.lit("planks_dark"), t * Transform3D(Basis(), Vector3(0, 0.5, 0.6)), Vector3(3.0, 1.0, 0.8), 1.0, Color(0.75, 0.65, 0.55))
	M.box(cols, t * Transform3D(Basis(), Vector3(0, 0.5, 0.6)), Vector3(3.0, 1.0, 0.8))
	for k in range(3):
		absorb(mb, cols, Props.rope_coil(), t * Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(-1.0 + k * 1.0, 1.0, 0.6)))
	absorb(mb, cols, Props.barrel(), t * Transform3D(Basis(), Vector3(-1.9, 0, -0.2)))
	_awning(mb, t * Transform3D(Basis(), Vector3(0, 2.6, -0.4)), 3.6, 1.8, "awning_blue")
	for s in [-1.0, 1.0]:
		mb.add_box(PSXMat.lit("planks_dark"), t * Transform3D(Basis(), Vector3(s * 1.7, 1.3, -0.4)), Vector3(0.12, 2.6, 0.12), 1.0)
	_spot(out, "chandler", _q(t * Vector3(0, 0, -0.3)), y, Vector2(1, 0))


## The fence's corner at the wharf's back: a stack of crates for a counter under a patched tarp, a lantern, a cellar
## hatch (spot "fence", the smugglers about it).
static func _fence(out: Dictionary, mb: MeshBuilder, cols: Array, rng: RandomNumberGenerator) -> void:
	var wharf: Rect2 = P.FLOORS[10][1]
	var q := Vector2(wharf.end.x - 2.0, wharf.position.y + 4.0)
	var y := P.ground(q)
	var t := M.xf(M.v3(q, y), M.yaw_of(Vector2(-1, 0)))
	for k in range(3):
		absorb(mb, cols, Props.crate(0.85), t * Transform3D(Basis(Vector3.UP, rng.randf_range(-0.2, 0.2)), Vector3(-1.0 + k * 0.95, 0, 0.9)))
	mb.add_box(PSXMat.lit("fabric", Color(0.3, 0.12, 0.1)), t * Transform3D(Basis(), Vector3(0, 0.88, 0.9)), Vector3(2.8, 0.03, 0.9), 1.0)
	_awning(mb, t * Transform3D(Basis(), Vector3(0, 2.5, -0.6)), 3.4, 2.0, "awning_red")
	for s in [-1.0, 1.0]:
		mb.add_box(PSXMat.lit("planks_dark"), t * Transform3D(Basis(), Vector3(s * 1.6, 1.25, -0.6)), Vector3(0.12, 2.5, 0.12), 1.0)
	_lantern(mb, t * Transform3D(Basis(), Vector3(1.6, 2.0, -0.55)))
	mb.add_box(PSXMat.lit("planks_dark"), t * Transform3D(Basis(), Vector3(-2.6, 0.04, -0.4)), Vector3(1.2, 0.08, 1.2), 1.0, Color(0.5, 0.42, 0.34), false)
	# (where the Queen's signet lies hidden: the palace's quest line)
	_spot(out, "signet", _q(t * Vector3(-2.6, 0, -0.4)), y, _fd(t))
	_spot(out, "fence", _q(t * Vector3(0, 0, -0.1)), y, _fd(t))
	for i in range(2):
		_spot(out, "smuggler%d" % i, _q(t * Vector3(-2.4 + i * 4.6, 0, 1.9 + i * 0.6)), y, -_fd(t))


# --------------------------------------------------------------------------
# The noble quarter's terrace (1.21): grand houses, the outfitter, cypresses and a garden fountain, lamps
# --------------------------------------------------------------------------
static func _terrace(out: Dictionary) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	var rng := _rng(8821)
	var ter: Rect2 = P.FLOORS[12][1]
	var cy := ter.get_center().y
	var lime := M.mat("lime")
	# cypresses in pairs down the middle, and stone planters between them
	for i in range(6):
		var x := ter.position.x + 10.0 + i * 15.0
		for s in [-1.0, 1.0]:
			var q := Vector2(x, cy + s * 3.4)
			M.cypress(mb, M.v3(q, P.ground(q)), rng.randf_range(6.5, 8.0), rng)
			M.cyl(cols, M.v3(q, P.ground(q)), 0.5, 3.0)
		if i % 2 == 1:
			var pq := Vector2(x + 7.5, cy)
			var py := P.ground(pq)
			mb.add_box(lime, M.xf(M.v3(pq, py + 0.35)), Vector3(3.2, 0.7, 1.2), 0.6, Color(0.92, 0.9, 0.86))
			for k in range(6):
				mb.add_blob(PSXMat.flat(Color.WHITE), M.xf(M.v3(pq + Vector2(-1.25 + k * 0.5, rng.randf_range(-0.3, 0.3)), py + 0.85)), Vector3(0.28, 0.22, 0.28), rng, 0.3, 2, 5, 1.0,
					[Color(0.86, 0.3, 0.38), Color(0.95, 0.85, 0.4), Color(0.75, 0.55, 0.85), Color(0.4, 0.6, 0.3)][k % 4])
			M.box(cols, M.xf(M.v3(pq, py + 0.35)), Vector3(3.2, 0.7, 1.2))
	# clipped hedges along both edges, the gardens' fronts (gaps at every door, the outfitter's porch and the step)
	var hedge := PSXMat.lit("leaves", Color(0.42, 0.6, 0.38))
	var porch: Rect2 = (P.SPECIAL["outfitter"][0] as Rect2).grow_individual(0.0, 4.0, 0.0, 0.0)
	for s in [-1.0, 1.0]:
		var x := ter.position.x + 1.2
		while x < ter.end.x - 1.0:
			var q := Vector2(x, ter.get_center().y + s * (ter.size.y * 0.5 - 0.55))
			x += 2.0
			if _door_near(out, q, 2.4) or porch.has_point(q) or (s > 0.0 and q.x < ter.position.x + 3.0):
				continue
			var hy := P.ground(q)
			mb.add_box(hedge, M.xf(M.v3(q, hy + 0.55)), Vector3(2.0, 1.1, 1.0), 0.8, Color(0.9, 0.95, 0.9) * rng.randf_range(0.88, 1.0))
			M.box(cols, M.xf(M.v3(q, hy + 0.55)), Vector3(2.0, 1.1, 1.0))
	# the garden fountain at the terrace's middle: a round basin and a figure
	var fq := Vector2(ter.position.x + ter.size.x * 0.5 + 0.5, cy)
	var fy := P.ground(fq)
	mb.add_cylinder(lime, M.xf(M.v3(fq, fy)), 2.6, 2.6, 0.7, 14, 0.5, Color(0.94, 0.92, 0.88), true, false)
	mb.add_cylinder(PSXMat.flat(Color(0.3, 0.5, 0.6)), M.xf(M.v3(fq, fy + 0.6)), 2.3, 2.3, 0.02, 14, 0.5)
	mb.add_cylinder(lime, M.xf(M.v3(fq, fy + 0.6)), 0.35, 0.3, 1.2, 8, 0.5, Color(0.92, 0.9, 0.86))
	_figure(mb, M.xf(M.v3(fq, fy + 1.8), PI), 2.0, false)
	M.cyl(cols, M.v3(fq, fy), 2.6, 0.9)
	# lamps, one lit
	for i in range(2):
		var lq := Vector2(ter.position.x + 22.0 + i * 46.0, ter.position.y + 2.4)
		lamp_post(mb, cols, lq, P.ground(lq), PI * 0.5)
		if i == 0:
			_light(out, M.v3(lq, P.ground(lq) + 3.5), 1.5, 11.0)
	_outfitter(out, mb, cols)
	# the people's places: nobles strolling the terrace, a footman, a guard at the step
	for i in range(4):
		var q := Vector2(ter.position.x + 16.0 + i * 19.0, cy + (5.6 if i % 2 == 0 else -5.6))
		_spot(out, "noble%d" % i, q, P.ground(q), Vector2(1, 0) if i % 2 == 0 else Vector2(-1, 0))
	var gq := Vector2(ter.position.x + 2.2, ter.end.y - 2.0)
	_spot(out, "terrace_guard", gq, P.ground(gq), Vector2(-1, 0))
	_spot(out, "invitation", fq + Vector2(0, 3.4), fy, Vector2(0, -1))
	_piece(out, "Terrace", mb, cols)


## The outfitter's on the terrace: a three-storey town house with a tailor's front and a columned porch, its counter
## under the porch (spot "outfitter"): the rare-gear merchant.
static func _outfitter(out: Dictionary, mb: MeshBuilder, cols: Array) -> void:
	var sp: Array = P.SPECIAL["outfitter"]
	var r: Rect2 = sp[0]
	var l := {"r": r, "cell": r, "c": r.get_center(), "face": sp[1], "seed": 66121, "floors": 3, "roof": "hip"}
	var fr := lot_frame(l)
	var t: Transform3D = fr[0]
	var w: float = fr[1]
	var d: float = fr[2]
	var top := _ground_span(r).y
	var dd := townhouse(mb, cols, l, "tailor")
	var lime := M.mat("lime")
	for s in [-1.0, 1.0]:
		var c := t * Vector3(s * (w * 0.5 - 1.2), top, d * 0.5 + 2.2)
		mb.add_cylinder(lime, M.xf(c), 0.3, 0.26, 3.8, 8, 0.6, Color(0.98, 0.96, 0.93))
		M.cyl(cols, c, 0.3, 3.8)
	mb.add_box(lime, t * Transform3D(Basis(), Vector3(0, top + 3.95, d * 0.5 + 1.15)), Vector3(w - 1.4, 0.3, 2.6), 0.6, Color(0.95, 0.93, 0.9), false)
	var counter := t * Transform3D(Basis(), Vector3(w * 0.18, top, d * 0.5 + 1.0))
	mb.add_box(PSXMat.lit("planks_dark"), counter * Transform3D(Basis(), Vector3(0, 0.5, 0)), Vector3(2.2, 1.0, 0.7), 1.0, Color(0.6, 0.5, 0.42))
	mb.add_box(PSXMat.lit("fabric", Color(0.22, 0.2, 0.42)), counter * Transform3D(Basis(), Vector3(0, 1.01, 0)), Vector3(2.3, 0.03, 0.8), 1.0)
	M.box(cols, counter * Transform3D(Basis(), Vector3(0, 0.5, 0)), Vector3(2.2, 1.0, 0.7))
	_spot(out, "outfitter", _q(counter * Vector3(0, 0, -0.8)), top, _fd(t))
	out["spots"]["outfitter_door"] = [dd["at"], M.yaw_of(dd["face"])]


# --------------------------------------------------------------------------
# The palace (1.21): the throne hall's furnishings and the court before it
# --------------------------------------------------------------------------
static func _throne(out: Dictionary) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	var rng := _rng(9301)
	var lime := M.mat("lime")
	var t := M.xf(M.v3(P.HALL_C, 0.0))
	var fy := P.hall_floor()
	var iw := P.HALL_W * 0.5 - 0.8
	var idd := P.HALL_D * 0.5 - 0.8
	var ih := P.HALL_H - 0.4
	var red := PSXMat.lit("fabric", Color(0.56, 0.12, 0.12))
	# the carpet from the door to the dais
	mb.add_quad(red, t * Vector3(-1.5, fy + 0.03, idd), t * Vector3(1.5, fy + 0.03, idd), t * Vector3(1.5, fy + 0.03, -idd + 4.0), t * Vector3(-1.5, fy + 0.03, -idd + 4.0),
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 6), Vector2(0, 6), Color.WHITE, Vector3.UP)
	for s in [-1.0, 1.0]:
		mb.add_box(M.mat("gold"), t * Transform3D(Basis(), Vector3(s * 1.55, fy + 0.03, (idd + (-idd + 4.0)) * 0.5)), Vector3(0.1, 0.02, idd * 2.0 - 4.0), 1.0, Color.WHITE, false)
	# two rows of columns down the hall
	for s in [-1.0, 1.0]:
		for k in range(5):
			var z := -6.4 + k * 3.4
			var cp := t * Vector3(s * 6.0, fy, z)
			mb.add_cylinder(lime, M.xf(cp), 0.6, 0.52, ih, 10, 0.6, Color(0.98, 0.96, 0.93))
			mb.add_box(lime, M.xf(cp + Vector3(0, 0.2, 0)), Vector3(1.5, 0.4, 1.5), 0.6, Color(0.9, 0.88, 0.84))
			mb.add_box(lime, M.xf(cp + Vector3(0, ih - 0.3, 0)), Vector3(1.4, 0.5, 1.4), 0.6, Color(0.92, 0.9, 0.86), false)
			M.cyl(cols, cp, 0.6, ih)
	# the dais (three steps over a ramp) and the throne
	for k in range(3):
		var dw := 12.0 - k * 2.0
		# (step k's top at 0.3 (k + 1): the throne's floor at 0.9, the collider's)
		mb.add_box(lime, t * Transform3D(Basis(), Vector3(0, fy + 0.15 * (k + 1), -idd + 2.1 - k * 0.6)), Vector3(dw, 0.3 * (k + 1), 4.2 - k * 1.2), 0.6,
			Color(0.9 - k * 0.03, 0.88 - k * 0.03, 0.84 - k * 0.03))
	mb.add_quad(red, t * Vector3(-1.5, fy + 0.31, -idd + 4.2), t * Vector3(1.5, fy + 0.31, -idd + 4.2), t * Vector3(1.5, fy + 0.91, -idd + 1.8), t * Vector3(-1.5, fy + 0.91, -idd + 1.8),
		Vector2.ZERO, Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Color.WHITE, (t.basis * Vector3(0, 2.4, 0.6)).normalized())
	M.box(cols, t * Transform3D(Basis(), Vector3(0, fy + 0.45, -idd + 1.2)), Vector3(12.0, 0.9, 2.4))
	var r0 := t * Vector3(0, fy, -idd + 4.4)
	var r1 := t * Vector3(0, fy + 0.9, -idd + 2.4)
	M.box(cols, Transform3D(Basis.looking_at(r1 - r0, Vector3.UP), (r0 + r1) * 0.5) * Transform3D(Basis(), Vector3(0, -0.15, 0)), Vector3(8.0, 0.3, r0.distance_to(r1) + 0.2))
	var th := t * Transform3D(Basis(), Vector3(0, fy + 0.9, -idd + 0.9))
	var gold := M.mat("gold")
	mb.add_box(gold, th * Transform3D(Basis(), Vector3(0, 0.45, 0)), Vector3(1.6, 0.9, 1.2), 1.0)
	mb.add_box(red, th * Transform3D(Basis(), Vector3(0, 0.93, 0.05)), Vector3(1.3, 0.1, 1.0), 1.0)
	var back := PackedVector2Array([Vector2(-0.8, 0), Vector2(0.8, 0), Vector2(0.8, 2.4), Vector2(0.45, 2.9), Vector2(0.0, 3.4), Vector2(-0.45, 2.9), Vector2(-0.8, 2.4)])
	mb.add_extrude(gold, th * Transform3D(Basis(), Vector3(0, 0.9, -0.55)), back, 0.25, 1.0, Color.WHITE)
	mb.add_box(red, th * Transform3D(Basis(), Vector3(0, 2.2, -0.41)), Vector3(1.1, 2.2, 0.04), 1.0)
	for s in [-1.0, 1.0]:
		mb.add_box(gold, th * Transform3D(Basis(), Vector3(s * 0.75, 1.25, 0.1)), Vector3(0.14, 0.14, 1.1), 1.0, Color.WHITE, false)
	M.box(cols, th * Transform3D(Basis(), Vector3(0, 1.0, -0.2)), Vector3(1.6, 2.0, 1.4))
	# banners behind the throne and down the side walls, windows high on the walls
	for s in [-1.0, 1.0]:
		_banner(mb, t * Transform3D(Basis(), Vector3(s * 3.2, fy + ih - 1.0, -idd + 0.05)), 2.0, 7.5, M.BLUE)
		for k in range(4):
			var z := -6.0 + k * 4.4
			var wtx := t * Transform3D(Basis(Vector3.UP, -s * PI * 0.5), Vector3(s * (iw - 0.02), fy + 7.0, z))
			mb.add_box_unit_uv(M.mat("window"), wtx, Vector3(1.6, 3.6, 0.04))
			if k % 2 == 0:
				_banner(mb, t * Transform3D(Basis(Vector3.UP, -s * PI * 0.5), Vector3(s * (iw - 0.05), fy + 4.2, z + 2.2)), 1.2, 3.6, Color(0.62, 0.16, 0.14))
	# two chandeliers: a ring of candles on chains
	var glow := M.mat("glow")
	for z in [-3.0, 4.0]:
		var cc := t * Vector3(0, fy + ih - 4.0, z)
		mb.add_tube(M.mat("iron"), MeshBuilder.curve_points(cc + Vector3(-1.4, 0, 0), cc + Vector3(0, 0, 1.6), cc + Vector3(1.4, 0, 0), 6), 0.05, 0.05, 4, 1.0)
		mb.add_tube(M.mat("iron"), MeshBuilder.curve_points(cc + Vector3(1.4, 0, 0), cc + Vector3(0, 0, -1.6), cc + Vector3(-1.4, 0, 0), 6), 0.05, 0.05, 4, 1.0)
		mb.add_tube(M.mat("iron"), PackedVector3Array([cc, cc + Vector3(0, 4.0, 0)]), 0.04, 0.04, 3, 1.0)
		for k in range(8):
			var a := TAU * k / 8.0
			mb.add_blob(glow, M.xf(cc + Vector3(cos(a) * 1.4, 0.25, sin(a) * 1.4)), Vector3(0.09, 0.16, 0.09), rng, 0.0, 2, 4)
	_light(out, t * Vector3(0, fy + 8.0, -2.0), 2.4, 26.0, true)
	# where the court stands
	_spot(out, "queen", _q(t * Vector3(0, 0, -idd + 2.2)), fy + 0.9, _fd(t))
	for s in [-1.0, 1.0]:
		_spot(out, "hall_guard%d" % int(s > 0.0), _q(t * Vector3(s * 3.4, 0, idd - 1.2)), fy, _fd(t))
		_spot(out, "courtier%d" % int(s > 0.0), _q(t * Vector3(s * 9.0, 0, -1.0)), fy, Vector2(-s, 0))
	_piece(out, "ThroneHall", mb, cols)
	_court(out)


## The court between the palace's wings: statues on plinths, planters, its guards at the ring wall's gate.
static func _court(out: Dictionary) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	var rng := _rng(9302)
	var lime := M.mat("lime")
	var court: Rect2 = P.FLOORS[14][1]
	for s in [-1.0, 1.0]:
		var q := Vector2(s * 7.0, court.position.y + 14.0)
		var y := P.ground(q)
		mb.add_box(lime, M.xf(M.v3(q, y + 0.8)), Vector3(1.8, 1.6, 1.8), 0.6, Color(0.92, 0.9, 0.86))
		_figure(mb, M.xf(M.v3(q, y + 1.6), PI), 3.0, true)
		M.box(cols, M.xf(M.v3(q, y + 1.6)), Vector3(1.8, 3.2, 1.8))
		for k in range(3):
			var pq := Vector2(s * 8.2, court.position.y + 24.0 + k * 3.0)
			var py := P.ground(pq)
			mb.add_cylinder(M.mat("lime"), M.xf(M.v3(pq, py)), 0.6, 0.5, 0.7, 8, 0.6, Color(0.88, 0.62, 0.5), true, false)
			M.cypress(mb, M.v3(pq, py + 0.6), rng.randf_range(2.4, 3.2), rng)
			M.cyl(cols, M.v3(pq, py), 0.6, 1.4)
		_spot(out, "court_guard%d" % int(s > 0.0), Vector2(s * 3.6, court.end.y - 3.0), P.ground(Vector2(s * 3.6, court.end.y - 3.0)), Vector2(0, 1))
	var cq := Vector2(3.0, court.position.y + 6.0)
	_spot(out, "chamberlain", cq, P.ground(cq), Vector2(0, 1))
	_piece(out, "Court", mb, cols)
