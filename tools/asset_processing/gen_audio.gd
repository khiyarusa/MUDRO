extends SceneTree
## MUDRO — deterministic procedural audio generator.
##
## Every asset is synthesised from mathematics only: loop-locked harmonic
## stacks, circular (steady-state) filtered noise, granular events and damped
## modal resonators. No samples, no network, no randomness that is not seeded.
##
## Usage:
##   godot --headless --path <project> --script res://tools/asset_processing/gen_audio.gd
##   ... -- --list                     # print asset names, groups, loop flags
##   ... -- --only=ui_click,medal      # subset by name (no .wav suffix)
##   ... -- --group=engines            # subset by group
##   ... -- --verbose                  # add centroid / band diagnostics
##
## Output: res://assets/audio/*.wav
##   44100 Hz, 16-bit signed PCM, mono, RIFF/WAVE fmt 1, peak -3.00 dBFS.
##
## Loops are seamless by construction:
##   * tonal partials are snapped to integer multiples of 1/loop_length, so
##     every partial completes a whole number of cycles inside the loop;
##   * "detune" is a second partial exactly one loop-bin away, so the beat
##     between the pair closes exactly at the seam;
##   * all modulators use an integer number of cycles per loop;
##   * noise beds are run "circularly" (the filter state is carried through
##     several passes) which converges to the periodic steady state instead of
##     fading the tail out.

const SR: int = 44100
const OUT_DIR: String = "res://assets/audio"
const TARGET_PEAK_DB: float = -3.0
const TARGET_PEAK_LIN: float = 0.7079457843841379

var _verbose: bool = false
var _failed: int = 0
var _stats: Array = []


func _initialize() -> void:
	var specs: Array = _build_specs()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var only: PackedStringArray = PackedStringArray()
	var group: String = ""
	var list_only: bool = false
	for a: String in args:
		if a.begins_with("--only="):
			only = a.substr(7).split(",", false)
		elif a.begins_with("--group="):
			group = a.substr(8)
		elif a == "--list":
			list_only = true
		elif a == "--verbose":
			_verbose = true

	if list_only:
		for s: Dictionary in specs:
			print("%-22s %-11s %s" % [s["name"], s["group"], "loop" if s["loop"] else "oneshot"])
		quit(0)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var t_start: int = Time.get_ticks_msec()
	var made: int = 0
	for s: Dictionary in specs:
		var short: String = String(s["name"]).get_basename()
		if only.size() > 0 and not only.has(short):
			continue
		if group != "" and group != String(s["group"]):
			continue
		var fn: Callable = s["make"]
		var buf: PackedFloat32Array = fn.call()
		_emit(String(s["name"]), buf, bool(s["loop"]))
		made += 1
		if made % 6 == 0:
			print("  ... %d/%d assets" % [made, specs.size()])

	var total_bytes: int = 0
	for st: Dictionary in _stats:
		total_bytes += int(st["bytes"])
	var elapsed: float = float(Time.get_ticks_msec() - t_start) / 1000.0
	print("")
	print("SUMMARY  assets=%d  ok=%d  failed=%d  total=%.2f MB  elapsed=%.1fs"
			% [made, _stats.size(), _failed, float(total_bytes) / 1048576.0, elapsed])
	if _failed != 0:
		printerr("FAILED: %d asset(s) did not verify" % _failed)
	quit(0 if _failed == 0 else 1)


func _build_specs() -> Array:
	var s: Array = []
	s.append({"name": "engine_buggy.wav", "group": "engines", "loop": true, "make": Callable(self, "_make_engine_buggy")})
	s.append({"name": "engine_ranger.wav", "group": "engines", "loop": true, "make": Callable(self, "_make_engine_ranger")})
	s.append({"name": "engine_pickup.wav", "group": "engines", "loop": true, "make": Callable(self, "_make_engine_pickup")})
	s.append({"name": "engine_titan.wav", "group": "engines", "loop": true, "make": Callable(self, "_make_engine_titan")})
	s.append({"name": "engine_idle.wav", "group": "engines", "loop": true, "make": Callable(self, "_make_engine_idle")})
	s.append({"name": "engine_start.wav", "group": "engines", "loop": false, "make": Callable(self, "_make_engine_start")})
	s.append({"name": "engine_stall.wav", "group": "engines", "loop": false, "make": Callable(self, "_make_engine_stall")})
	s.append({"name": "shift.wav", "group": "drivetrain", "loop": false, "make": Callable(self, "_make_shift")})
	s.append({"name": "clutch.wav", "group": "drivetrain", "loop": false, "make": Callable(self, "_make_clutch")})
	s.append({"name": "tire_roll_gravel.wav", "group": "tires", "loop": true, "make": Callable(self, "_make_tire_gravel")})
	s.append({"name": "tire_roll_dirt.wav", "group": "tires", "loop": true, "make": Callable(self, "_make_tire_dirt")})
	s.append({"name": "skid.wav", "group": "tires", "loop": true, "make": Callable(self, "_make_skid")})
	s.append({"name": "mud_loop.wav", "group": "tires", "loop": true, "make": Callable(self, "_make_mud_loop")})
	s.append({"name": "water_splash.wav", "group": "one_shots", "loop": false, "make": Callable(self, "_make_water_splash")})
	s.append({"name": "impact_rock.wav", "group": "one_shots", "loop": false, "make": Callable(self, "_make_impact_rock")})
	s.append({"name": "impact_wood.wav", "group": "one_shots", "loop": false, "make": Callable(self, "_make_impact_wood")})
	s.append({"name": "land_thud.wav", "group": "one_shots", "loop": false, "make": Callable(self, "_make_land_thud")})
	s.append({"name": "suspension_creak.wav", "group": "one_shots", "loop": false, "make": Callable(self, "_make_suspension_creak")})
	s.append({"name": "checkpoint.wav", "group": "progress", "loop": false, "make": Callable(self, "_make_checkpoint")})
	s.append({"name": "finish.wav", "group": "progress", "loop": false, "make": Callable(self, "_make_finish")})
	s.append({"name": "medal.wav", "group": "progress", "loop": false, "make": Callable(self, "_make_medal")})
	s.append({"name": "ui_click.wav", "group": "ui", "loop": false, "make": Callable(self, "_make_ui_click")})
	s.append({"name": "ui_confirm.wav", "group": "ui", "loop": false, "make": Callable(self, "_make_ui_confirm")})
	s.append({"name": "ui_back.wav", "group": "ui", "loop": false, "make": Callable(self, "_make_ui_back")})
	s.append({"name": "ambience_canyon.wav", "group": "ambience", "loop": true, "make": Callable(self, "_make_amb_canyon")})
	s.append({"name": "ambience_pine.wav", "group": "ambience", "loop": true, "make": Callable(self, "_make_amb_pine")})
	s.append({"name": "ambience_quarry.wav", "group": "ambience", "loop": true, "make": Callable(self, "_make_amb_quarry")})
	return s


# ---------------------------------------------------------------------------
# master: clean, normalise, write, read back and verify
# ---------------------------------------------------------------------------

func _emit(fname: String, buf: PackedFloat32Array, is_loop: bool) -> void:
	if buf.is_empty():
		printerr("FAIL %-22s empty buffer" % fname)
		_failed += 1
		return
	var n: int = buf.size()

	var sum: float = 0.0
	for v: float in buf:
		sum += v
	var dc: float = sum / float(n)
	for i: int in range(n):
		buf[i] -= dc

	if not is_loop:
		_fade_edges(buf, 0.0015, 0.010)

	var pk: float = 0.0
	for v: float in buf:
		pk = maxf(pk, absf(v))
	if pk < 1.0e-6:
		printerr("FAIL %-22s silent" % fname)
		_failed += 1
		return
	var gain: float = TARGET_PEAK_LIN / pk
	for i: int in range(n):
		buf[i] *= gain

	var path: String = OUT_DIR.path_join(fname)
	if not _write_wav(path, buf):
		printerr("FAIL %-22s write error" % fname)
		_failed += 1
		return

	var v: Dictionary = _verify(path, is_loop)
	if not bool(v["ok"]):
		printerr("FAIL %-22s verification error (%s)" % [fname, String(v.get("why", "?"))])
		_failed += 1
		return

	var dc_abs: float = absf(float(v["dc"]))
	var dc_sign: String = "+" if float(v["dc"]) >= 0.0 else "-"
	var line: String = "OK   %-22s %7d B  %5.3fs  peak %6.2f dBFS  rms %6.2f dBFS  dc %s%.5f" % [
			fname, int(v["bytes"]), float(v["dur"]), float(v["peak_db"]), float(v["rms_db"]), dc_sign, dc_abs]
	if is_loop:
		line += "  seam %.2fx  LOOP" % float(v["seam"])
	if _verbose:
		line += "\n       centroid %5.0f Hz   low %4.1f%%  mid %4.1f%%  high %4.1f%%   seam/max %.2f" % [
				float(v["centroid"]), float(v["low"]), float(v["mid"]), float(v["high"]), float(v["seam_max"])]
	print(line)
	_stats.append(v)


func _fade_edges(buf: PackedFloat32Array, in_s: float, out_s: float) -> void:
	var n: int = buf.size()
	var ni: int = maxi(1, int(in_s * float(SR)))
	var no: int = maxi(1, int(out_s * float(SR)))
	for i: int in range(mini(ni, n)):
		var w: float = float(i) / float(ni)
		buf[i] *= w * w * (3.0 - 2.0 * w)
	for i: int in range(mini(no, n)):
		var idx: int = n - 1 - i
		var w: float = float(i) / float(no)
		buf[idx] *= w * w * (3.0 - 2.0 * w)


func _write_wav(path: String, buf: PackedFloat32Array) -> bool:
	var n: int = buf.size()
	var bytes := PackedByteArray()
	bytes.resize(44 + n * 2)
	_put_tag(bytes, 0, "RIFF")
	bytes.encode_u32(4, 36 + n * 2)
	_put_tag(bytes, 8, "WAVE")
	_put_tag(bytes, 12, "fmt ")
	bytes.encode_u32(16, 16)
	bytes.encode_u16(20, 1)
	bytes.encode_u16(22, 1)
	bytes.encode_u32(24, SR)
	bytes.encode_u32(28, SR * 2)
	bytes.encode_u16(32, 2)
	bytes.encode_u16(34, 16)
	_put_tag(bytes, 36, "data")
	bytes.encode_u32(40, n * 2)
	for i: int in range(n):
		var s: int = int(round(clampf(buf[i], -1.0, 1.0) * 32767.0))
		bytes.encode_s16(44 + i * 2, s)
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(bytes)
	f.close()
	return true


func _put_tag(bytes: PackedByteArray, off: int, tag: String) -> void:
	for i: int in range(4):
		bytes.encode_u8(off + i, tag.unicode_at(i))


func _verify(path: String, is_loop: bool) -> Dictionary:
	var res: Dictionary = {"ok": false, "why": "open"}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return res
	var size: int = f.get_length()
	if size < 44:
		f.close()
		return res
	var head: PackedByteArray = f.get_buffer(44)
	var fmt: int = head.decode_u16(20)
	var ch: int = head.decode_u16(22)
	var rate: int = head.decode_u32(24)
	var bits: int = head.decode_u16(34)
	var data_bytes: int = head.decode_u32(40)
	if head.decode_u32(0) != 0x46464952 \
			or head.decode_u32(8) != 0x45564157 \
			or fmt != 1 or ch != 1 or rate != SR or bits != 16:
		f.close()
		res["why"] = "header"
		return res
	f.seek(44)
	var data: PackedByteArray = f.get_buffer(data_bytes)
	f.close()
	var n: int = data.size() / 2
	if n <= 0:
		res["why"] = "empty"
		return res

	var peak: float = 0.0
	var sumsq: float = 0.0
	var sum: float = 0.0
	var first: float = 0.0
	var last: float = 0.0
	var prev: float = 0.0
	var max_step: float = 0.0
	var diffs := PackedFloat32Array()
	diffs.resize(maxi(n - 1, 1))
	for i: int in range(n):
		var v: float = float(data.decode_s16(i * 2))
		peak = maxf(peak, absf(v))
		sumsq += v * v
		sum += v
		if i == 0:
			first = v
		else:
			var st: float = absf(v - prev)
			diffs[i - 1] = st
			max_step = maxf(max_step, st)
		prev = v
		last = v
	var sorted := diffs.duplicate()
	sorted.sort()
	var p99: float = sorted[mini(int(float(sorted.size()) * 0.99), sorted.size() - 1)]

	res["ok"] = true
	res["why"] = ""
	res["bytes"] = size
	res["dur"] = float(n) / float(SR)
	res["peak_db"] = linear_to_db(peak / 32768.0)
	res["rms_db"] = linear_to_db(sqrt(sumsq / float(n)) / 32768.0)
	res["dc"] = (sum / float(n)) / 32768.0
	res["seam"] = absf(first - last) / maxf(p99, 1.0)
	res["seam_max"] = absf(first - last) / maxf(max_step, 1.0)
	res["peak_lin"] = peak
	if _verbose:
		_spectrum_report(res, data, n, is_loop)
	return res


## Band balance and centroid measured by integrating filtered energy over the
## whole file. (A sparse Goertzel probe under-counts broadband noise by ~50x,
## so it must not be used to judge a noise-based mix.)
func _spectrum_report(res: Dictionary, data: PackedByteArray, n: int, is_loop: bool) -> void:
	var x := PackedFloat32Array()
	x.resize(n)
	for i: int in range(n):
		x[i] = float(data.decode_s16(i * 2)) / 32768.0

	var lp160: PackedFloat32Array = _lp_circ(x, 160.0, 3)
	var lp1500: PackedFloat32Array = _lp_circ(x, 1500.0, 3)
	var e_low: float = 0.0
	var e_mid: float = 0.0
	var e_high: float = 0.0
	for i: int in range(n):
		var a: float = lp160[i]
		var b: float = lp1500[i]
		var mm: float = b - a
		var hh: float = x[i] - b
		e_low += a * a
		e_mid += mm * mm
		e_high += hh * hh
	var tot: float = maxf(e_low + e_mid + e_high, 1.0e-12)
	res["low"] = 100.0 * e_low / tot
	res["mid"] = 100.0 * e_mid / tot
	res["high"] = 100.0 * e_high / tot

	# octave-ish centroid from the energy above a set of cutoffs
	var cutoffs: Array = [125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0]
	var centres: Array = [62.5, 187.5, 375.0, 750.0, 1500.0, 3000.0, 6000.0, 12000.0]
	var e_total: float = 0.0
	for i: int in range(n):
		e_total += x[i] * x[i]
	var prev: float = e_total
	var centroid: float = 0.0
	for k: int in range(cutoffs.size()):
		var hp: PackedFloat32Array = _hp_circ(x, float(cutoffs[k]), 3)
		var e: float = 0.0
		for i: int in range(n):
			e += hp[i] * hp[i]
		centroid += float(centres[k]) * maxf(prev - e, 0.0)
		prev = e
	centroid += float(centres[cutoffs.size()]) * prev
	res["centroid"] = centroid / maxf(e_total, 1.0e-12)


# ---------------------------------------------------------------------------
# primitives
# ---------------------------------------------------------------------------

func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func _noise(n: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in range(n):
		out[i] = rng.randf_range(-1.0, 1.0)
	return out


## Snaps a frequency to an even number of cycles per loop, so that the
## fundamental *and* its octave-down sub both close at the seam.
func _snap_even(f: float, loop_s: float) -> float:
	var bins: int = int(round(f * loop_s))
	if bins < 2:
		bins = 2
	if bins % 2 != 0:
		bins += 1
	return float(bins) / loop_s


## Sine table of one loop, in cycles-per-loop units (integer = seamless).
func _lfo(n: int, cycles: float, phase: float = 0.0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var w: float = TAU * cycles / float(n)
	var p: float = phase
	for i: int in range(n):
		out[i] = sin(p)
		p += w
	return out


func _add_sine_loop(buf: PackedFloat32Array, freq: float, amp: float, phase: float) -> void:
	var n: int = buf.size()
	var w: float = TAU * freq / float(SR)
	var p: float = phase
	for i: int in range(n):
		buf[i] += amp * sin(p)
		p += w


func _add_cos_loop(buf: PackedFloat32Array, freq: float, amp: float, phase: float) -> void:
	var n: int = buf.size()
	var w: float = TAU * freq / float(SR)
	var p: float = phase
	for i: int in range(n):
		buf[i] += amp * cos(p)
		p += w


## One-pole low pass run over the buffer N times; the filter state carries
## across passes so the result converges to the circular steady state.
func _lp_circ(src: PackedFloat32Array, cutoff: float, passes: int = 3) -> PackedFloat32Array:
	var n: int = src.size()
	var out := PackedFloat32Array()
	out.resize(n)
	var a: float = 1.0 - exp(-TAU * cutoff / float(SR))
	var y: float = 0.0
	for p: int in range(maxi(passes, 1)):
		for i: int in range(n):
			y += a * (src[i] - y)
			out[i] = y
	return out


func _hp_circ(src: PackedFloat32Array, cutoff: float, passes: int = 3) -> PackedFloat32Array:
	var lp: PackedFloat32Array = _lp_circ(src, cutoff, passes)
	var out := PackedFloat32Array()
	out.resize(src.size())
	for i: int in range(src.size()):
		out[i] = src[i] - lp[i]
	return out


func _bp_circ(src: PackedFloat32Array, freq: float, q: float, passes: int = 3) -> PackedFloat32Array:
	var n: int = src.size()
	var out := PackedFloat32Array()
	out.resize(n)
	var w0: float = TAU * freq / float(SR)
	var alpha: float = sin(w0) / (2.0 * maxf(q, 0.2))
	var a0: float = 1.0 + alpha
	var b0: float = alpha / a0
	var b2: float = -alpha / a0
	var a1: float = (-2.0 * cos(w0)) / a0
	var a2: float = (1.0 - alpha) / a0
	var x1: float = 0.0
	var x2: float = 0.0
	var y1: float = 0.0
	var y2: float = 0.0
	for p: int in range(maxi(passes, 1)):
		for i: int in range(n):
			var x: float = src[i]
			var y: float = b0 * x + b2 * x2 - a1 * y1 - a2 * y2
			x2 = x1
			x1 = x
			y2 = y1
			y1 = y
			out[i] = y
	return out


## Forward (non-circular) band pass, for one-shot transients.
func _bp_forward(src: PackedFloat32Array, freq: float, q: float) -> PackedFloat32Array:
	var n: int = src.size()
	var out := PackedFloat32Array()
	out.resize(n)
	var w0: float = TAU * freq / float(SR)
	var alpha: float = sin(w0) / (2.0 * maxf(q, 0.2))
	var a0: float = 1.0 + alpha
	var b0: float = alpha / a0
	var b2: float = -alpha / a0
	var a1: float = (-2.0 * cos(w0)) / a0
	var a2: float = (1.0 - alpha) / a0
	var x1: float = 0.0
	var x2: float = 0.0
	var y1: float = 0.0
	var y2: float = 0.0
	for i: int in range(n):
		var x: float = src[i]
		var y: float = b0 * x + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		out[i] = y
	return out


## Resonant biquad excited by an arbitrary buffer (impulse train -> creak).
func _resonator(src: PackedFloat32Array, freq: float, q: float) -> PackedFloat32Array:
	return _bp_forward(src, freq, q)


func _scale_peak(buf: PackedFloat32Array, target: float) -> void:
	var pk: float = 0.0
	for v: float in buf:
		pk = maxf(pk, absf(v))
	if pk < 1.0e-9:
		return
	var g: float = target / pk
	for i: int in range(buf.size()):
		buf[i] *= g


func _soft_clip(buf: PackedFloat32Array, drive: float) -> void:
	if drive <= 1.0:
		return
	var norm: float = 1.0 / tanh(drive)
	for i: int in range(buf.size()):
		buf[i] = tanh(buf[i] * drive) * norm


func _rms(buf: PackedFloat32Array) -> float:
	if buf.is_empty():
		return 0.0
	var s: float = 0.0
	for v: float in buf:
		s += v * v
	return sqrt(s / float(buf.size()))


## Adds `src` to `dst` at a fixed RMS ratio, so layer balance is independent
## of each layer's crest factor. Keeps the mix deterministic.
func _mix_db(dst: PackedFloat32Array, src: PackedFloat32Array, rel_db: float) -> void:
	var rd: float = _rms(dst)
	var rs: float = _rms(src)
	if rd <= 0.0 or rs <= 0.0:
		return
	var g: float = rd * db_to_linear(rel_db) / rs
	var n: int = mini(dst.size(), src.size())
	for i: int in range(n):
		dst[i] += src[i] * g


func _add_partial(dst: PackedFloat32Array, start_s: float, freq: float, amp: float,
		dur_s: float, decay_s: float, attack_s: float, phase: float = 0.0) -> void:
	var n: int = dst.size()
	var s0: int = int(start_s * float(SR))
	var ns: int = int(dur_s * float(SR))
	var w: float = TAU * freq / float(SR)
	var ph: float = phase
	for j: int in range(ns):
		var i: int = s0 + j
		if i < 0:
			continue
		if i >= n:
			break
		var t: float = float(j) / float(SR)
		var env: float = (1.0 - exp(-t / maxf(attack_s, 1.0e-5))) * exp(-t / maxf(decay_s, 1.0e-5))
		dst[i] += amp * env * sin(ph)
		ph += w


## Sine with a linear pitch sweep (drops, chirps).
func _add_sine(dst: PackedFloat32Array, start_s: float, dur_s: float, f0: float, f1: float,
		amp: float, attack_s: float, decay_s: float, phase: float = 0.0) -> void:
	var n: int = dst.size()
	var s0: int = int(start_s * float(SR))
	var ns: int = int(dur_s * float(SR))
	var ph: float = phase
	for j: int in range(ns):
		var i: int = s0 + j
		if i < 0:
			continue
		if i >= n:
			break
		var u: float = float(j) / float(maxi(ns - 1, 1))
		var t: float = float(j) / float(SR)
		var f: float = lerpf(f0, f1, u)
		ph += TAU * f / float(SR)
		var env: float = (1.0 - exp(-t / maxf(attack_s, 1.0e-5))) * exp(-t / maxf(decay_s, 1.0e-5))
		dst[i] += amp * env * sin(ph)


func _add_burst(dst: PackedFloat32Array, start_s: float, dur_s: float, amp: float,
		lp_hz: float, hp_hz: float, attack_s: float, decay_s: float,
		rng: RandomNumberGenerator) -> void:
	var n: int = dst.size()
	var s0: int = int(start_s * float(SR))
	var ns: int = int(dur_s * float(SR))
	var la: float = 1.0 - exp(-TAU * lp_hz / float(SR))
	var ha: float = 1.0 - exp(-TAU * hp_hz / float(SR))
	var ly: float = 0.0
	var hy: float = 0.0
	for j: int in range(ns):
		var i: int = s0 + j
		if i < 0:
			continue
		if i >= n:
			break
		var t: float = float(j) / float(SR)
		var w: float = rng.randf_range(-1.0, 1.0)
		ly += la * (w - ly)
		var x: float = ly
		hy += ha * (x - hy)
		var env: float = (1.0 - exp(-t / maxf(attack_s, 1.0e-5))) * exp(-t / maxf(decay_s, 1.0e-5))
		dst[i] += amp * env * (x - hy)


## Low thump with a pitch drop (impact body, suspension, timpani).
func _add_thud(dst: PackedFloat32Array, start_s: float, dur_s: float, f_start: float,
		f_end: float, amp: float, drop_s: float, attack_s: float,
		rng: RandomNumberGenerator, noise_amp: float = 0.0) -> void:
	var n: int = dst.size()
	var s0: int = int(start_s * float(SR))
	var ns: int = int(dur_s * float(SR))
	var ph: float = 0.0
	var la: float = 1.0 - exp(-TAU * 900.0 / float(SR))
	var ha: float = 1.0 - exp(-TAU * 90.0 / float(SR))
	var ly: float = 0.0
	var hy: float = 0.0
	for j: int in range(ns):
		var i: int = s0 + j
		if i < 0:
			continue
		if i >= n:
			break
		var t: float = float(j) / float(SR)
		var f: float = f_end + (f_start - f_end) * exp(-t / maxf(drop_s, 1.0e-4))
		ph += TAU * f / float(SR)
		var env: float = (1.0 - exp(-t / maxf(attack_s, 1.0e-5))) * exp(-t / (dur_s * 0.32))
		var v: float = sin(ph)
		if noise_amp > 0.0:
			var w: float = rng.randf_range(-1.0, 1.0)
			ly += la * (w - ly)
			hy += ha * (ly - hy)
			v += noise_amp * (ly - hy) * exp(-t / maxf(0.03, dur_s * 0.2))
		dst[i] += amp * env * v


## Small noise grain. wrap=true makes it loop-safe across the seam.
func _grain(dst: PackedFloat32Array, pos_s: float, dur_s: float, amp: float,
		lp_hz: float, hp_hz: float, rng: RandomNumberGenerator,
		sharp: bool = false, wrap: bool = false) -> void:
	var n: int = dst.size()
	var ns: int = maxi(8, int(dur_s * float(SR)))
	var s0: int = int(pos_s * float(SR))
	var la: float = 1.0 - exp(-TAU * lp_hz / float(SR))
	var ha: float = 1.0 - exp(-TAU * hp_hz / float(SR))
	var ly: float = 0.0
	var hy: float = 0.0
	for j: int in range(ns):
		var u: float = float(j) / float(ns)
		var w: float = rng.randf_range(-1.0, 1.0)
		ly += la * (w - ly)
		hy += ha * (ly - hy)
		var env: float
		if sharp:
			env = exp(-u * 4.5) * (1.0 - exp(-u * 60.0))
		else:
			env = sin(PI * u)
			env *= env
		var val: float = amp * env * (ly - hy)
		var idx: int = s0 + j
		if wrap:
			idx = ((idx % n) + n) % n
		elif idx < 0 or idx >= n:
			continue
		dst[idx] += val


func _add_pad(dst: PackedFloat32Array, start_s: float, dur_s: float, freq: float,
		amp: float, attack_s: float, release_s: float, bright: float) -> void:
	var n: int = dst.size()
	var ns: int = int(dur_s * float(SR))
	var s0: int = int(start_s * float(SR))
	for k: int in range(1, 6):
		var a: float = amp * pow(float(k), -bright)
		if a < 0.003:
			continue
		var offsets: Array = [0.0]
		if k <= 3:
			offsets = [-0.0016, 0.0016]
		for o: float in offsets:
			var f: float = freq * float(k) * (1.0 + o)
			var w: float = TAU * f / float(SR)
			var ph: float = 0.7 * float(k) + (0.0 if o <= 0.0 else 1.9)
			for j: int in range(ns):
				var i: int = s0 + j
				if i < 0:
					continue
				if i >= n:
					break
				var t: float = float(j) / float(SR)
				var env: float = (1.0 - exp(-t / maxf(attack_s, 1.0e-4))) \
						* (1.0 - smoothstep(dur_s - release_s, dur_s, t))
				dst[i] += a * env * sin(ph)
				ph += w


## Cheap Schroeder room for one-shots (finish / medal / checkpoint).
func _space(buf: PackedFloat32Array, mix: float) -> void:
	var n: int = buf.size()
	var dry: PackedFloat32Array = buf.duplicate()
	var delays: Array = [1319, 1601, 1867, 2053]
	var wet := PackedFloat32Array()
	wet.resize(n)
	for d: int in delays:
		var line := PackedFloat32Array()
		line.resize(d)
		var idx: int = 0
		for i: int in range(n):
			var y: float = line[idx]
			line[idx] = dry[i] + y * 0.72
			wet[i] += y
			idx = (idx + 1) % d
	for i: int in range(n):
		wet[i] *= 0.25
	# one allpass to smear the comb pattern
	var ap_d: int = 89
	var ap := PackedFloat32Array()
	ap.resize(ap_d)
	var ai: int = 0
	var g: float = 0.55
	for i: int in range(n):
		var d: float = ap[ai]
		var v: float = wet[i] + g * d
		ap[ai] = v
		wet[i] = d - g * v
		ai = (ai + 1) % ap_d
	for i: int in range(n):
		buf[i] = dry[i] + wet[i] * mix


## Linear taper over the last `seconds` — used where a one-shot hands over to
## a loop and must not cut a sustained tone.
func _tail_fade(buf: PackedFloat32Array, seconds: float) -> void:
	var n: int = buf.size()
	var ns: int = mini(int(seconds * float(SR)), n)
	for i: int in range(ns):
		buf[n - 1 - i] *= float(i) / float(ns)


func _interp_keys(keys: Array, t: float) -> float:
	if keys.is_empty():
		return 0.0
	var first: Vector2 = keys[0]
	if t <= first.x:
		return first.y
	for i: int in range(keys.size() - 1):
		var a: Vector2 = keys[i]
		var b: Vector2 = keys[i + 1]
		if t <= b.x:
			var u: float = clampf((t - a.x) / maxf(b.x - a.x, 1.0e-6), 0.0, 1.0)
			u = u * u * (3.0 - 2.0 * u)
			return lerpf(a.y, b.y, u)
	var last: Vector2 = keys[keys.size() - 1]
	return last.y


# ---------------------------------------------------------------------------
# engines
# ---------------------------------------------------------------------------

func _make_engine_buggy() -> PackedFloat32Array:
	return _engine_loop(_engine_params("buggy"))


func _make_engine_ranger() -> PackedFloat32Array:
	return _engine_loop(_engine_params("ranger"))


func _make_engine_pickup() -> PackedFloat32Array:
	return _engine_loop(_engine_params("pickup"))


func _make_engine_titan() -> PackedFloat32Array:
	return _engine_loop(_engine_params("titan"))


func _make_engine_idle() -> PackedFloat32Array:
	return _engine_loop(_engine_params("idle"))


func _engine_params(id: String) -> Dictionary:
	match id:
		"buggy":
			# light, buzzy twin: strong 3rd/5th, bright intake, fast clatter
			return {
				"dur": 2.0, "crank": 37.0, "seed": 1101,
				"harm": PackedFloat32Array([0.55, 0.85, 1.00, 0.62, 0.70, 0.45, 0.42, 0.30, 0.26, 0.20, 0.16, 0.12, 0.10, 0.075, 0.055, 0.040, 0.028]),
				"sub_amp": 0.10, "fire_mul": 2.0, "pulse_harm": 10, "pulse_roll": 1.05,
				"pulse_db": -6.0, "noise_db": -7.0, "clatter_db": -18.0,
				"noise_center": 2000.0, "noise_q": 0.8,
				"detune": 0.22, "lope": 0.06, "lope_cycles": 12.0,
				"clatter": 0.10, "clatter_center": 3000.0, "clatter_decay": 0.0030,
				"grit": 1.35,
			}
		"ranger":
			# even inline four: smooth rolloff, mid intake, low mechanical noise
			return {
				"dur": 2.0, "crank": 36.0, "seed": 1201,
				"harm": PackedFloat32Array([0.70, 0.95, 0.80, 0.55, 0.42, 0.32, 0.24, 0.17, 0.13, 0.095, 0.070, 0.050, 0.036, 0.026, 0.018, 0.013]),
				"sub_amp": 0.12, "fire_mul": 2.0, "pulse_harm": 8, "pulse_roll": 1.20,
				"pulse_db": -6.0, "noise_db": -8.5, "clatter_db": -24.0,
				"noise_center": 1400.0, "noise_q": 1.0,
				"detune": 0.18, "lope": 0.04, "lope_cycles": 8.0,
				"clatter": 0.06, "clatter_center": 2600.0, "clatter_decay": 0.0028,
				"grit": 1.15,
			}
		"pickup":
			# deep uneven V8: heavy 1st/2nd, half-order lope, firing order 4
			return {
				"dur": 2.0, "crank": 37.0, "seed": 1301,
				"harm": PackedFloat32Array([0.85, 1.00, 0.70, 0.62, 0.40, 0.34, 0.22, 0.17, 0.12, 0.090, 0.065, 0.048, 0.034, 0.024, 0.017, 0.012]),
				"sub_amp": 0.38, "fire_mul": 4.0, "pulse_harm": 12, "pulse_roll": 1.00,
				"pulse_db": -4.0, "noise_db": -10.5, "clatter_db": -18.0,
				"noise_center": 850.0, "noise_q": 1.0,
				"detune": 0.25, "lope": 0.22, "lope_cycles": 16.0,
				"clatter": 0.10, "clatter_center": 2200.0, "clatter_decay": 0.0035,
				"grit": 1.50,
			}
		"titan":
			# very low heavy diesel: dominant half-order, hard injection clatter
			return {
				"dur": 2.0, "crank": 36.0, "seed": 1401,
				"harm": PackedFloat32Array([1.00, 0.80, 0.60, 0.42, 0.30, 0.22, 0.15, 0.105, 0.075, 0.052, 0.036, 0.025, 0.018, 0.013]),
				"sub_amp": 0.45, "fire_mul": 3.0, "pulse_harm": 14, "pulse_roll": 1.35,
				"pulse_db": -3.0, "noise_db": -9.5, "clatter_db": -12.0,
				"noise_center": 620.0, "noise_q": 0.8,
				"detune": 0.30, "lope": 0.10, "lope_cycles": 10.0,
				"clatter": 0.55, "clatter_center": 2000.0, "clatter_decay": 0.0045,
				"grit": 1.70,
			}
		_:
			# idle: 780 rpm, light load, hunting slightly
			return {
				"dur": 2.0, "crank": 13.0, "seed": 1501,
				"harm": PackedFloat32Array([0.80, 0.75, 0.50, 0.40, 0.32, 0.28, 0.22, 0.18, 0.15, 0.12, 0.10, 0.08, 0.065, 0.052, 0.042, 0.034, 0.026, 0.020, 0.015, 0.011]),
				"sub_amp": 0.20, "fire_mul": 2.0, "pulse_harm": 9, "pulse_roll": 1.25,
				"pulse_db": -7.0, "noise_db": -8.0, "clatter_db": -21.0,
				"noise_center": 1100.0, "noise_q": 0.85,
				"detune": 0.20, "lope": 0.18, "lope_cycles": 4.0,
				"clatter": 0.08, "clatter_center": 2400.0, "clatter_decay": 0.0030,
				"grit": 1.20,
			}


func _engine_loop(p: Dictionary) -> PackedFloat32Array:
	var dur: float = float(p["dur"])
	var n: int = int(round(dur * float(SR)))
	var nd: float = float(n) / float(SR)
	var rng: RandomNumberGenerator = _rng(int(p["seed"]))
	var f0: float = _snap_even(float(p["crank"]), nd)
	var buf := PackedFloat32Array()
	buf.resize(n)

	# 1. crank-order harmonic stack
	var harm: PackedFloat32Array = p["harm"]
	var hn: int = harm.size()
	var norm: float = 0.0
	for k: int in range(hn):
		norm = maxf(norm, float(harm[k]))
	if norm <= 0.0:
		norm = 1.0
	var det_amp: float = float(p["detune"])
	for k: int in range(1, hn + 1):
		var a: float = float(harm[k - 1]) / norm
		if a < 0.004:
			continue
		var f: float = f0 * float(k)
		if f > 6800.0:
			break
		var ph: float = rng.randf() * TAU
		_add_sine_loop(buf, f, a, ph)
		if k >= 6 and a > 0.03 and det_amp > 0.0:
			# exactly one loop-bin away: the beat closes at the seam
			_add_sine_loop(buf, f + 1.0 / nd, a * det_amp, ph + 2.1)

	# 2. half-order weight (V8 / diesel gut)
	var sub_amp: float = float(p["sub_amp"])
	if sub_amp > 0.0:
		_add_sine_loop(buf, f0 * 0.5, sub_amp, 1.1)

	# 3. combustion pulse train (cosines in phase = impulse train)
	var fire: float = f0 * float(p["fire_mul"])
	var pulse_harm: int = int(p["pulse_harm"])
	var roll: float = float(p["pulse_roll"])
	var pulse := PackedFloat32Array()
	pulse.resize(n)
	for k: int in range(1, pulse_harm + 1):
		if fire * float(k) > 5200.0:
			break
		_add_cos_loop(pulse, fire * float(k), pow(float(k), -roll), -2.2 * float(k))
	_mix_db(buf, pulse, float(p["pulse_db"]))

	# 4. filtered intake noise, breathing with the firing order
	var lfo_fire: PackedFloat32Array = _lfo(n, fire * nd, 0.4)
	var raw: PackedFloat32Array = _bp_circ(_noise(n, rng), float(p["noise_center"]), float(p["noise_q"]), 3)
	var noise := PackedFloat32Array()
	noise.resize(n)
	for i: int in range(n):
		noise[i] = raw[i] * (1.0 + 0.30 * lfo_fire[i])
	_mix_db(buf, noise, float(p["noise_db"]))

	# 5. mechanical / injection clatter on every firing pulse
	var cl: float = float(p["clatter"])
	if cl > 0.0:
		var cn: PackedFloat32Array = _bp_circ(_noise(n, rng), float(p["clatter_center"]), 1.1, 3)
		var fdec: float = maxf(float(p["clatter_decay"]) * fire, 1.0e-4)
		var clatter := PackedFloat32Array()
		clatter.resize(n)
		for i: int in range(n):
			var phase: float = fposmod(float(i) * fire / float(SR), 1.0)
			clatter[i] = cn[i] * exp(-phase / fdec)
		_mix_db(buf, clatter, float(p["clatter_db"]))

	# 6. load lope (uneven cylinders) — whole cycles per loop, so still seamless
	var lope: float = float(p["lope"])
	if lope > 0.0:
		var lfo_l: PackedFloat32Array = _lfo(n, float(p["lope_cycles"]), 0.0)
		for i: int in range(n):
			buf[i] *= 1.0 - lope * (0.5 + 0.5 * lfo_l[i])

	_scale_peak(buf, 0.85)
	_soft_clip(buf, float(p["grit"]))
	return buf


func _sweep_params(id: String) -> Dictionary:
	var harm: PackedFloat32Array
	var noise_db: float
	var clatter_db: float
	var grit: float
	if id == "start":
		harm = PackedFloat32Array([0.70, 0.90, 0.75, 0.50, 0.40, 0.30, 0.22, 0.16, 0.12, 0.09, 0.070, 0.050])
		noise_db = -8.0
		clatter_db = -22.0
		grit = 1.45
	else:
		harm = PackedFloat32Array([0.75, 0.85, 0.70, 0.50, 0.38, 0.28, 0.20, 0.15, 0.11, 0.08, 0.060, 0.045])
		noise_db = -9.0
		clatter_db = -23.0
		grit = 1.40
	return {
		"seed": 2207 if id == "start" else 2208,
		"harm": harm, "fire_mul": 2.0, "pulse_amp": 0.35, "pulse_harm": 9, "pulse_roll": 1.10,
		"noise_db": noise_db, "noise_center": 1100.0, "noise_q": 1.0,
		"clatter": 0.10, "clatter_center": 2600.0, "clatter_decay": 0.0030,
		"clatter_db": clatter_db, "grit": grit,
	}


## Engine whose speed follows a keyframed rpm curve.
func _engine_sweep(dur: float, rpm_keys: Array, amp_keys: Array, p: Dictionary) -> PackedFloat32Array:
	var n: int = int(round(dur * float(SR)))
	var rng: RandomNumberGenerator = _rng(int(p["seed"]))
	var rpm := PackedFloat32Array()
	rpm.resize(n)
	var amp := PackedFloat32Array()
	amp.resize(n)
	for i: int in range(n):
		var t: float = float(i) / float(SR)
		rpm[i] = _interp_keys(rpm_keys, t)
		amp[i] = _interp_keys(amp_keys, t)
	var phase := PackedFloat32Array()
	phase.resize(n)
	var ph: float = 0.0
	for i: int in range(n):
		phase[i] = ph
		ph += TAU * (rpm[i] / 60.0) / float(SR)

	var buf := PackedFloat32Array()
	buf.resize(n)
	var harm: PackedFloat32Array = p["harm"]
	for k: int in range(1, harm.size() + 1):
		var a: float = float(harm[k - 1])
		if a < 0.004:
			continue
		var off: float = rng.randf() * TAU
		for i: int in range(n):
			buf[i] += a * amp[i] * sin(phase[i] * float(k) + off)

	var fire: float = float(p["fire_mul"])
	var poff: float = rng.randf() * TAU
	for k: int in range(1, int(p["pulse_harm"]) + 1):
		var a: float = float(p["pulse_amp"]) * pow(float(k), -float(p["pulse_roll"]))
		if a < 0.004:
			continue
		for i: int in range(n):
			buf[i] += a * amp[i] * cos(phase[i] * fire * float(k) + poff * float(k))

	var nz: PackedFloat32Array = _bp_forward(_noise(n, rng), float(p["noise_center"]), float(p["noise_q"]))
	var noise := PackedFloat32Array()
	noise.resize(n)
	for i: int in range(n):
		var ripple: float = 0.55 + 0.45 * cos(phase[i] * fire)
		noise[i] = nz[i] * amp[i] * ripple
	_mix_db(buf, noise, float(p["noise_db"]))

	var cl: float = float(p["clatter"])
	if cl > 0.0:
		var cn: PackedFloat32Array = _bp_forward(_noise(n, rng), float(p["clatter_center"]), 1.1)
		var clat := PackedFloat32Array()
		clat.resize(n)
		for i: int in range(n):
			clat[i] = cn[i] * exp(-fposmod(phase[i] * fire, 1.0) / 0.20) * amp[i]
		_mix_db(buf, clat, float(p["clatter_db"]))

	_scale_peak(buf, 0.85)
	_soft_clip(buf, float(p["grit"]))
	return buf


func _make_engine_start() -> PackedFloat32Array:
	var rpm: Array = [
		Vector2(0.00, 0.0), Vector2(0.05, 140.0), Vector2(0.12, 205.0),
		Vector2(0.20, 225.0), Vector2(0.27, 200.0), Vector2(0.34, 240.0),
		Vector2(0.41, 210.0), Vector2(0.48, 250.0), Vector2(0.54, 195.0),
		Vector2(0.60, 300.0), Vector2(0.65, 240.0), Vector2(0.70, 470.0),
		Vector2(0.75, 980.0), Vector2(0.80, 1430.0), Vector2(0.84, 1520.0),
		Vector2(0.88, 1180.0), Vector2(0.94, 960.0), Vector2(1.02, 870.0),
		Vector2(1.10, 845.0), Vector2(1.20, 850.0),
	]
	var amp: Array = [
		Vector2(0.00, 0.0), Vector2(0.05, 0.30), Vector2(0.55, 0.38),
		Vector2(0.62, 0.26), Vector2(0.70, 0.80), Vector2(0.80, 1.0),
		Vector2(0.90, 0.72), Vector2(1.00, 0.62), Vector2(1.20, 0.60),
	]
	var buf: PackedFloat32Array = _engine_sweep(1.2, rpm, amp, _sweep_params("start"))
	var rng: RandomNumberGenerator = _rng(2207)

	# starter motor: low whirr plus gear noise
	_add_sine(buf, 0.0, 0.62, 92.0, 124.0, 0.20, 0.040, 0.90)
	_add_sine(buf, 0.0, 0.62, 460.0, 610.0, 0.090, 0.050, 0.90)
	_add_burst(buf, 0.0, 0.64, 0.16, 1600.0, 380.0, 0.030, 0.90, rng)

	# compression beats while cranking
	for t: float in [0.14, 0.23, 0.32, 0.40, 0.47, 0.53]:
		_add_thud(buf, t, 0.085, 92.0, 54.0, 0.42, 0.020, 0.0015, rng, 0.30)

	# first catch, then settle
	_add_thud(buf, 0.695, 0.16, 118.0, 58.0, 0.55, 0.030, 0.0020, rng, 0.25)
	_add_burst(buf, 0.700, 0.18, 0.22, 3200.0, 300.0, 0.004, 0.060, rng)

	_scale_peak(buf, 0.90)
	_soft_clip(buf, 1.70)
	_tail_fade(buf, 0.080)
	return buf


func _make_engine_stall() -> PackedFloat32Array:
	var rpm: Array = [
		Vector2(0.00, 880.0), Vector2(0.10, 860.0), Vector2(0.17, 690.0),
		Vector2(0.23, 770.0), Vector2(0.31, 560.0), Vector2(0.39, 470.0),
		Vector2(0.47, 300.0), Vector2(0.54, 175.0), Vector2(0.59, 85.0),
		Vector2(0.62, 0.0), Vector2(1.00, 0.0),
	]
	var amp: Array = [
		Vector2(0.00, 0.75), Vector2(0.12, 0.72), Vector2(0.30, 0.62),
		Vector2(0.48, 0.40), Vector2(0.58, 0.20), Vector2(0.62, 0.0),
		Vector2(1.00, 0.0),
	]
	var buf: PackedFloat32Array = _engine_sweep(1.0, rpm, amp, _sweep_params("stall"))
	var rng: RandomNumberGenerator = _rng(2208)

	# the clunk of a stopped drivetrain settling on its mounts
	_add_thud(buf, 0.640, 0.30, 88.0, 44.0, 0.90, 0.050, 0.0020, rng, 0.25)
	_add_partial(buf, 0.645, 195.0, 0.22, 0.18, 0.060, 0.0020)
	_add_partial(buf, 0.648, 412.0, 0.10, 0.10, 0.030, 0.0015)
	for i: int in range(9):
		var t: float = 0.642 + rng.randf_range(0.0, 0.12)
		_grain(buf, t, rng.randf_range(0.004, 0.012), rng.randf_range(0.05, 0.16),
				rng.randf_range(3000.0, 6000.0), rng.randf_range(700.0, 1500.0), rng, true)
	_add_sine(buf, 0.690, 0.20, 330.0, 255.0, 0.05, 0.020, 0.080)

	_scale_peak(buf, 0.92)
	_soft_clip(buf, 1.55)
	return buf


## Sine event that wraps around the loop seam.
func _add_sine_wrap(dst: PackedFloat32Array, pos_s: float, dur_s: float, f0: float,
		f1: float, amp: float, attack_s: float, decay_s: float, phase: float = 0.0) -> void:
	var n: int = dst.size()
	var ns: int = int(dur_s * float(SR))
	var s0: int = int(pos_s * float(SR))
	var ph: float = phase
	for j: int in range(ns):
		var u: float = float(j) / float(maxi(ns - 1, 1))
		var t: float = float(j) / float(SR)
		var f: float = lerpf(f0, f1, u)
		ph += TAU * f / float(SR)
		var env: float = (1.0 - exp(-t / maxf(attack_s, 1.0e-5))) * exp(-t / maxf(decay_s, 1.0e-5))
		dst[((s0 + j) % n + n) % n] += amp * env * sin(ph)


func _periodic_bump(x: float, centers: Array, width: float) -> float:
	var s: float = 0.0
	for c: float in centers:
		var d: float = absf(x - c)
		d = minf(d, 1.0 - d)
		s += exp(-(d * d) / (2.0 * width * width))
	return s


func _add_bell(dst: PackedFloat32Array, start_s: float, freq: float, amp: float, dur_s: float) -> void:
	var ratios: Array = [1.0, 2.0, 3.0, 4.2]
	var amps: Array = [1.0, 0.45, 0.22, 0.10]
	var decs: Array = [1.0, 0.60, 0.40, 0.25]
	for k: int in range(4):
		_add_partial(dst, start_s, freq * float(ratios[k]), amp * float(amps[k]),
				dur_s * 1.05, dur_s * float(decs[k]), 0.004, 0.6 * float(k))


func _add_chirp(dst: PackedFloat32Array, start_s: float, dur_s: float, f0: float,
		f1: float, amp: float) -> void:
	var n: int = dst.size()
	var s0: int = int(start_s * float(SR))
	var ns: int = int(dur_s * float(SR))
	var ph: float = 0.0
	for j: int in range(ns):
		var i: int = s0 + j
		if i < 0:
			continue
		if i >= n:
			break
		var u: float = float(j) / float(ns)
		var f: float = lerpf(f0, f1, u) * (1.0 + 0.05 * sin(TAU * 55.0 * u))
		ph += TAU * f / float(SR)
		var env: float = sin(PI * u)
		env *= env
		dst[i] += amp * env * sin(ph)


# ---------------------------------------------------------------------------
# drivetrain
# ---------------------------------------------------------------------------

func _make_shift() -> PackedFloat32Array:
	var n: int = int(round(0.25 * float(SR)))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng: RandomNumberGenerator = _rng(3301)

	# lever out of gear: bright metallic tick
	_add_burst(buf, 0.004, 0.050, 1.30, 12000.0, 2600.0, 0.0006, 0.012, rng)
	_add_partial(buf, 0.004, 3100.0, 0.55, 0.060, 0.012, 0.0005)
	# slider engages: harder clack, lower ring
	_add_burst(buf, 0.042, 0.070, 1.20, 9000.0, 1700.0, 0.0008, 0.020, rng)
	_add_partial(buf, 0.042, 1750.0, 0.50, 0.070, 0.018, 0.0005, 1.0)
	_add_partial(buf, 0.042, 880.0, 0.30, 0.070, 0.016, 0.0005, 2.0)
	# drivetrain thunk
	_add_thud(buf, 0.070, 0.160, 120.0, 62.0, 0.55, 0.030, 0.0020, rng, 0.22)
	_add_partial(buf, 0.072, 420.0, 0.10, 0.100, 0.030, 0.0020, 0.5)
	# small linkage rattle
	for i: int in range(14):
		_grain(buf, rng.randf_range(0.030, 0.130), rng.randf_range(0.002, 0.006),
				rng.randf_range(0.02, 0.08), rng.randf_range(6000.0, 11000.0),
				rng.randf_range(1500.0, 3000.0), rng, true)

	_scale_peak(buf, 0.90)
	_soft_clip(buf, 1.30)
	return buf


func _make_clutch() -> PackedFloat32Array:
	var n: int = int(round(0.30 * float(SR)))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng: RandomNumberGenerator = _rng(3401)
	var nz: PackedFloat32Array = _noise(n, rng)
	var hi: PackedFloat32Array = _bp_forward(nz, 2400.0, 1.4)
	var lo: PackedFloat32Array = _bp_forward(nz, 800.0, 1.2)
	for i: int in range(n):
		var t: float = float(i) / float(SR)
		var m: float = smoothstep(0.0, 0.24, t)
		var env: float = (1.0 - exp(-t / 0.012)) * (1.0 - smoothstep(0.20, 0.30, t))
		var chatter: float = 0.72 + 0.28 * sin(TAU * 37.0 * t) * sin(TAU * 11.0 * t)
		buf[i] = (hi[i] * (1.0 - m) + lo[i] * m) * env * chatter * 1.2
	# low shudder of the release fork and a short slip honk
	_add_sine(buf, 0.0, 0.28, 150.0, 118.0, 0.10, 0.030, 0.160)
	_add_sine(buf, 0.0, 0.16, 640.0, 520.0, 0.06, 0.010, 0.100)

	_scale_peak(buf, 0.90)
	return buf


# ---------------------------------------------------------------------------
# tyres and surface
# ---------------------------------------------------------------------------

func _make_tire_gravel() -> PackedFloat32Array:
	var n: int = SR
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng: RandomNumberGenerator = _rng(4401)
	var bed: PackedFloat32Array = _lp_circ(_noise(n, rng), 420.0, 3)
	var bed2: PackedFloat32Array = _lp_circ(bed, 240.0, 2)
	var rumble: PackedFloat32Array = _lfo(n, 3.0, 0.0)
	for i: int in range(n):
		buf[i] = (bed[i] * 0.25 + bed2[i] * 0.22) * (0.85 + 0.15 * rumble[i])
	# granular crunch: dense small chips
	for i: int in range(170):
		_grain(buf, rng.randf(), rng.randf_range(0.003, 0.010), rng.randf_range(0.10, 0.60),
				rng.randf_range(3500.0, 8500.0), rng.randf_range(900.0, 2200.0), rng, false, true)
	# a few heavier crunches
	for i: int in range(10):
		_grain(buf, rng.randf(), rng.randf_range(0.010, 0.020), rng.randf_range(0.35, 0.80),
				rng.randf_range(2500.0, 5000.0), rng.randf_range(300.0, 700.0), rng, true, true)
	# stones knocking the tread
	for i: int in range(9):
		_add_thud(buf, rng.randf_range(0.02, 0.90), 0.070, 95.0, 60.0, 0.18, 0.020, 0.0020, rng, 0.20)

	_scale_peak(buf, 0.90)
	_soft_clip(buf, 1.20)
	return buf


func _make_tire_dirt() -> PackedFloat32Array:
	var n: int = SR
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng: RandomNumberGenerator = _rng(4501)
	var bed: PackedFloat32Array = _lp_circ(_noise(n, rng), 300.0, 3)
	var bed2: PackedFloat32Array = _lp_circ(bed, 160.0, 2)
	var am: PackedFloat32Array = _lfo(n, 4.0, 0.0)
	var am2: PackedFloat32Array = _lfo(n, 7.0, 1.1)
	for i: int in range(n):
		buf[i] = (bed[i] * 0.45 + bed2[i] * 0.30) * (0.80 + 0.12 * am[i] + 0.08 * am2[i])
	# soft granular patter, much sparser and duller than gravel
	for i: int in range(50):
		_grain(buf, rng.randf(), rng.randf_range(0.004, 0.013), rng.randf_range(0.05, 0.22),
				rng.randf_range(1800.0, 3200.0), rng.randf_range(350.0, 800.0), rng, false, true)
	_add_sine_loop(buf, 58.0, 0.05, 0.4)

	_scale_peak(buf, 0.88)
	return buf


func _make_skid() -> PackedFloat32Array:
	var n: int = SR
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng: RandomNumberGenerator = _rng(4601)

	# rubber squeal: two close voices with periodic FM warble. Every rate is a
	# whole number of cycles per second, so the one-second loop is exact.
	for v: int in range(2):
		var f: float = 1178.0 + 16.0 * float(v)
		var amp: float = 0.55 if v == 0 else 0.38
		var p0: float = 0.0 if v == 0 else 1.3
		for i: int in range(n):
			var t: float = float(i) / float(SR)
			var mod: float = 1.15 * sin(TAU * 7.0 * t + p0) + 0.45 * sin(TAU * 13.0 * t + 2.0 * p0)
			var ph: float = TAU * f * t + mod
			buf[i] += amp * (sin(ph) + 0.35 * sin(2.0 * ph) + 0.16 * sin(3.0 * ph))

	# rough rubber under the squeal
	var rough: PackedFloat32Array = _bp_circ(_noise(n, rng), 1600.0, 1.6, 3)
	var wob: PackedFloat32Array = _lfo(n, 5.0, 0.0)
	for i: int in range(n):
		buf[i] += rough[i] * 0.35 * (0.7 + 0.3 * wob[i])

	# gravel spray, bursting rather than constant
	var centres: Array = [0.06, 0.34, 0.61, 0.86]
	for i: int in range(110):
		var pos: float = rng.randf()
		var bump: float = _periodic_bump(pos, centres, 0.075)
		_grain(buf, pos, rng.randf_range(0.002, 0.008), rng.randf_range(0.04, 0.20) * (0.25 + bump),
				rng.randf_range(4000.0, 9000.0), rng.randf_range(1200.0, 3000.0), rng, true, true)

	_scale_peak(buf, 0.90)
	_soft_clip(buf, 1.25)
	return buf


func _make_mud_loop() -> PackedFloat32Array:
	var n: int = SR
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng: RandomNumberGenerator = _rng(4701)

	var bed: PackedFloat32Array = _lp_circ(_noise(n, rng), 280.0, 3)
	var bed2: PackedFloat32Array = _lp_circ(bed, 140.0, 2)
	var suck: PackedFloat32Array = _lfo(n, 3.0, 0.0)
	for i: int in range(n):
		buf[i] = (bed[i] * 0.35 + bed2[i] * 0.25) * (0.70 + 0.30 * (0.5 + 0.5 * suck[i]))

	# suction pops: a short downward bloop plus a wet squelch
	for i: int in range(14):
		var pos: float = rng.randf()
		var f0: float = rng.randf_range(170.0, 270.0)
		_add_sine_wrap(buf, pos, rng.randf_range(0.06, 0.13), f0, f0 * 0.30,
				rng.randf_range(0.20, 0.45), 0.002, 0.035, rng.randf() * TAU)
		_grain(buf, pos, rng.randf_range(0.03, 0.09), rng.randf_range(0.08, 0.22),
				rng.randf_range(1200.0, 2600.0), rng.randf_range(120.0, 400.0), rng, false, true)

	# wet splatter
	for i: int in range(90):
		_grain(buf, rng.randf(), rng.randf_range(0.008, 0.020), rng.randf_range(0.05, 0.20),
				rng.randf_range(1800.0, 4000.0), rng.randf_range(300.0, 900.0), rng, false, true)

	_scale_peak(buf, 0.88)
	_soft_clip(buf, 1.15)
	return buf


func _make_water_splash() -> PackedFloat32Array:
	var n: int = int(round(0.8 * float(SR)))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng: RandomNumberGenerator = _rng(5101)

	_add_burst(buf, 0.000, 0.300, 1.00, 14000.0, 1200.0, 0.0015, 0.090, rng)
	_add_burst(buf, 0.020, 0.450, 0.55, 5200.0, 380.0, 0.0100, 0.160, rng)
	_add_thud(buf, 0.000, 0.200, 260.0, 90.0, 0.45, 0.050, 0.0020, rng, 0.30)
	# droplets: short downward chirps scattered through the body
	for i: int in range(16):
		var t: float = 0.07 + rng.randf() * 0.52
		var f: float = rng.randf_range(1800.0, 3200.0)
		_add_sine(buf, t, 0.035, f, f * 0.62, rng.randf_range(0.05, 0.14), 0.0012, 0.012, rng.randf() * TAU)

	_scale_peak(buf, 0.92)
	return buf


# ---------------------------------------------------------------------------
# impacts
# ---------------------------------------------------------------------------

func _make_impact_rock() -> PackedFloat32Array:
	var n: int = int(round(0.5 * float(SR)))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng: RandomNumberGenerator = _rng(5201)

	_add_burst(buf, 0.000, 0.020, 1.00, 16000.0, 2500.0, 0.0003, 0.004, rng)
	var modes: Array = [720.0, 1180.0, 1930.0, 2740.0, 3670.0, 4520.0]
	for k: int in range(modes.size()):
		_add_partial(buf, 0.000, float(modes[k]), 0.50 / pow(1.35, float(k)), 0.300,
				0.050 + 0.030 * float(k), 0.0005, rng.randf() * TAU)
	_add_thud(buf, 0.000, 0.120, 150.0, 88.0, 0.35, 0.025, 0.0010, rng, 0.25)
	# debris skitter
	for i: int in range(26):
		var t: float = rng.randf_range(0.010, 0.340)
		_grain(buf, t, rng.randf_range(0.002, 0.012), 0.16 * (1.0 - t / 0.40),
				rng.randf_range(4000.0, 9000.0), rng.randf_range(900.0, 2200.0), rng, true)

	_scale_peak(buf, 0.92)
	_soft_clip(buf, 1.40)
	return buf


func _make_impact_wood() -> PackedFloat32Array:
	var n: int = int(round(0.4 * float(SR)))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng: RandomNumberGenerator = _rng(5301)

	_add_burst(buf, 0.000, 0.040, 0.80, 4000.0, 300.0, 0.0005, 0.010, rng)
	var modes: Array = [190.0, 310.0, 470.0, 700.0, 980.0]
	var decs: Array = [0.100, 0.075, 0.055, 0.040, 0.030]
	for k: int in range(modes.size()):
		_add_partial(buf, 0.000, float(modes[k]), 0.90 / pow(1.12, float(k)), 0.280,
				float(decs[k]), 0.0008, rng.randf() * TAU)
	_add_thud(buf, 0.000, 0.130, 130.0, 72.0, 0.55, 0.020, 0.0010, rng, 0.20)
	# splinters
	for i: int in range(12):
		_grain(buf, rng.randf_range(0.004, 0.090), rng.randf_range(0.002, 0.007),
				rng.randf_range(0.08, 0.26), rng.randf_range(4000.0, 9000.0),
				rng.randf_range(2000.0, 4000.0), rng, true)

	_scale_peak(buf, 0.92)
	_soft_clip(buf, 1.50)
	return buf


func _make_land_thud() -> PackedFloat32Array:
	var n: int = int(round(0.5 * float(SR)))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng: RandomNumberGenerator = _rng(5401)

	_add_thud(buf, 0.000, 0.420, 82.0, 40.0, 0.75, 0.040, 0.0015, rng, 0.28)
	_add_burst(buf, 0.000, 0.100, 0.50, 900.0, 80.0, 0.0010, 0.030, rng)
	# mount clank and rubber squish keep it audible on small speakers
	_add_partial(buf, 0.004, 480.0, 0.40, 0.140, 0.070, 0.0010)
	_add_partial(buf, 0.006, 2150.0, 0.45, 0.090, 0.030, 0.0005)
	_add_partial(buf, 0.008, 3250.0, 0.26, 0.080, 0.025, 0.0005)
	_add_sine(buf, 0.040, 0.100, 620.0, 380.0, 0.28, 0.004, 0.030)
	_add_sine(buf, 0.260, 0.180, 300.0, 240.0, 0.05, 0.020, 0.060)

	_scale_peak(buf, 0.92)
	_soft_clip(buf, 1.90)
	return buf


func _make_suspension_creak() -> PackedFloat32Array:
	var n: int = int(round(0.6 * float(SR)))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng: RandomNumberGenerator = _rng(5501)

	# stick-slip: irregular impulses exciting a resonant bush
	var exc := PackedFloat32Array()
	exc.resize(n)
	var t: float = 0.030
	while t < 0.520:
		var idx: int = int(t * float(SR))
		var sw: float = sin(PI * clampf(t / 0.55, 0.0, 1.0))
		exc[idx] += rng.randf_range(0.25, 1.00) * (0.40 + 0.60 * sw)
		t += rng.randf_range(0.0045, 0.0160)
	var r1: PackedFloat32Array = _resonator(exc, 1020.0, 9.0)
	var r2: PackedFloat32Array = _resonator(exc, 1780.0, 12.0)
	var r3: PackedFloat32Array = _resonator(exc, 640.0, 7.0)
	for i: int in range(n):
		buf[i] = r1[i] * 5.0 + r2[i] * 1.8 + r3[i] * 2.2

	_add_sine(buf, 0.020, 0.500, 92.0, 76.0, 0.05, 0.060, 0.250)
	_add_burst(buf, 0.000, 0.600, 0.020, 1200.0, 200.0, 0.050, 0.500, rng)

	_scale_peak(buf, 0.90)
	_soft_clip(buf, 1.25)
	return buf


# ---------------------------------------------------------------------------
# progression and UI
# ---------------------------------------------------------------------------

func _make_checkpoint() -> PackedFloat32Array:
	var n: int = int(round(0.6 * float(SR)))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng: RandomNumberGenerator = _rng(6101)

	_add_bell(buf, 0.000, 880.00, 0.55, 0.34)
	_add_bell(buf, 0.105, 1318.51, 0.60, 0.44)
	_add_burst(buf, 0.105, 0.120, 0.05, 16000.0, 6000.0, 0.0010, 0.030, rng)

	_space(buf, 0.10)
	_scale_peak(buf, 0.95)
	return buf


func _make_finish() -> PackedFloat32Array:
	var n: int = int(round(1.6 * float(SR)))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng: RandomNumberGenerator = _rng(6301)

	# D minor rising motif, then a D major lift — restrained, no bombast
	var motif: Array = [146.83, 174.61, 220.00, 293.66]
	var times: Array = [0.00, 0.20, 0.40, 0.62]
	for i: int in range(4):
		var f: float = float(motif[i])
		var t: float = float(times[i])
		_add_pad(buf, t, 0.60, f, 0.26, 0.050, 0.45, 0.90)
		_add_pad(buf, t, 0.55, f * 2.0, 0.09, 0.060, 0.40, 1.30)

	var chord: Array = [146.83, 185.00, 220.00, 293.66, 370.00, 440.00]
	var camps: Array = [0.20, 0.15, 0.15, 0.14, 0.10, 0.08]
	for i: int in range(chord.size()):
		_add_pad(buf, 0.90, 0.70, float(chord[i]), float(camps[i]), 0.090, 0.55, 1.50)

	_add_thud(buf, 0.885, 0.50, 62.0, 46.0, 0.55, 0.100, 0.0040, rng, 0.22)
	_add_partial(buf, 0.885, 98.0, 0.18, 0.55, 0.30, 0.0040)
	_add_burst(buf, 0.550, 0.95, 0.09, 6000.0, 500.0, 0.350, 1.300, rng)

	_space(buf, 0.16)
	_scale_peak(buf, 0.95)
	return buf


func _make_medal() -> PackedFloat32Array:
	var n: int = int(round(0.9 * float(SR)))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng: RandomNumberGenerator = _rng(6401)
	var f: float = 1318.51

	var ratios: Array = [1.00, 2.00, 2.76, 4.07, 5.43]
	var damp: Array = [0.62, 0.38, 0.26, 0.16, 0.10]
	var amps: Array = [0.50, 0.34, 0.30, 0.14, 0.08]
	for k: int in range(ratios.size()):
		_add_partial(buf, 0.000, f * float(ratios[k]), float(amps[k]), 0.850,
				float(damp[k]), 0.0015, rng.randf() * TAU)
	# a quieter fifth for shimmer, plus a detuned twin that beats
	_add_partial(buf, 0.012, f * 1.5, 0.16, 0.800, 0.450, 0.0030, 0.4)
	_add_partial(buf, 0.012, f * 1.5 * 2.0, 0.09, 0.780, 0.280, 0.0030, 1.1)
	_add_partial(buf, 0.020, f * 1.5 * 2.76, 0.06, 0.750, 0.180, 0.0030, 2.0)
	_add_partial(buf, 0.006, f * 1.004, 0.14, 0.820, 0.420, 0.0020, 0.9)
	# sparkle
	for i: int in range(22):
		_grain(buf, rng.randf_range(0.000, 0.500), rng.randf_range(0.004, 0.012),
				rng.randf_range(0.02, 0.07), 14000.0, 5000.0, rng, true)

	_space(buf, 0.18)
	_scale_peak(buf, 0.95)
	return buf


func _make_ui_click() -> PackedFloat32Array:
	var n: int = int(round(0.12 * float(SR)))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng: RandomNumberGenerator = _rng(6501)
	_add_burst(buf, 0.000, 0.030, 0.60, 16000.0, 3000.0, 0.0003, 0.005, rng)
	_add_partial(buf, 0.000, 1800.0, 0.50, 0.060, 0.012, 0.0006)
	_add_partial(buf, 0.000, 900.0, 0.25, 0.060, 0.020, 0.0008)
	_scale_peak(buf, 0.90)
	return buf


func _make_ui_confirm() -> PackedFloat32Array:
	var n: int = int(round(0.16 * float(SR)))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng: RandomNumberGenerator = _rng(6601)
	_add_partial(buf, 0.000, 1046.50, 0.55, 0.130, 0.060, 0.0040)
	_add_partial(buf, 0.000, 2093.00, 0.16, 0.120, 0.035, 0.0040)
	_add_partial(buf, 0.052, 1567.98, 0.60, 0.130, 0.070, 0.0045)
	_add_partial(buf, 0.052, 3135.96, 0.14, 0.120, 0.040, 0.0045)
	_add_burst(buf, 0.000, 0.020, 0.10, 14000.0, 4000.0, 0.0005, 0.004, rng)
	_space(buf, 0.08)
	_scale_peak(buf, 0.92)
	return buf


func _make_ui_back() -> PackedFloat32Array:
	var n: int = int(round(0.13 * float(SR)))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng: RandomNumberGenerator = _rng(6701)
	_add_partial(buf, 0.000, 880.00, 0.45, 0.110, 0.050, 0.0030)
	_add_partial(buf, 0.038, 587.33, 0.50, 0.110, 0.060, 0.0035)
	_add_partial(buf, 0.038, 1174.66, 0.12, 0.100, 0.035, 0.0035)
	_add_burst(buf, 0.000, 0.018, 0.09, 12000.0, 3000.0, 0.0005, 0.004, rng)
	_scale_peak(buf, 0.90)
	return buf


# ---------------------------------------------------------------------------
# ambience (4 s seamless loops)
# ---------------------------------------------------------------------------

func _make_amb_canyon() -> PackedFloat32Array:
	var n: int = int(round(4.0 * float(SR)))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng: RandomNumberGenerator = _rng(7101)

	var white: PackedFloat32Array = _noise(n, rng)
	var dark: PackedFloat32Array = _lp_circ(_lp_circ(white, 480.0, 3), 480.0, 2)
	var bright: PackedFloat32Array = _lp_circ(_lp_circ(white, 1500.0, 3), 1500.0, 2)
	var g1: PackedFloat32Array = _lfo(n, 1.0, 0.0)
	var g2: PackedFloat32Array = _lfo(n, 3.0, 1.3)
	var g3: PackedFloat32Array = _lfo(n, 7.0, 2.1)
	for i: int in range(n):
		var gust: float = 0.5 + 0.5 * g1[i]
		var bmix: float = 0.30 + 0.40 * gust
		var m: float = 0.45 + 0.35 * gust + 0.10 * (0.5 + 0.5 * g2[i]) + 0.06 * (0.5 + 0.5 * g3[i])
		buf[i] = (dark[i] * (1.0 - bmix) + bright[i] * bmix) * m

	var hiss: PackedFloat32Array = _hp_circ(_noise(n, rng), 5000.0, 3)
	var hmod: PackedFloat32Array = _lfo(n, 2.0, 0.7)
	for i: int in range(n):
		buf[i] += hiss[i] * 0.045 * (0.70 + 0.30 * (0.5 + 0.5 * hmod[i]))

	_scale_peak(buf, 0.95)
	return buf


func _make_amb_pine() -> PackedFloat32Array:
	var n: int = int(round(4.0 * float(SR)))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng: RandomNumberGenerator = _rng(7201)

	var white: PackedFloat32Array = _noise(n, rng)
	var low: PackedFloat32Array = _lp_circ(_lp_circ(white, 380.0, 3), 380.0, 2)
	var needle: PackedFloat32Array = _bp_circ(white, 3600.0, 0.70, 3)
	var needle2: PackedFloat32Array = _bp_circ(white, 6200.0, 1.20, 3)
	var m1: PackedFloat32Array = _lfo(n, 3.0, 0.0)
	var m2: PackedFloat32Array = _lfo(n, 5.0, 1.1)
	var m3: PackedFloat32Array = _lfo(n, 8.0, 2.2)
	for i: int in range(n):
		var am: float = 0.55 + 0.18 * (0.5 + 0.5 * m1[i]) + 0.12 * (0.5 + 0.5 * m2[i]) + 0.08 * (0.5 + 0.5 * m3[i])
		var lowmod: float = 0.70 + 0.30 * (0.5 + 0.5 * m1[i])
		buf[i] = low[i] * 1.40 * lowmod + (needle[i] * 0.20 + needle2[i] * 0.08) * am

	# a distant bird, twice per loop, tails dying well before the seam
	_add_chirp(buf, 1.140, 0.055, 3400.0, 3000.0, 0.055)
	_add_chirp(buf, 1.300, 0.045, 3550.0, 3250.0, 0.040)
	_add_chirp(buf, 1.480, 0.060, 3200.0, 2800.0, 0.035)
	_add_chirp(buf, 2.860, 0.050, 3300.0, 2950.0, 0.026)
	_add_chirp(buf, 2.980, 0.040, 3480.0, 3150.0, 0.020)

	_scale_peak(buf, 0.95)
	return buf


func _make_amb_quarry() -> PackedFloat32Array:
	var n: int = int(round(4.0 * float(SR)))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng: RandomNumberGenerator = _rng(7301)

	var white: PackedFloat32Array = _noise(n, rng)
	var high: PackedFloat32Array = _hp_circ(_lp_circ(white, 7000.0, 3), 900.0, 3)
	var whistle_a: PackedFloat32Array = _bp_circ(white, 2100.0, 16.0, 4)
	var whistle_b: PackedFloat32Array = _bp_circ(white, 2900.0, 20.0, 4)
	var rumble: PackedFloat32Array = _lp_circ(white, 180.0, 3)
	var w1: PackedFloat32Array = _lfo(n, 2.0, 0.0)
	var w2: PackedFloat32Array = _lfo(n, 5.0, 1.7)
	var w3: PackedFloat32Array = _lfo(n, 11.0, 2.6)
	for i: int in range(n):
		var gust: float = 0.5 + 0.5 * w1[i]
		var wmix: float = 0.45 + 0.55 * (0.5 + 0.5 * w2[i])
		var m: float = 0.50 + 0.30 * gust + 0.10 * (0.5 + 0.5 * w3[i])
		var body: float = high[i] * 0.20 * m + rumble[i] * 1.10 * (0.7 + 0.3 * gust)
		buf[i] = body + (whistle_a[i] * 0.22 + whistle_b[i] * 0.11) * wmix

	# sparse gravel trickle somewhere above
	for i: int in range(9):
		_grain(buf, rng.randf_range(0.05, 3.95), rng.randf_range(0.003, 0.010),
				rng.randf_range(0.02, 0.07), rng.randf_range(3500.0, 8000.0),
				rng.randf_range(1200.0, 2500.0), rng, true)

	_scale_peak(buf, 0.95)
	return buf
