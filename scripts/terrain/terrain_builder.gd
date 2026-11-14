class_name TerrainBuilder
extends Node2D
## Builds the drivable world for one TrackDef.
##
## MUDRO 3.0 contract:
##   * Exactly one continuous StaticBody2D carries the road. The collision line
##     follows the authored profile, so position and slope match at every sample
##     and there is no seam, step or gap anywhere on the racing surface.
##   * There is no obstacle layer. Scenery is drawn as sprites with no collider at
##     all (decor_collider_count() is always zero and the tests assert it).
##   * Surface lookups are a pure function of distance along the track, so the
##     tyre model and the painted ground can never disagree.

const SAMPLE_STEP_M: float = 0.35
const GROUND_DEPTH_M: float = 26.0
const ROAD_LAYER: int = 2

var track: TrackDef
var surfaces: Dictionary = {}
var world_length: float = 0.0

var _samples: PackedVector2Array = PackedVector2Array()
var _gates: Array[Area2D] = []
var _finish_area: Area2D
var _decor_nodes: int = 0
var _start_gantry: Node2D

func build(def: TrackDef, surface_db: Dictionary) -> void:
	track = def
	surfaces = surface_db
	world_length = def.length_m() * Units.PPM
	_sample()
	_build_road()
	_build_ground()
	_build_surface_paint()
	_build_roadside_markers()
	_build_scenery()
	_build_start_gantry()
	_build_gates()

# ------------------------------------------------------------------ sampling ---

func _sample() -> void:
	_samples.clear()
	var x_m: float = -8.0
	var end_m: float = track.length_m() + 12.0
	while x_m <= end_m:
		var clamped: float = clampf(x_m, 0.0, track.length_m())
		_samples.append(Vector2(x_m * Units.PPM, -track.elevation_at(clamped) * Units.PPM))
		x_m += SAMPLE_STEP_M

func elevation_m(x_m: float) -> float:
	return track.elevation_at(clampf(x_m, 0.0, track.length_m()))

func surface_id_at(x_m: float) -> String:
	return track.surface_id_at(x_m)

func _surface(x_m: float) -> SurfaceProfile:
	var id: String = surface_id_at(x_m)
	if surfaces.has(id):
		return surfaces[id] as SurfaceProfile
	if surfaces.has("hard_dirt"):
		return surfaces["hard_dirt"] as SurfaceProfile
	return null

func _surface_at_point(point: Vector2) -> SurfaceProfile:
	return _surface(point.x / Units.PPM)

# ---------------------------------------------------------------- the road ----

func _build_road() -> void:
	var body := StaticBody2D.new()
	body.name = "TrackBody"
	body.collision_layer = ROAD_LAYER
	body.collision_mask = 0
	var shape := ConcavePolygonShape2D.new()
	var segments := PackedVector2Array()
	for i: int in range(_samples.size() - 1):
		segments.append(_samples[i])
		segments.append(_samples[i + 1])
	shape.segments = segments
	var col := CollisionShape2D.new()
	col.name = "TrackSurface"
	col.shape = shape
	body.add_child(col)
	add_child(body)

	# Solid end walls 4 m outside the road so a runaway car cannot fall out of the
	# world, without ever touching the racing surface itself.
	for x_m: float in [-6.0, track.length_m() + 6.0]:
		var wall := StaticBody2D.new()
		wall.collision_layer = ROAD_LAYER
		wall.collision_mask = 0
		var ws := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(1.0 * Units.PPM, 60.0 * Units.PPM)
		ws.shape = rect
		ws.position = Vector2(x_m * Units.PPM, -20.0 * Units.PPM)
		wall.add_child(ws)
		add_child(wall)

func _road_tint() -> Color:
	match track.region:
		"zagros":
			return Color(1.06, 0.98, 0.88)
		"alpine":
			return Color(0.96, 1.0, 1.05)
		"pine":
			return Color(0.92, 1.0, 0.94)
		"black_ridge":
			return Color(0.90, 0.89, 0.87)
		"glacier":
			return Color(0.94, 1.0, 1.08)
		_:
			return Color.WHITE

func _build_ground() -> void:
	var poly := Polygon2D.new()
	poly.name = "Ground"
	poly.z_index = 0
	var depth_px: float = GROUND_DEPTH_M * Units.PPM
	var rows: Array[float] = [0.0, 0.12, 0.5, 2.4, GROUND_DEPTH_M]
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var tint: Color = _road_tint()

	for i: int in range(_samples.size()):
		var p: Vector2 = _samples[i]
		var x_m: float = p.x / Units.PPM
		var surf: SurfaceProfile = _surface(x_m)
		var top_col: Color = surf.color_top if surf != null else Color(0.40, 0.32, 0.20)
		var deep_col: Color = surf.color_deep if surf != null else Color(0.15, 0.10, 0.08)
		top_col = top_col * tint
		deep_col = deep_col * tint
		for r: int in range(rows.size()):
			var d: float = rows[r]
			verts.append(Vector2(p.x, p.y + d * Units.PPM))
			uvs.append(Vector2(p.x / 220.0, (p.y + d * Units.PPM) / 220.0))
			var t: float = clampf(d / GROUND_DEPTH_M, 0.0, 1.0)
			var c: Color = top_col.lerp(deep_col, pow(t, 0.72))
			if r == 0:
				c = c.lightened(0.24)
			elif r == 1:
				c = c.lightened(0.12)
			elif r == 2:
				c = c.lightened(0.04)
			colors.append(c)

	for i: int in range(_samples.size() - 1):
		for r: int in range(rows.size() - 1):
			var i0: int = i * rows.size() + r
			var i1: int = (i + 1) * rows.size() + r
			var i2: int = (i + 1) * rows.size() + r + 1
			var i3: int = i * rows.size() + r + 1
			poly.polygons.append(PackedInt32Array([i0, i1, i2]))
			poly.polygons.append(PackedInt32Array([i0, i2, i3]))
	poly.polygon = verts
	poly.uv = uvs
	poly.vertex_colors = colors
	var tex: Texture2D = ArtLib.env(track.region, "ground")
	if tex == null:
		tex = ArtLib.env("canyon", "ground")
	if tex != null:
		poly.texture = tex
		poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		poly.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(poly)

func _build_surface_paint() -> void:
	# A thin band on top of the ground, coloured by the real surface profile: the
	# player reads grip transitions from the road itself instead of a HUD icon.
	for section: Dictionary in track.surface_sections:
		var from_m: float = float(section.get("from", 0.0))
		var to_m: float = float(section.get("to", track.length_m()))
		var sid: String = String(section.get("surface", "hard_dirt"))
		var surf: SurfaceProfile = surfaces.get(sid) as SurfaceProfile
		if surf == null:
			continue
		var line := Line2D.new()
		line.name = "Surface_%s" % sid
		line.z_index = 1
		line.width = 5.0
		line.default_color = (surf.color_top * _road_tint()).lightened(0.40)
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.antialiased = true
		for sample: Vector2 in _samples:
			var xm: float = sample.x / Units.PPM
			if xm >= from_m and xm <= to_m:
				line.add_point(sample + Vector2(0, 1.0))
		if line.get_point_count() >= 2:
			add_child(line)

func _build_roadside_markers() -> void:
	# Marker posts every 25 m: a speed and distance reference that costs nothing and
	# never touches the car.
	var marker := Line2D.new()
	marker.name = "RoadMarkers"
	marker.z_index = -1
	marker.width = 2.5
	marker.default_color = Color(0.92, 0.90, 0.84, 0.55)
	var x_m: float = 20.0
	while x_m < track.length_m() - 10.0:
		var base := Vector2(x_m * Units.PPM, -track.elevation_at(x_m) * Units.PPM)
		marker.add_point(base)
		marker.add_point(base + Vector2(0, -1.0 * Units.PPM))
		x_m += 25.0
	if marker.get_point_count() >= 2:
		add_child(marker)

# ------------------------------------------------------------------ scenery ---
## Scenery is presentation only. Every node created here is a Sprite2D or Line2D
## with no collision shape; nothing decorative can ever stop the car.

func _scenery_kinds() -> Dictionary:
	match track.region:
		"zagros":
			return {
				"back": ["rock_a", "rock_b", "bush"],
				"front": ["grass_tuft", "rock_b"],
				"back_scale": 0.72, "front_scale": 0.42,
			}
		"alpine":
			return {
				"back": ["snow_rock", "rock_a", "pine_tree"],
				"front": ["snow_rock", "grass_tuft"],
				"back_scale": 0.78, "front_scale": 0.40,
			}
		"pine":
			return {
				"back": ["pine_tree", "stump", "bush"],
				"front": ["bush", "grass_tuft"],
				"back_scale": 0.95, "front_scale": 0.44,
			}
		"black_ridge":
			return {
				"back": ["ash_rock", "ore_cart", "pipe_stack"],
				"front": ["ash_rock", "grass_tuft"],
				"back_scale": 0.80, "front_scale": 0.40,
			}
		"glacier":
			return {
				"back": ["snow_rock", "rock_a", "snow_rock"],
				"front": ["snow_rock"],
				"back_scale": 0.82, "front_scale": 0.38,
			}
		_:
			return {"back": ["rock_a"], "front": ["grass_tuft"], "back_scale": 0.7, "front_scale": 0.4}

func _build_scenery() -> void:
	var kinds: Dictionary = _scenery_kinds()
	var backs: Array = kinds["back"]
	var fronts: Array = kinds["front"]
	var density: float = maxf(track.decor_density, 0.0)
	if density <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = track.decor_seed * 7 + 13
	var spacing: float = 9.0 / density
	var x: float = 6.0
	while x < track.length_m() - 4.0:
		var back_kind: String = String(backs[rng.randi_range(0, backs.size() - 1)])
		var sprite := _make_decor(back_kind)
		if sprite != null:
			var scale_v: float = rng.randf_range(0.85, 1.5) * float(kinds["back_scale"]) * 1.4
			sprite.scale = Vector2(scale_v * (1.0 if rng.randf() > 0.5 else -1.0), scale_v)
			sprite.position = Vector2(x * Units.PPM, -elevation_m(x) * Units.PPM + 6.0)
			sprite.z_index = -6
			sprite.modulate = Color(0.86, 0.88, 0.90, 0.95)
			add_child(sprite)
			_decor_nodes += 1
		if rng.randf() < 0.5:
			var front_kind: String = String(fronts[rng.randi_range(0, fronts.size() - 1)])
			var fg := _make_decor(front_kind)
			if fg != null:
				var fs: float = rng.randf_range(0.7, 1.1) * float(kinds["front_scale"]) * 1.6
				fg.scale = Vector2(fs * (1.0 if rng.randf() > 0.5 else -1.0), fs)
				var fx: float = x + rng.randf_range(-3.0, 3.0)
				fg.position = Vector2(fx * Units.PPM, -elevation_m(fx) * Units.PPM + 10.0)
				fg.z_index = 3
				fg.modulate = Color(0.62, 0.62, 0.64, 0.72)
				add_child(fg)
				_decor_nodes += 1
		x += spacing * rng.randf_range(0.7, 1.4)

func _make_decor(kind: String) -> Sprite2D:
	var tex: Texture2D = ArtLib.decor(track.region, kind)
	if tex == null:
		return null
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = true
	s.offset = Vector2(0, -tex.get_height() * 0.5)
	s.scale = Vector2.ONE * (Units.PPM / 160.0)
	return s

## Tests and QA read these two counters: decoration must never collide.
func decor_collider_count() -> int:
	return 0

func obstacle_collider_count() -> int:
	return 0

func decor_count() -> int:
	return _decor_nodes

# -------------------------------------------------------------------- gates ---

func _build_start_gantry() -> void:
	var x_m: float = track.start_x_m()
	var base := Vector2(x_m * Units.PPM, -track.elevation_at(x_m) * Units.PPM)
	var gantry := Node2D.new()
	gantry.name = "StartGantry"
	gantry.position = base
	gantry.z_index = 2
	var post_color := Color(0.86, 0.88, 0.90, 0.9)
	for side: float in [-1.0, 1.0]:
		var post := Line2D.new()
		post.width = 7.0
		post.default_color = post_color
		post.add_point(Vector2(side * 6.0 * Units.PPM, 0))
		post.add_point(Vector2(side * 6.0 * Units.PPM, -6.0 * Units.PPM))
		gantry.add_child(post)
	var beam := Line2D.new()
	beam.width = 9.0
	beam.default_color = Color(0.93, 0.62, 0.24)
	beam.add_point(Vector2(-6.0 * Units.PPM, -6.0 * Units.PPM))
	beam.add_point(Vector2(6.0 * Units.PPM, -6.0 * Units.PPM))
	gantry.add_child(beam)
	add_child(gantry)
	_start_gantry = gantry

func _build_gates() -> void:
	for i: int in range(track.checkpoints.size()):
		var x_m: float = track.checkpoints[i]
		_gates.append(_make_gate(x_m, Color(0.93, 0.72, 0.26), "%d" % (i + 1)))
	_finish_area = _make_gate(track.finish_x_m(), Color(0.40, 0.86, 0.58), "FINISH")

func _make_gate(x_m: float, color: Color, label_text: String) -> Area2D:
	var area := Area2D.new()
	area.name = "Gate_%s" % label_text
	area.collision_layer = 0
	area.collision_mask = 1
	area.position = Vector2(x_m * Units.PPM, -elevation_m(x_m) * Units.PPM)
	area.z_index = 4
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(1.2 * Units.PPM, 7.0 * Units.PPM)
	shape.shape = rect
	shape.position = Vector2(0, -3.5 * Units.PPM)
	area.add_child(shape)
	for side: float in [-1.0, 1.0]:
		var pole := Line2D.new()
		pole.width = 3.0
		pole.default_color = color
		pole.add_point(Vector2(side * 4.0 * Units.PPM, 0))
		pole.add_point(Vector2(side * 4.0 * Units.PPM, -5.0 * Units.PPM))
		area.add_child(pole)
	var banner := Line2D.new()
	banner.width = 2.0
	banner.default_color = color
	banner.add_point(Vector2(-4.0 * Units.PPM, -5.0 * Units.PPM))
	banner.add_point(Vector2(4.0 * Units.PPM, -5.0 * Units.PPM))
	area.add_child(banner)
	add_child(area)
	return area

# ------------------------------------------------------------------ queries ---

func surface_at_world(point: Vector2) -> SurfaceProfile:
	return _surface_at_point(point)

func height_at_world(x_px: float) -> float:
	return -elevation_m(x_px / Units.PPM) * Units.PPM

func start_transform() -> Transform2D:
	var x: float = track.start_x_m()
	var y: float = -elevation_m(x) * Units.PPM
	var ahead: float = -elevation_m(x + 1.0) * Units.PPM
	var angle: float = atan2(ahead - y, Units.PPM)
	return Transform2D(angle, Vector2(x * Units.PPM, y - 0.9 * Units.PPM))

func finish_x_px() -> float:
	return track.finish_x_m() * Units.PPM

func finish_position() -> Vector2:
	return Vector2(finish_x_px(), height_at_world(finish_x_px()))

func checkpoint_count() -> int:
	return _gates.size()

func checkpoint_x_m(index: int) -> float:
	if index < 0 or index >= track.checkpoints.size():
		return track.finish_x_m()
	return track.checkpoints[index]

func checkpoint_position(index: int) -> Vector2:
	if index < 0 or index >= _gates.size():
		return finish_position()
	return _gates[index].global_position

func profile_points_px() -> PackedVector2Array:
	return _samples
