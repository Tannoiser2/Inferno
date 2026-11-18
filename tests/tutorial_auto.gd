extends SceneTree
## Gioca da solo un tutorial (campagna o battaglia): sfoglia le lezioni, segue il consiglio del tutor e
## salva una schermata per ogni lezione e per ogni tipo di decisione.
## Argomenti: cartella, "campagna"|"battaglia", larghezza, altezza.
var visti := {}

func _init() -> void:
	_run()

func _bottoni(n: Node, out: Array) -> void:
	if n is Button and n.is_visible_in_tree():
		out.append(n)
	for c in n.get_children():
		_bottoni(c, out)

func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var dir: String = a[0] if a.size() > 0 else "/tmp/tut"
	var modo: String = a[1] if a.size() > 1 else "campagna"
	var w := int(a[2]) if a.size() > 2 else 1920
	var h := int(a[3]) if a.size() > 3 else 1080
	DirAccess.make_dir_recursive_absolute(dir)
	root.size = Vector2i(w, h)
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	var cfg: Dictionary = Tutorial.config_campagna() if modo == "campagna" else Tutorial.config_battaglia()
	cfg["ai_delay"] = 0.05
	cfg["anim"] = 3.0
	main.start_game(cfg)
	var g = main.current
	var n := 0
	var t0 := Time.get_ticks_msec()
	var lezioni := 0
	while Time.get_ticks_msec() - t0 < 500000:
		await create_timer(0.15).timeout
		if g._lezione_aperta:
			var bs := []
			_bottoni(g.popup_layer, bs)
			for b in bs:
				if b.text in ["Avanti", "Ho capito"]:
					var titolo := ""
					await create_timer(0.3).timeout
					root.get_viewport().get_texture().get_image().save_png("%s/l%02d.png" % [dir, lezioni])
					lezioni += 1
					b.pressed.emit()
					break
			continue
		if g.engine.over:
			await create_timer(1.0).timeout
			root.get_viewport().get_texture().get_image().save_png("%s/zz_fine.png" % dir)
			break
		var req: Dictionary = g.pending
		if req.is_empty():
			continue
		var k: String = req.get("k", req.get("type", ""))
		if not visti.has(k):
			visti[k] = true
			await create_timer(0.4).timeout
			root.get_viewport().get_texture().get_image().save_png("%s/d%02d_%s.png" % [dir, n, k])
			n += 1
		if req.get("type", "") == "piano":
			for c in g.popup_layer.get_children():
				c.queue_free()
		g._submit(g.tutor_ai.decide(g.engine, req["side"], req))
	print("INFTEST tutorial %s: lezioni %d, decisioni %s, fine %s %s" % [modo, lezioni, visti.keys(), g.engine.over, g.engine.result.get("motivo", "")])
	quit()
