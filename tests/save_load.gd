extends SceneTree
## Prova di salvataggio e caricamento (sul finto Firebase): gioca qualche turno, salva, ricarica dal
## codice e controlla che la partita ripresa sia identica (impronta) e prosegua.

var ai := InfAI.new()

func _init() -> void:
	_run()

func _wait(s: float) -> void:
	await create_timer(s).timeout

func _play_until(g, turno: int) -> void:
	while g.engine.turno < turno or g.pending.is_empty():
		await process_frame
		if g.engine.fase == "fine":
			return
		if not g.pending.is_empty():
			g._submit(ai.decide(g.engine, g.pending["side"], g.pending))

func _run() -> void:
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await _wait(0.5)
	var seats := [{"name": "Io", "ai": false}, {"name": "", "ai": true, "level": 1}]
	main.start_game({"scen": "B", "seats": seats, "ai_delay": 0.0, "anim": 0.0, "seed": 77})
	var g = main.current
	await _play_until(g, 3)
	var fp1: String = g.engine.impronta()
	await g._save_game()
	var code: String = g.save_code
	print("INFTEST salvata ", code, " ", fp1)
	main.show_menu()
	await _wait(0.3)
	var menu = main.current
	menu._load_panel()
	menu.on_code.text = code
	await menu._do_load()
	var g2 = main.current
	while g2.pending.is_empty():
		await process_frame
	print("INFTEST ripresa ", g2.engine.impronta(), " ", "OK" if g2.engine.impronta() == fp1 else "DIVERSA")
	await _play_until(g2, 5)
	print("INFTEST prosegue fino al turno ", g2.engine.turno)
	quit()
