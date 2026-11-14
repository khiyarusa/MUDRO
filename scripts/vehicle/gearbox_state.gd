class_name GearboxState
extends RefCounted
## Gear selection, shift interruption, transfer case and automatic scheduling.
##
## Gear 0 = neutral, 1..N = forward, -1 = reverse.
## The gearbox never decides by itself whether a manual shift is legal: the player
## interface asks, and `can_engage()` answers with a concrete reason. That is what
## makes the clutch interlock and the over-rev guard testable instead of cosmetic.

const REJECT_NONE: String = ""
const REJECT_CLUTCH: String = "clutch"
const REJECT_SHIFTING: String = "shifting"
const REJECT_REVERSE: String = "reverse"
const REJECT_OVERREV: String = "overrev"
const REJECT_RANGE: String = "range"
const REJECT_STALLED: String = "stalled"

var profile: TransmissionProfile
## Legacy view of the same ratios, kept so older call sites and tools keep working.
var config: GearboxConfig

var gear: int = 0
var shift_timer: float = 0.0
var time_in_gear: float = 0.0
var auto_mode: bool = false
var last_shift_dir: int = 0
var reject_reason: String = ""
var reject_gear: int = 0

var engine_redline: float = 6000.0
var wheel_radius: float = 0.4

var transfer_ids: PackedStringArray = PackedStringArray(["2H"])
var transfer_ratios: PackedFloat32Array = PackedFloat32Array([1.0])
var transfer_index: int = 0
var range_id: String = "D"

var kickdown_timer: float = 0.0
var auto_hold: float = 0.0
var converter_slip_rpm: float = 0.0

func _init(source: Resource = null) -> void:
	if source != null:
		setup(source)

## Accepts either a TransmissionProfile (preferred) or a legacy GearboxConfig.
func setup(source: Resource) -> void:
	if source is TransmissionProfile:
		profile = (source as TransmissionProfile).duplicate_profile()
	elif source is GearboxConfig:
		profile = (source as GearboxConfig).to_profile()
	else:
		push_warning("GearboxState.setup: unsupported data %s" % source)
		return
	config = profile_to_config(profile)
	auto_mode = profile.is_automatic()
	if profile.is_automatic():
		range_id = "D"
	else:
		range_id = "M"

static func profile_to_config(p: TransmissionProfile) -> GearboxConfig:
	var g := GearboxConfig.new()
	g.display_name = p.name_en
	g.ratios = p.ratios.duplicate()
	g.reverse_ratio = p.reverse_ratio
	g.final_drive = p.final_drive
	g.efficiency = p.efficiency
	g.shift_time = p.shift_time
	g.auto_upshift_fraction = p.auto_upshift_fraction
	g.auto_downshift_fraction = p.auto_downshift_fraction
	return g

func reset(initial_gear: int = 0) -> void:
	gear = initial_gear
	shift_timer = 0.0
	time_in_gear = 0.0
	last_shift_dir = 0
	kickdown_timer = 0.0
	auto_hold = 0.0
	reject_reason = ""
	reject_gear = 0
	if profile != null and profile.is_automatic():
		range_id = "D"

func gear_count() -> int:
	if profile != null:
		return profile.gear_count()
	return config.gear_count() if config != null else 0

func is_shifting() -> bool:
	return shift_timer > 0.0

## Ratio actually transmitting torque right now (0 while the box is between gears).
func effective_ratio() -> float:
	if profile == null or is_shifting():
		return 0.0
	return profile.ratio_for(gear)

func transfer_ratio() -> float:
	if transfer_ratios.is_empty():
		return 1.0
	return transfer_ratios[clampi(transfer_index, 0, transfer_ratios.size() - 1)]

func transfer_id() -> String:
	if transfer_ids.is_empty():
		return "2H"
	return transfer_ids[clampi(transfer_index, 0, transfer_ids.size() - 1)]

func total_ratio() -> float:
	return effective_ratio() * (profile.final_drive if profile != null else 1.0) * transfer_ratio()

## Wheel-side torque for a crank torque in the selected gear.
func wheel_torque(crank_torque: float) -> float:
	if profile == null:
		return 0.0
	return crank_torque * total_ratio() * profile.efficiency

## Highest road speed this gear can be engaged at without overspeeding the engine.
func max_speed_for(target: int) -> float:
	if profile == null or engine_redline <= 0.0 or wheel_radius <= 0.0:
		return 999.0
	var ratio: float = absf(profile.ratio_for(target)) * profile.final_drive * transfer_ratio()
	if ratio <= 0.0001:
		return 999.0
	return Units.omega_from_rpm(engine_redline) * wheel_radius / ratio

## Returns REJECT_* (empty string when the shift is legal).
func can_engage(target: int, speed_mps: float = 0.0, clutch_ok: bool = true) -> String:
	if profile == null:
		return REJECT_NONE
	if target == gear:
		return REJECT_NONE
	if target > gear_count() or target < -1:
		return REJECT_RANGE
	if is_shifting():
		return REJECT_SHIFTING
	if target == -1:
		if not profile.has_reverse:
			return REJECT_RANGE
		if speed_mps > 1.4:
			return REJECT_REVERSE
		return REJECT_NONE
	if target == 0:
		return REJECT_NONE
	if profile.requires_clutch and not clutch_ok:
		return REJECT_CLUTCH
	var limit: float = max_speed_for(target) * (1.0 + profile.overrev_margin)
	if absf(speed_mps) > limit:
		return REJECT_OVERREV
	return REJECT_NONE

## Returns true when the requested gear was accepted. `force` bypasses the player
## interlock (used by the automatic scheduler and by recovery/tests).
func request_gear(target: int, force: bool = false, clutch_ok: bool = true, speed_mps: float = 0.0) -> bool:
	if profile == null:
		return false
	var top: int = gear_count()
	if profile.is_automatic():
		top = range_top_gear()
	elif range_id == "P":
		top = 0
	var clamped: int = clampi(target, -1, top)
	if clamped == gear:
		return false
	if not force:
		var reason: String = can_engage(clamped, speed_mps, clutch_ok)
		if reason != REJECT_NONE:
			reject_reason = reason
			reject_gear = clamped
			return false
	last_shift_dir = signi(clamped - gear)
	gear = clamped
	# A crash box needs a deliberate hand and takes longer; a synchromesh box is
	# quicker. Neither is instantaneous.
	shift_timer = maxf(0.05, profile.shift_time * (1.35 - 0.35 * clampf(profile.synchro, 0.0, 1.0)))
	time_in_gear = 0.0
	reject_reason = ""
	reject_gear = 0
	return true

func shift_up(clutch_ok: bool = true, speed_mps: float = 0.0) -> bool:
	return request_gear(gear + 1, false, clutch_ok, speed_mps)

func shift_down(clutch_ok: bool = true, speed_mps: float = 0.0) -> bool:
	return request_gear(gear - 1, false, clutch_ok, speed_mps)

func update(dt: float) -> void:
	shift_timer = maxf(0.0, shift_timer - dt)
	time_in_gear += dt
	kickdown_timer = maxf(0.0, kickdown_timer - dt)
	auto_hold = maxf(0.0, auto_hold - dt)

## ---------------------------------------------------------------- transfer ---

func set_transfer_modes(ids: PackedStringArray, ratios: PackedFloat32Array) -> void:
	transfer_ids = ids
	transfer_ratios = ratios
	transfer_index = clampi(transfer_index, 0, maxi(ids.size() - 1, 0))

func set_transfer(id: String) -> bool:
	var idx: int = transfer_ids.find(id)
	if idx < 0 or idx == transfer_index:
		return false
	transfer_index = idx
	# Changing range is a mechanical event: it interrupts torque briefly.
	shift_timer = maxf(shift_timer, 0.25)
	return true

func cycle_transfer() -> String:
	if transfer_ids.size() <= 1:
		return transfer_id()
	transfer_index = (transfer_index + 1) % transfer_ids.size()
	shift_timer = maxf(shift_timer, 0.25)
	return transfer_id()

func transfer_drives_front() -> bool:
	var id: String = transfer_id()
	return id == "4H" or id == "4L" or id == "AWD"

func has_low_range() -> bool:
	return transfer_ids.has("4L")

## --------------------------------------------------------------- automatic ---

func range_top_gear() -> int:
	match range_id:
		"P", "N":
			return 0
		"R":
			return -1
		"L":
			return mini(2, gear_count())
		_:
			return gear_count()

func set_range(id: String) -> bool:
	if profile == null or not profile.is_automatic():
		return false
	if profile.ranges.size() > 0 and not profile.ranges.has(id):
		return false
	if id == range_id:
		return false
	range_id = id
	match id:
		"P":
			request_gear(0, true)
			return true
		"N":
			request_gear(0, true)
			return true
		"R":
			request_gear(-1, true)
			return true
		"L":
			request_gear(clampi(gear, 1, mini(2, gear_count())), true)
			return true
		_:
			request_gear(clampi(gear, 1, gear_count()), true)
			return true

func parking_lock() -> bool:
	return range_id == "P"

## Automatic shift schedule. This is load-, grade- and slip-aware instead of a
## single rpm threshold:
##  * upshift needs rpm above the schedule *and* a road speed that will not lug
##    the engine in the next gear;
##  * a loaded engine raises the upshift point (it holds the gear longer);
##  * kickdown drops a gear under full throttle and blocks the immediate upshift;
##  * a steep grade or a low-rpm lug downshifts before the engine dies.
func auto_update(dt: float, rpm: float, throttle: float, speed_mps: float,
		load_frac: float = 0.0, slope_deg: float = 0.0, slip: float = 0.0) -> void:
	update(dt)
	if profile == null or not profile.is_automatic() or is_shifting():
		return
	if range_id == "P" or range_id == "N":
		return
	if range_id == "R":
		if throttle > 0.2 and speed_mps > -0.3 and gear == -1:
			request_gear(1, true)
		return
	if gear == 0:
		if absf(speed_mps) > 0.35 or throttle > 0.12:
			request_gear(1 if speed_mps >= -0.2 else -1, true)
		return
	if gear == -1:
		if speed_mps > -0.2 and (throttle > 0.15 or speed_mps > 0.4):
			request_gear(1, true)
		return
	if time_in_gear < 0.30:
		return

	var top: int = range_top_gear()
	var up_rpm: float = engine_redline * (profile.auto_upshift_fraction + profile.load_upshift_bias * clampf(load_frac, 0.0, 1.0))
	var down_rpm: float = engine_redline * profile.auto_downshift_fraction
	var kick: bool = throttle >= profile.kickdown_throttle and rpm < engine_redline * profile.kickdown_rpm_fraction
	var lug: bool = load_frac > 0.55 and rpm < engine_redline * 0.42
	var grade: bool = slope_deg > profile.slope_downshift_deg and rpm < engine_redline * 0.60
	var spinning: bool = absf(slip) > 1.2

	# Downshift first: a kickdown or a lugging engine matters more than a smooth
	# upshift schedule.
	if gear > 1:
		var need_lower: bool = kick or lug or grade
		if need_lower or (rpm < down_rpm and time_in_gear > 0.45 and not spinning):
			if request_gear(gear - 1, true):
				kickdown_timer = profile.kickdown_hold_s if kick else 0.0
			return

	if kickdown_timer > 0.0:
		return
	if rpm > up_rpm and gear < top and speed_mps > 1.2 and not spinning:
		var next_ratio_speed: float = max_speed_for(gear + 1)
		var projected_rpm: float = 0.0
		if next_ratio_speed > 0.1:
			projected_rpm = engine_redline * clampf(absf(speed_mps) / next_ratio_speed, 0.0, 1.2)
		if projected_rpm < down_rpm * 1.25:
			# Never shift up into a gear that would immediately lug.
			return
		request_gear(gear + 1, true)

func is_kickdown() -> bool:
	return kickdown_timer > 0.0

## ------------------------------------------------------------------ utils ---

func describe() -> String:
	if gear == 0:
		return "N"
	if gear == -1:
		return "R"
	return str(gear)

func label(lang: String) -> String:
	return profile.label(lang) if profile != null else ""

func gear_label() -> String:
	if profile != null and profile.is_automatic():
		return range_id
	return describe()
