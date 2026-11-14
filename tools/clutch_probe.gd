extends Node2D
## Drivetrain diagnostic: one gear, full throttle, prints the torque path so a
## crawl can be traced to the clutch, the axle or the tyre instead of guessed.
## Run:
##   godot --headless --path . res://tools/clutch_probe.tscn -- <track_id> <vehicle_id> <seconds>

var track: TrackDef
var terrain: TerrainBuilder
var vehicle: VehicleBody
var _time: float = 0.0
var _limit: float = 10.0
var _next: float = 0.0

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var track_id: String = args[0] if args.size() > 0 else "zagros_01"
	var vehicle_id: String = args[1] if args.size() > 1 else "hilux_an120"
	_limit = float(args[2]) if args.size() > 2 else 10.0
	track = Content.track_by_id(track_id)
	terrain = TerrainBuilder.new()
	add_child(terrain)
	terrain.build(track, Content.surfaces)
	var base: VehicleDef = Content.vehicle_by_id(vehicle_id)
	var def: VehicleDef = GarageModel.build(base, GarageModel.empty_config())
	vehicle = VehicleBody.new()
	add_child(vehicle)
	vehicle.setup(def, Content.surfaces)
	vehicle.attach_surface_probe(terrain)
	vehicle.global_transform = terrain.start_transform()
	vehicle.gearbox.request_gear(1, true, true, 0.0)
	print("CLUTCH PROBE %s / %s | auto_clutch=%s manual=%s capacity=%.0f stiffness=%.2f" % [
		track_id, vehicle_id, str(vehicle.auto_clutch), str(vehicle.manual_clutch_enabled),
		vehicle.clutch.capacity, vehicle.clutch.stiffness])

func _physics_process(delta: float) -> void:
	if vehicle == null:
		return
	_time += delta
	vehicle.set_inputs(1.0, 0.0, 0.0, 1.0)
	if _time >= _next:
		_next = _time + 0.5
		var gb: GearboxState = vehicle.gearbox
		var a0: WheelAxis = vehicle.axles[0]
		var a1: WheelAxis = vehicle.axles[1]
		print("t=%4.1f spd=%5.1fkm/h gear=%d ratio=%5.2f rpm=%4.0f eng_tq=%5.0f eng=%5.0f%% clutch: eng=%.2f tq=%5.0f lock=%s shift=%s | ax0 w=%6.1f N=%6.0f F=%6.0f | ax1 w=%6.1f N=%6.0f F=%6.0f | x=%6.1f" % [
			_time, vehicle.speed_kmh(), gb.gear, gb.total_ratio(), vehicle.engine.rpm,
			vehicle.engine.output_torque(), vehicle.engine.throttle * 100.0,
			vehicle.clutch.engagement, vehicle.clutch.transmitted_torque,
			str(vehicle.clutch.locked), str(gb.is_shifting()),
			a0.omega, a0.normal_load, a0.tire_force,
			a1.omega, a1.normal_load, a1.tire_force,
			vehicle.global_position.x / Units.PPM])
	if _time >= _limit:
		print("CLUTCH PROBE DONE: %.1f m in %.1f s" % [
			vehicle.global_position.x / Units.PPM, _time])
		get_tree().quit(0)
