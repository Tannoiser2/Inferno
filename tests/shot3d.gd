extends SceneTree
func _init() -> void:
	_run()
func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.start_game({"scen": "D", "seats": [{"name": "A", "ai": true}, {"name": "B", "ai": true}], "ai_delay": 0.4, "anim": 1.0, "view3d": true, "seed": 3})
	var g = main.current
	await create_timer(6.0).timeout
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/s3d_a.png")
	g.mappa3d.focus(Vector2(3300, 2100))
	await create_timer(1.0).timeout
	img = root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/s3d_b.png")
	g.engine.abort = true
	quit()
