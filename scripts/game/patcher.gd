extends Node
## Patcher (autoload, FIRST in the list): applies a downloaded update before any other game script loads. Godot makes
## the autoloads one at a time, in order, so this node's _init runs before the next autoload's script is even read:
## a patch pack loaded here (replacing files) is what every later script, scene and asset comes from.
##   user://update/patch.pck + patch.json  the patch in use ({"base", "version", "sha256"}): loaded when its base is
##                                         the version this build was exported as
##   user://update/next.pck + next.json    one downloaded by Updater, waiting: promoted to patch.* first
## A patch is one cumulative pack (Godot's --export-patch against the base release's pack, delta-encoded), so a
## captain who skipped releases downloads one file. Only in an exported game (the editor and the test runners load
## nothing). Keep this script tiny and free of the game's classes: it can never be patched itself.

const DIR := "user://update/"

## The version this build was exported as, and the one running (a patch's, once loaded).
static var base_version := ""
static var running_version := ""
## Why a patch wasn't used ("" if none or it loaded).
static var skipped := ""


func _init() -> void:
	base_version = str(ProjectSettings.get_setting("application/config/version", ""))
	running_version = base_version
	if not OS.has_feature("template"):
		return
	_promote()
	var meta := _read(DIR + "patch.json")
	if meta.is_empty() or not FileAccess.file_exists(DIR + "patch.pck"):
		return
	if str(meta.get("base", "")) != base_version:
		# (a full install of a newer base replaced the game: this patch belongs to the old one)
		skipped = "patch for %s, this build is %s" % [meta.get("base", "?"), base_version]
		_drop("patch")
		return
	# (the update test, tools/release/update_test.ps1: does a file the patch changed read back changed?)
	var probe := OS.get_environment("DRIFTWAKE_UPDATE_PROBE")
	var before := FileAccess.get_md5(probe) if probe != "" else ""
	if not ProjectSettings.load_resource_pack(DIR + "patch.pck", true):
		skipped = "the patch wouldn't load"
		_drop("patch")
		return
	running_version = str(meta.get("version", base_version))
	ProjectSettings.set_setting("application/config/version", running_version)
	print("Patcher: %s on base %s" % [running_version, base_version])
	if probe != "":
		print("Patcher probe: %s" % ("changed" if FileAccess.get_md5(probe) != before else "same"))


## A waiting download becomes the patch in use (its checksum checked again first).
func _promote() -> void:
	var meta := _read(DIR + "next.json")
	if meta.is_empty() or not FileAccess.file_exists(DIR + "next.pck"):
		return
	if FileAccess.get_sha256(DIR + "next.pck") != str(meta.get("sha256", "")):
		skipped = "the download was damaged"
		_drop("next")
		return
	var d := DirAccess.open(DIR)
	_drop("patch")
	d.rename("next.pck", "patch.pck")
	d.rename("next.json", "patch.json")


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var v = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}


static func _drop(stem: String) -> void:
	var d := DirAccess.open(DIR)
	if d:
		d.remove(stem + ".pck")
		d.remove(stem + ".json")
