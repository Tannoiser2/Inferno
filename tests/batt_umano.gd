extends SceneTree
## Prova delle scelte di battaglia di un giocatore umano: i Guelfi sono «umani» che rispondono a caso
## (anche «decidi tu»), i Ghibellini sono l'IA. Conta le scelte fatte per tipo e controlla che la partita finisca.
## godot --headless --path . -s tests/batt_umano.gd -- <scenario> <partite>
var conta := {}
var rng := RandomNumberGenerator.new()

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var scen: String = a[0] if a.size() > 0 else "F"
	var n := int(a[1]) if a.size() > 1 else 3
	rng.seed = 42
	for i in n:
		var e := InfEngine.new()
		e.headless = true
		root.add_child(e)
		e.setup({"scen": scen, "seed": 500 + i, "ai_delay": 0.0, "anim": 0.0,
			"seats": [{"name": "Umano", "ai": false}, {"name": "IA", "ai": true, "level": 1}]})
		e.decision_requested.connect(func(req):
			var r
			var k: String = req.get("k", req.get("type", ""))
			conta[k] = int(conta.get(k, 0)) + 1
			if req.get("type", "") == "scelta" and k in ["schiera", "avanza", "al_centro", "aggiungi", "fianco", "assorbe", "colpo", "sortita_esce"]:
				var o: Array = req["opzioni"]
				r = str(o[rng.randi() % o.size()]["id"])
			else:
				r = e.ais[req["side"]].decide(e, req["side"], req)
			e.provide_decision.call_deferred(r))
		await e.run()
		var lines := 0
		for t in e.log_lines:
			if "passano a" in t or "alle spalle" in t or "esce da" in t:
				lines += 1
		print("partita %d: turno %d, %s; righe speciali %d" % [i, e.turno, e.result.get("motivo", "?"), lines])
		e.queue_free()
	print("scelte: ", conta)
	quit()
