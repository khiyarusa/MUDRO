extends SceneTree
## Diagnostic: where do user:// writes land, and can we write there?

func _initialize() -> void:
	print("user_data_dir: ", OS.get_user_data_dir())
	print("globalized user://: ", ProjectSettings.globalize_path("user://"))
	var f := FileAccess.open("user://_probe.txt", FileAccess.WRITE)
	if f == null:
		printerr("cannot open user:// for writing, error ", FileAccess.get_open_error())
		quit(1)
		return
	f.store_string("ok")
	f.close()
	print("wrote: ", ProjectSettings.globalize_path("user://_probe.txt"))
	print("exists: ", FileAccess.file_exists("user://_probe.txt"))
	quit(0)
