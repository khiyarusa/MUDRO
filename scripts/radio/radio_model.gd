class_name RadioModel
extends RefCounted
## MUDRO Radio: an offline garage radio.
##
## Two sources of audio, and only two:
##  * the built-in station, which is project-synthesised (`assets/audio/radio/`,
##    bucket A in docs/RADIO_CONTENT_POLICY.md) and therefore shippable inside the APK;
##  * content packs sideloaded into `user://radio_packs/`, each validated by RadioPack.
##
## Nothing here touches the network. There is no code path that resolves a track
## from a URL, which is what makes the feature offline by construction rather than
## by good intentions.

const PACK_ROOT: String = "user://radio_packs"
const BUILTIN_DIR: String = "res://assets/audio/radio"
## Shipped order matters: the ident plays first, then the loops.
const BUILTIN_FILES: Array = [
	"radio_ident.wav", "01_dust_road.wav", "02_long_climb.wav", "03_workshop.wav",
]
const BUILTIN_TITLES_EN: Array = [
	"Station ident", "Dust Road", "Long Climb", "Workshop",
]
const BUILTIN_TITLES_FA: Array = [
	"شناسهٔ ایستگاه", "جادهٔ خاکی", "صعود طولانی", "کارگاه",
]

var packs: Array[RadioPack] = []
## Flat playable list: built-in tracks first, then every accepted pack track.
var playlist: Array[Dictionary] = []
var current: int = -1
var enabled: bool = true
var volume: float = 0.55

func scan() -> void:
	packs.clear()
	playlist.clear()
	_add_builtin()
	_scan_packs()

func _add_builtin() -> void:
	for i: int in range(BUILTIN_FILES.size()):
		var path: String = BUILTIN_DIR.path_join(BUILTIN_FILES[i])
		if not ResourceLoader.exists(path):
			continue
		playlist.append({
			"id": BUILTIN_FILES[i].get_basename(),
			"title_en": BUILTIN_TITLES_EN[i],
			"title_fa": BUILTIN_TITLES_FA[i],
			"artist": "MUDRO",
			"bucket": "A",
			"license_id": "OWN-WORK",
			"attribution": "",
			"pack_id": "",
			"path": path,
			"loop": i > 0,
		})

func _scan_packs() -> void:
	var dir: DirAccess = DirAccess.open(PACK_ROOT)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			var pack: RadioPack = RadioPack.load_pack(PACK_ROOT.path_join(entry))
			packs.append(pack)
			if pack.ok():
				for track: Dictionary in pack.tracks:
					playlist.append({
						"id": String(track["id"]),
						"title_en": String(track["title"]),
						"title_fa": String(track["title"]),
						"artist": String(track["artist"]),
						"bucket": String(track["source_bucket"]),
						"license_id": String(track["license_id"]),
						"attribution": String(track["attribution_text"]),
						"pack_id": pack.pack_id,
						"path": String(track["abs_path"]),
						"loop": bool(track["loop"]),
					})
		entry = dir.get_next()
	dir.list_dir_end()

func accepted_packs() -> Array[RadioPack]:
	var out: Array[RadioPack] = []
	for pack: RadioPack in packs:
		if pack.ok():
			out.append(pack)
	return out

func rejected_packs() -> Array[RadioPack]:
	var out: Array[RadioPack] = []
	for pack: RadioPack in packs:
		if not pack.ok():
			out.append(pack)
	return out

func playable_count() -> int:
	return playlist.size()

func current_track() -> Dictionary:
	if current < 0 or current >= playlist.size():
		return {}
	return playlist[current]

func select(index: int) -> Dictionary:
	if playlist.is_empty():
		current = -1
		return {}
	current = posmod(index, playlist.size())
	return current_track()

func next_track() -> Dictionary:
	return select(current + 1)

func previous_track() -> Dictionary:
	return select(current - 1)

## The attribution line the radio overlay must display, or "" when none is needed.
func attribution_line() -> String:
	var track: Dictionary = current_track()
	if track.is_empty():
		return ""
	var text: String = String(track.get("attribution", ""))
	if text.is_empty():
		return ""
	return text

func title(lang: String) -> String:
	var track: Dictionary = current_track()
	if track.is_empty():
		return ""
	return String(track["title_fa"] if lang == "fa" else track["title_en"])
