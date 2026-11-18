extends Control
## Menu principale: scenario, chi guida Guelfi e Ghibellini (persona o IA), vista, partite salvate,
## gioco online e regole.

const D = preload("res://scripts/data/inf_data.gd")
const PW := 1920.0
const PH := 1080.0

var main
var page: Control
var scen := "F"
var modes := [0, 2]              # 0 persona, 1 IA facile, 2 IA normale, 3 IA esperta
var view3d := 0
var scen_btns := {}
var mode_rows := []
var view_row: HBoxContainer
var desc_lbl: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var st: Dictionary = main.menu_state
	scen = str(st.get("scen", "F"))
	modes = st.get("modes", [0, 2]).duplicate()
	view3d = int(st.get("view3d", 0))
	# sfondo: la mappa sfumata
	var bg := TextureRect.new()
	bg.texture = UI.tex("res://assets/mappa/mappa_piccola.jpg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.45, 0.38, 0.32)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	page = Control.new()
	page.size = Vector2(PW, PH)
	add_child(page)
	resized.connect(_center)
	_build()
	_center.call_deferred()


func _center() -> void:
	var s := minf(size.x / PW, size.y / PH)
	page.scale = Vector2(s, s)
	page.position = (size - Vector2(PW, PH) * s) * 0.5


func _store() -> void:
	main.menu_state = {"scen": scen, "modes": modes.duplicate(), "view3d": view3d}


func _build() -> void:
	var t := UI.title("Inferno", 132, UI.ORO_L)
	t.position = Vector2(80, 30)
	page.add_child(t)
	var st := UI.label("Guelfi e Ghibellini si contendono la Toscana, 1259-1261", 34, UI.PERG, UI.font_head)
	st.position = Vector2(88, 196)
	page.add_child(st)
	var st2 := UI.label("Leva e Campagna, volume III — Enrico Acerbi e Volko Ruhnke, GMT Games", 22, UI.MUTED, UI.font_italic)
	st2.position = Vector2(90, 244)
	page.add_child(st2)
	# scenari
	var sp := UI.Pergamena.new()
	sp.position = Vector2(80, 300)
	sp.custom_minimum_size = Vector2(900, 700)
	page.add_child(sp)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	sp.add_child(sv)
	sv.add_child(UI.label("Scenario", 34, UI.INK, UI.font_title))
	for k in D.ORDINE_SCENARI:
		var sc: Dictionary = D.SCENARI[k]
		var b := Button.new()
		b.custom_minimum_size = Vector2(860, 74)
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%s\n%s" % [sc["nome"], sc["sotto"]]
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(func():
			scen = k
			_store()
			_refresh())
		sv.add_child(b)
		scen_btns[k] = b
	desc_lbl = UI.wrap(UI.ink("", 21, UI.font_italic), 860)
	desc_lbl.custom_minimum_size.y = 90
	sv.add_child(desc_lbl)
	# giocatori
	var pp := PanelContainer.new()
	pp.add_theme_stylebox_override("panel", UI.dark_style(10, 0.94))
	pp.position = Vector2(1030, 300)
	pp.custom_minimum_size = Vector2(810, 0)
	page.add_child(pp)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 14)
	pp.add_child(pv)
	pv.add_child(UI.heading("Chi guida le fazioni", 32))
	for s in 2:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var sc := UI.icon_rect(UI.scudo("firenze" if s == 0 else "siena"), Vector2(46, 56))
		row.add_child(sc)
		var nl := UI.label(D.LATI[s], 26, UI.lato_col(s).lightened(0.35), UI.font_head)
		nl.custom_minimum_size.x = 150
		row.add_child(nl)
		var seg := HBoxContainer.new()
		seg.add_theme_constant_override("separation", 4)
		row.add_child(seg)
		mode_rows.append(seg)
		for i in 4:
			var b := UI.button(["Persona", "IA facile", "IA normale", "IA esperta"][i], 140, 54, 19)
			b.toggle_mode = true
			var ss := s
			var ii := i
			b.pressed.connect(func():
				modes[ss] = ii
				_store()
				_refresh())
			seg.add_child(b)
		pv.add_child(row)
	var vr := HBoxContainer.new()
	vr.add_theme_constant_override("separation", 8)
	var vl := UI.label("Mappa", 26, UI.PERG, UI.font_head)
	vl.custom_minimum_size.x = 204
	vr.add_child(vl)
	view_row = HBoxContainer.new()
	view_row.add_theme_constant_override("separation", 4)
	vr.add_child(view_row)
	for i in 2:
		var b := UI.button(["2D, la mappa originale", "3D, città e armate"][i], 280, 54, 19)
		b.toggle_mode = true
		var ii := i
		b.pressed.connect(func():
			view3d = ii
			_store()
			_refresh())
		view_row.add_child(b)
	pv.add_child(vr)
	pv.add_child(UI.wrap(UI.label("Si può cambiare vista anche durante la partita. Con due persone sullo stesso dispositivo, le scelte segrete (piano di campagna, eventi tenuti) si fanno passandosi il dispositivo.", 19, UI.MUTED, UI.font_italic), 760))
	var start := UI.primary(UI.button("Nuova partita", 780, 84, 34))
	start.pressed.connect(_on_start)
	pv.add_child(start)
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 10)
	var onl := UI.button("Gioca online", 250, 64, 22)
	onl.pressed.connect(_online_panel)
	r2.add_child(onl)
	var ld := UI.button("Carica partita", 250, 64, 22)
	ld.pressed.connect(_load_panel)
	r2.add_child(ld)
	var rg := UI.button("Regole", 260, 64, 22)
	rg.pressed.connect(func(): main.show_rules())
	r2.add_child(rg)
	pv.add_child(r2)
	# i tutorial e il manuale di strategia
	var r3 := HBoxContainer.new()
	r3.add_theme_constant_override("separation", 10)
	var t1 := UI.button("Tutorial: campagna guidata", 300, 60, 20)
	t1.pressed.connect(func(): main.start_game(Tutorial.config_campagna()))
	r3.add_child(t1)
	var t2 := UI.button("Tutorial: la battaglia", 250, 60, 20)
	t2.pressed.connect(func(): main.start_game(Tutorial.config_battaglia()))
	r3.add_child(t2)
	var t3 := UI.button("Strategie", 210, 60, 20)
	t3.pressed.connect(func(): main.show_strategie())
	r3.add_child(t3)
	pv.add_child(r3)
	var cred := UI.wrap(UI.label("Versione digitale per uso personale della ludoteca. Grafica di Robert Altbauer e Matthew Wallhead (GMT Games); traduzione italiana di carte e regole dal materiale del gioco.", 16, UI.MUTED), 760)
	pv.add_child(cred)
	_refresh()


func _refresh() -> void:
	for k in scen_btns:
		scen_btns[k].button_pressed = k == scen
	desc_lbl.text = D.SCENARI[scen]["x"]
	for s in 2:
		var seg: HBoxContainer = mode_rows[s]
		for i in seg.get_child_count():
			seg.get_child(i).button_pressed = i == modes[s]
	for i in view_row.get_child_count():
		view_row.get_child(i).button_pressed = i == view3d


func _config() -> Dictionary:
	var seats := []
	for s in 2:
		var ai: bool = modes[s] > 0
		seats.append({"name": D.LATI[s] if not ai else "%s (IA)" % D.LATI[s], "ai": ai, "level": maxi(0, modes[s] - 1)})
	return {"scen": scen, "seats": seats, "view3d": view3d == 1}


func _on_start() -> void:
	_store()
	main.start_game(_config())


# =================================================================== online

var on_panel: Control
var on_name: LineEdit
var on_code: LineEdit
var on_lbl: Label
var on_start: Button


func _overlay(w: float) -> VBoxContainer:
	if is_instance_valid(on_panel):
		on_panel.queue_free()
	on_panel = Control.new()
	on_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	on_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(on_panel)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	on_panel.add_child(shade)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.dark_style(10, 0.98))
	box.position = page.position + Vector2((PW - w) * 0.5, 130) * page.scale
	box.scale = page.scale
	box.custom_minimum_size = Vector2(w, 0)
	on_panel.add_child(box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	box.add_child(vb)
	return vb


func _online_panel() -> void:
	var vb := _overlay(860)
	vb.add_child(UI.title("Gioca online", 54))
	vb.add_child(UI.wrap(UI.label("Chi crea la stanza guida la fazione segnata «Persona» nel menu (se lo sono entrambe, i Guelfi); l'amico entra con il codice e prende l'altra. Se l'altra fazione è segnata IA la gioca il computer. Scenario e opzioni scelti nel menu valgono per tutti. La partita resta nella stanza: si rientra con lo stesso codice.", 20, UI.MUTED), 820))
	var ses: Dictionary = main.get_net().load_session()
	on_name = _line("Il tuo nome", 20)
	on_name.text = str(ses.get("name", ""))
	vb.add_child(on_name)
	var b_create := UI.button("Crea una stanza", 0, 58, 22)
	b_create.pressed.connect(_online_create)
	vb.add_child(b_create)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	on_code = _line("Codice", 4)
	on_code.custom_minimum_size.x = 220
	on_code.text_changed.connect(func(t):
		on_code.text = t.to_upper()
		on_code.caret_column = t.length())
	row.add_child(on_code)
	var b_join := UI.button("Entra", 200, 58, 22)
	b_join.pressed.connect(_online_join)
	row.add_child(b_join)
	vb.add_child(row)
	on_lbl = UI.wrap(UI.label("", 21, Color.WHITE), 820)
	on_lbl.custom_minimum_size.y = 120
	vb.add_child(on_lbl)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	on_start = UI.primary(UI.button("Inizia online", 420, 62, 24))
	on_start.pressed.connect(_online_start)
	on_start.visible = main.lobby.get("role", "") == "host"
	row2.add_child(on_start)
	var b_close := UI.button("Indietro", 300, 62, 22)
	b_close.pressed.connect(func(): on_panel.queue_free())
	row2.add_child(b_close)
	vb.add_child(row2)
	if not main.lobby.is_empty():
		on_code.text = main.lobby["code"]
		on_lbl.text = "Stanza %s…" % main.lobby["code"]
	elif str(ses.get("room", "")) != "":
		on_code.text = str(ses["room"])
		on_lbl.text = "Eri nella stanza %s: premi Entra per rientrare." % ses["room"]


func _line(ph: String, maxlen: int) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = ph
	le.max_length = maxlen
	le.custom_minimum_size = Vector2(0, 58)
	le.add_theme_font_size_override("font_size", 24)
	return le


func _say(t: String) -> void:
	if is_instance_valid(on_lbl):
		on_lbl.text = t


func _seats_text(room: Dictionary) -> String:
	var seats := Net._as_dict(room.get("seats", {}))
	var parts := []
	for idx in room.get("open", []):
		var k := str(int(idx))
		var who := str(seats[k].get("name", "?")) if seats.has(k) and seats[k] is Dictionary else "libero"
		parts.append("%s: %s" % [D.LATI[int(idx)], who])
	return ", ".join(parts)


func _online_create() -> void:
	var nm := on_name.text.strip_edges()
	if nm == "":
		_say("Scrivi il tuo nome.")
		return
	var mio := 0 if modes[0] == 0 or modes[1] != 0 else 1
	var seats := [mio]
	if modes[1 - mio] == 0:
		seats.append(1 - mio)
	if seats.size() < 2:
		_say("Segna «Persona» nel menu per entrambe le fazioni: una è la tua, l'altra è per l'amico.")
		return
	_store()
	_say("Creo la stanza…")
	var net: Net = main.get_net()
	var code := await net.create_room(nm, seats)
	if code == "":
		_say("Non riesco a creare la stanza.\n%s" % net.last_error)
		return
	main.lobby = {"role": "host", "code": code, "seat": mio}
	net.remember_room(code, mio)
	net._save({"name": nm})
	if is_instance_valid(on_code):
		on_code.text = code
	if is_instance_valid(on_start):
		on_start.visible = true
	_lobby_poll(code)


func _online_join() -> void:
	var code := on_code.text.strip_edges().to_upper()
	var nm := on_name.text.strip_edges()
	if nm == "" or code.length() != 4:
		_say("Scrivi il tuo nome e il codice di 4 lettere.")
		return
	_say("Entro nella stanza %s…" % code)
	var net: Net = main.get_net()
	var seat := await net.join_room(code, nm)
	if seat == -2:
		_say("Stanza %s non trovata, oppure la partita è già iniziata.%s" % [code, ("\n" + net.last_error) if net.last_error != "" else ""])
		return
	if seat == -1:
		_say("Nella stanza %s non ci sono posti liberi." % code)
		return
	var room: Dictionary = net.last_room
	main.lobby = {"role": "host" if room.get("host", "") == net.uid else "guest", "code": code, "seat": seat}
	net.remember_room(code, seat)
	net._save({"name": nm})
	if room.get("status", "") in ["playing", "over"] and room.has("game"):
		_say("Rientro nella partita della stanza %s…" % code)
		_begin(room["game"], true)
		return
	if is_instance_valid(on_start):
		on_start.visible = main.lobby["role"] == "host"
	_lobby_poll(code)


func _lobby_poll(code: String) -> void:
	var net: Net = main.get_net()
	while is_inside_tree() and main.lobby.get("code", "") == code:
		var room := await net.room(code)
		if not is_inside_tree() or main.lobby.get("code", "") != code:
			return
		if room.is_empty():
			_say("La stanza %s non esiste più." % code)
			main.lobby = {}
			return
		if main.lobby["role"] == "host":
			_say("Stanza [ %s ]: dai il codice all'amico.\nPosti: %s.\nQuando c'è premi Inizia online." % [code, _seats_text(room)])
		else:
			if room.get("status", "") == "playing" and room.has("game"):
				_begin(room["game"], false)
				return
			_say("Sei nella stanza [ %s ] e guidi i %s.\nAspetta che chi l'ha creata avvii la partita." % [code, D.LATI[int(main.lobby["seat"])]])
		await get_tree().create_timer(2.0).timeout


func _online_start() -> void:
	var code: String = main.lobby["code"]
	var net: Net = main.get_net()
	var room := await net.room(code)
	if room.is_empty():
		_say("La stanza %s non esiste più." % code)
		main.lobby = {}
		return
	var seats_db := Net._as_dict(room.get("seats", {}))
	var cfg := _config()
	for i in 2:
		var k := str(i)
		if seats_db.has(k) and seats_db[k] is Dictionary:
			cfg["seats"][i]["name"] = str(seats_db[k].get("name", cfg["seats"][i]["name"]))
			cfg["seats"][i]["ai"] = false
		else:
			cfg["seats"][i]["ai"] = true
			cfg["seats"][i]["level"] = maxi(1, modes[i] - 1)
			cfg["seats"][i]["name"] = "%s (IA)" % D.LATI[i]
	cfg["seed"] = 1 + randi() % 2000000000
	var g := {"cfg": var_to_str(cfg)}
	if not await net.start_room(code, g):
		_say("Non riesco ad avviare la partita (%s)." % net.last_error)
		return
	_begin(g, false)


func _begin(g: Dictionary, rejoin: bool) -> void:
	var net: Net = main.get_net()
	var lob: Dictionary = main.lobby
	var backlog: Array = []
	if rejoin:
		backlog = await net.get_acts(lob["code"])
		net.set_away(lob["code"], int(lob["seat"]), false)
	var cfg = str_to_var(str(g.get("cfg", "")))
	if not (cfg is Dictionary):
		_say("Configurazione della partita non valida.")
		return
	cfg["view3d"] = view3d == 1
	var ses := OnlineSession.new()
	ses.setup(net, lob["code"], int(lob["seat"]), lob["role"], backlog)
	cfg["online"] = ses
	main.lobby = {}
	main.start_game(cfg)


# =================================================================== partite salvate

func _load_panel() -> void:
	var vb := _overlay(820)
	vb.add_child(UI.title("Carica partita", 54))
	vb.add_child(UI.wrap(UI.label("Scrivi il codice di 6 lettere ottenuto con «Salva» durante la partita. Le partite salvate stanno su Firebase e si riprendono da qualsiasi dispositivo.", 20, UI.MUTED), 780))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	on_code = _line("Codice", 6)
	on_code.custom_minimum_size.x = 260
	on_code.text_changed.connect(func(t):
		on_code.text = t.to_upper()
		on_code.caret_column = t.length())
	row.add_child(on_code)
	var b := UI.primary(UI.button("Carica", 220, 58, 22))
	b.pressed.connect(_do_load)
	row.add_child(b)
	vb.add_child(row)
	on_lbl = UI.wrap(UI.label("", 21, Color.WHITE), 780)
	on_lbl.custom_minimum_size.y = 80
	vb.add_child(on_lbl)
	var cl := UI.button("Indietro", 260, 58, 22)
	cl.pressed.connect(func(): on_panel.queue_free())
	vb.add_child(cl)


func _do_load() -> void:
	var code := on_code.text.strip_edges().to_upper()
	if code.length() != 6:
		_say("Il codice ha 6 lettere.")
		return
	_say("Carico la partita %s…" % code)
	var net: Net = main.get_net()
	var data := await net.load_game(code)
	if data.is_empty():
		_say("Partita %s non trovata.%s" % [code, ("\n" + net.last_error) if net.last_error != "" else ""])
		return
	var cfg = str_to_var(str(data.get("cfg", "")))
	var moves = str_to_var(str(data.get("moves", "[]")))
	if not (cfg is Dictionary) or not (moves is Array):
		_say("Salvataggio non valido.")
		return
	cfg["replay"] = moves
	cfg["view3d"] = view3d == 1
	main.start_game(cfg)
	if main.current != null:
		main.current.save_code = code
