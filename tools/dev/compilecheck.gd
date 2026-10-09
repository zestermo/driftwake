extends SceneTree
## Compiles scripts and reports the ones that fail (with the autoloads loaded,
## unlike Godot's --check-only, which doesn't know Net, FX, Ocean...).
##   --script res://tools/dev/compilecheck.gd                  every .gd in the project
##   --script res://tools/dev/compilecheck.gd -- a.gd b.gd     just these (res:// or project-relative)
## Prints "COMPILE OK (n scripts)" or "COMPILE FAILED <path>" per bad script;
## Godot's own SCRIPT ERROR lines above say what and where. Exit code = failures.

var bad: Array = []
var n := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		_walk("res://")
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
