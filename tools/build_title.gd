extends SceneTree
## Generator: res://scenes/title.tscn (start page; the level is instanced at runtime).

func _initialize() -> void:
	var root := Node3D.new()
	root.name = "Title"
	root.set_script(load("res://scripts/ui/title_screen.gd"))
	var err := SceneUtil.save(root, "res://scenes/title.tscn")
	root.free()
	print("build_title: saved (err=%d)" % err)
	quit(err)
