extends SceneTree
## Compiles scripts and reports the ones that fail (with the autoloads loaded,
## unlike Godot's --check-only, which doesn't know Net, FX, Ocean...).
##   --script res://tools/dev/compilecheck.gd                  every .gd in the project
##   --script res://tools/dev/compilecheck.gd -- a.gd b.gd     just these (res:// or project-relative)
## Prints "COMPILE OK (n scripts)" or "COMPILE FAILED <path>" per bad script;
## Godot's own SCRIPT ERROR lines above say what and where. Exit code = failures.
## Also the wall-clock lint: game code (scripts/, scenes/) runs on game time, so a wall-clock call there
## (Time.get_ticks_*, Time/OS unix or system time) fails as "WALL CLOCK <path>:<line>" unless
## tools/dev/wallclock_allow.txt lists its file (or file:function) with a reason.

const ALLOW := "res://tools/dev/wallclock_allow.txt"
const LINT_DIRS := ["res://scripts/", "res://scenes/"]

var bad: Array = []
var n := 0
var _wall: RegEx
var _func: RegEx
## "path" or "path:func" -> times it matched
var _allow := {}


func _initialize() -> void:
	_wall = RegEx.create_from_string("\\b(Time\\.get_ticks_(msec|usec)|Time\\.get_unix_time\\w*|Time\\.get_\\w+_from_system|OS\\.get_ticks_\\w+|OS\\.get_unix_time\\w*|OS\\.get_system_time\\w*|OS\\.get_(datetime|date|time)\\w*)\\s*\\(")
	_func = RegEx.create_from_string("^\\s*(static\\s+)?func\\s+(\\w+)")
	for line in FileAccess.get_file_as_string(ALLOW).split("\n"):
		var l := line.strip_edges()
		if l != "" and not l.begins_with("#"):
			_allow[l.get_slice("|", 0).strip_edges()] = 0
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		_walk("res://")
		for k in _allow:
			if _allow[k] == 0:
				print("WALL CLOCK allow-list entry matches nothing now (drop it from %s): %s" % [ALLOW.get_file(), k])
	else:
		for a in args:
			_check(a if a.begins_with("res://") else "res://" + a.replace("\\", "/").trim_prefix("./"))
	for b in bad:
		print("COMPILE FAILED ", b)
	if n == 0:
		print("COMPILE FAILED: no scripts checked (args: %s)" % str(args))
		quit(1)
		return
	if bad.is_empty():
		print("COMPILE OK (%d scripts)" % n)
	quit(bad.size())


func _walk(dir: String) -> void:
	for d in DirAccess.get_directories_at(dir):
		if d.begins_with(".") or d == "addons" or (dir == "res://tools/dev/" and d == "out"):
			continue
		_walk(dir.path_join(d) + "/")
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			_check(dir.path_join(f))


func _check(path: String) -> void:
	# (reloading the running checker itself crashes Godot)
	if not path.ends_with(".gd") or path == (get_script() as Script).resource_path:
		return
	n += 1
	var s := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as GDScript
	if s == null or not s.can_instantiate():
		bad.append(path)
	elif LINT_DIRS.any(func(d): return path.begins_with(d)) and not _lint(path, s.source_code):
		bad.append(path)


## Wall-clock calls in game code outside the allow list: printed, and false.
func _lint(path: String, src: String) -> bool:
	var rel := path.trim_prefix("res://")
	var fn := ""
	var ok := true
	var lines := src.split("\n")
	for i in range(lines.size()):
		var code := lines[i].get_slice("#", 0)
		var fm := _func.search(code)
		if fm:
			fn = fm.get_string(2)
		var m := _wall.search(code)
		if m == null:
			continue
		var key := rel if _allow.has(rel) else "%s:%s" % [rel, fn]
		if _allow.has(key):
			_allow[key] += 1
			continue
		ok = false
		print("WALL CLOCK %s:%d (in %s): %s. Game code runs on game time: delta, physics ticks (Engine.get_physics_frames()), timers, Ocean.clock() / Weather.world_time() for shared clocks; or list it in %s with a reason." % [
			rel, i + 1, fn if fn != "" else "the script body", m.get_string(1), ALLOW.trim_prefix("res://")])
	return ok
