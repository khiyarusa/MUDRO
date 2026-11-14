class_name ViewportScreenshot
extends RefCounted
## Saves what the renderer actually produced. Used by the documentation harness and
## by the Android verification pass; never used to fake a screenshot.

static func shot(viewport: Viewport, dir: String, name: String) -> bool:
	if viewport == null:
		print("SCREENSHOT: no viewport for ", name)
		return false
	var tex: ViewportTexture = viewport.get_texture()
	if tex == null:
		print("SCREENSHOT: no texture for ", name)
		return false
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		print("SCREENSHOT: empty image for ", name)
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path: String = dir.path_join(name + ".png")
	var err: int = img.save_png(path)
	if err != OK:
		print("SCREENSHOT: save failed for ", name, " err=", err)
		return false
	print("SHOT %s -> %s (%dx%d)" % [name, path, img.get_width(), img.get_height()])
	return true
