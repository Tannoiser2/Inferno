extends SceneTree
## Partite fra due IA, senza grafica: godot --headless --path . -s tests/sim.gd -- <scenario> <partite> <livello>
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var scen := args[0] if args.size() > 0 else "F"
	var n := int(args[1]) if args.size() > 1 else 1
	var lv := int(args[2]) if args.size() > 2 else 1
	var vinte := [0, 0, 0]
	for i in n:
		var e := InfEngine.new()
		e.headless = true
		root.add_child(e)
		e.setup({"scen": scen, "seed": int(args[3]) if args.size() > 3 else 1000 + i, "ai_delay": 0.0, "anim": 0.0,
			"seats": [{"name": "Guelfi", "ai": true, "level": lv}, {"name": "Ghibellini", "ai": true, "level": lv}]})
		var t0 := Time.get_ticks_msec()
		await e.run()
		var r: Dictionary = e.result
		var v: int = int(r.get("vince", -1))
		vinte[v if v >= 0 else 2] += 1
		print("partita %d: turno %d, %s (decisioni %d, %d ms)" % [i, e.turno, r.get("motivo", "?"), e.record.size(), Time.get_ticks_msec() - t0])
		if n == 1:
			for t in e.log_lines:
				print(t)
		e.queue_free()
	print("Guelfi %d, Ghibellini %d, pari %d" % vinte)
	quit()
