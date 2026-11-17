extends Control
## Schermata di gioco: in alto il calendario con i turni, i Signori pronti, il Servizio e la Vittoria;
## ai lati le due fazioni con le loro armate; al centro la mappa (2D o 3D); in basso la barra delle
## decisioni e il diario. Le scelte si fanno con i pulsanti o toccando la mappa.

const D = preload("res://scripts/data/inf_data.gd")
const SIDE_W := 330.0
const CAL_H := 132.0
const BOT_H := 236.0

var main
var config := {}
var engine: InfEngine
var mappa2d
var mappa3d
var view3d := false
var cal: Control
var lati_box := []               # i due VBox delle fazioni
var center: Control
var prompt: PanelContainer
var prompt_title: Label
var prompt_text: Label
var prompt_list: VBoxContainer
var prompt_scroll: ScrollContainer
var log_box: RichTextLabel
var popup_layer: Control
var toast_box: VBoxContainer
var wait_lbl: Label
var fase_lbl: Label
var battle_panel: PanelContainer
var battle_box: VBoxContainer
var banner: Label
var pending := {}
var _loc_opts := {}
var _dirty := true
var save_code := ""
var humans: Array = []
var _ultimo_lato := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	engine = InfEngine.new()
	add_child(engine)
	if not config.has("seed"):
		config["seed"] = 1 + randi() % 2000000000
	engine.setup(config)
	for s in 2:
		if not config["seats"][s].get("ai", false):
			humans.append(s)
	if config.has("online"):
		engine.online = config["online"]
		add_child(engine.online)
		engine.online.view = self
		humans = [engine.online.seat]
		engine.online.heartbeat_loop()
	_build()
	engine.changed.connect(func(): _dirty = true)
	engine.log_added.connect(_on_log)
	engine.decision_requested.connect(_on_decision)
	engine.fx.connect(_on_fx)
	engine.game_ended.connect(_on_end)
	view3d = bool(config.get("view3d", false))
	_apply_view()
	_fit_iniziale.call_deferred()
	engine.run.call_deferred()


func _fit_iniziale() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	mappa2d.fit()


func _exit_tree() -> void:
	if engine != null:
		engine.abort = true
		engine.provide_decision(null)


# ================================================================ struttura

func _build() -> void:
	# calendario
	cal = Calendario.new()
	cal.e = engine
	cal.anchor_right = 1.0
	cal.offset_bottom = CAL_H
	add_child(cal)
	# colonne delle fazioni
	for s in 2:
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", _side_style(s))
		if s == 0:
			pc.anchor_bottom = 1.0
			pc.offset_top = CAL_H
			pc.offset_right = SIDE_W
			pc.offset_bottom = -BOT_H
		else:
			pc.anchor_left = 1.0
			pc.anchor_right = 1.0
			pc.anchor_bottom = 1.0
			pc.offset_left = -SIDE_W
			pc.offset_top = CAL_H
			pc.offset_bottom = -BOT_H
		add_child(pc)
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		pc.add_child(sc)
		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.custom_minimum_size.x = SIDE_W - 30
		vb.add_theme_constant_override("separation", 6)
		sc.add_child(vb)
		lati_box.append(vb)
	# mappa
	center = Control.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.offset_left = SIDE_W
	center.offset_right = -SIDE_W
	center.offset_top = CAL_H
	center.offset_bottom = -BOT_H
	center.clip_contents = true
	add_child(center)
	mappa2d = preload("res://scripts/ui/map_2d.gd").new()
	mappa2d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(mappa2d)
	mappa2d.setup(engine)
	mappa2d.spot_pressed.connect(_on_spot)
	mappa2d.lord_pressed.connect(_scheda)
	# comandi della vista
	var vb := HBoxContainer.new()
	vb.position = Vector2(10, 8)
	vb.add_theme_constant_override("separation", 6)
	center.add_child(vb)
	for it in [["Menu", _ask_menu], ["Carte", _carte], ["Tutta", _view_all], ["+", func(): _zoom(1.25)], ["-", func(): _zoom(0.8)],
			["Ruota", func(): _rotate(PI / 8)], ["2D / 3D", _toggle_view]]:
		var b := UI.button(it[0], 0, 48, 19)
		if it[0].length() <= 1:
			b.custom_minimum_size.x = 48
		b.pressed.connect(it[1])
		vb.add_child(b)
	fase_lbl = UI.label("", 22, UI.ORO_L, UI.font_head)
	fase_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	fase_lbl.add_theme_constant_override("shadow_offset_x", 2)
	fase_lbl.add_theme_constant_override("shadow_offset_y", 2)
	# sotto i comandi, su una fascia scura: non si sovrappone ai pulsanti nemmeno sugli schermi stretti
	var fp := PanelContainer.new()
	var fsb := UI.panel_style(Color(0.08, 0.05, 0.03, 0.78), UI.ORO.darkened(0.3), 1, 6)
	fsb.content_margin_left = 12
	fsb.content_margin_right = 12
	fsb.content_margin_top = 2
	fsb.content_margin_bottom = 4
	fp.add_theme_stylebox_override("panel", fsb)
	fp.position = Vector2(10, 64)
	fp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fp.add_child(fase_lbl)
	center.add_child(fp)
	wait_lbl = UI.label("", 22, UI.PERG, UI.font_head)
	wait_lbl.anchor_top = 1.0
	wait_lbl.anchor_bottom = 1.0
	wait_lbl.offset_top = -44
	wait_lbl.offset_left = 14
	wait_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	center.add_child(wait_lbl)
	banner = UI.title("", 76, UI.ORO_L)
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.modulate.a = 0.0
	center.add_child(banner)
	# barra in basso: decisione e diario
	var bot := HBoxContainer.new()
	bot.anchor_top = 1.0
	bot.anchor_right = 1.0
	bot.anchor_bottom = 1.0
	bot.offset_top = -BOT_H
	bot.add_theme_constant_override("separation", 0)
	add_child(bot)
	prompt = PanelContainer.new()
	prompt.add_theme_stylebox_override("panel", _prompt_style(-1))
	prompt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt.size_flags_stretch_ratio = 2.2
	bot.add_child(prompt)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 4)
	prompt.add_child(pv)
	prompt_title = UI.heading("", 24)
	pv.add_child(prompt_title)
	prompt_text = UI.label("", 18, UI.PERG, UI.font_body)
	prompt_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_text.custom_minimum_size.x = 500
	pv.add_child(prompt_text)
	prompt_scroll = ScrollContainer.new()
	prompt_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	prompt_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pv.add_child(prompt_scroll)
	prompt_list = VBoxContainer.new()
	prompt_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_list.add_theme_constant_override("separation", 4)
	prompt_scroll.add_child(prompt_list)
	var lp := PanelContainer.new()
	lp.add_theme_stylebox_override("panel", UI.panel_style(Color("#1a120c"), Color("#6b4f2e"), 2, 0))
	lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot.add_child(lp)
	var lv := VBoxContainer.new()
	lp.add_child(lv)
	lv.add_child(UI.heading("Diario", 20, UI.PERG_D))
	log_box = RichTextLabel.new()
	log_box.scroll_following = true
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box.add_theme_font_size_override("normal_font_size", 17)
	log_box.add_theme_color_override("default_color", UI.PERG_D)
	lv.add_child(log_box)
	# battaglia
	battle_panel = PanelContainer.new()
	battle_panel.add_theme_stylebox_override("panel", UI.dark_style(10, 0.96))
	battle_panel.visible = false
	battle_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(battle_panel)
	battle_box = VBoxContainer.new()
	battle_box.add_theme_constant_override("separation", 6)
	battle_panel.add_child(battle_box)
	# messaggi e finestre
	toast_box = VBoxContainer.new()
	toast_box.anchor_left = 0.5
	toast_box.anchor_right = 0.5
	toast_box.offset_left = -300
	toast_box.offset_right = 300
	toast_box.offset_top = CAL_H + 64
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_box)
	popup_layer = Control.new()
	popup_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(popup_layer)
	_clear_prompt()


func _side_style(s: int) -> StyleBoxFlat:
	var sb := UI.panel_style(Color("#24180f"), D.COL_LATO[s].darkened(0.2), 3, 0)
	sb.set_content_margin_all(8)
	return sb


func _prompt_style(s: int) -> StyleBoxFlat:
	var sb := UI.panel_style(Color("#2a1d14"), UI.ORO if s < 0 else D.COL_LATO[s], 3, 0)
	sb.set_content_margin_all(10)
	return sb


func _apply_view() -> void:
	if view3d and mappa3d == null:
		mappa3d = preload("res://scripts/ui/map_3d.gd").new()
		mappa3d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.add_child(mappa3d)
		center.move_child(mappa3d, 1)
		mappa3d.setup(engine)
		mappa3d.spot_pressed.connect(_on_spot)
		mappa3d.lord_pressed.connect(_scheda)
	mappa2d.visible = not view3d
	if mappa3d != null:
		mappa3d.visible = view3d
		mappa3d.hot = mappa2d.hot
		mappa3d.refresh()


func _toggle_view() -> void:
	view3d = not view3d
	_apply_view()


func _view_all() -> void:
	if view3d:
		mappa3d.fit()
	else:
		mappa2d.fit()


func _zoom(f: float) -> void:
	if view3d:
		mappa3d.zoom_by(f)
	else:
		mappa2d.zoom_at(mappa2d.size * 0.5, f)


func _rotate(a: float) -> void:
	if view3d:
		mappa3d.rotate_by(a)
	else:
		mappa2d.rotate_by(a)


func _process(_dt: float) -> void:
	if _dirty:
		_dirty = false
		_refresh()


# ================================================================ aggiornamento

func _refresh() -> void:
	var e := engine
	cal.queue_redraw()
	mappa2d.queue_redraw()
	if mappa3d != null:
		mappa3d.refresh()
	var st: String = D.STAGIONE[e.turno] if e.turno <= 16 else "E"
	var t := "Turno %d, %s %s — %s" % [e.turno, D.MESI_BREVI[mini(e.turno, 16)], D.ANNI[mini(e.turno, 16)], D.NOME_STAGIONE[st]]
	match e.fase:
		"leva":
			t += " — Leva: %s" % e.passo
		"campagna":
			t += " — Campagna"
			if e.sig_attivo != "":
				t += ": %s" % e.nome(e.sig_attivo)
		"fine":
			t += " — Partita finita"
	fase_lbl.text = t
	fase_lbl.get_parent().reset_size.call_deferred()
	for s in 2:
		_lato_panel(s)
	_battaglia_refresh()


func _lato_panel(s: int) -> void:
	var e := engine
	var vb: VBoxContainer = lati_box[s]
	for c in vb.get_children():
		c.queue_free()
	var head := HBoxContainer.new()
	head.add_child(UI.icon_rect(UI.scudo("firenze" if s == 0 else "siena"), Vector2(34, 42)))
	var hl := UI.title(D.LATI[s], 34, D.COL_LATO[s].lightened(0.35))
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hl)
	var pvl := UI.label("%s PV" % e.pv_testo(s), 24, UI.ORO_L, UI.font_head)
	head.add_child(pvl)
	vb.add_child(head)
	var chi := UI.label(e.pname(s) + ("" if not e.players[s].get("ai", false) else ""), 17, UI.MUTED, UI.font_italic)
	vb.add_child(chi)
	# Signori sulla mappa
	for id in e.signori_mappa(s):
		vb.add_child(_riga_signore(id))
	# al calendario e fuori
	var cal_ids := []
	var out_ids := []
	for id in D.SIGNORI_LATO[s]:
		if e.L[id]["stato"] == "cal":
			cal_ids.append(id)
		elif e.L[id]["stato"] == "rimosso":
			out_ids.append(id)
	if not cal_ids.is_empty():
		vb.add_child(UI.label("Al calendario", 18, UI.PERG_D, UI.font_head))
		var fl := HFlowContainer.new()
		fl.add_theme_constant_override("h_separation", 6)
		for id in cal_ids:
			var b := Button.new()
			b.icon = UI.scudo(id)
			b.expand_icon = true
			b.custom_minimum_size = Vector2(140, 46)
			b.text = "%s %s" % [e.nome(id).split(" ")[0], ("pronto" if e.L[id]["cal"] <= e.turno else "t.%d" % e.L[id]["cal"])]
			b.add_theme_font_size_override("font_size", 16)
			b.tooltip_text = "%s: pronto per il Raduno dal turno %d." % [D.SIGNORI[id]["titolo"], e.L[id]["cal"]]
			var idc: String = id
			b.pressed.connect(func(): _scheda(idc))
			fl.add_child(b)
		vb.add_child(fl)
	if not out_ids.is_empty():
		var nomi := []
		for id in out_ids:
			nomi.append(e.nome(id))
		vb.add_child(UI.wrap(UI.label("Fuori gioco: " + ", ".join(nomi), 16, UI.MUTED, UI.font_italic), SIDE_W - 40))
	# carte e altro
	var info := []
	if not e.cap_lato[s].is_empty():
		var nomi := []
		for c in e.cap_lato[s]:
			nomi.append(D.CARTE[c]["cap"])
		info.append("Capacità: " + ", ".join(nomi))
	info.append("Eventi tenuti: %d" % e.tenute[s].size())
	info.append("Tradimenti nel mazzo: %d" % e.tradimento[s].size())
	var catt: int = e.catturati[s]["cav"] + e.catturati[s]["ritter"]
	if catt > 0:
		info.append("Cavalieri prigionieri: %d" % catt)
	if e.carroccio_preso[s]:
		info.append("Il Carroccio è stato catturato!")
	if e.fase == "campagna":
		info.append("Carte del piano rimaste: %d" % e.piano[s].size())
	vb.add_child(UI.wrap(UI.label("\n".join(info), 16, UI.PERG_D), SIDE_W - 40))


func _riga_signore(id: String) -> Control:
	var e := engine
	var s: int = e.lato(id)
	var pc := PanelContainer.new()
	var attivo: bool = e.sig_attivo == id and e.fase == "campagna"
	var sb := UI.panel_style(Color("#33241a") if not attivo else Color("#4a3418"), D.COL_LATO[s].darkened(0.1) if not attivo else UI.ORO_L, 2, 6)
	sb.set_content_margin_all(6)
	pc.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	pc.add_child(vb)
	var r1 := HBoxContainer.new()
	r1.add_child(UI.icon_rect(UI.scudo(id), Vector2(28, 34)))
	var nl := UI.label(e.nome(id), 21, UI.PERG, UI.font_head)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.clip_text = true
	r1.add_child(nl)
	var sv := UI.label("fino al t.%d" % e.L[id]["svc"], 16, UI.ROSSO_L if e.L[id]["svc"] <= e.turno else UI.MUTED)
	r1.add_child(sv)
	vb.add_child(r1)
	var dove: String = e.lnome(e.L[id]["loc"])
	if e.assediato(id):
		dove += " (assediato)"
	elif e.L[id]["dentro"]:
		dove += " (dentro)"
	elif e.L[id]["aggira"]:
		dove += " (aggira)"
	elif e.assediata_da(e.L[id]["loc"], s):
		dove += " (assedia)"
	vb.add_child(UI.label(dove, 16, UI.MUTED, UI.font_italic))
	var forze := Forze.new()
	forze.f = e.L[id]["forze"].duplicate()
	var c: String = e.comune(id)
	if c != "":
		for u in e.L[c]["forze"]:
			forze.f[u] = int(forze.f.get(u, 0)) + int(e.L[c]["forze"][u])
	forze.custom_minimum_size = Vector2(SIDE_W - 40, 26)
	vb.add_child(forze)
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 2)
	for k in ["prov", "carro", "moneta", "bottino", "nave"]:
		var n: int = e.supp(id, k) + (e.supp(c, k) if c != "" else 0)
		if n == 0 and k in ["bottino", "nave"]:
			continue
		var tx := UI.segnalino({"prov": "provviste", "carro": "carro", "moneta": "moneta", "bottino": "bottino", "nave": "nave"}[k])
		r2.add_child(UI.icon_rect(tx, Vector2(26, 26)))
		var nl2 := UI.label(str(n), 18, UI.PERG)
		nl2.custom_minimum_size.x = 18
		r2.add_child(nl2)
	vb.add_child(r2)
	var caps := []
	for cc in e.L[id]["caps"]:
		caps.append(D.CARTE[cc]["cap"])
	if c != "":
		for cc in e.L[c]["caps"]:
			caps.append(D.CARTE[cc]["cap"])
	if not caps.is_empty():
		vb.add_child(UI.wrap(UI.label(", ".join(caps), 15, UI.ORO_L, UI.font_italic), SIDE_W - 50))
	pc.gui_input.connect(func(ev):
		if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed):
			_scheda(id)
			_focus_loc(e.L[id]["loc"]))
	pc.tooltip_text = "Tocca per la scheda di %s" % e.nome(id)
	return pc


func _focus_loc(l: String) -> void:
	if l == "":
		return
	if view3d:
		mappa3d.focus(D.LOCALI[l]["pos"])
	else:
		mappa2d.focus(D.LOCALI[l]["pos"], maxf(mappa2d.zoom, 0.45))


func _on_log(t: String) -> void:
	var col := UI.PERG_D
	if t.begins_with("—"):
		col = UI.ORO_L
	elif t.begins_with("   "):
		col = Color("#c9b48c")
	elif "SI ARRENDE" in t or "SACCHEGGIATA" in t or "BATTAGLIA" in t or "ASSALTO" in t or "passa ai" in t:
		col = UI.ROSSO_L
	log_box.push_color(col)
	if t.begins_with("—"):
		log_box.push_font(UI.font_head)
		log_box.add_text(t)
		log_box.pop()
	else:
		log_box.add_text(t)
	log_box.pop()
	log_box.newline()


func toast(t: String, col := UI.PERG) -> void:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.dark_style(8, 0.92))
	var l := UI.wrap(UI.label(t, 22, col, UI.font_head), 560)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pc.add_child(l)
	toast_box.add_child(pc)
	while toast_box.get_child_count() > 3:
		var vecchio := toast_box.get_child(0)
		toast_box.remove_child(vecchio)
		vecchio.queue_free()
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(pc, "modulate:a", 0.0, 0.6)
	tw.tween_callback(pc.queue_free)


func _banner(t: String) -> void:
	banner.text = t
	var tw := create_tween()
	banner.modulate.a = 0.0
	tw.tween_property(banner, "modulate:a", 1.0, 0.35)
	tw.tween_interval(1.4)
	tw.tween_property(banner, "modulate:a", 0.0, 0.6)


func _on_fx(kind: String, d: Dictionary) -> void:
	var e := engine
	match kind:
		"turno":
			_banner("Turno %d — Leva" % d["turno"])
		"campagna":
			_banner("Campagna")
		"chiamata":
			_banner("Chiamata alle Armi!")
		"battaglia_inizio":
			_battaglia_mostra()
			mappa2d.flash[d["loc"]] = 1.5
		"battaglia_fine":
			_battaglia_refresh()
			var bp := battle_panel
			get_tree().create_timer(2.5 if not e.headless else 0.0).timeout.connect(func():
				if is_instance_valid(bp) and (e.battaglia.is_empty() or e.battaglia.get("esito", "") != ""):
					bp.visible = false)
		"battaglia_riga", "battaglia_colpi", "battaglia_round":
			_battaglia_refresh()
		"resa":
			toast("%s si arrende!" % e.lnome(d["loc"]), UI.ORO_L)
			mappa2d.flash[d["loc"]] = 1.5
		"saccheggio":
			toast("%s è saccheggiata!" % e.lnome(d["loc"]), UI.ROSSO_L)
			mappa2d.flash[d["loc"]] = 1.5
		"alleanza":
			mappa2d.flash[d["loc"]] = 1.2
		"devasta":
			mappa2d.flash[d["loc"]] = 1.0
		"carroccio":
			_banner("Il Carroccio è catturato!")
		"comune":
			toast("Il %s scende in campo con il Carroccio!" % e.nome(d["sig"]), UI.ORO_L)
		"carta":
			var c: String = d["id"]
			if d.get("cap", false):
				pass
			elif D.CARTE[c]["ev_t"] != "tenere":
				_mostra_carta(c)
		"carta_comando":
			var card: Dictionary = d["carta"]
			if card["t"] != "passa" and e.sulla_mappa(card["l"]):
				_focus_soft(e.L[card["l"]]["loc"])
	_dirty = true


func _focus_soft(l: String) -> void:
	if view3d or l == "":
		return
	var p: Vector2 = mappa2d.to_screen(D.LOCALI[l]["pos"])
	if p.x < 0 or p.y < 0 or p.x > mappa2d.size.x or p.y > mappa2d.size.y:
		mappa2d.focus(D.LOCALI[l]["pos"])


## Una carta Evento appena pescata: si vede per qualche secondo al centro.
func _mostra_carta(c: String) -> void:
	var tr := UI.icon_rect(UI.carta(c), Vector2(300, 420))
	tr.position = (center.size - Vector2(300, 420)) * 0.5
	center.add_child(tr)
	tr.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(tr, "modulate:a", 1.0, 0.3)
	tw.tween_interval(2.2)
	tw.tween_property(tr, "modulate:a", 0.0, 0.5)
	tw.tween_callback(tr.queue_free)


# ================================================================ battaglia

func _battaglia_mostra() -> void:
	battle_panel.visible = true
	_battaglia_refresh()


func _battaglia_refresh() -> void:
	var e := engine
	var b: Dictionary = e.battaglia
	if b.is_empty() or not battle_panel.visible:
		return
	for c in battle_box.get_children():
		battle_box.remove_child(c)
		c.queue_free()
	var tipo: String = {"battaglia": "Battaglia", "assalto": "Assalto", "sortita": "Sortita"}[b["tipo"]]
	var titolo := "%s a %s — Round %d" % [tipo, e.lnome(b["loc"]), b["round"]]
	if b.get("esito", "") != "":
		titolo = "%s a %s — vincono i %s" % [tipo, e.lnome(b["loc"]), b["esito"]]
	battle_box.add_child(UI.title(titolo, 34))
	for s in [b["dif"], b["att"]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var lbl := UI.label("%s\n%s" % [D.LATI[s], "attaccano" if s == b["att"] else "difendono"], 20, D.COL_LATO[s].lightened(0.4), UI.font_head)
		lbl.custom_minimum_size.x = 130
		row.add_child(lbl)
		for p in 3:
			var id: String = b["fronte"][s][p]
			row.add_child(_box_battaglia(id, s))
		if b["tipo"] == "assalto" and s == b["dif"]:
			row.add_child(_box_guarnigione(b))
		var ris := []
		for id in b["riserva"][s]:
			ris.append(e.nome(id))
		if not ris.is_empty():
			row.add_child(UI.wrap(UI.label("Riserva: " + ", ".join(ris), 17, UI.MUTED), 160))
		battle_box.add_child(row)
	var righe: Array = b["righe"]
	var ultime := righe.slice(maxi(0, righe.size() - 6))
	var lg := UI.wrap(UI.label("\n".join(ultime), 17, UI.PERG_D), 900)
	battle_box.add_child(lg)
	var close := UI.button("Nascondi", 160, 42, 18)
	close.pressed.connect(func(): battle_panel.visible = false)
	battle_box.add_child(close)
	_battaglia_adatta.call_deferred()


func _battaglia_adatta() -> void:
	battle_panel.size = Vector2.ZERO
	battle_panel.reset_size()
	battle_panel.position = ((center.size - battle_panel.size) * 0.5).max(Vector2(6, 60))


func _box_battaglia(id: String, s: int) -> Control:
	var e := engine
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.panel_style(Color("#33241a"), D.COL_LATO[s], 2, 6))
	pc.custom_minimum_size = Vector2(190, 108)
	var vb := VBoxContainer.new()
	pc.add_child(vb)
	if id == "":
		vb.add_child(UI.label("—", 20, UI.MUTED))
		return pc
	var r := HBoxContainer.new()
	r.add_child(UI.icon_rect(UI.scudo(id), Vector2(26, 32)))
	var rotto: bool = id in e.battaglia["rotti"][s]
	r.add_child(UI.label(e.nome(id), 19, UI.ROSSO_L if rotto else UI.PERG, UI.font_head))
	vb.add_child(r)
	var f := Forze.new()
	f.f = e.L[id]["forze"]
	f.custom_minimum_size = Vector2(180, 24)
	vb.add_child(f)
	var rt := 0
	for u in e.L[id]["rotte"]:
		rt += int(e.L[id]["rotte"][u])
	vb.add_child(UI.label("in rotta: %d" % rt if not rotto else "IN ROTTA", 16, UI.ROSSO_L if rt > 0 or rotto else UI.MUTED))
	return pc


func _box_guarnigione(b: Dictionary) -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.panel_style(Color("#3a3128"), UI.PERG_D, 2, 6))
	pc.custom_minimum_size = Vector2(190, 108)
	var vb := VBoxContainer.new()
	pc.add_child(vb)
	vb.add_child(UI.label("Guarnigione", 19, UI.PERG, UI.font_head))
	var f := Forze.new()
	f.f = b["guarn"]["forze"]
	f.custom_minimum_size = Vector2(180, 24)
	vb.add_child(f)
	vb.add_child(UI.label("mura 1-%d, opere %d" % [b["mura"], b["opere"]], 16, UI.MUTED))
	return pc


# ================================================================ online

func online_waiting(s: int, slow: bool) -> void:
	if s < 0:
		wait_lbl.text = ""
	else:
		wait_lbl.text = "Aspetto %s…%s" % [engine.pname(s), " (ci mette un po')" if slow else ""]


func online_mine() -> bool:
	return engine.online != null and engine.online._mine_pending


func online_status(t: String) -> void:
	toast(t, UI.ROSSO_L)


func online_caught_up() -> void:
	toast("Partita ripresa: sei di nuovo al tavolo.", UI.VERDE)


func online_cancel_decision(t: String) -> void:
	_clear_prompt()
	toast(t, UI.ROSSO_L)


# ================================================================ decisioni

func _clear_prompt() -> void:
	pending = {}
	_loc_opts = {}
	for c in prompt_list.get_children():
		c.queue_free()
	prompt_title.text = ""
	prompt_text.text = "In attesa…" if engine != null and not engine.over else ""
	prompt.add_theme_stylebox_override("panel", _prompt_style(-1))
	mappa2d.hot = {}
	mappa2d.sel_lord = ""
	if mappa3d != null:
		mappa3d.hot = mappa2d.hot
		mappa3d.sel_lord = ""
		mappa3d.refresh()
	_dirty = true


func _submit(r) -> void:
	var req := pending
	_clear_prompt()
	for c in popup_layer.get_children():
		c.queue_free()
	if req.is_empty():
		return
	engine.provide_decision(r)


func _on_spot(l: String) -> void:
	if not _loc_opts.has(l):
		return
	var ids: Array = _loc_opts[l]
	if ids.size() == 1:
		_submit(ids[0])
		return
	# più scelte sulla stessa località: si mostrano solo quelle
	for c in prompt_list.get_children():
		if c.has_meta("loc"):
			c.visible = c.get_meta("loc") == l
		elif c.has_meta("opt"):
			c.visible = false


func _on_decision(req: Dictionary) -> void:
	var s: int = req["side"]
	var segreto: bool = req["type"] == "piano" or req.get("k", "") in ["evento", "tradimento_az"]
	if humans.size() > 1 and segreto and s != _ultimo_lato:
		_ultimo_lato = s
		_curtain(s, func(): _show_decision(req))
		return
	if humans.size() > 1:
		_ultimo_lato = s
	_show_decision(req)


func _curtain(s: int, then: Callable) -> void:
	var dlg := _dialog("Tocca ai %s" % D.LATI[s], 640)
	dlg["box"].add_child(UI.wrap(UI.label("La prossima scelta è segreta: passate il dispositivo a chi guida i %s." % D.LATI[s], 21, UI.PERG), 580))
	var b := UI.lato_btn(UI.button("Guido i %s" % D.LATI[s], 0, 62, 24), s)
	b.pressed.connect(func():
		dlg["root"].queue_free()
		then.call())
	dlg["box"].add_child(b)


func _show_decision(req: Dictionary) -> void:
	pending = req
	if req["type"] == "piano":
		_ui_piano(req)
		return
	_ui_scelta(req)


func _ui_scelta(req: Dictionary) -> void:
	var s: int = req["side"]
	prompt.add_theme_stylebox_override("panel", _prompt_style(s))
	prompt_title.text = "%s — %s" % [D.LATI[s], req.get("titolo", "")]
	prompt_title.add_theme_color_override("font_color", D.COL_LATO[s].lightened(0.45))
	prompt_text.text = str(req.get("testo", ""))
	for c in prompt_list.get_children():
		c.queue_free()
	_loc_opts = {}
	var hot := {}
	if req.has("sig") and engine.L.has(req["sig"]):
		mappa2d.sel_lord = req["sig"]
		if mappa3d != null:
			mappa3d.sel_lord = req["sig"]
		if engine.sulla_mappa(req["sig"]):
			_focus_soft(engine.L[req["sig"]]["loc"])
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 6)
	fl.add_theme_constant_override("v_separation", 6)
	fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_list.add_child(fl)
	for o in req["opzioni"]:
		var id: String = str(o["id"])
		var b := UI.button(str(o["t"]), 0, 46, 18)
		b.custom_minimum_size.x = 220
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if o.has("carta"):
			b.icon = UI.carta(str(o["carta"]))
			b.expand_icon = false
			b.add_theme_constant_override("icon_max_width", 34)
			b.tooltip_text = str(o.get("dett", D.CARTE[o["carta"]]["cap_x"]))
		elif o.has("sig") and D.SIGNORI.has(o["sig"]):
			b.icon = UI.scudo(str(o["sig"]))
			b.add_theme_constant_override("icon_max_width", 26)
		if o.has("dett"):
			b.tooltip_text = str(o["dett"])
		if id in ["fine", "passa", "no", "combatti"]:
			b.add_theme_color_override("font_color", UI.PERG_D)
		if o.has("loc"):
			var l: String = o["loc"]
			if not _loc_opts.has(l):
				_loc_opts[l] = []
			_loc_opts[l].append(id)
			hot[l] = str(o["t"])
			b.set_meta("loc", l)
			b.mouse_entered.connect(func(): _focus_soft(l))
		else:
			b.set_meta("opt", true)
		b.pressed.connect(func(): _submit(id))
		fl.add_child(b)
	mappa2d.hot = hot
	if mappa3d != null:
		mappa3d.hot = hot
		mappa3d.refresh()
	if not hot.is_empty():
		prompt_text.text += "  (Puoi anche toccare la località sulla mappa.)"
	_dirty = true


# ---------------------------------------------------------------- piano di campagna

func _ui_piano(req: Dictionary) -> void:
	var s: int = req["side"]
	var n: int = req["n"]
	var carte: Array = req["carte"]
	var scelte := []
	var dlg := _dialog("Piano di Campagna dei %s: %d carte" % [D.LATI[s], n], 1400)
	var box: VBoxContainer = dlg["box"]
	box.add_child(UI.wrap(UI.label("Tocca le carte nell'ordine in cui vuoi giocarle: la prima del piano sarà il primo Signore attivo. Ogni Signore ha 3 carte Comando; le carte Passare riempiono il piano. Tocca una carta del piano per toglierla.", 19, UI.PERG), 1340))
	var piano_row := HFlowContainer.new()
	piano_row.add_theme_constant_override("h_separation", 6)
	piano_row.custom_minimum_size = Vector2(1340, 210)
	box.add_child(UI.heading("Il tuo piano", 24))
	box.add_child(piano_row)
	box.add_child(UI.heading("Carte disponibili", 24))
	var disp := HFlowContainer.new()
	disp.add_theme_constant_override("h_separation", 6)
	disp.add_theme_constant_override("v_separation", 6)
	disp.custom_minimum_size.x = 1340
	box.add_child(disp)
	var conferma := UI.primary(UI.button("Conferma il piano", 360, 60, 24))
	var aggiorna := func(): pass
	var tex_for := func(c: Dictionary) -> Texture2D:
		if c["t"] == "passa":
			return UI.tex("res://assets/carte/passa_%s.jpg" % ("G" if s == 0 else "H"))
		return UI.carta_comando(c)
	aggiorna = func():
		for x in piano_row.get_children():
			x.queue_free()
		for x in disp.get_children():
			x.queue_free()
		for i in scelte.size():
			var c: Dictionary = scelte[i]
			var b := _card_btn(tex_for.call(c), "%d" % (i + 1), Vector2(130, 182))
			var ii := i
			b.pressed.connect(func():
				scelte.remove_at(ii)
				aggiorna.call())
			piano_row.add_child(b)
		var usate := {}
		for c in scelte:
			usate[c["id"]] = true
		var passa_mostrata := false
		for c in carte:
			if usate.has(c["id"]):
				continue
			if c["t"] == "passa":
				if passa_mostrata:
					continue
				passa_mostrata = true
			var etich := ""
			if c["t"] != "passa" and not engine.sulla_mappa(c["l"]):
				continue
			var b := _card_btn(tex_for.call(c), etich, Vector2(100, 140))
			b.disabled = scelte.size() >= n
			var cc: Dictionary = c
			b.pressed.connect(func():
				if scelte.size() < n:
					scelte.append(cc)
					aggiorna.call())
			disp.add_child(b)
		conferma.disabled = scelte.size() != n
		conferma.text = "Conferma il piano" if scelte.size() == n else "Mancano %d carte" % (n - scelte.size())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var sug := UI.button("Suggerisci un piano", 300, 60, 22)
	sug.pressed.connect(func():
		var r: Array = engine.ais[s].decide(engine, s, req)
		scelte.clear()
		for id in r:
			for c in carte:
				if c["id"] == id:
					scelte.append(c)
		aggiorna.call())
	row.add_child(sug)
	var mappa_b := UI.button("Guarda la mappa", 260, 60, 22)
	mappa_b.pressed.connect(func():
		dlg["root"].visible = false
		var back := UI.primary(UI.button("Torna al piano", 300, 56, 22))
		back.position = Vector2(SIDE_W + 20, size.y - BOT_H - 80)
		popup_layer.add_child(back)
		back.pressed.connect(func():
			back.queue_free()
			dlg["root"].visible = true))
	row.add_child(mappa_b)
	conferma.pressed.connect(func():
		var ids := []
		for c in scelte:
			ids.append(c["id"])
		dlg["root"].queue_free()
		_submit(ids))
	row.add_child(conferma)
	box.add_child(row)
	aggiorna.call()
	prompt_title.text = "%s — Piano di Campagna" % D.LATI[s]
	prompt_text.text = "Componi il piano nella finestra."


func _card_btn(tx: Texture2D, etich: String, sz: Vector2) -> Button:
	var b := Button.new()
	b.custom_minimum_size = sz + Vector2(8, 8)
	b.icon = tx
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	if etich != "":
		b.text = etich
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_font_size_override("font_size", 16)
	return b


# ================================================================ finestre

## Finestra al centro: {root, box}.
func _dialog(title: String, w := 760.0) -> Dictionary:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	popup_layer.add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.dark_style(12, 0.98))
	root.add_child(pc)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pc.add_child(sc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	sc.add_child(vb)
	vb.add_child(UI.title(title, 38))
	var place := func():
		if not is_instance_valid(vb) or not is_instance_valid(pc) or not is_instance_valid(sc):
			return
		var avail := get_viewport_rect().size
		var ww := minf(w, avail.x - 40)
		vb.custom_minimum_size.x = ww - 44
		var want := vb.get_combined_minimum_size().y + 30
		sc.custom_minimum_size = Vector2(ww - 24, minf(want, avail.y - 90))
		pc.reset_size()
		pc.position = ((avail - pc.size) * 0.5).max(Vector2(10, 10))
	vb.resized.connect(place)
	resized.connect(place)
	place.call_deferred()
	return {"root": root, "box": vb, "panel": pc}


func _chiudi_btn(dlg: Dictionary) -> void:
	var b := UI.button("Chiudi", 220, 54, 22)
	b.pressed.connect(func(): dlg["root"].queue_free())
	dlg["box"].add_child(b)


## Scheda di un Signore: l'immagine originale della scheda e il suo stato.
func _scheda(id: String) -> void:
	var e := engine
	var dlg := _dialog(D.SIGNORI[id]["titolo"], 1300)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	dlg["box"].add_child(row)
	var img := UI.icon_rect(UI.tex("res://assets/schede/%s.jpg" % id), Vector2(560, 620))
	row.add_child(img)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size.x = 640
	row.add_child(vb)
	var x: Dictionary = e.L[id]
	var sd: Dictionary = D.SIGNORI[id]
	if e.comune_di(id) == "":
		vb.add_child(UI.label("Fedeltà 1-%d   Servizio %d   Signoria %d   Comando %d" % [sd["fed"], sd["serv"], sd["sign"], sd["cmd"]], 21, UI.ORO_L, UI.font_head))
	var stato := ""
	match x["stato"]:
		"mappa":
			stato = "A %s. Servizio fino al turno %d." % [e.lnome(x["loc"]), x["svc"]] if e.comune_di(id) == "" else "Con il suo Comandante a %s." % e.lnome(x["loc"])
		"cal":
			stato = "Al calendario: pronto per il Raduno dal turno %d." % x["cal"]
		"rimosso":
			stato = "Fuori gioco."
		_:
			stato = "Non in campo."
	vb.add_child(UI.wrap(UI.label(stato, 20, UI.PERG), 620))
	var sedi := []
	for l in sd["sedi"]:
		sedi.append(e.lnome(l))
	if not sedi.is_empty():
		vb.add_child(UI.wrap(UI.label("Sedi: " + ", ".join(sedi), 19, UI.PERG_D), 620))
	if x["stato"] == "mappa":
		vb.add_child(UI.heading("Forze", 22))
		var f := Forze.new()
		f.f = x["forze"]
		f.grande = true
		f.custom_minimum_size = Vector2(620, 40)
		vb.add_child(f)
		vb.add_child(UI.label(e.descr_forze(x["forze"]), 18, UI.PERG))
		vb.add_child(UI.heading("Supporti", 22))
		vb.add_child(UI.label(e.descr_supp(id), 18, UI.PERG))
	vb.add_child(UI.heading("Vassalli", 22))
	var vf := HFlowContainer.new()
	vf.add_theme_constant_override("h_separation", 8)
	vf.custom_minimum_size.x = 620
	for v in D.VASSALLI:
		if e.V[v]["presso"] != id and D.VASSALLI[v]["sig"] != id:
			continue
		var cell := VBoxContainer.new()
		cell.add_child(UI.icon_rect(UI.tex("res://assets/vassalli/%s.png" % v), Vector2(150, 76)))
		var st: String = e.V[v]["stato"]
		if e.V[v]["presso"] != D.VASSALLI[v]["sig"] and v != "altopascio":
			st = "voltagabbana con %s" % e.nome(e.V[v]["presso"])
		var lbl := UI.wrap(UI.label("%s\n%s" % [D.VASSALLI[v]["nome"], {"pronto": "pronto", "radunato": "radunato", "nonpronto": "non pronto", "fuori": "non disponibile"}.get(st, st)], 15, UI.PERG_D), 150)
		cell.add_child(lbl)
		vf.add_child(cell)
	vb.add_child(vf)
	if not x["caps"].is_empty():
		vb.add_child(UI.heading("Capacità", 22))
		var cf := HBoxContainer.new()
		for c in x["caps"]:
			cf.add_child(UI.icon_rect(UI.carta(c), Vector2(170, 238)))
		vb.add_child(cf)
	_chiudi_btn(dlg)


## Le carte in gioco: Capacità di entrambe le parti, eventi attivi e (per chi guarda) eventi tenuti.
func _carte() -> void:
	var e := engine
	var dlg := _dialog("Carte in gioco", 1400)
	var box: VBoxContainer = dlg["box"]
	for s in 2:
		box.add_child(UI.heading("Capacità dei %s" % D.LATI[s], 26, D.COL_LATO[s].lightened(0.4)))
		var fl := HFlowContainer.new()
		fl.add_theme_constant_override("h_separation", 8)
		fl.custom_minimum_size.x = 1340
		var tutte := []
		for c in e.cap_lato[s]:
			tutte.append([c, "per tutti"])
		for id in e.L:
			if e.lato(id) == s:
				for c in e.L[id]["caps"]:
					tutte.append([c, e.nome(id)])
		if tutte.is_empty():
			box.add_child(UI.label("nessuna", 18, UI.MUTED))
		for t in tutte:
			var cell := VBoxContainer.new()
			cell.add_child(UI.icon_rect(UI.carta(t[0]), Vector2(190, 266)))
			cell.add_child(UI.label(t[1], 16, UI.PERG_D))
			fl.add_child(cell)
		box.add_child(fl)
	if not e.ev_attivi.is_empty():
		box.add_child(UI.heading("Eventi in corso", 26))
		var fl := HFlowContainer.new()
		for x in e.ev_attivi:
			fl.add_child(UI.icon_rect(UI.carta(x["id"]), Vector2(190, 266)))
		box.add_child(fl)
	# eventi tenuti: solo quelli di chi guarda
	var miei: Array = humans if humans.size() == 1 else ([pending["side"]] if not pending.is_empty() else [])
	for s in miei:
		box.add_child(UI.heading("I tuoi eventi tenuti (%s)" % D.LATI[s], 26))
		if e.tenute[s].is_empty():
			box.add_child(UI.label("nessuno", 18, UI.MUTED))
		var fl := HFlowContainer.new()
		for c in e.tenute[s]:
			fl.add_child(UI.icon_rect(UI.carta(c), Vector2(190, 266)))
		box.add_child(fl)
	_chiudi_btn(dlg)


func _ask_menu() -> void:
	var dlg := _dialog("Menu", 560)
	var box: VBoxContainer = dlg["box"]
	for it in [["Salva la partita", _save_game], ["Regole", _show_rules], ["Torna al menu principale", func(): main.show_menu()]]:
		var b := UI.button(it[0], 0, 58, 22)
		var cb: Callable = it[1]
		b.pressed.connect(func():
			dlg["root"].queue_free()
			cb.call())
		box.add_child(b)
	var v := UI.button("Velocità dell'IA: %s" % ("veloce" if engine.ai_delay < 0.3 else "normale"), 0, 58, 22)
	v.pressed.connect(func():
		engine.ai_delay = 0.15 if engine.ai_delay >= 0.3 else 0.5
		engine.anim = 2.5 if engine.ai_delay < 0.3 else 1.0
		v.text = "Velocità dell'IA: %s" % ("veloce" if engine.ai_delay < 0.3 else "normale"))
	box.add_child(v)
	_chiudi_btn(dlg)


func _show_rules() -> void:
	var dlg := _dialog("Regole in breve", 1200)
	var rv := preload("res://scripts/ui/rules_view.gd")
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.fit_content = true
	t.custom_minimum_size.x = 1140
	t.text = rv.TESTO
	dlg["box"].add_child(t)
	_chiudi_btn(dlg)


func _save_game() -> void:
	if engine.online != null:
		toast("Le partite online restano nella stanza: si rientra con il codice.", UI.PERG)
		return
	var cfg := config.duplicate()
	cfg.erase("replay")
	cfg.erase("online")
	var data := {"cfg": var_to_str(cfg), "moves": var_to_str(engine.record)}
	toast("Salvo la partita…", UI.PERG)
	var code: String = await main.get_net().save_game(data, save_code)
	if code == "":
		toast("Salvataggio non riuscito: %s" % main.get_net().last_error, UI.ROSSO_L)
		return
	save_code = code
	var dlg := _dialog("Partita salvata", 640)
	dlg["box"].add_child(UI.wrap(UI.label("Codice della partita:", 22, UI.PERG), 580))
	var cl := UI.title(code, 64)
	dlg["box"].add_child(cl)
	dlg["box"].add_child(UI.wrap(UI.label("Con «Carica partita» nel menu e questo codice la riprendi da qui, anche da un altro dispositivo.", 19, UI.PERG_D), 580))
	_chiudi_btn(dlg)


func _on_end(res: Dictionary) -> void:
	_clear_prompt()
	var v: int = int(res.get("vince", -1))
	var t := "Pareggio" if v < 0 else "Vincono i %s" % D.LATI[v]
	var dlg := _dialog(t, 820)
	dlg["box"].add_child(UI.wrap(UI.label(str(res.get("motivo", "")), 22, UI.PERG), 760))
	dlg["box"].add_child(UI.label("Guelfi %s PV — Ghibellini %s PV" % [engine.pv_testo(0), engine.pv_testo(1)], 26, UI.ORO_L, UI.font_head))
	var b := UI.primary(UI.button("Torna al menu", 320, 60, 24))
	b.pressed.connect(func(): main.show_menu())
	dlg["box"].add_child(b)
	var b2 := UI.button("Guarda la mappa", 320, 60, 22)
	b2.pressed.connect(func(): dlg["root"].queue_free())
	dlg["box"].add_child(b2)
	if engine.online != null:
		engine.online.finish()


# ================================================================ disegni

## Le unità di un Signore: cunei per la cavalleria e barre per la fanteria, con il numero.
class Forze extends Control:
	var f := {}
	var grande := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var x := 2.0
		var hgt := size.y
		var k := 1.6 if grande else 1.0
		var font := UI.font_bold
		for u in D.ORDINE_UNITA:
			var n: int = int(f.get(u, 0))
			if n <= 0:
				continue
			var col: Color = D.UNITA[u]["col"]
			if D.UNITA[u]["cav"]:
				var pts := PackedVector2Array([Vector2(x, hgt * 0.85), Vector2(x + 9 * k, hgt * 0.1), Vector2(x + 18 * k, hgt * 0.85)])
				draw_colored_polygon(pts, col)
				pts.append(pts[0])
				draw_polyline(pts, Color(0, 0, 0, 0.7), 1.5)
				x += 20 * k
			else:
				var r := Rect2(x, hgt * 0.35, 22 * k, hgt * 0.42)
				draw_rect(r, col)
				draw_rect(r, Color(0, 0, 0, 0.7), false, 1.5)
				x += 24 * k
			var t := str(n)
			draw_string(font, Vector2(x, hgt * 0.78), t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * k), UI.PERG)
			x += font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * k)).x + 8 * k


## Il calendario: 16 turni con la stagione, il segnalino Leva/Campagna, i cilindri dei Signori
## pronti al raduno, i segnalini Servizio dei Signori in campo e la Vittoria.
class Calendario extends Control:
	var e

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		tooltip_text = " "

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#1a110a"))
		if e == null:
			return
		var w := size.x / 16.0
		var font := UI.font_head
		for t in range(1, 17):
			var x := (t - 1) * w
			var st: String = D.STAGIONE[t]
			var col: Color = D.COL_STAGIONE[st]
			var r := Rect2(x + 2, 2, w - 4, size.y - 4)
			var attivo: bool = t == e.turno
			draw_rect(r, col.darkened(0.15) if not attivo else col.lightened(0.15))
			draw_rect(r, Color("#3a2414") if not attivo else UI.ROSSO, false, 2.0 if not attivo else 4.0)
			if t < e.S.get("da", 1) or t > e.turno_fine:
				draw_rect(r, Color(0, 0, 0, 0.35))
			draw_string(UI.font_title, Vector2(x + 7, 30), str(t), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#3a2414"))
			draw_string(font, Vector2(x + 34, 22), D.MESI_BREVI[t], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#3a2414"))
			draw_string(font, Vector2(x + 34, 38), D.ANNI[t], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#5a3a20"))
			if attivo:
				var tx := UI.segnalino("leva" if e.fase == "leva" else "campagna")
				if tx:
					draw_texture_rect(tx, Rect2(x + w - 40, 42, 36, 36), false)
			if (t == e.turno_fine + 1 and e.turno_fine < 16) or (e.fine_box > 0 and t == e.fine_box):
				var tf := UI.segnalino("fine")
				if tf:
					draw_texture_rect(tf, Rect2(x + w - 76, 42, 34, 34), false)
		# Vittoria
		for s in 2:
			var v: float = e.pv(s)
			var box: int = clampi(int(floor(v)), 0, 16)
			var x := (maxi(box, 1) - 1) * w + 4 + s * 34
			var tx := UI.segnalino("vittoria_G" if s == 0 else "vittoria_H")
			if tx and box >= 1:
				draw_texture_rect(tx, Rect2(x, 42, 32, 32), false)
		# Signori: cilindri pronti (in alto) e Servizio (in basso)
		var cnt := {}
		for id in e.L:
			var xx: Dictionary = e.L[id]
			if e.comune_di(id) != "":
				continue
			var box := -1
			var y := 0.0
			if xx["stato"] == "cal":
				box = clampi(xx["cal"], 1, 16)
				y = 82
			elif xx["stato"] == "mappa":
				box = clampi(xx["svc"], 1, 16)
				y = 104
			if box < 0:
				continue
			var key := "%d_%d" % [box, int(y)]
			var i: int = cnt.get(key, 0)
			cnt[key] = i + 1
			var cx := (box - 1) * w + 6 + i * 22
			var tx := UI.stemma(id) if y < 100 else UI.scudo(id)
			if tx:
				if y < 100:
					draw_texture_rect(tx, Rect2(cx, y - 2, 22, 22), false)
				else:
					draw_texture_rect(tx, Rect2(cx, y, 18, 22), false)
		draw_string(UI.font_body, Vector2(4, size.y - 3), "", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.MUTED)

	func _get_tooltip(at: Vector2) -> String:
		if e == null:
			return ""
		var t := clampi(int(at.x / (size.x / 16.0)) + 1, 1, 16)
		var parti := ["Turno %d — %s (%s, %d carte nel piano)" % [t, D.MESI[t], D.NOME_STAGIONE[D.STAGIONE[t]], D.CARTE_PIANO[D.STAGIONE[t]]]]
		var pronti := []
		var servizio := []
		for id in e.L:
			if e.comune_di(id) != "":
				continue
			if e.L[id]["stato"] == "cal" and clampi(e.L[id]["cal"], 1, 16) == t:
				pronti.append(e.nome(id))
			if e.L[id]["stato"] == "mappa" and clampi(e.L[id]["svc"], 1, 16) == t:
				servizio.append(e.nome(id))
		if not pronti.is_empty():
			parti.append("Pronti al Raduno: " + ", ".join(pronti))
		if not servizio.is_empty():
			parti.append("Servizio fino a qui: " + ", ".join(servizio))
		if t in D.CRESCITA:
			parti.append("A fine turno: Crescita (metà delle devastazioni nemiche si cancella).")
		parti.append(D.NOTE_CAL[t])
		return "\n".join(parti)
