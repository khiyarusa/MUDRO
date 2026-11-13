extends Node
## Diagnostic: one vehicle on one slope, printing the driveline state over time.
## Run: godot --headless --path . res://tools/diag_climb.tscn -- <angle> <gear> <surface> <vehicle> <seconds>

var _arena: Node2D

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var angle: float = float(args[0]) if args.size() > 0 else 20.0
	var gear: int = int(args[1]) if args.size() > 1 else 1
	var surface: String = args[2] if args.size() > 2 else "hard_dirt"
	var vehicle_id: String = args[3] if args.size() > 3 else "ranger_4x4"
	var seconds: float = float(args[4]) if args.size() > 4 else 5.0
	await get_tree().process_frame

	var stage := StageDef.new()
	stage.id = "diag"
	stage.environment = "canyon"
	stage.length_m = 260.0
	stage.noise_amplitude = 0.0
	stage.decor_density = 0.0
	var rise: float = 260.0 * tan(deg_to_rad(angle))
	stage.points = PackedVector2Array([Vector2(0, 0), Vector2(130, rise * 0.5), Vector2(260, rise)])
	stage.surface_spans = [{"from": 0.0, "to": 280.0, "surface": surface}]
	stage.checkpoints = PackedFloat32Array()
	stage.obstacles = []

	_arena = Node2D.new()
	add_child(_arena)
	var terrain := TerrainBuilder.new()
	_arena.add_child(terrain)
	terrain.build(stage, Content.surfaces)
	var def: VehicleDef = Content.vehicle_by_id(vehicle_id)
	var veh := VehicleBody.new()
	_arena.add_child(veh)
	veh.setup(def, Content.surfaces)
	veh.attach_surface_probe(terrain)
	veh.global_transform = terrain.start_transform()
	veh.gearbox.reset(gear)
	veh.damage.reset()
	veh.controls_locked = false
	veh.auto_transmission = false

	print("angle %.1f  gear %d  surface %s  vehicle %s  mass %.0f  ratio %.2f" % [
		angle, gear, surface, vehicle_id, def.mass_kg, def.gearbox.total_ratio(gear)])
	var steps: int = int(seconds * 120.0)
	var start_y: float = veh.global_position.y
	var start_x: float = veh.global_position.x
	for i: int in range(steps):
		veh.set_inputs(1.0, 0.0, 0.0, 1.0)
		await get_tree().physics_frame
		if i % 30 == 0:
			var front: WheelAxis = veh.axles[0]
			var rear: WheelAxis = veh.axles[1]
			var ratio: float = veh.gearbox.total_ratio()
			var slip_rpm: float = veh.engine.rpm - Units.rpm_from_omega(rear.omega) * ratio
			print("t=%.2f x=%.1f dy=%.1f v=%5.1f km/h rpm=%4.0f g=%d clut=%.2f tq=%.0f drive=%.0f Nm | F:slip %+.2f F=%.0f N %.0f | R:slip %+.2f F=%.0f N %.0f om=%.1f sliprpm=%.0f" % [
				float(i) / 120.0,
				(veh.global_position.x - start_x) / Units.PPM,
				(start_y - veh.global_position.y) / Units.PPM,
				veh.speed_kmh(), veh.engine.rpm, veh.gearbox.gear,
				veh.clutch.engagement, veh.clutch.transmitted_torque,
				veh.clutch.transmitted_torque * ratio * def.gearbox.efficiency,
				front.slip_ratio, front.tire_force, front.normal_load,
				rear.slip_ratio, rear.tire_force, rear.normal_load, rear.omega, slip_rpm])
	get_tree().quit(0)
