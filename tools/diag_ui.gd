extends Node
## Run-only diagnostic: instantiate the race and print the real control geometry
## geometry so a layout bug can be seen without guessing.
##   godot --path . --resolution 1280x720 res://tools/diag_ui.tscn --uidiag

func _ready() -> void:
	await get_tree().process_frame
	GameSession.start_stage("canyon_01", "career")
	var packed: PackedScene = load("res://scenes/race/race.tscn") as PackedScene
	var race: Node = packed.instantiate()
	add_child(race)
	for i: int in range(10):
		await get_tree().process_frame
	var controls: TouchControls = race.get("controls") as TouchControls
	if controls == null:
		print("[diag] no controls")
		get_tree().quit(1)
		return
	print("[diag] viewport rect = %s" % str(get_viewport().get_visible_rect()))
	print("[diag] controls size = %s  pos = %s  scale = %s" % [str(controls.size), str(controls.position), str(controls.scale)])
	for id: String in controls.widgets.keys():
		var w: TouchWidget = controls.widgets[id] as TouchWidget
		var art: TextureRect = w.get_child(0) as TextureRect
		print("[diag] %-10s pos=%s size=%s art_size=%s art_vis=%s tex=%s global=%s" % [id, str(w.position), str(w.size), str(art.size), str(art.visible), str(art.texture if art != null else null), str(w.get_global_rect())])
	if controls.panel != null:
		print("[diag] panel pos=%s size=%s visible=%s" % [str(controls.panel.position), str(controls.panel.size), str(controls.panel.visible)])
	var marker := ColorRect.new()
	marker.color = Color(1, 0, 0, 1)
	marker.position = Vector2(100, 100)
	marker.size = Vector2(300, 120)
	controls.add_child(marker)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("res://local-builds/screenshots-v2/diag_layer.png")
		print("[diag] saved %dx%d" % [img.get_width(), img.get_height()])
	get_tree().quit(0)
