class_name TrackProfile
extends RefCounted
## Authored elevation profile of a mountain track.
##
## A profile is a list of contiguous segments. Every segment stores the slope at
## its entry and at its exit (rise / run, so 0.15 == 15 %). Within a segment the
## slope blends linearly, and elevation is the exact integral of that slope:
##
##     s(t) = s_in + (s_out - s_in) * t            t = distance / segment length
##     y(t) = y0 + L * (s_in * t + 0.5 * (s_out - s_in) * t^2)
##
## Because neighbouring segments share the slope at their joint, the surface is
## C1 continuous: position and gradient match exactly at every knot. There are no
## steps, no seams and no random noise — every crest and every climb is authored.
## This is the "smooth interpolation" contract the terrain builder relies on.

var segments: Array[Dictionary] = []
var start_elevation_m: float = 0.0

var _xs: PackedFloat32Array = PackedFloat32Array()
var _ys: PackedFloat32Array = PackedFloat32Array()
var _ss: PackedFloat32Array = PackedFloat32Array()
var _built: bool = false

func setup(profile_segments: Array, start_m: float = 0.0) -> TrackProfile:
	segments.clear()
	for entry: Variant in profile_segments:
		if entry is Dictionary:
			segments.append(entry as Dictionary)
	start_elevation_m = start_m
	_built = false
	return self

func segment_count() -> int:
	return segments.size()

func total_length() -> float:
	var total: float = 0.0
	for s: Dictionary in segments:
		total += maxf(float(s.get("len", 0.0)), 0.0)
	return total

## Builds the knot tables. Safe to call repeatedly.
func build() -> void:
	if _built:
		return
	_xs.clear()
	_ys.clear()
	_ss.clear()
	var x: float = 0.0
	var y: float = start_elevation_m
	_xs.append(x)
	_ys.append(y)
	_ss.append(float(segments[0].get("s_in", 0.0)) if not segments.is_empty() else 0.0)
	for s: Dictionary in segments:
		var length_m: float = maxf(float(s.get("len", 0.0)), 0.0)
		var s_in: float = float(s.get("s_in", 0.0))
		var s_out: float = float(s.get("s_out", s_in))
		if length_m <= 0.0:
			continue
		y += length_m * (s_in + 0.5 * (s_out - s_in))
		x += length_m
		_xs.append(x)
		_ys.append(y)
		_ss.append(s_out)
	_built = true

func _ensure() -> void:
	if not _built:
		build()

func _segment_index(x_m: float) -> int:
	# Profiles are short (<= 30 segments); a linear scan is cheaper and exact.
	for i: int in range(_xs.size() - 1):
		if x_m >= _xs[i] and x_m <= _xs[i + 1]:
			return i
	return -1

## Elevation in metres at distance x. Outside the authored range the end slope is
## extended, so a vehicle that rolls past the finish line never falls off a cliff.
func elevation_at(x_m: float) -> float:
	_ensure()
	if _xs.size() < 2:
		return start_elevation_m
	if x_m <= _xs[0]:
		return _ys[0] + (_xs[0] - x_m) * -_ss[0]
	var last: int = _xs.size() - 1
	if x_m >= _xs[last]:
		return _ys[last] + (x_m - _xs[last]) * _ss[last]
	var i: int = _segment_index(x_m)
	if i < 0:
		return _ys[last]
	var length_m: float = _xs[i + 1] - _xs[i]
	if length_m <= 0.0001:
		return _ys[i]
	var t: float = (x_m - _xs[i]) / length_m
	var s_in: float = _ss[i]
	var s_out: float = _ss[i + 1]
	return _ys[i] + length_m * (s_in * t + 0.5 * (s_out - s_in) * t * t)

## Slope (rise / run) at distance x.
func slope_at(x_m: float) -> float:
	_ensure()
	if _xs.size() < 2:
		return 0.0
	if x_m <= _xs[0]:
		return _ss[0]
	var last: int = _xs.size() - 1
	if x_m >= _xs[last]:
		return _ss[last]
	var i: int = _segment_index(x_m)
	if i < 0:
		return _ss[last]
	var length_m: float = _xs[i + 1] - _xs[i]
	if length_m <= 0.0001:
		return _ss[i]
	var t: float = (x_m - _xs[i]) / length_m
	return lerpf(_ss[i], _ss[i + 1], t)

func grade_deg_at(x_m: float) -> float:
	return rad_to_deg(atan(slope_at(x_m)))

## Uniform sampling used by rendering, collision and validation.
func sample(step_m: float) -> PackedVector2Array:
	_ensure()
	var out := PackedVector2Array()
	var total: float = total_length()
	var step: float = maxf(step_m, 0.05)
	var x: float = 0.0
	while x < total:
		out.append(Vector2(x, elevation_at(x)))
		x += step
	out.append(Vector2(total, elevation_at(total)))
	return out

func knots() -> PackedVector2Array:
	_ensure()
	var out := PackedVector2Array()
	for i: int in range(_xs.size()):
		out.append(Vector2(_xs[i], _ys[i]))
	return out

## Walking the profile gives the true gain and descent, not a keyframe estimate.
func elevation_gain_m() -> float:
	_ensure()
	var gain: float = 0.0
	var descent: float = 0.0
	for i: int in range(_ys.size() - 1):
		var dy: float = _ys[i + 1] - _ys[i]
		if dy > 0.0:
			gain += dy
		else:
			descent -= dy
	return gain

func elevation_descent_m() -> float:
	_ensure()
	var descent: float = 0.0
	for i: int in range(_ys.size() - 1):
		var dy: float = _ys[i + 1] - _ys[i]
		if dy < 0.0:
			descent -= dy
	return descent

func net_elevation_m() -> float:
	_ensure()
	if _ys.size() < 2:
		return 0.0
	return _ys[_ys.size() - 1] - _ys[0]

func max_grade_deg() -> float:
	_ensure()
	var worst: float = 0.0
	for s: float in _ss:
		worst = maxf(worst, absf(rad_to_deg(atan(s))))
	return worst

func average_grade_deg() -> float:
	var total: float = total_length()
	if total <= 0.0:
		return 0.0
	return rad_to_deg(atan(net_elevation_m() / total))

## Steepest sustained climb: the largest rise over a 20 m window. This is what
## actually decides whether a heavy truck can make a section in one gear.
func steepest_window_grade_deg(window_m: float = 20.0) -> float:
	_ensure()
	var total: float = total_length()
	if total <= window_m:
		return max_grade_deg()
	var best: float = 0.0
	var x: float = 0.0
	while x + window_m <= total:
		var rise: float = elevation_at(x + window_m) - elevation_at(x)
		best = maxf(best, rad_to_deg(atan(rise / window_m)))
		x += 5.0
	return best
