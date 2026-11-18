extends SceneTree
## Prova del gioco online: due istanze (chi crea la stanza guida i Guelfi, l'amico i Ghibellini)
## giocano lo scenario A sul finto Firebase (tests/firebase_mock.py), con le decisioni prese dall'IA.
## INF_ROLE=host|guest, INF_CODEFILE=file per il codice della stanza.
## Alla fine ognuno stampa l'impronta della partita: devono coincidere.

var main
var t0 := 0
var ai := InfAI.new()

func _init() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	t0 = Time.get_ticks_msec()
	_run()

func _wait(s: float) -> void:
	await create_timer(s).timeout

func _run() -> void:
	await _wait(0.5)
	var role := OS.get_environment("INF_ROLE")
	var cf := OS.get_environment("INF_CODEFILE")
	var menu = main.current
	menu.scen = OS.get_environment("INF_SCEN") if OS.get_environment("INF_SCEN") != "" else "A"
	menu.modes = [0, 0]
	menu._online_panel()
	menu.on_name.text = "Host" if role == "host" else "Ospite"
	if role == "host":
		await menu._online_create()
		var code: String = main.lobby.get("code", "")
		print("INFTEST stanza ", code)
		var f := FileAccess.open(cf, FileAccess.WRITE)
		f.store_string(code)
		f.close()
		while true:
			var room: Dictionary = await main.net.room(code)
			if Net._as_dict(room.get("seats", {})).size() >= 2:
				break
			await _wait(0.5)
		await menu._online_start()
	else:
		var code := ""
		while code == "":
			if FileAccess.file_exists(cf):
				code = FileAccess.get_file_as_string(cf).strip_edges()
			await _wait(0.3)
		menu.on_code.text = code
		await menu._online_join()
	var ultimo := 0
	while true:
		await process_frame
		if Time.get_ticks_msec() - ultimo > 20000 and main.current != null and "engine" in main.current and main.current.engine != null:
			ultimo = Time.get_ticks_msec()
			print("INFTEST avanzamento turno ", main.current.engine.turno, " decisioni ", main.current.engine.record.size(), " in attesa ", main.current.pending.get("k", main.current.pending.get("type", "")))
		if Time.get_ticks_msec() - t0 > 900000:
			print("INFTEST tempo scaduto")
			quit(2)
			return
		var view = main.current
		if view == null or not ("engine" in view) or view.engine == null:
			continue
		var e: InfEngine = view.engine
		e.ai_delay = 0.0
		e.anim = 0.0
		var req: Dictionary = view.pending
		if not req.is_empty() and view.online_mine():
			view._submit(ai.decide(e, req["side"], req))
		if e.fase == "fine":
			await _wait(0.5)
			print("INFTEST impronta ", e.impronta(), " | ", e.pv_testo(0), " ", e.pv_testo(1))
			quit(0)
			return
