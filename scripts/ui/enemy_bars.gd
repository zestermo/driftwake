class_name EnemyBars
extends Control
## (1.30) A small PS1-style health bar and a red marker over every hostile that's engaged (in a fight, just hit, or
## within ENGAGE_R and after a captain), so foes stand out in a crowd and you see how hurt they are. It fades FADE s
## after the fight; bosses keep their top bar and minibosses their own name bar (OverheadBar); townsfolk aren't enemies
## and never get one. One canvas item on the HUD draws them all: a poll every POLL s finds who's engaged near you (group
## "enemies", read from their synced state and health, so a guest sees the same), and each frame only those are drawn.

const POLL := 0.25
const NEAR := 45.0
const ENGAGE_R := 15.0
const FADE := 5.0
const BAR := Vector2(28, 4)
const RED := Color("f17c62")
const RIM := Color("f5e8c8")
const WELL := Color("0c2427")

## instance id -> {"n": enemy, "t": seconds since it was last engaged}
var shown := {}
var _poll := 0.0
var _was := false
## The health each foe near you had at the last poll (instance id -> health): a drop is a hit.
var _hp := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	for k in shown.keys():
		shown[k]["t"] = float(shown[k]["t"]) + delta
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL
		_scan()
	# (redrawn while any shows, and once more to clear the last)
	if not shown.is_empty() or _was:
		queue_redraw()
	_was = not shown.is_empty()


## Engaged foes near this screen's captain, and the faded ones let go.
func _scan() -> void:
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me == null:
		return
	var seen := {}
	for e in get_tree().get_nodes_in_group("enemies"):
		var n := e as Node3D
		if n.is_in_group("bosses") or n.get("_overhead") != null:
			continue
		var d := n.global_position.distance_to(me.global_position)
		if d > NEAR:
			continue
		var hc := n.get("health") as HealthComponent
		if hc == null or hc.current_health <= 0.0:
			continue
		var k := n.get_instance_id()
		seen[k] = hc.current_health
		var target = n.get("_player")
		var after: bool = target != null and is_instance_valid(target) and d < ENGAGE_R
		if hc.current_health < float(_hp.get(k, hc.current_health)) - 0.01 or (n.has_method("in_combat") and n.in_combat()) or after:
			shown[k] = {"n": n, "t": 0.0}
	_hp = seen
	for k in shown.keys():
		var n = shown[k]["n"]
		if not is_instance_valid(n) or float(shown[k]["t"]) > FADE or (n.get("health") as HealthComponent).current_health <= 0.0:
			shown.erase(k)


## How much of the bar shows for one shown entry (fades over its last second).
static func alpha(t: float) -> float:
	return clampf(FADE - t, 0.0, 1.0)


func _draw() -> void:
	var cam := get_tree().root.get_camera_3d()
	if cam == null:
		return
	var vs := get_viewport_rect().size
	for e in shown.values():
		var n = e["n"]
		if not is_instance_valid(n):
			continue
		var top: Vector3 = (n as Node3D).global_position + Vector3.UP * (2.15 if n is PirateGrunt else 1.6)
		if cam.is_position_behind(top):
			continue
		var p := PixelCanvas.project(cam, top, vs).round()
		if not Rect2(Vector2.ZERO, vs).has_point(p):
			continue
		var a := alpha(float(e["t"]))
		var hc := n.get("health") as HealthComponent
		var f := clampf(hc.current_health / maxf(hc.max_health, 1.0), 0.0, 1.0)
		var r := Rect2(p - Vector2(BAR.x * 0.5, 0.0), BAR)
		draw_rect(r.grow(1.0), Color(RIM, a))
		draw_rect(r, Color(WELL, a))
		draw_rect(Rect2(r.position, Vector2(roundf(BAR.x * f), BAR.y)), Color(RED, a))
		var m := p + Vector2(0, -3)
		draw_colored_polygon(PackedVector2Array([m + Vector2(-4, -5), m + Vector2(4, -5), m]), Color(RED, a))
