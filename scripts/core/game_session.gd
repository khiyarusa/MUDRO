extends Node
## GameSession (autoload): what is being raced right now and what just happened.
##
## MUDRO 3.0 races tracks, not stages: the session holds a TrackDef id, the
## player's vehicle and the exact build the garage produced for this run.

const MODES: Array[String] = [
	"rally", "hillclimb", "downhill", "sprint", "timeattack", "endurance",
	"freedrive", "test",
]

## 2.0 mode ids still reachable from old saved shortcuts.
const MODE_ALIAS: Dictionary = {
	"career": "rally",
	"timetrial": "timeattack",
	"technical": "sprint",
}

var mode: String = "rally"
var track_id: String = ""
var stage_id: String = ""  # compatibility alias
var vehicle_id: String = ""
var region_filter: String = ""
var env_filter: String = ""
var last_result: Dictionary = {}
var race_attempt: int = 0

func start_track(id: String, race_mode: String) -> void:
	track_id = id
	stage_id = id
	mode = String(MODE_ALIAS.get(race_mode, race_mode))
	vehicle_id = SaveManager.selected_vehicle()
	race_attempt = 0
	last_result = {}

func start_stage(id: String, race_mode: String) -> void:
	start_track(id, race_mode)

func begin_stage(id: String, race_mode: String) -> void:
	start_track(id, race_mode)

func track_def() -> TrackDef:
	return Content.track_by_id(track_id)

func stage_def() -> TrackDef:
	return track_def()

func vehicle_def() -> VehicleDef:
	var base: VehicleDef = Content.vehicle_by_id(vehicle_id)
	if base == null:
		base = Content.vehicles[0]
		vehicle_id = base.id
	return GarageModel.build(base, SaveManager.vehicle_config(vehicle_id))

## The saved garage configuration for this run, already sanitised.
func vehicle_config() -> Dictionary:
	var base: VehicleDef = Content.vehicle_by_id(vehicle_id)
	return GarageModel.sanitize_config(base, SaveManager.vehicle_config(vehicle_id))

func set_vehicle_config_value(key: String, value: Variant) -> void:
	SaveManager.set_config_value(vehicle_id, key, value)

func mode_label() -> String:
	return Loc.t("mode_%s" % mode)

func objective_text() -> String:
	match mode:
		"hillclimb":
			return Loc.t("objective_hillclimb")
		"downhill":
			return Loc.t("objective_downhill")
		"timeattack", "sprint":
			return Loc.t("objective_timeattack")
		"endurance":
			return Loc.t("objective_endurance")
		"freedrive":
			return Loc.t("objective_freedrive")
		"test":
			return Loc.t("objective_test")
		_:
			return Loc.t("objective_rally")

## Ambient temperature used by the cooling model, from region and weather.
func ambient_c() -> float:
	var track: TrackDef = track_def()
	if track == null:
		return 22.0
	match track.region:
		"alpine":
			return 6.0
		"glacier":
			return -6.0
		"black_ridge":
			return 12.0
		"pine":
			return 14.0
		_:
			return 28.0

func finish(time_s: float, damage: float, top_speed: float, extra: Dictionary = {}) -> Dictionary:
	var track: TrackDef = track_def()
	if track == null:
		return {}
	var medal: int = track.medal_for_time(time_s)
	var prev_best: float = SaveManager.best_time(track.id)
	var outcome: Dictionary = SaveManager.complete_track(track, time_s, medal, mode, vehicle_id)
	var next_track: TrackDef = SaveManager.next_track_after(track.id)
	last_result = {
		"track_id": track.id,
		"stage_id": track.id,
		"stage_name": track.label(Loc.lang),
		"track_name": track.label(Loc.lang),
		"region": track.region,
		"mode": mode,
		"time": time_s,
		"medal": medal,
		"best": SaveManager.best_time(track.id),
		"previous_best": prev_best,
		"vehicle_best": SaveManager.best_time_for(track.id, vehicle_id),
		"new_best": bool(outcome.get("new_best", false)),
		"vehicle_best_new": bool(outcome.get("vehicle_best", false)),
		"credits": int(outcome.get("credits", 0)),
		"xp": int(outcome.get("xp", 0)),
		"damage": damage,
		"top_speed": top_speed,
		"first_clear": bool(outcome.get("first_clear", false)),
		"splits": extra.get("splits", []),
		"targets": extra.get("targets", []),
		"next_track_id": next_track.id if next_track != null else "",
		"next_track_unlocked": next_track != null and SaveManager.is_track_unlocked(next_track.id),
	}
	return last_result

func next_stage() -> TrackDef:
	return SaveManager.next_track_after(track_id)

func next_track() -> TrackDef:
	return next_stage()

func retry() -> void:
	start_track(track_id, mode)

func owned_vehicle_ids() -> Array:
	var out: Array = []
	for v: VehicleDef in Content.vehicles:
		if SaveManager.is_vehicle_owned(v.id):
			out.append(v.id)
	return out
