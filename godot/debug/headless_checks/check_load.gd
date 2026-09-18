## Loads every scene, resource and script of the game to catch parse and reference errors.
extends HeadlessCheck


## Folders that are not part of the running game: editor-only import scripts.
const SKIP_DIRS: PackedStringArray = ["res://.godot", "res://asset_import"]
const EXTENSIONS: PackedStringArray = ["gd", "tscn", "tres"]


func run() -> void:
	var paths: PackedStringArray = []
	_collect("res://", paths)
	var loaded := 0
	for path in paths:
		var resource := ResourceLoader.load(path)
		if resource == null:
			expect(false, "Could not load %s" % path)
			continue
		if resource is Script and not (resource as Script).can_instantiate():
			expect(false, "Script does not compile: %s" % path)
			continue
		loaded += 1
	note("%d resources loaded" % loaded)
	await get_tree().process_frame


func _collect(dir_path: String, paths: PackedStringArray) -> void:
	if dir_path.trim_suffix("/") in SKIP_DIRS:
		return
	var dir := DirAccess.open(dir_path)
	if not dir:
		return
	for file in dir.get_files():
		var file_path := dir_path.path_join(file)
		# Exported builds list "file.gd.remap" instead of the source file.
		file_path = file_path.trim_suffix(".remap")
		if file_path.get_extension() in EXTENSIONS:
			paths.append(file_path)
	for sub in dir.get_directories():
		_collect(dir_path.path_join(sub), paths)
