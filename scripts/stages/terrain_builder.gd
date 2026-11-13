class_name TerrainBuilder
extends Node2D
## Builds a stage from a StageDef: sampled elevation, collision segments,
## material-banded ground rendering, decoration, solid obstacles and checkpoints.
## Exposes surface lookups used by the tyre model.

const SAMPLE_STEP_M: float = 0.30
const GROUND_ROWS: int = 5

var stage: StageDef
var surfaces: Dictionary = {}
var world_length: float = 0.0

var _samples: PackedVector2Array = PackedVector2Array()
var _elevations: PackedFloat32Array = PackedFloat32Array()
var _noise: FastNoiseLite
var _detail: FastNoiseLite
var _obstacles: Array[Dictionary] = []
var _checkpoint_nodes: Array[Area2D] = []
var _finish_area: Area2D
var _start_x: float = 0.0
var _finish_x: float = 0.0

func build(def: StageDef, surface_db: Dictionary) -> void:
	stage = def
	surfaces = surface_db
	world_length = def.length_m * Units.PPM
	_noise = FastNoiseLite.new()
	_noise.seed = def.seed_value
	_noise.frequency = 0.075
	_noise.fractal_octaves = 3
	_detail = FastNoiseLite.new()
	_detail.seed = def.seed_value + 991
	_detail.frequency = 0.55
	_detail.fractal_octaves = 2
	_sample_profile()
	_build_collision()
	_build_ground()
	_build_surface_bands()
	_build_decoration()
	_build_obstacles()
	_build_checkpoints()

func _surface_id(x_m: float) -> String:
	return stage.surface_id_at(x_m) if stage != null else "hard_dirt"

func _surface(x_m: float) -> SurfaceProfile:
	var id: String = _surface_id(x_m)
	if surfaces.has(id):
		return surfaces[id] as SurfaceProfile
	if surfaces.has("hard_dirt"):
		return surfaces["hard_dirt"] as SurfaceProfile
	return null

func _roughness(x_m: float) -> float:
	var s: SurfaceProfile = _surface(x_m)
	return s.bumpiness if s != null else 0.3

func elevation_m(x_m: float) -> float:
	var base: float = stage.elevation_at(x_m)
	var rough: float = _roughness(x_m)
	var amp: float = clampf(0.16 * rough, 0.0, 0.22)
	var wobble: float = _noise.get_noise_1d(x_m * 3.2) * amp
	wobble += _detail.get_noise_1d(x_m * 11.0) * amp * 0.35
	# Flatten the launch pad so the vehicle always spawns on level ground.
	var pad: float = clampf(x_m / 9.0, 0.0, 1.0)
	return base + wobble * pad * stage.noise_amplitude

func _sample_profile() -> void:
	_samples.clear()
	_elevations.clear()
	var x_m: float = -6.0
	while x_m <= stage.length_m + 8.0:
		var elev: float = elevation_m(maxf(x_m, 0.0))
		_elevations.append(elev)
		_samples.append(Vector2(x_m * Units.PPM, -elev * Units.PPM))
		x_m += SAMPLE_STEP_M
	_start_x = 3.0
	_finish_x = stage.length_m - 2.0

func _build_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "TerrainBody"
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := ConcavePolygonShape2D.new()
	var segs: PackedVector2Array = PackedVector2Array()
	for i: int in range(_samples.size() - 1):
		segs.append(_samples[i])
		segs.append(_samples[i + 1])
	shape.segments = segs
	var col := CollisionShape2D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)

	# Invisible walls so the vehicle cannot leave the stage sideways.
	for x: float in [-8.0, stage.length_m + 10.0]:
		var wall := StaticBody2D.new()
		wall.collision_layer = 2
		var ws := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(2.0 * Units.PPM, 40.0 * Units.PPM)
		ws.shape = rect
		ws.position = Vector2(x * Units.PPM, -10.0 * Units.PPM)
		wall.add_child(ws)
		add_child(wall)

func _build_ground() -> void:
	var poly := Polygon2D.new()
	poly.name = "Ground"
	poly.z_index = 0
	var depth_px: float = 30.0 * Units.PPM
	var rows: Array[float] = [0.0, 0.10, 0.45, 2.2, 30.0]
	var verts: PackedVector2Array = PackedVector2Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var tops: PackedVector2Array = PackedVector2Array()

	for i: int in range(_samples.size()):
		var p: Vector2 = _samples[i]
		tops.append(p)
		var surf: SurfaceProfile = _surface(p.x / Units.PPM)
		var top_col: Color = surf.color_top if surf != null else Color(0.4, 0.32, 0.2)
		var deep_col: Color = surf.color_deep if surf != null else Color(0.15, 0.1, 0.08)
		for r: int in range(rows.size()):
			var d: float = rows[r]
			verts.append(Vector2(p.x, p.y + d))
			uvs.append(Vector2(p.x / 220.0, (p.y + d) / 220.0))
			var t: float = clampf(d / depth_px * 5.0, 0.0, 1.0)
			var c: Color = top_col.lerp(deep_col, pow(t, 0.75))
			if r == 0:
				c = c.lightened(0.26)
			elif r == 1:
				c = c.lightened(0.14)
			elif r == 2:
				c = c.lightened(0.05)
			colors.append(c)

	# Triangulate as a strip between consecutive rows.
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
	var tex: Texture2D = _load_ground_texture(stage.environment)
	if tex != null:
		poly.texture = tex
		poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(poly)

func _load_ground_texture(env: String) -> Texture2D:
	var path: String = "res://assets/environments/%s/ground.svg" % env
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _build_surface_bands() -> void:
	for span: Dictionary in stage.surface_spans:
		var from_m: float = float(span.get("from", 0.0))
		var to_m: float = float(span.get("to", stage.length_m))
		var sid: String = String(span.get("surface", "hard_dirt"))
		var surf: SurfaceProfile = surfaces.get(sid) as SurfaceProfile
		if surf == null:
			continue
		var line := Line2D.new()
		line.z_index = 1
		line.width = 6.0
		line.default_color = surf.color_top.lightened(0.42)
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		var antialias: bool = true
		line.antialiased = antialias
		var i: int = 0
		while i < _samples.size():
			var xm: float = _samples[i].x / Units.PPM
			if xm >= from_m and xm <= to_m:
				line.add_point(_samples[i] + Vector2(0, 1.0))
			i += 1
		if line.get_point_count() >= 2:
			add_child(line)

func _build_decoration() -> void:
	var env: String = stage.environment
	var density: float = maxf(stage.decor_density, 0.0)
	if density <= 0.0:
		return
	var back_kinds: PackedStringArray = PackedStringArray()
	var front_kinds: PackedStringArray = PackedStringArray()
	match env:
		"canyon":
			back_kinds = PackedStringArray(["rock_a", "rock_b", "bush"])
			front_kinds = PackedStringArray(["rock_b", "grass_tuft"])
		"pine":
			back_kinds = PackedStringArray(["pine_tree", "stump", "bush"])
			front_kinds = PackedStringArray(["bush", "grass_tuft"])
		"quarry":
			back_kinds = PackedStringArray(["quarry_block", "snow_rock", "rock_a"])
			front_kinds = PackedStringArray(["snow_rock", "rock_b"])
		"black_ridge":
			back_kinds = PackedStringArray(["ash_rock", "ore_cart", "pipe_stack", "floodlight"])
			front_kinds = PackedStringArray(["ash_rock", "industrial_barrier"])
	var rng := RandomNumberGenerator.new()
	rng.seed = stage.seed_value * 7 + 13
	var spacing: float = 7.5 / density
	var x: float = 8.0
	while x < stage.length_m - 6.0:
		var back_kind: String = back_kinds[rng.randi_range(0, back_kinds.size() - 1)]
		var sprite := _make_decor(back_kind, env)
		if sprite != null:
			var scale_v: float = rng.randf_range(0.75, 1.55) * _decor_scale(back_kind)
			sprite.scale = Vector2(scale_v * (1.0 if rng.randf() > 0.5 else -1.0), scale_v)
			sprite.position = Vector2(x * Units.PPM, -elevation_m(x) * Units.PPM + 2.0)
			sprite.z_index = -6
			sprite.modulate = Color(0.86, 0.88, 0.9, 0.95)
			add_child(sprite)
		if rng.randf() < 0.55:
			var front_kind: String = front_kinds[rng.randi_range(0, front_kinds.size() - 1)]
			var fg := _make_decor(front_kind, env)
			if fg != null:
				var fs: float = rng.randf_range(0.6, 1.2) * _decor_scale(front_kind)
				fg.scale = Vector2(fs * (1.0 if rng.randf() > 0.5 else -1.0), fs)
				var fx: float = x + rng.randf_range(-2.4, 2.4)
				fg.position = Vector2(fx * Units.PPM, -elevation_m(fx) * Units.PPM + 12.0)
				fg.z_index = 3
				fg.modulate = Color(0.55, 0.55, 0.58, 0.75)
				add_child(fg)
		x += spacing * rng.randf_range(0.65, 1.45)

func _decor_scale(kind: String) -> float:
	match kind:
		"grass_tuft":
			return 0.42
		"bush":
			return 0.50
		"pine_tree":
			return 1.05
		"stump":
			return 0.7
		"rock_a", "rock_b", "snow_rock":
			return 0.68
		"quarry_block":
			return 0.62
		"log":
			return 0.8
		"ash_rock":
			return 0.8
		"ore_cart":
			return 0.85
		"pipe_stack":
			return 0.8
		"floodlight":
			return 0.9
		"industrial_barrier":
			return 0.85
		_:
			return 0.8

func _make_decor(kind: String, env: String) -> Sprite2D:
	var paths: Array[String] = [
		"res://assets/environments/common/%s.svg" % kind,
		"res://assets/environments/%s/%s.svg" % [env, kind],
	]
	for p: String in paths:
		if ResourceLoader.exists(p):
			var tex: Texture2D = load(p) as Texture2D
			if tex == null:
				continue
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = true
			s.offset = Vector2(0, -tex.get_height() * 0.5)
			s.scale = Vector2.ONE * (Units.PPM / 160.0)
			return s
	return null

func _build_obstacles() -> void:
	for entry: Dictionary in stage.obstacles:
		var kind: String = String(entry.get("kind", "rock_a"))
		if kind == "steel_bridge":
			_build_bridge(entry)
			continue
		var x_m: float = float(entry.get("x", 0.0))
		var scale_v: float = float(entry.get("scale", 1.0))
		var rot: float = float(entry.get("rot", 0.0))
		var solid: bool = bool(entry.get("solid", true))
		var y_m: float = elevation_m(x_m) + float(entry.get("y_offset", 0.0))
		var pos := Vector2(x_m * Units.PPM, -y_m * Units.PPM)

		var sprite := _make_decor(kind, stage.environment)
		if sprite == null:
			sprite = _make_solid_block_sprite(scale_v)
		sprite.position = pos
		sprite.scale = Vector2(scale_v, scale_v) * (Units.PPM / 160.0)
		sprite.rotation = rot
		sprite.z_index = 6
		add_child(sprite)

		if solid:
			var body := StaticBody2D.new()
			body.collision_layer = 4
			body.collision_mask = 0
			body.position = pos
			var col := CollisionShape2D.new()
			var r: float = _obstacle_radius(kind) * scale_v * Units.PPM
			var box: Vector2 = _obstacle_box(kind) * scale_v
			if box.x > 0.0:
				var rect := RectangleShape2D.new()
				rect.size = box * Units.PPM
				col.shape = rect
				col.position = Vector2(0, -box.y * 0.5 * Units.PPM)
				col.rotation = rot
			elif kind == "log":
				var lb := RectangleShape2D.new()
				lb.size = Vector2(r * 2.6, r * 1.0)
				col.shape = lb
				col.position = Vector2(0, -r * 0.45)
				col.rotation = rot
			else:
				var circle := CircleShape2D.new()
				circle.radius = r * 0.80
				col.shape = circle
				col.position = Vector2(0, -r * 0.45)
			body.add_child(col)
			add_child(body)
			_obstacles.append({
				"rect": Rect2(pos + Vector2(-r, -r * 1.4), Vector2(r * 2.0, r * 1.7)),
				"surface": "rock" if kind != "ash_rock" else "ash",
			})

## A bridge is a real platform: the collider top is the deck surface, so the car
## drives on it and the gap below stays a gap.
func _build_bridge(entry: Dictionary) -> void:
	var x_m: float = float(entry.get("x", 0.0))
	var span: float = float(entry.get("span_m", 12.0))
	# The deck height is authored absolutely: a bridge spans a gap, it is not "the
	# ground plus an offset" (the ground under a bridge is the bottom of the gap).
	var deck_y: float = float(entry.get("deck_y", elevation_m(x_m) + float(entry.get("y_offset", 0.0))))
	var deck_pos := Vector2(x_m * Units.PPM, -deck_y * Units.PPM)
	var tex: Texture2D = ArtLib.decor(stage.environment, "steel_bridge")
	if tex == null:
		tex = ArtLib.decor("black_ridge", "steel_bridge")
	if OS.get_cmdline_args().has("--uidiag"):
		print("[bridge] tex=%s deck=%.1f span=%.1f x=%.1f" % [str(tex), deck_y, span, x_m])
	if tex != null:
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.centered = false
		var sx: float = span * Units.PPM / maxf(float(tex.get_width()), 1.0)
		sprite.scale = Vector2(sx, sx)
		# The artwork draws the deck along its bottom edge and the truss above it.
		# Flipping it puts the deck on top and hangs the truss into the gap, which is
		# both readable and does not cover the car.
		sprite.flip_v = true
		sprite.position = Vector2(deck_pos.x - span * Units.PPM * 0.5, deck_pos.y)
		sprite.z_index = 1
		sprite.modulate = Color(1.35, 1.36, 1.38, 1.0)
		add_child(sprite)

	# Readable structure: the authored texture is low-contrast dark steel, so a lighter
	# truss is drawn from the span geometry itself, hanging under the deck where
	# nothing else competes with it.
	var truss := Line2D.new()
	truss.name = "BridgeTruss"
	truss.width = 3.5
	truss.default_color = Color(0.80, 0.82, 0.84, 1.0)
	truss.z_index = 1
	var half: float = span * Units.PPM * 0.5
	var x0: float = deck_pos.x - half
	var top_y: float = deck_pos.y + 4.0
	var bot_y: float = deck_pos.y + 1.9 * Units.PPM
	var panels: int = maxi(int(span / 3.0), 2)
	truss.add_point(Vector2(x0, top_y))
	truss.add_point(Vector2(x0 + span * Units.PPM, top_y))
	for i: int in range(panels + 1):
		var px: float = x0 + span * Units.PPM * float(i) / float(panels)
		truss.add_point(Vector2(px, top_y))
		truss.add_point(Vector2(px, bot_y))
	truss.add_point(Vector2(x0, bot_y))
	truss.add_point(Vector2(x0 + span * Units.PPM, bot_y))
	for i: int in range(panels):
		var a: float = x0 + span * Units.PPM * float(i) / float(panels)
		var b: float = x0 + span * Units.PPM * float(i + 1) / float(panels)
		truss.add_point(Vector2(a, top_y))
		truss.add_point(Vector2(a, bot_y))
		truss.add_point(Vector2(a, bot_y))
		truss.add_point(Vector2(b, top_y))
	add_child(truss)

	# Guard rail above the deck, in the region's restrained amber. This is what makes
	# the span read as a bridge at a glance, whatever the texture does.
	var rail := Line2D.new()
	rail.name = "BridgeRail"
	rail.width = 4.5
	rail.default_color = Color(1.0, 0.74, 0.30, 1.0)
	rail.z_index = 4
	var rail_y: float = deck_pos.y - 0.95 * Units.PPM
	rail.add_point(Vector2(x0, rail_y))
	rail.add_point(Vector2(x0 + span * Units.PPM, rail_y))
	for i: int in range(panels + 1):
		var rx: float = x0 + span * Units.PPM * float(i) / float(panels)
		rail.add_point(Vector2(rx, rail_y))
		rail.add_point(Vector2(rx, rail_y))
		rail.add_point(Vector2(rx, rail_y))
		rail.add_point(Vector2(rx, deck_pos.y - 4.0))
	add_child(rail)

	var body := StaticBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	body.position = deck_pos
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(span * Units.PPM, 0.5 * Units.PPM)
	col.shape = rect
	col.position = Vector2(0, 0.25 * Units.PPM)
	body.add_child(col)
	add_child(body)
	_obstacles.append({
		"rect": Rect2(deck_pos - Vector2(span * Units.PPM * 0.5, 0.2 * Units.PPM), Vector2(span * Units.PPM, 0.8 * Units.PPM)),
		"surface": "steel",
	})

func _obstacle_box(kind: String) -> Vector2:
	match kind:
		"industrial_barrier":
			return Vector2(2.1, 1.05)
		"ore_cart":
			return Vector2(2.0, 1.6)
		"pipe_stack":
			return Vector2(2.3, 1.4)
		"quarry_block":
			return Vector2(1.5, 1.5)
		"floodlight":
			return Vector2(0.3, 2.6)
		_:
			return Vector2.ZERO

func _obstacle_radius(kind: String) -> float:
	match kind:
		"log":
			return 0.55
		"stump":
			return 0.45
		"quarry_block":
			return 0.95
		"tire_stack":
			return 0.45
		_:
			return 0.7

func _make_solid_block_sprite(scale_v: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _glow_square()
	s.scale = Vector2(1.6 * scale_v, 1.0 * scale_v)
	s.modulate = Color(0.30, 0.26, 0.23)
	return s

func _glow_square() -> Texture2D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)

func _build_checkpoints() -> void:
	for i: int in range(stage.checkpoints.size()):
		var x_m: float = stage.checkpoints[i]
		var area := _make_gate(x_m, Color(0.92, 0.72, 0.25), "%d" % (i + 1))
		_checkpoint_nodes.append(area)
	_finish_area = _make_gate(_finish_x, Color(0.35, 0.85, 0.55), "FINISH")

func _make_gate(x_m: float, color: Color, label_text: String) -> Area2D:
	var area := Area2D.new()
	area.name = "Gate_%s" % label_text
	area.collision_layer = 0
	area.collision_mask = 1
	area.position = Vector2(x_m * Units.PPM, -elevation_m(x_m) * Units.PPM)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(1.2 * Units.PPM, 6.0 * Units.PPM)
	shape.shape = rect
	shape.position = Vector2(0, -3.0 * Units.PPM)
	area.add_child(shape)

	var pole := Line2D.new()
	pole.add_point(Vector2(0, 0))
	pole.add_point(Vector2(0, -4.2 * Units.PPM))
	pole.width = 3.0
	pole.default_color = color
	area.add_child(pole)

	var flag := Polygon2D.new()
	flag.polygon = PackedVector2Array([
		Vector2(0, -4.2 * Units.PPM),
		Vector2(1.5 * Units.PPM, -3.8 * Units.PPM),
		Vector2(0, -3.2 * Units.PPM),
	])
	flag.color = color
	area.add_child(flag)
	area.z_index = 3
	add_child(area)
	return area

func _build_finish_banner() -> void:
	pass

func surface_at_world(point: Vector2) -> SurfaceProfile:
	for entry: Dictionary in _obstacles:
		var rect: Rect2 = entry["rect"]
		if rect.has_point(point):
			var sid: String = String(entry["surface"])
			if surfaces.has(sid):
				return surfaces[sid] as SurfaceProfile
	var x_m: float = point.x / Units.PPM
	return _surface(x_m)

func height_at_world(x_px: float) -> float:
	var x_m: float = x_px / Units.PPM
	return -elevation_m(clampf(x_m, 0.0, stage.length_m)) * Units.PPM

func start_transform() -> Transform2D:
	var x: float = _start_x
	var y: float = -elevation_m(x) * Units.PPM
	var ahead: float = -elevation_m(x + 1.0) * Units.PPM
	var angle: float = atan2(ahead - y, Units.PPM)
	return Transform2D(angle, Vector2(x * Units.PPM, y - 0.9 * Units.PPM))

func finish_x_px() -> float:
	return _finish_x * Units.PPM

func checkpoint_count() -> int:
	return _checkpoint_nodes.size()

func checkpoint_position(index: int) -> Vector2:
	if index < 0 or index >= _checkpoint_nodes.size():
		return Vector2(finish_x_px(), height_at_world(finish_x_px()))
	return _checkpoint_nodes[index].global_position

func finish_position() -> Vector2:
	return Vector2(finish_x_px(), height_at_world(finish_x_px()))
