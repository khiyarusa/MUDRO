extends SceneTree
## Headless SVG validator + rasteriser for the MUDRO art pipeline.
##
## Usage:
##   godot --headless --path <project> --script res://tools/validate_svg.gd -- \
##       res://assets/ui/icons/gear_up.svg res://assets/vehicles/.../body.svg
##
## For every SVG it prints "OK <path> <w>x<h>" and writes a PNG preview to
## res://local-builds/previews/<name>.png so the artwork can be visually reviewed.
## Exit code = number of failures.

const PREVIEW_DIR := "res://local-builds/previews"

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: --script res://tools/validate_svg.gd -- <svg paths...>")
		quit(2)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PREVIEW_DIR))
	var failures: int = 0
	for path: String in args:
		var svg_path: String = path if path.begins_with("res://") else ProjectSettings.localize_path(path)
		if not FileAccess.file_exists(svg_path):
			printerr("MISSING %s" % svg_path)
			failures += 1
			continue
		var text: String = FileAccess.get_file_as_string(svg_path)
		var img := Image.new()
		var err: int = img.load_svg_from_string(text, 1.0)
		if err != OK or img.is_empty():
			printerr("INVALID %s (error %d)" % [svg_path, err])
			failures += 1
			continue
		var preview_name: String = svg_path.get_file().get_basename() + ".png"
		var preview_path: String = PREVIEW_DIR.path_join(preview_name)
		img.save_png(preview_path)
		print("OK %s %dx%d -> %s" % [svg_path, img.get_width(), img.get_height(), preview_path])
	quit(failures)
