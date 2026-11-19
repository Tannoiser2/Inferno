extends SceneTree
## Confronto fra l'IA con i consigli strategici e la prima versione: metà partite per parte.
## godot --headless --path . -s tests/confronto_ia.gd -- <scenario> <partite> <livello>
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var scen: String = a[0] if a.size() > 0 else "F"
	var n := int(a[1]) if a.size() > 1 else 4
	var lv := int(a[2]) if a.size() > 2 else 2
	var sim := a.size() > 4 and a[4] == "sim"
	var cons: Array = (Array(a[3].split(",")) if a[3] != "tutti" else []) if a.size() > 3 else InfAI.CONSIGLI_SCELTI.duplicate()
	var nuova := 0.0
	var vecchia := 0.0
	var diff := 0.0
	for i in n:
		var nuova_lato := i % 2
		var e := InfEngine.new()
		e.headless = true
		root.add_child(e)
		var seats := [{"name": "G", "ai": true, "level": lv, "strategia": nuova_lato == 0 or sim, "consigli": cons, "simula": sim and nuova_lato == 0}, {"name": "H", "ai": true, "level": lv, "strategia": nuova_lato == 1 or sim, "consigli": cons, "simula": sim and nuova_lato == 1}]
		e.setup({"scen": scen, "seed": 3000 + i / 2, "ai_delay": 0.0, "anim": 0.0, "seats": seats})
		await e.run()
		var v: int = int(e.result.get("vince", -1))
		if v == nuova_lato:
			nuova += 1
		elif v == 1 - nuova_lato:
			vecchia += 1
		else:
			nuova += 0.5
			vecchia += 0.5
		diff += e.pv(nuova_lato) - e.pv(1 - nuova_lato)
		e.queue_free()
	print("CONFRONTO %s %s%s: nuova %.1f, vecchia %.1f, scarto medio PV %+.2f" % [scen, cons, " (simulazione)" if sim else "", nuova, vecchia, diff / n])
	quit()
