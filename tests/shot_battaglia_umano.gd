extends SceneTree
## Schermate delle scelte di battaglia di un giocatore umano (Guelfi): fuori dalla battaglia risponde l'IA,
## nella battaglia si fotografa ogni scelta e poi si risponde con il consiglio.
## Argomenti: cartella, scenario, larghezza, altezza, seme.
func _init() -> void:
	_run()

func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var dir: String = a[0] if a.size() > 0 else "/tmp/battu"
	var scen: String = a[1] if a.size() > 1 else "F"
	var w := int(a[2]) if a.size() > 2 else 1920
	var h := int(a[3]) if a.size() > 3 else 1080
	var seme := int(a[4]) if a.size() > 4 else 23
	DirAccess.make_dir_recursive_absolute(dir)
	root.size = Vector2i(w, h)
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.start_game({"scen": scen, "seats": [{"name": "Io", "ai": false}, {"name": "B", "ai": true, "level": 1}], "ai_delay": 0.0, "anim": 0.0, "seed": seme})
	var g = main.current
	var ai := InfAI.new()
	g.engine.fx.connect(func(k, _d):
		if k == "battaglia_inizio":
			g.engine.anim = 1.0
			g.engine.ai_delay = 0.2)
	var n := 0
	var t0 := Time.get_ticks_msec()
	while n < 14 and Time.get_ticks_msec() - t0 < 400000 and not g.engine.over:
		await process_frame
		var req: Dictionary = g.pending
		if req.is_empty():
			continue
		if g.engine.battaglia.is_empty() or req.get("type", "") != "scelta":
			g._submit(ai.decide(g.engine, req["side"], req))
			continue
		await create_timer(1.2).timeout
		root.get_viewport().get_texture().get_image().save_png("%s/u%02d_%s.png" % [dir, n, req.get("k", "")])
		print("INFTEST scelta ", req.get("k", ""), ": ", req.get("titolo", ""))
		n += 1
		g._submit(ai.decide(g.engine, req["side"], req))
	g.engine.abort = true
	quit()
