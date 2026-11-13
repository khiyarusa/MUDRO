extends Node
## GameSession (autoload): what is being raced right now and what just happened.

var mode: String = "career"
var stage_id: String = ""
var vehicle_id: String = ""
var env_filter: String = ""
var last_result: Dictionary = {}
var race_attempt: int = 0

func start_stage(id: String, race_mode: String) -> void:
	stage_id = id
	mode = race_mode
	vehicle_id = SaveManager.selected_vehicle()
	race_attempt = 0
	last_result = {}

func stage_def() -> StageDef:
	return Content.stage_by_id(stage_id)

func vehicle_def() -> VehicleDef:
	var base: VehicleDef = Content.vehicle_by_id(vehicle_id)
	if base == null:
		base = Content.vehicles[0]
	return GarageModel.build(base, SaveManager.vehicle_upgrades(vehicle_id), SaveManager.vehicle_config(vehicle_id))

## The driveline configuration that will actually be simulated for this run.
func vehicle_config() -> Dictionary:
	var base: VehicleDef = Content.vehicle_by_id(vehicle_id)
	return GarageModel.sanitize_config(base, SaveManager.vehicle_config(vehicle_id))

func set_vehicle_config_value(key: String, value: Variant) -> void:
	SaveManager.set_config_value(vehicle_id, key, value)

## Prepares a run without switching scenes, so the route briefing can inspect the
## real stage and driveline before the player commits.
func begin_stage(id: String, race_mode: String) -> void:
	start_stage(id, race_mode)

func mode_label() -> String:
	return Loc.t("mode_%s" % mode)

func objective_text() -> String:
	match mode:
		"hillclimb":
			return Loc.t("objective_hillclimb")
		"timetrial":
			return Loc.t("objective_timetrial")
		"technical":
			return Loc.t("objective_technical")
		_:
			return Loc.t("objective_career")

func finish(time_s: float, damage: float, top_speed: float) -> Dictionary:
	var stage: StageDef = stage_def()
	if stage == null:
		return {}
	var medal: int = stage.medal_for_time(time_s)
	var prev_best: float = SaveManager.best_time(stage.id)
	var outcome: Dictionary = SaveManager.complete_stage(stage, time_s, medal, mode)
	last_result = {
		"stage_id": stage.id,
		"stage_name": stage.label(Loc.lang),
		"mode": mode,
		"time": time_s,
		"medal": medal,
		"best": SaveManager.best_time(stage.id),
		"previous_best": prev_best,
		"new_best": bool(outcome.get("new_best", false)),
		"credits": int(outcome.get("credits", 0)),
		"xp": int(outcome.get("xp", 0)),
		"damage": damage,
		"top_speed": top_speed,
		"first_clear": bool(outcome.get("first_clear", false)),
	}
	return last_result

func next_stage() -> StageDef:
	return SaveManager.next_stage_after(stage_id)

func retry() -> void:
	start_stage(stage_id, mode)
