extends Node
## SaveManager (autoload): versioned, atomic, offline progression.
##
## Schema v5 stores a real garage: per vehicle, the parts the player owns, the
## parts fitted, their condition and the saved setups. Migration from the 2.0
## schema (v2-v4) maps the old fictional vehicles, old stage ids and old upgrade
## ids onto their 3.0 equivalents, so an existing profile keeps its money,
## unlocks, records and purchases instead of being reset.

signal profile_changed
signal credits_changed(amount: int)

const PATH: String = "user://profile.json"
const VERSION: int = 5
const STARTING_CREDITS: int = 600

## Old fictional vehicle -> documented 3.0 vehicle, by role.
const LEGACY_VEHICLE_MAP: Dictionary = {
	"rocky_buggy": "jimny_jb74",
	"ranger_4x4": "hilux_an120",
	"dune_pickup": "patrol_y61",
	"titan_offroad": "lc79",
}

## Old stage id -> 3.0 track id (several old stages collapse onto one track).
const LEGACY_TRACK_MAP: Dictionary = {
	"canyon_01": "zagros_01", "canyon_02": "zagros_02", "canyon_03": "zagros_03",
	"canyon_04": "zagros_03",
	"pine_01": "pine_01", "pine_02": "pine_02", "pine_03": "pine_03", "pine_04": "pine_03",
	"quarry_01": "alpine_01", "quarry_02": "alpine_02", "quarry_03": "alpine_03",
	"quarry_04": "alpine_03",
	"black_ridge_01": "black_ridge_01", "black_ridge_02": "black_ridge_02",
	"black_ridge_03": "black_ridge_03", "black_ridge_04": "black_ridge_03",
	"glacier_01": "glacier_01", "glacier_02": "glacier_02", "glacier_03": "glacier_03",
}

## Old upgrade id -> part id suffix, so a 2.0 purchase becomes a 3.0 part.
const LEGACY_UPGRADE_MAP: Dictionary = {
	"engine_1": "intake_sport", "engine_2": "ecu_1", "engine_3": "turbo",
	"gearbox_1": "clutch_hd", "gearbox_2": "gbox_close", "gearbox_3": "gbox_race",
	"diff_1": "diff_lsd", "diff_2": "diff_lock", "diff_3": "diff_lock",
	"susp_1": "damper_gas", "susp_2": "lift_25", "susp_3": "damper_race",
	"tires_1": "tyre_at", "tires_2": "tyre_mt", "tires_3": "tyre_rock",
	"brakes_1": "pad_ceramic", "brakes_2": "disc_slot", "brakes_3": "pad_race",
	"chassis_1": "cage", "chassis_2": "bumper_f_steel", "chassis_3": "cage",
}

var data: Dictionary = {}
var _loaded: bool = false

func _ready() -> void:
	load_profile()

func _default_profile() -> Dictionary:
	return {
		"version": VERSION,
		"credits": STARTING_CREDITS,
		"xp": 0,
		"selected_vehicle": "jimny_jb74",
		"owned_vehicles": ["jimny_jb74"],
		"records": {},
		"garage": {},
		"play_time_s": 0.0,
		"distance_m": 0.0,
		"created": Time.get_datetime_string_from_system(),
		"migrated_from": 0,
	}

func load_profile() -> void:
	var d: Dictionary = _default_profile()
	var loaded_any: bool = false
	var raw_version: int = 0
	for candidate: String in [PATH, PATH + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(candidate))
		if parsed is Dictionary and (parsed as Dictionary).has("credits"):
			d = parsed as Dictionary
			raw_version = int(d.get("version", 0))
			loaded_any = true
			break
	if loaded_any:
		d = _migrate(d, raw_version)
	data = d
	_loaded = true
	if not loaded_any:
		save_profile()

# ---------------------------------------------------------------- migration ---

func _migrate(d: Dictionary, from_version: int) -> Dictionary:
	var defaults: Dictionary = _default_profile()
	for k: String in defaults.keys():
		if not d.has(k):
			d[k] = defaults[k]
	if not (d["records"] is Dictionary):
		d["records"] = {}
	if not (d["garage"] is Dictionary):
		d["garage"] = {}
	if not (d["owned_vehicles"] is Array):
		d["owned_vehicles"] = ["jimny_jb74"]

	var legacy_vehicles: Array = []
	for raw: Variant in (d["owned_vehicles"] as Array):
		legacy_vehicles.append(String(raw))
	var mapped: Array = []
	for vid: String in legacy_vehicles:
		var target: String = String(LEGACY_VEHICLE_MAP.get(vid, vid))
		if not mapped.has(target):
			mapped.append(target)
	if mapped.is_empty():
		mapped.append("jimny_jb74")
	d["owned_vehicles"] = mapped

	var selected: String = String(d.get("selected_vehicle", "jimny_jb74"))
	selected = String(LEGACY_VEHICLE_MAP.get(selected, selected))
	if not mapped.has(selected):
		selected = String(mapped[0])
	d["selected_vehicle"] = selected

	d["records"] = _migrate_records(d.get("records", {}) as Dictionary)
	d["garage"] = _migrate_garage(d, mapped, legacy_vehicles, from_version)

	for key: String in ["upgrades", "config"]:
		if d.has(key):
			d.erase(key)
	d["version"] = VERSION
	d["migrated_from"] = from_version
	return d

func _migrate_records(old: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for raw_id: String in old.keys():
		var src: Dictionary = old[raw_id] as Dictionary if old[raw_id] is Dictionary else {}
		var target: String = String(LEGACY_TRACK_MAP.get(raw_id, raw_id))
		if Content != null and Content.track_by_id(target) == null:
			target = Content.tracks[0].id if not Content.tracks.is_empty() else target
		var rec: Dictionary = out.get(target, {
			"best_time": 0.0, "medal": 0, "attempts": 0, "completed": false,
			"by_vehicle": {},
		})
		var best: float = float(src.get("best_time", 0.0))
		var prev_best: float = float(rec.get("best_time", 0.0))
		if best > 0.0 and (prev_best <= 0.0 or best < prev_best):
			rec["best_time"] = best
		rec["medal"] = maxi(int(rec.get("medal", 0)), int(src.get("medal", 0)))
		rec["attempts"] = int(rec.get("attempts", 0)) + int(src.get("attempts", 0))
		rec["completed"] = bool(rec.get("completed", false)) or bool(src.get("completed", false))
		rec["mode"] = String(src.get("mode", "career"))
		out[target] = rec
	return out

func _migrate_garage(d: Dictionary, owned: Array, legacy_owned: Array, from_version: int) -> Dictionary:
	var garage: Dictionary = {}
	var raw_garage: Dictionary = d.get("garage", {}) if d.get("garage", {}) is Dictionary else {}
	var legacy_upgrades: Dictionary = d.get("upgrades", {}) if d.get("upgrades", {}) is Dictionary else {}
	var legacy_config: Dictionary = d.get("config", {}) if d.get("config", {}) is Dictionary else {}

	for vid: String in owned:
		var entry: Dictionary = {"parts": {}, "owned": [], "condition": {}, "presets": {}}
		var matched_legacy: String = vid
		for old_id: String in LEGACY_VEHICLE_MAP.keys():
			if String(LEGACY_VEHICLE_MAP[old_id]) == vid and legacy_owned.has(old_id):
				matched_legacy = old_id
				break
		if raw_garage.has(vid) and raw_garage[vid] is Dictionary:
			var stored: Dictionary = raw_garage[vid] as Dictionary
			entry["parts"] = (stored.get("parts", {}) as Dictionary).duplicate(true)
			entry["owned"] = _string_array(stored.get("owned", []))
			entry["condition"] = (stored.get("condition", {}) as Dictionary).duplicate(true)
			entry["presets"] = (stored.get("presets", {}) as Dictionary).duplicate(true)
		# 2.0 purchases become 3.0 parts: owned and fitted, never lost.
		var old_list: Array = legacy_upgrades.get(matched_legacy, []) as Array
		for raw: Variant in old_list:
			var part: PartDef = _legacy_upgrade_part(vid, String(raw))
			if part == null:
				continue
			if not entry["owned"].has(part.id):
				(entry["owned"] as Array).append(part.id)
			(entry["parts"] as Dictionary)[str(int(part.slot))] = part.id
		var cfg_old: Dictionary = legacy_config.get(matched_legacy, {}) as Dictionary
		var transfer: String = String(cfg_old.get("transfer", ""))
		if not transfer.is_empty():
			entry["transfer"] = transfer
		var diff: String = String(cfg_old.get("diff", ""))
		if not diff.is_empty():
			entry["diff"] = diff
		garage[vid] = entry
	return garage

func _legacy_upgrade_part(vehicle_id: String, upgrade_id: String) -> PartDef:
	var suffix: String = String(LEGACY_UPGRADE_MAP.get(upgrade_id, ""))
	if suffix.is_empty():
		return null
	var base: VehicleDef = Content.vehicle_by_id(vehicle_id) if Content != null else null
	if base == null:
		return null
	if suffix == "turbo":
		suffix = "turbo_kit" if base.aspiration == "na" else "turbo_hybrid"
	var part: PartDef = Content.part_by_id("%s_%s" % [vehicle_id, suffix])
	return part

func _string_array(raw: Variant) -> Array:
	var out: Array = []
	if raw is Array:
		for v: Variant in (raw as Array):
			out.append(String(v))
	return out

# ------------------------------------------------------------------ writing ---

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

func record_of(track_id: String) -> Dictionary:
	var records: Dictionary = data.get("records", {})
	if records.has(track_id):
		return records[track_id] as Dictionary
	return {}

func best_time(track_id: String) -> float:
	return float(record_of(track_id).get("best_time", 0.0))

func best_time_for(track_id: String, vehicle_id: String) -> float:
	var by_vehicle: Dictionary = record_of(track_id).get("by_vehicle", {})
	var raw: Variant = by_vehicle.get(vehicle_id, {})
	# Older and hand-edited profiles stored a bare float here. Reading it as a
	# record object would crash the garage, so both shapes are accepted.
	if raw is Dictionary:
		return float((raw as Dictionary).get("best_time", 0.0))
	return float(raw) if raw is float or raw is int else 0.0

func medal_of(track_id: String) -> int:
	return int(record_of(track_id).get("medal", 0))

func is_completed(track_id: String) -> bool:
	return bool(record_of(track_id).get("completed", false))

func attempts_of(track_id: String) -> int:
	return int(record_of(track_id).get("attempts", 0))

## Returns { new_best, first_clear, credits, xp, vehicle_best, medal }.
func complete_track(track: TrackDef, time_s: float, medal: int, mode: String,
		vehicle_id: String = "") -> Dictionary:
	var records: Dictionary = data.get("records", {})
	var rec: Dictionary = records.get(track.id, {
		"best_time": 0.0, "medal": 0, "attempts": 0, "completed": false, "by_vehicle": {},
	})
	var by_vehicle: Dictionary = rec.get("by_vehicle", {}) if rec.get("by_vehicle", {}) is Dictionary else {}
	var first_clear: bool = not bool(rec.get("completed", false))
	var old_best: float = float(rec.get("best_time", 0.0))
	var new_best: bool = old_best <= 0.0 or time_s < old_best
	if new_best:
		rec["best_time"] = time_s
	rec["medal"] = maxi(int(rec.get("medal", 0)), medal)
	rec["attempts"] = int(rec.get("attempts", 0)) + 1
	rec["completed"] = true
	rec["mode"] = mode
	var vehicle_best: bool = false
	if not vehicle_id.is_empty():
		var raw_v: Variant = by_vehicle.get(vehicle_id, {"best_time": 0.0, "medal": 0})
		var vr: Dictionary = raw_v as Dictionary if raw_v is Dictionary else {
			"best_time": float(raw_v) if raw_v is float or raw_v is int else 0.0, "medal": 0,
		}
		var vbest: float = float(vr.get("best_time", 0.0))
		if vbest <= 0.0 or time_s < vbest:
			vr["best_time"] = time_s
			vehicle_best = true
		vr["medal"] = maxi(int(vr.get("medal", 0)), medal)
		by_vehicle[vehicle_id] = vr
	rec["by_vehicle"] = by_vehicle
	records[track.id] = rec
	data["records"] = records

	var reward: int = track.reward_credits if first_clear else int(track.reward_credits * 0.2)
	var xp: int = track.reward_xp if first_clear else int(track.reward_xp * 0.2)
	if vehicle_best:
		reward += int(track.reward_credits * 0.1)
		xp += int(track.reward_xp * 0.15)
	data["credits"] = credits() + reward
	data["xp"] = int(data.get("xp", 0)) + xp
	save_profile()
	credits_changed.emit(credits())
	_check_vehicle_unlocks()
	return {
		"new_best": new_best, "first_clear": first_clear, "credits": reward,
		"xp": xp, "vehicle_best": vehicle_best, "medal": medal,
	}

func add_distance(meters: float, seconds: float) -> void:
	data["distance_m"] = float(data.get("distance_m", 0.0)) + meters
	data["play_time_s"] = float(data.get("play_time_s", 0.0)) + seconds

# ------------------------------------------------------------------- tracks ---

func track_index(track_id: String) -> int:
	for i: int in range(Content.tracks.size()):
		if Content.tracks[i].id == track_id:
			return i
	return -1

func is_track_unlocked(track_id: String) -> bool:
	var idx: int = track_index(track_id)
	if idx <= 0:
		return idx == 0
	var prev: TrackDef = Content.tracks[idx - 1]
	return is_completed(prev.id)

func next_track_after(track_id: String) -> TrackDef:
	var idx: int = track_index(track_id)
	if idx >= 0 and idx + 1 < Content.tracks.size():
		return Content.tracks[idx + 1]
	return null

func total_medals() -> int:
	var total: int = 0
	for sid: String in (data.get("records", {}) as Dictionary).keys():
		total += int((data["records"][sid] as Dictionary).get("medal", 0))
	return total

func max_medals() -> int:
	return Content.tracks.size() * 3

func completed_count() -> int:
	var n: int = 0
	for t: TrackDef in Content.tracks:
		if is_completed(t.id):
			n += 1
	return n

# ----------------------------------------------------------------- vehicles ---

func owned_vehicles() -> Array:
	return data.get("owned_vehicles", ["jimny_jb74"]) as Array

func is_vehicle_owned(vehicle_id: String) -> bool:
	return owned_vehicles().has(vehicle_id)

func own_vehicle(vehicle_id: String) -> void:
	var owned: Array = owned_vehicles()
	if not owned.has(vehicle_id):
		owned.append(vehicle_id)
		data["owned_vehicles"] = owned
		_ensure_garage_entry(vehicle_id)
		save_profile()

func buy_vehicle(vehicle_id: String) -> bool:
	var def: VehicleDef = Content.vehicle_by_id(vehicle_id)
	if def == null or is_vehicle_owned(vehicle_id):
		return false
	if not is_vehicle_unlocked(def):
		return false
	if not spend_credits(def.price):
		return false
	own_vehicle(vehicle_id)
	select_vehicle(vehicle_id)
	return true

func is_vehicle_unlocked(def: VehicleDef) -> bool:
	if def.unlock_track.is_empty():
		return true
	return is_completed(def.unlock_track)

func _check_vehicle_unlocks() -> void:
	for def: VehicleDef in Content.vehicles:
		if def.unlock_track.is_empty():
			continue
		if is_completed(def.unlock_track):
			own_vehicle(def.id)

func selected_vehicle() -> String:
	var id: String = String(data.get("selected_vehicle", "jimny_jb74"))
	if not owned_vehicles().has(id):
		id = String(owned_vehicles()[0]) if not owned_vehicles().is_empty() else "jimny_jb74"
	return id

func select_vehicle(vehicle_id: String) -> void:
	if not is_vehicle_owned(vehicle_id):
		return
	data["selected_vehicle"] = vehicle_id
	save_profile()

# ------------------------------------------------------------------ garage ----

func _ensure_garage_entry(vehicle_id: String) -> Dictionary:
	var garage: Dictionary = data.get("garage", {})
	var entry: Dictionary = garage.get(vehicle_id, {"parts": {}, "owned": [], "condition": {}, "presets": {}})
	garage[vehicle_id] = entry
	data["garage"] = garage
	return entry

func garage_entry(vehicle_id: String) -> Dictionary:
	var garage: Dictionary = data.get("garage", {})
	if garage.has(vehicle_id):
		return garage[vehicle_id] as Dictionary
	return _ensure_garage_entry(vehicle_id)

func vehicle_config(vehicle_id: String) -> Dictionary:
	var def: VehicleDef = Content.vehicle_by_id(vehicle_id)
	var entry: Dictionary = garage_entry(vehicle_id)
	if def == null:
		return GarageModel.empty_config()
	return GarageModel.sanitize_config(def, entry)

func set_vehicle_config(vehicle_id: String, cfg: Dictionary) -> void:
	var def: VehicleDef = Content.vehicle_by_id(vehicle_id)
	var entry: Dictionary = _ensure_garage_entry(vehicle_id)
	var clean: Dictionary = GarageModel.sanitize_config(def, cfg) if def != null else cfg
	entry["parts"] = clean.get("parts", {})
	entry["condition"] = clean.get("condition", {})
	entry["presets"] = clean.get("presets", {})
	entry["transfer"] = clean.get("transfer", "")
	entry["diff"] = clean.get("diff", "")
	save_profile()
	profile_changed.emit()

func set_config_value(vehicle_id: String, key: String, value: Variant) -> void:
	var cfg: Dictionary = vehicle_config(vehicle_id)
	cfg[key] = value
	set_vehicle_config(vehicle_id, cfg)

func owned_parts(vehicle_id: String) -> Array:
	var entry: Dictionary = garage_entry(vehicle_id)
	return _string_array(entry.get("owned", []))

func is_part_owned(vehicle_id: String, part_id: String) -> bool:
	if Content.part_by_id(part_id) == null:
		return false
	var p: PartDef = Content.part_by_id(part_id)
	if p.tier == 0:
		return true
	return owned_parts(vehicle_id).has(part_id)

func buy_part(vehicle_id: String, part_id: String) -> bool:
	var part: PartDef = Content.part_by_id(part_id)
	if part == null or is_part_owned(vehicle_id, part_id):
		return false
	if not spend_credits(part.cost):
		return false
	var entry: Dictionary = _ensure_garage_entry(vehicle_id)
	var owned: Array = _string_array(entry.get("owned", []))
	owned.append(part_id)
	entry["owned"] = owned
	save_profile()
	return true

## Fits an owned part. Returns {ok, reasons[], warnings[]}.
func install_part(vehicle_id: String, part_id: String) -> Dictionary:
	var part: PartDef = Content.part_by_id(part_id)
	var def: VehicleDef = Content.vehicle_by_id(vehicle_id)
	if part == null or def == null:
		return {"ok": false, "reasons": [{"fa": "قطعه نامعتبر", "en": "Invalid part"}], "warnings": []}
	var cfg: Dictionary = vehicle_config(vehicle_id)
	if not is_part_owned(vehicle_id, part_id):
		return {"ok": false, "reasons": [{"fa": "این قطعه خریداری نشده است.", "en": "This part has not been purchased."}], "warnings": []}
	var check: Dictionary = PartCompatibility.check(def, cfg, part)
	if not bool(check.get("ok", false)):
		return check
	var parts: Dictionary = (cfg.get("parts", {}) as Dictionary).duplicate()
	parts[str(int(part.slot))] = part.id
	cfg["parts"] = parts
	set_vehicle_config(vehicle_id, cfg)
	return {"ok": true, "reasons": [], "warnings": check.get("warnings", [])}

func part_condition(vehicle_id: String, part_id: String) -> int:
	var entry: Dictionary = garage_entry(vehicle_id)
	var cond: Dictionary = entry.get("condition", {}) if entry.get("condition", {}) is Dictionary else {}
	return clampi(int(cond.get(part_id, 0)), 0, 4)

func set_part_condition(vehicle_id: String, part_id: String, condition: int) -> void:
	var entry: Dictionary = _ensure_garage_entry(vehicle_id)
	var cond: Dictionary = entry.get("condition", {}) if entry.get("condition", {}) is Dictionary else {}
	cond[part_id] = clampi(condition, 0, 4)
	entry["condition"] = cond
	save_profile()

func repair_cost(vehicle_id: String, part_id: String) -> int:
	var part: PartDef = Content.part_by_id(part_id)
	if part == null:
		return 0
	var condition: int = part_condition(vehicle_id, part_id)
	if condition == PartDef.Condition.NEW:
		return 0
	var factor: float = [0.0, 0.12, 0.3, 0.55, 0.8][condition]
	return maxi(int(float(part.cost) * factor), 25)

func repair_part(vehicle_id: String, part_id: String) -> bool:
	var cost: int = repair_cost(vehicle_id, part_id)
	if cost <= 0:
		return false
	if not spend_credits(cost):
		return false
	set_part_condition(vehicle_id, part_id, PartDef.Condition.NEW)
	return true

## Wear from one race. High load and high temperature age the engine; a heavy foot
## wears the clutch and tyres. Condition is a state, not a percentage.
func apply_race_wear(vehicle_id: String, seconds: float, load_avg: float,
		heat_peak_c: float, clutch_slip_s: float) -> void:
	var cfg: Dictionary = vehicle_config(vehicle_id)
	var entry: Dictionary = _ensure_garage_entry(vehicle_id)
	var cond: Dictionary = entry.get("condition", {}) if entry.get("condition", {}) is Dictionary else {}
	var parts: Dictionary = cfg.get("parts", {})
	var wear: float = seconds * (0.002 + load_avg * 0.010)
	if heat_peak_c > 118.0:
		wear += (heat_peak_c - 118.0) * 0.02
	for slot_key: String in parts.keys():
		var slot: int = int(slot_key)
		var pid: String = String(parts[slot_key])
		var part: PartDef = Content.part_by_id(pid)
		if part == null:
			continue
		var amount: float = wear
		match part.slot:
			PartDef.Slot.TYRES:
				amount = seconds * 0.012 + load_avg * 0.02
			PartDef.Slot.CLUTCH:
				amount = clutch_slip_s * 0.006 + wear * 0.5
			PartDef.Slot.BRAKE_PADS, PartDef.Slot.BRAKE_DISCS:
				amount = seconds * 0.004
			PartDef.Slot.SPRINGS, PartDef.Slot.DAMPERS:
				amount = seconds * 0.003
			_:
				pass
		_bump_condition(cond, pid, amount)
	entry["condition"] = cond
	save_profile()

func _bump_condition(cond: Dictionary, part_id: String, amount: float) -> void:
	if amount <= 0.0:
		return
	var current: int = clampi(int(cond.get(part_id, 0)), 0, 4)
	# Accumulate fractional wear in a hidden bucket per part id.
	var key: String = part_id + ":wear"
	var accum: float = float(cond.get(key, 0.0)) + amount
	cond[key] = accum
	while accum >= 1.0 and current < 4:
		current += 1
		accum -= 1.0
	cond[part_id] = current
	cond[key] = accum

# ---------------------------------------------------------------- presets -----

func save_preset(vehicle_id: String, preset_name: String) -> void:
	var cfg: Dictionary = vehicle_config(vehicle_id)
	var entry: Dictionary = _ensure_garage_entry(vehicle_id)
	var presets: Dictionary = entry.get("presets", {}) if entry.get("presets", {}) is Dictionary else {}
	presets[preset_name] = (cfg.get("parts", {}) as Dictionary).duplicate(true)
	entry["presets"] = presets
	save_profile()

func preset_names(vehicle_id: String) -> Array:
	var entry: Dictionary = garage_entry(vehicle_id)
	var presets: Dictionary = entry.get("presets", {}) if entry.get("presets", {}) is Dictionary else {}
	var out: Array = presets.keys()
	out.sort()
	return out

func apply_preset(vehicle_id: String, preset_name: String) -> bool:
	var entry: Dictionary = garage_entry(vehicle_id)
	var presets: Dictionary = entry.get("presets", {}) if entry.get("presets", {}) is Dictionary else {}
	if not presets.has(preset_name):
		return false
	var cfg: Dictionary = vehicle_config(vehicle_id)
	cfg["parts"] = (presets[preset_name] as Dictionary).duplicate(true)
	set_vehicle_config(vehicle_id, cfg)
	return true

func delete_preset(vehicle_id: String, preset_name: String) -> void:
	var entry: Dictionary = _ensure_garage_entry(vehicle_id)
	var presets: Dictionary = entry.get("presets", {}) if entry.get("presets", {}) is Dictionary else {}
	presets.erase(preset_name)
	entry["presets"] = presets
	save_profile()

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
		"version": int(data.get("version", VERSION)),
	}
