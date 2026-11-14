extends SceneTree
## Renders SVG assets to PNG so the geometry can be inspected as pixels.
## Uses Godot's own SVG rasteriser, i.e. the same one that will draw them
## in game.  Run:
##   godot --headless --path <project> --script res://tools/asset_processing/render_preview.gd -- <file.svg> <file.svg> ...

func _initialize() -> void:
	var out_dir := "res://.preview"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var args := OS.get_cmdline_user_args()
	var ok := 0
	var fail := 0
	for p in args:
		var f := FileAccess.open(p, FileAccess.READ)
		if f == null:
			printerr("OPEN-FAIL ", p)
			fail += 1
			continue
		var txt := f.get_as_text()
		f.close()
		var img := Image.new()
		var err := img.load_svg_from_string(txt, 1.0)
		if err != OK:
			printerr("SVG-FAIL ", p)
			fail += 1
			continue
		var name: String = p.get_base_dir().get_file() + "_" + p.get_file().get_basename()
		var dst := out_dir.path_join(name + ".png")
		img.save_png(dst)
		print("OK %s  %dx%d" % [name, img.get_width(), img.get_height()])
		ok += 1
	print("RENDERED ok=%d fail=%d" % [ok, fail])
	quit(0 if fail == 0 else 1)
