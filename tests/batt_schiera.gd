extends SceneTree
## Battaglie preparate a mano per provare schieramento, aggiramento, assorbimento, colpi che passano
## e Sortita di soccorso. I Guelfi sono «umani» che rispondono a caso; i Ghibellini sono l'IA.
## Argomenti: numero di prove.  Con «vista» come secondo argomento apre la scena (per le schermate).
var conta := {}
var rng := RandomNumberGenerator.new()

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var n := int(a[0]) if a.size() > 0 else 20
	rng.seed = 7
	var guelfi := ["firenze", "arezzo", "lucca", "colle", "guido"]
	var ghib := ["siena", "pisa", "provenzano", "giordano", "astimberg", "santa_fiora"]
	for i in n:
		var e := InfEngine.new()
		e.headless = true
		root.add_child(e)
		e.setup({"scen": "F", "seed": 900 + i, "ai_delay": 0.0, "anim": 0.0,
			"seats": [{"name": "Umano", "ai": false}, {"name": "IA", "ai": true, "level": 1}]})
		e.decision_requested.connect(func(req):
			var k: String = req.get("k", "")
			conta[k] = int(conta.get(k, 0)) + 1
			var o: Array = req.get("opzioni", [])
			var r = str(o[rng.randi() % o.size()]["id"]) if not o.is_empty() else e.ais[0].decide(e, 0, req)
			e.provide_decision.call_deferred(r))
		var l := "poggio_bonizio" if i % 2 == 0 else "monteriggioni"
		var ng := 1 + rng.randi() % 4
		var nh := 1 + rng.randi() % 4
		var gs := []
		var hs := []
		for id in guelfi.slice(0, ng):
			gs.append(id)
		for id in ghib.slice(0, nh):
			hs.append(id)
		for id in gs + hs:
			if not e.L.has(id):
				continue
			e.L[id]["stato"] = "mappa"
			e.L[id]["loc"] = l
			e.L[id]["dentro"] = false
			e.L[id]["aggira"] = false
			if e.L[id]["forze"].is_empty():
				e.L[id]["forze"] = {"cav": 2, "uia": 1, "mil": 2}
		var soccorso := []
		# metà delle prove: una Sortita di soccorso (un Ghibellino assediato dentro)
		if i % 3 == 2 and e.L.has("santa_fiora"):
			var sid := "santa_fiora"
			e.L[sid]["stato"] = "mappa"
			e.L[sid]["loc"] = l
			e.L[sid]["dentro"] = true
			if e.L[sid]["forze"].is_empty():
				e.L[sid]["forze"] = {"cav": 2, "arm": 2}
			e.loc[l]["assedio"] = 2
			e.loc[l]["assedio_l"] = 0
			soccorso = [sid]
			hs.erase(sid)
		var att := 1 if i % 2 == 0 else 0
		var attivo: String = (hs if att == 1 else gs)[0]
		if (hs if att == 1 else gs).is_empty():
			e.queue_free()
			continue
		var vince = await e.battaglia_campale(l, att, attivo, "", soccorso if att == 1 else [])
		var spec := 0
		for t in e.log_lines:
			if "passano a" in t or "alle spalle" in t or "esce da" in t:
				spec += 1
		print("prova %d a %s: %d contro %d%s, vincono i %s, righe speciali %d" % [i, l, ng, nh, " con sortita" if not soccorso.is_empty() and att == 1 else "", ["Guelfi", "Ghibellini"][vince], spec])
		e.queue_free()
	print("scelte: ", conta)
	quit()
