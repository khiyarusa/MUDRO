class_name RadioPack
extends RefCounted
## One MUDRO Radio content pack, validated against docs/RADIO_CONTENT_POLICY.md.
##
## A pack lives outside the game package (`user://radio_packs/<pack_id>/`) and is
## rejected whole if any single track fails a gate — a pack is a unit of
## provenance, not a playlist. The gates below are numbered exactly as §6.4 of the
## policy so a rejection message can name the rule that failed.

const SCHEMA_VERSION: int = 1
const MAX_PACK_BYTES: int = 512 * 1024 * 1024
const AUDIO_EXTENSIONS: Array = ["ogg", "wav"]
const BUCKETS: Array = ["A", "B", "C"]

var pack_id: String = ""
var display_name: String = ""
var author: String = ""
var license_file: String = ""
var root: String = ""
var tracks: Array[Dictionary] = []
## Empty when the pack is usable. Otherwise it holds the first failing gate.
var reject_reason: String = ""
var reject_gate: int = 0

static func load_pack(dir_path: String) -> RadioPack:
	var pack := RadioPack.new()
	pack.root = dir_path
	pack.pack_id = dir_path.get_file()
	pack._load(dir_path)
	return pack

func ok() -> bool:
	return reject_reason.is_empty()

func track_count() -> int:
	return tracks.size()

func _reject(gate: int, reason: String) -> void:
	reject_gate = gate
	reject_reason = "[gate %d] %s" % [gate, reason]

func _load(dir_path: String) -> void:
	# --- gate 1: manifest present and parseable ---------------------------
	var manifest_path: String = dir_path.path_join("manifest.json")
	if not FileAccess.file_exists(manifest_path):
		_reject(1, "manifest.json is missing")
		return
	var text: String = FileAccess.get_file_as_string(manifest_path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_reject(1, "manifest.json is not a JSON object")
		return
	var manifest: Dictionary = parsed as Dictionary

	# --- gate 2: schema ---------------------------------------------------
	var version: int = int(manifest.get("schema_version", -1))
	if version != SCHEMA_VERSION:
		_reject(2, "unsupported schema_version %d" % version)
		return
	pack_id = String(manifest.get("pack_id", ""))
	display_name = String(manifest.get("display_name", pack_id))
	author = String(manifest.get("author", ""))
	license_file = String(manifest.get("license_file", ""))

	# --- gate 3: identity -------------------------------------------------
	if pack_id.is_empty():
		_reject(3, "pack_id is empty")
		return
	if pack_id != dir_path.get_file():
		_reject(3, "pack_id '%s' does not match the folder '%s'" % [pack_id, dir_path.get_file()])
		return

	var list: Variant = manifest.get("tracks", [])
	if typeof(list) != TYPE_ARRAY or (list as Array).is_empty():
		_reject(2, "tracks[] is missing or empty")
		return

	# --- gate 8: size -----------------------------------------------------
	var bytes: int = _dir_size(dir_path)
	if bytes > MAX_PACK_BYTES:
		_reject(8, "pack is %d MB, above the %d MB cap" % [
			bytes / (1024 * 1024), MAX_PACK_BYTES / (1024 * 1024)])
		return

	for raw: Variant in (list as Array):
		if typeof(raw) != TYPE_DICTIONARY:
			_reject(2, "a track entry is not an object")
			return
		var row: Dictionary = raw as Dictionary
		var track: Dictionary = {
			"id": String(row.get("id", "")),
			"file": String(row.get("file", "")),
			"title": String(row.get("title", "")),
			"artist": String(row.get("artist", "")),
			"rights_holder": String(row.get("rights_holder", "")),
			"source_bucket": String(row.get("source_bucket", "")),
			"license_id": String(row.get("license_id", "")),
			"license_url": String(row.get("license_url", "")),
			"evidence_path": String(row.get("evidence_path", "")),
			"attribution_text": String(row.get("attribution_text", "")),
			"edited": bool(row.get("edited", false)),
			"duration_s": float(row.get("duration_s", 0.0)),
			"loop": bool(row.get("loop", false)),
		}

		# --- gate 6: containment -----------------------------------------
		var file: String = String(track["file"])
		if not _is_contained(file):
			_reject(6, "track '%s' points outside the pack" % track["id"])
			return
		var ext: String = file.get_extension().to_lower()
		if not AUDIO_EXTENSIONS.has(ext):
			_reject(6, "track '%s' has a non-audio extension '.%s'" % [track["id"], ext])
			return

		# --- gate 4: integrity -------------------------------------------
		var abs_path: String = dir_path.path_join(file)
		if not FileAccess.file_exists(abs_path):
			_reject(4, "track '%s' is missing (%s)" % [track["id"], file])
			return

		# --- gate 5: provenance ------------------------------------------
		var bucket: String = String(track["source_bucket"])
		if not BUCKETS.has(bucket):
			_reject(5, "track '%s' has no valid source_bucket" % track["id"])
			return
		if String(track["license_id"]).is_empty():
			_reject(5, "track '%s' has no license_id" % track["id"])
			return
		var evidence: String = String(track["evidence_path"])
		if evidence.is_empty():
			_reject(5, "track '%s' has no evidence_path" % track["id"])
			return
		if not _is_contained(evidence):
			_reject(5, "track '%s' evidence_path escapes the pack" % track["id"])
			return
		if not FileAccess.file_exists(dir_path.path_join(evidence)):
			_reject(5, "track '%s' evidence file is missing" % track["id"])
			return

		# --- gate 7: attribution completeness ----------------------------
		if bucket != "A" and String(track["attribution_text"]).is_empty():
			_reject(7, "track '%s' needs attribution_text for bucket %s" % [track["id"], bucket])
			return

		# --- gate 9: no network ------------------------------------------
		var url: String = String(track["license_url"])
		if not url.is_empty() and not (url.begins_with("https://") or url.begins_with("http://")):
			_reject(9, "track '%s' has an unsupported license_url scheme" % track["id"])
			return

		track["abs_path"] = abs_path
		tracks.append(track)

func _dir_size(dir_path: String) -> int:
	var total: int = 0
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return 0
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			total += _dir_size(dir_path.path_join(entry))
		else:
			total += _file_size(dir_path.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	return total

func _file_size(path: String) -> int:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var size: int = f.get_length()
	f.close()
	return size

## Rejects absolute paths, `..` segments, backslashes and URL schemes.
static func _is_contained(relative_path: String) -> bool:
	if relative_path.is_empty():
		return false
	if relative_path.contains("://"):
		return false
	if relative_path.contains("\\"):
		return false
	if relative_path.begins_with("/"):
		return false
	for part: String in relative_path.split("/", false):
		if part == ".." or part == ".":
			return false
	return true
