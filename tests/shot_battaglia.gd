extends SceneTree
## Schermate della battaglia 3D: partita IA contro IA finché scoppia una battaglia, poi una serie di fotogrammi.
## Argomenti: cartella, scenario, larghezza, altezza, seme.
func _init() -> void:
	_run()

func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var dir: String = a[0] if a.size() > 0 else "/tmp/batt"
	var scen: String = a[1] if a.size() > 1 else "D"
	var w := int(a[2]) if a.size() > 2 else 1920
	var h := int(a[3]) if a.size() > 3 else 1080
	var seme := int(a[4]) if a.size() > 4 else 5
	DirAccess.make_dir_recursive_absolute(dir)
	root.size = Vector2i(w, h)
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.start_game({"scen": scen, "seats": [{"name": "A", "ai": true, "level": 1}, {"name": "B", "ai": true, "level": 1}], "ai_delay": 0.0, "anim": 0.0, "seed": seme})
	var g = main.current
	g.engine.fx.connect(func(k, _d):
		if k == "battaglia_inizio":
			g.engine.anim = 2.5
			g.engine.ai_delay = 0.15)
	var t0 := Time.get_ticks_msec()
	while g.engine.battaglia.is_empty():
		await process_frame
		if Time.get_ticks_msec() - t0 > 240000 or g.engine.over:
			print("INFTEST nessuna battaglia")
			quit(1)
			return
	print("INFTEST battaglia ", g.engine.battaglia["tipo"], " a ", g.engine.battaglia["loc"])
	await create_timer(1.0).timeout
	var bt = g.batt3d
	print("INFTEST vp ", bt.vp.size, " cam ", bt.cam.current, " ", bt.cam.global_transform.origin, " size ", bt.size, " figli ", bt.mondo.get_child_count(), " rep ", bt.reparti.size(), " vis ", bt.is_visible_in_tree(), " upd ", bt.vp.render_target_update_mode)
	for i in 40:
		await create_timer(0.35).timeout
		root.get_viewport().get_texture().get_image().save_png("%s/b%02d.png" % [dir, i])
		print("INFTEST pannello ", i, " ", g.battle_panel.visible)
		if g.engine.battaglia.is_empty():
			break
	g.engine.abort = true
	quit()
