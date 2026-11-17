extends SceneTree
## Fotografie dell'interfaccia (serve un display, anche virtuale: xvfb-run).
## Uso: xvfb-run -s "-screen 0 1920x1080x24" godot --path . -s tests/shot.gd -- <cartella> [scenario] [larghezza] [altezza] [3d] [max]
## La persona (Guelfi) lascia decidere all'IA; si fotografano le decisioni la prima volta che compaiono.

var out := "/tmp/shots"
var taken := {}

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var scen := args[1] if args.size() > 1 else "F"
	var w := int(args[2]) if args.size() > 2 else 1920
	var h := int(args[3]) if args.size() > 3 else 1080
	var v3 := args.size() > 4 and args[4] == "3d"
	var mx := int(args[5]) if args.size() > 5 else 40
	DirAccess.make_dir_recursive_absolute(out)
	_run(scen, w, h, v3, mx)


func _snap(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, name])
	print("foto ", name)


func _run(scen: String, w: int, h: int, v3: bool, mx: int) -> void:
	root.size = Vector2i(w, h)
	DisplayServer.window_set_size(Vector2i(w, h))
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.0).timeout
	await _snap("00_menu")
	main.start_game({"scen": scen, "seats": [{"name": "Stefano", "ai": false}, {"name": "Ghibellini (IA)", "ai": true, "level": 1}],
		"ai_delay": 0.0, "anim": 6.0, "view3d": v3, "seed": 11})
	var g = main.current
	await create_timer(1.5).timeout
	await _snap("01_inizio")
	var guard := 0
	var n := 0
	while guard < 3000 and n < mx:
		guard += 1
		if g.engine.over:
			break
		var req: Dictionary = g.pending
		if req.is_empty():
			await create_timer(0.05).timeout
			continue
		var k: String = req.get("k", req["type"])
		if not taken.has(k):
			taken[k] = true
			n += 1
			await create_timer(0.3).timeout
			await _snap("%02d_%s" % [taken.size() + 1, k])
		var r = g.engine.ais[0].decide(g.engine, 0, req)
		if req["type"] == "piano":
			for c in g.popup_layer.get_children():
				c.queue_free()
		g._submit(r)
		await create_timer(0.02).timeout
	g._scheda("firenze")
	await create_timer(0.4).timeout
	await _snap("90_scheda")
	for c in g.popup_layer.get_children():
		c.queue_free()
	g._carte()
	await create_timer(0.4).timeout
	await _snap("91_carte")
	for c in g.popup_layer.get_children():
		c.queue_free()
	g.view3d = true
	g._apply_view()
	await create_timer(1.5).timeout
	await _snap("92_3d")
	g.mappa3d.focus(Vector2(2300, 1700))
	await create_timer(1.0).timeout
	await _snap("93_3d_vicino")
	quit()
