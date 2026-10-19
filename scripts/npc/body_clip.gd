class_name BodyClip
extends Resource
## A clip for the Humanoid made outside the game (docs/blender_clips.md): per-joint rotation tracks in the
## animator's own convention (Euler YXZ, radians, relative to the parent joint, as Humanoid._cur holds them),
## one Vector3 a frame, and the hips' lift (metres). ClipImport makes it from a glb, ClipPlayer plays it.

@export var fps := 30.0
## Seconds (frames = length x fps + 1).
@export var length := 1.0
@export var loop := true
## "upper" (the legs keep the locomotion's: walking, sitting) or "full".
@export var mask := "full"
## joint name -> PackedVector3Array, one Euler a frame
@export var tracks: Dictionary = {}
## The pivot's offset from its rest, metres in the body's frame (empty: none).
@export var lift := PackedVector3Array()


func frames() -> int:
	return int(round(length * fps)) + 1


## The pose at `t` seconds (looped or held at the end): {joint: Euler}, "_lift" (metres) when it has one.
func sample(t: float) -> Dictionary:
	var f := fposmod(t, length) * fps if loop else clampf(t, 0.0, length) * fps
	var i := mini(int(f), frames() - 1)
	var j := mini(i + 1, frames() - 1)
	var k := f - i
	var out := {}
	for joint in tracks:
		var tr: PackedVector3Array = tracks[joint]
		out[joint] = tr[i].lerp(tr[j], k)
	if not lift.is_empty():
		out["_lift"] = lift[i].lerp(lift[j], k)
	return out
