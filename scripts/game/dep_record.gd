extends ResourceFormatLoader
## Every project file a test run loads, written at exit to DRIFTWAKE_DEPS_OUT (the runners' dependency cache).
## A loader first in line that claims nothing sees each load; the exit sweep adds scripts the GDScript cache loads by class name.

static var recording

var out := ""
var seen := {}
var mutex := Mutex.new()


## A file read without the resource loader, or a folder (ending in "/") the run lists. Callable from any
## script by preload (a class_name script compiled under a test's --script can't name an autoload).
static func note_dep(path: String) -> void:
	if recording:
		recording.note(path)


func _init(path: String) -> void:
	out = path
	recording = self
	ResourceLoader.add_resource_format_loader(self, true)


func _recognize_path(path: String, _type: StringName) -> bool:
	note(path)
	return false


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray()


func _handles_type(_type: StringName) -> bool:
	return false


func note(path: String) -> void:
	mutex.lock()
	seen[path] = true
	mutex.unlock()


func write() -> void:
	recording = null
	ResourceLoader.remove_resource_format_loader(self)
	var files := PackedStringArray()
	_walk("res://", files)
	mutex.lock()
	for f in files:
		if ResourceLoader.has_cached(f):
			seen[f] = true
	var keep := {}
	for p in seen.keys():
		var s := String(p).get_slice("::", 0)
		if not s.begins_with("res://") or s.begins_with("res://."):
			continue
		if (s.ends_with("/") and DirAccess.dir_exists_absolute(s)) or FileAccess.file_exists(s):
			keep[s.trim_prefix("res://")] = true
	mutex.unlock()
	var lines := PackedStringArray(keep.keys())
	lines.sort()
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()


func _walk(dir: String, files: PackedStringArray) -> void:
	if FileAccess.file_exists(dir + ".gdignore"):
		return
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			_walk(dir + d + "/", files)
	for f in DirAccess.get_files_at(dir):
		if not (f.ends_with(".import") or f.ends_with(".uid")):
			files.append(dir + f)
