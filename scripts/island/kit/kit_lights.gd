class_name KitLights
extends RefCounted
## Night lights on a budget: a lamp post here, lit after dark while the island's
## light budget (KitContext.take_light) lasts, dark after. Real lights cost; glow
## materials don't, so a dark post still glows.


## A lantern post at p (its lamp arm along local +X: `yaw` is the island yaw
## the arm points at minus PI/2). `energy` 0 = never lit.
static func post(ctx: KitContext, p: Vector2, yaw: float, footprint := 0.0, energy := 1.6, height := 2.6) -> Node3D:
	if ctx.style["props"]["lamp"] != "lantern_post":
		var sp := ctx.place(KitStyle.prop(ctx.style, "lamp", ctx.rng(int(p.x * 31.0 + p.y * 17.0)), height / 2.4), p, yaw, footprint)
		if energy > 0.0:
			light(ctx, sp, sp.get_node("Flame").position, energy)
		return sp
	var lp := ctx.place(Props.lantern_post(height), p, yaw, footprint)
	if energy > 0.0:
		light(ctx, lp, Vector3(0.55, 2.0, 0.0), energy)
	return lp


## A NightLight on `node` at its local `at`, from the budget (none once it's spent).
static func light(ctx: KitContext, node: Node3D, at: Vector3, energy: float, light_range := -1.0) -> NightLight:
	if not ctx.take_light():
		return null
	var nl := NightLight.make(ctx.style["lamp"], energy, float(ctx.style["lamp_range"]) if light_range < 0.0 else light_range)
	nl.position = at
	node.add_child(nl)
	return nl
