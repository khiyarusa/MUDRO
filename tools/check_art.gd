extends SceneTree
## Checks that every art resource imports into a usable Texture2D.

func _initialize() -> void:
	var dirs: Array[String] = [
		"res://assets/environments/canyon", "res://assets/environments/pine",
		"res://assets/environments/quarry", "res://assets/environments/common",
		"res://assets/vehicles/rocky_buggy", "res://assets/vehicles/ranger_4x4",
		"res://assets/vehicles/dune_pickup", "res://assets/vehicles/titan_offroad",
		"res://assets/ui/icons",
	]
	var missing: int = 0
	var ok: int = 0
	for d: String in dirs:
		var dir := DirAccess.open(d)
		if dir == null:
			print("NO DIR ", d)
			continue
		dir.list_dir_begin()
		var f: String = dir.get_next()
		while f != "":
			if f.ends_with(".svg"):
				var path: String = d.path_join(f)
				if not ResourceLoader.exists(path):
					print("NOT IMPORTED ", path)
					missing += 1
				else:
					var res: Resource = load(path)
					if res is Texture2D:
						var t := res as Texture2D
						print("OK %-52s %dx%d" % [path, t.get_width(), t.get_height()])
						ok += 1
					else:
						print("NOT A TEXTURE ", path)
						missing += 1
			f = dir.get_next()
		dir.list_dir_end()
	print("SUMMARY ok=%d missing=%d" % [ok, missing])
	quit(0 if missing == 0 else 1)
