extends Node
## SaveManager (autoload): versioned, atomic, offline progression.
## Writes go to a temp file and are renamed into place, keeping a .bak copy so an
## interrupted write cannot destroy a profile.

signal profile_changed
signal credits_changed(amount: int)

const PATH: String = "user://profile.json"
const VERSION: int = 3
const STARTING_CREDITS: int = 600

var data: Dictionary = {}
var _loaded: bool = false

func _ready() -> void:
	load_profile()

func _default_profile() -> Dictionary:
	return {
		"version": VERSION,
		"credits": STARTING_CREDITS,
		"xp": 0,
		"selected_vehicle": "rocky_buggy",
		"owned_vehicles": ["rocky_buggy"],
		"records": {},
		"upgrades": {},
		"play_time_s": 0.0,
		"distance_m": 0.0,
		"created": Time.get_datetime_string_from_system(),
	}

func load_profile() -> void:
	var d: Dictionary = _default_profile()
	var loaded_any: bool = false
	for candidate: String in [PATH, PATH + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(candidate))
		if parsed is Dictionary and (parsed as Dictionary).has("credits"):
			d = (parsed as Dictionary)
			loaded_any = true
			break
	data = _migrate(d)
	_loaded = true
	if not loaded_any:
		save_profile()

func _migrate(d: Dictionary) -> Dictionary:
	var defaults: Dictionary = _default_profile()
	for k: String in defaults.keys():
		if not d.has(k):
			d[k] = defaults[k]
	d["version"] = VERSION
	if not (d["records"] is Dictionary):
		d["records"] = {}
	if not (d["upgrades"] is Dictionary):
		d["upgrades"] = {}
	if not (d["owned_vehicles"] is Array):
		d["owned_vehicles"] = ["rocky_buggy"]
	if not (d["owned_vehicles"] as Array).has("rocky_buggy"):
		(d["owned_vehicles"] as Array).append("rocky_buggy")
	return d

func save_profile() -> void:
	if data.is_empty():
		return
	var text: String = JSON.stringify(data, "\t")
	var tmp: String = PATH + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("SaveManager: cannot open temp file for writing")
		return
	f.store_string(text)
	f.flush()
	f.close()
	if FileAccess.file_exists(PATH):
		var bak_abs: String = ProjectSettings.globalize_path(PATH + ".bak")
		if FileAccess.file_exists(PATH + ".bak"):
			DirAccess.remove_absolute(bak_abs)
		DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH), bak_abs)
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(PATH))
	profile_changed.emit()

# ------------------------------------------------------------------ credits ---

func credits() -> int:
	return int(data.get("credits", 0))

func add_credits(amount: int) -> void:
	data["credits"] = credits() + amount
	save_profile()
	credits_changed.emit(credits())

func spend_credits(amount: int) -> bool:
	if credits() < amount:
		return false
	data["credits"] = credits() - amount
	save_profile()
	credits_changed.emit(credits())
	return true

# ------------------------------------------------------------------ records ---

func record_of(stage_id: String) -> Dictionary:
	var records: Dictionary = data.get("records", {})
	if records.has(stage_id):
		return records[stage_id] as Dictionary
	return {}

func best_time(stage_id: String) -> float:
	return float(record_of(stage_id).get("best_time", 0.0))

func medal_of(stage_id: String) -> int:
	return int(record_of(stage_id).get("medal", 0))

func is_completed(stage_id: String) -> bool:
	return bool(record_of(stage_id).get("completed", false))

func attempts_of(stage_id: String) -> int:
	return int(record_of(stage_id).get("attempts", 0))

## Returns { new_best, first_clear, credits, xp }.
func complete_stage(stage: StageDef, time_s: float, medal: int, mode: String) -> Dictionary:
	var records: Dictionary = data.get("records", {})
	var rec: Dictionary = records.get(stage.id, {
		"best_time": 0.0, "medal": 0, "attempts": 0, "completed": false,
	})
	var first_clear: bool = not bool(rec.get("completed", false))
	var old_best: float = float(rec.get("best_time", 0.0))
	var new_best: bool = old_best <= 0.0 or time_s < old_best
	if new_best:
		rec["best_time"] = time_s
	rec["medal"] = maxi(int(rec.get("medal", 0)), medal)
	rec["attempts"] = int(rec.get("attempts", 0)) + 1
	rec["completed"] = true
	rec["mode"] = mode
	records[stage.id] = rec
	data["records"] = records

	var reward: int = stage.reward_credits if first_clear else int(stage.reward_credits * 0.2)
	var xp: int = stage.reward_xp if first_clear else int(stage.reward_xp * 0.2)
	data["credits"] = credits() + reward
	data["xp"] = int(data.get("xp", 0)) + xp
	save_profile()
	credits_changed.emit(credits())
	_check_vehicle_unlocks()
	return {"new_best": new_best, "first_clear": first_clear, "credits": reward, "xp": xp}

func add_distance(meters: float, seconds: float) -> void:
	data["distance_m"] = float(data.get("distance_m", 0.0)) + meters
	data["play_time_s"] = float(data.get("play_time_s", 0.0)) + seconds

# ------------------------------------------------------------------- stages ---

func stage_index(stage_id: String) -> int:
	for i: int in range(Content.stages.size()):
		if Content.stages[i].id == stage_id:
			return i
	return -1

func is_stage_unlocked(stage_id: String) -> bool:
	var idx: int = stage_index(stage_id)
	if idx <= 0:
		return idx == 0
	var prev: StageDef = Content.stages[idx - 1]
	return is_completed(prev.id)

func next_stage_after(stage_id: String) -> StageDef:
	var idx: int = stage_index(stage_id)
	if idx >= 0 and idx + 1 < Content.stages.size():
		return Content.stages[idx + 1]
	return null

func total_medals() -> int:
	var total: int = 0
	for sid: String in (data.get("records", {}) as Dictionary).keys():
		total += int((data["records"][sid] as Dictionary).get("medal", 0))
	return total

func max_medals() -> int:
	return Content.stages.size() * 3

func completed_count() -> int:
	var n: int = 0
	for s: StageDef in Content.stages:
		if is_completed(s.id):
			n += 1
	return n

# ----------------------------------------------------------------- vehicles ---

func owned_vehicles() -> Array:
	return data.get("owned_vehicles", ["rocky_buggy"]) as Array

func is_vehicle_owned(vehicle_id: String) -> bool:
	return owned_vehicles().has(vehicle_id)

func own_vehicle(vehicle_id: String) -> void:
	var owned: Array = owned_vehicles()
	if not owned.has(vehicle_id):
		owned.append(vehicle_id)
		data["owned_vehicles"] = owned
		save_profile()

func buy_vehicle(vehicle_id: String) -> bool:
	var def: VehicleDef = Content.vehicle_by_id(vehicle_id)
	if def == null or is_vehicle_owned(vehicle_id):
		return false
	if not is_stage_unlocked_vehicle(def):
		return false
	if not spend_credits(def.price):
		return false
	own_vehicle(vehicle_id)
	select_vehicle(vehicle_id)
	return true

func is_stage_unlocked_vehicle(def: VehicleDef) -> bool:
	if def.unlock_stage.is_empty():
		return true
	return is_completed(def.unlock_stage)

func _check_vehicle_unlocks() -> void:
	for def: VehicleDef in Content.vehicles:
		if def.unlock_stage.is_empty():
			continue
		if is_completed(def.unlock_stage):
			own_vehicle(def.id)

func selected_vehicle() -> String:
	var id: String = String(data.get("selected_vehicle", "rocky_buggy"))
	if not owned_vehicles().has(id):
		id = "rocky_buggy"
	return id

func select_vehicle(vehicle_id: String) -> void:
	if not is_vehicle_owned(vehicle_id):
		return
	data["selected_vehicle"] = vehicle_id
	save_profile()

# ----------------------------------------------------------------- upgrades ---

func vehicle_upgrades(vehicle_id: String) -> Array:
	var all: Dictionary = data.get("upgrades", {})
	var list: Array = all.get(vehicle_id, [])
	return list

func has_upgrade(vehicle_id: String, upgrade_id: String) -> bool:
	return vehicle_upgrades(vehicle_id).has(upgrade_id)

func buy_upgrade(vehicle_id: String, upgrade_id: String) -> bool:
	var up: UpgradeDef = Content.upgrade_by_id(upgrade_id)
	if up == null or has_upgrade(vehicle_id, upgrade_id):
		return false
	if up.tier > 1:
		var prev: String = "%s_%d" % [String(upgrade_id).rsplit("_", true, 1)[0], up.tier - 1]
		if not has_upgrade(vehicle_id, prev):
			return false
	if not spend_credits(up.cost):
		return false
	var all: Dictionary = data.get("upgrades", {})
	var list: Array = all.get(vehicle_id, [])
	list.append(upgrade_id)
	all[vehicle_id] = list
	data["upgrades"] = all
	save_profile()
	return true

func next_tier_cost(vehicle_id: String, category: int) -> int:
	var owned: Array = vehicle_upgrades(vehicle_id)
	for up: UpgradeDef in Content.upgrades_for(category):
		if not owned.has(up.id):
			return up.cost
	return 0

# --------------------------------------------------------------------- misc ---

func reset_profile() -> void:
	data = _default_profile()
	save_profile()
	profile_changed.emit()

func summary() -> Dictionary:
	return {
		"credits": credits(),
		"xp": int(data.get("xp", 0)),
		"completed": completed_count(),
		"medals": total_medals(),
		"vehicles": owned_vehicles().size(),
	}
