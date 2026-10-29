class_name Updater
extends Node
## In-game updates (the title screen's): asks GitHub for the latest stable release, reads its update.json and offers
## what fits this install.
##   patch  the release has a patch for the base this build was exported as: a small download (Patcher applies it at
##          the next start; restart())
##   full   a new base (the engine or the native library changed, or the patches grew too big), or no patch for this
##          base: the release page opens for the installer
## update.json (CI, tools/release/make_update.ps1): {"version", "base", "full_required", "patch": asset name, "size",
## "sha256"}. Pre-releases (unstable builds) are never offered: GitHub's "latest" skips them. Exported games only.

signal found(kind: String, version: String, size_mb: float)
signal progress(frac: float)
signal finished(ok: bool, message: String)

const LATEST := "https://api.github.com/repos/zestermo/driftwake/releases/latest"
const PAGE := "https://github.com/zestermo/driftwake/releases/latest"
const DIR := "user://update/"

var latest := ""
var _info := {}
var _assets := {}
var _http: HTTPRequest


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 20.0
	add_child(_http)


## Looks once (quietly: no network, no release, nothing new is no news). `force` checks in the editor too (tools).
func check(force := false) -> void:
	if not force and not OS.has_feature("template"):
		return
	_fetch(LATEST, _on_release)


func _fetch(url: String, then: Callable) -> void:
	if _http.request_completed.is_connected(_on_done):
		_http.request_completed.disconnect(_on_done)
	_http.request_completed.connect(_on_done.bind(then))
	_http.download_file = ""
	if _http.request(url, ["User-Agent: Driftwake", "Accept: application/vnd.github+json"]) != OK:
		finished.emit(false, "Couldn't reach GitHub")


func _on_done(result: int, code: int, _h: PackedStringArray, body: PackedByteArray, then: Callable) -> void:
	_http.request_completed.disconnect(_on_done)
	if result != HTTPRequest.RESULT_SUCCESS or code >= 400:
		then.call(null)
		return
	then.call(body)


func _on_release(body) -> void:
	var rel = JSON.parse_string(body.get_string_from_utf8()) if body else null
	if not (rel is Dictionary):
		return
	latest = str(rel.get("tag_name", "")).trim_prefix("v")
	if latest == "" or not newer(latest, running()):
		return
	for a in rel.get("assets", []):
		_assets[str(a.get("name", ""))] = str(a.get("browser_download_url", ""))
	if not _assets.has("update.json"):
		found.emit("full", latest, 0.0)
		return
	_fetch(_assets["update.json"], _on_info)


func _on_info(body) -> void:
	var info = JSON.parse_string(body.get_string_from_utf8()) if body else null
	if not (info is Dictionary):
		found.emit("full", latest, 0.0)
		return
	_info = info
	var fits := str(info.get("base", "")) == base() and not bool(info.get("full_required", false)) and _assets.has(str(info.get("patch", "")))
	found.emit("patch" if fits else "full", latest, float(info.get("size", 0)) / 1048576.0 if fits else 0.0)


## Downloads the patch to user://update/next.pck, checks it, and leaves next.json for Patcher.
func download() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_http.download_file = DIR + "next.part"
	if _http.request_completed.is_connected(_on_done):
		_http.request_completed.disconnect(_on_done)
	_http.request_completed.connect(_on_downloaded, CONNECT_ONE_SHOT)
	if _http.request(_assets[str(_info["patch"])], ["User-Agent: Driftwake"]) != OK:
		finished.emit(false, "Couldn't start the download")
		return
	set_process(true)


func _process(_d: float) -> void:
	var total := _http.get_body_size()
	if total > 0:
		progress.emit(float(_http.get_downloaded_bytes()) / float(total))


func _on_downloaded(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
	set_process(false)
	_http.download_file = ""
	var part := DIR + "next.part"
	if result != HTTPRequest.RESULT_SUCCESS or code >= 400 or FileAccess.get_sha256(part) != str(_info.get("sha256", "")):
		DirAccess.remove_absolute(part)
		finished.emit(false, "The download failed. Try again later.")
		return
	var d := DirAccess.open(DIR)
	d.remove("next.pck")
	d.rename("next.part", "next.pck")
	var f := FileAccess.open(DIR + "next.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"base": base(), "version": str(_info["version"]), "sha256": str(_info["sha256"])}))
	f.close()
	finished.emit(true, "v%s is ready" % _info["version"])


## The game starts again on the update (Patcher promotes it).
func restart() -> void:
	OS.set_restart_on_exit(true, OS.get_cmdline_args())
	get_tree().quit()


## The release page (the installer, for a full update).
static func open_page() -> void:
	OS.shell_open(PAGE)


static func base() -> String:
	var b := str(load("res://scripts/game/patcher.gd").base_version)
	return b if b != "" else str(ProjectSettings.get_setting("application/config/version", ""))


static func running() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))


## a newer than b ("1.25.2" > "1.25", "1.26" > "1.25.9").
static func newer(a: String, b: String) -> bool:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in range(maxi(pa.size(), pb.size())):
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return x > y
	return false
