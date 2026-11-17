extends Control
## Mappa 2D della Toscana: l'immagine originale (scritte in italiano) con sopra segnalini e cilindri
## dei Signori, disegnati dal codice. Si sposta trascinando (mouse o un dito), si ingrandisce con la
## rotella o pizzicando con due dita, si ruota con due dita (o con il tasto destro).
## Le località selezionabili della decisione in corso sono evidenziate e si scelgono toccandole.

const D = preload("res://scripts/data/inf_data.gd")
const W := 4096.0
const H := 3489.0

signal spot_pressed(id: String)
signal lord_pressed(id: String)

var e
var tex_map: Texture2D
var zoom := 0.3
var rot := 0.0
var pan := Vector2.ZERO
var hot := {}                    # località -> etichetta
var sel_lord := ""
var flash := {}                  # località -> tempo rimasto
var anim_pos := {}               # signore -> posizione mostrata (per i movimenti)
var _touches := {}
var _dragging := false
var _press_pos := Vector2.ZERO
var _pinch := {}
var _fitted := false
var _t := 0.0
var _lord_rects := {}            # signore -> [centro, raggio] in coordinate mappa


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_on_resized)


func setup(eng) -> void:
	e = eng
	tex_map = UI.tex("res://assets/mappa/mappa.jpg")
	queue_redraw()


func _on_resized() -> void:
	if not _fitted and size.x > 10:
		fit()
	queue_redraw()


func fit() -> void:
	rot = 0.0
	zoom = minf(size.x / W, size.y / H) * 0.99
	pan = size * 0.5
	queue_redraw()


func focus(p: Vector2, z := -1.0) -> void:
	_fitted = true
	if z > 0:
		zoom = z
	pan = size * 0.5 - (p - Vector2(W, H) * 0.5).rotated(rot) * zoom
	queue_redraw()


func to_screen(p: Vector2) -> Vector2:
	return pan + (p - Vector2(W, H) * 0.5).rotated(rot) * zoom


func to_map(s: Vector2) -> Vector2:
	return (s - pan).rotated(-rot) / zoom + Vector2(W, H) * 0.5


func zoom_at(s: Vector2, f: float) -> void:
	_fitted = true
	var b := to_map(s)
	zoom = clampf(zoom * f, 0.1, 2.5)
	pan += s - to_screen(b)
	queue_redraw()


func rotate_by(a: float) -> void:
	_fitted = true
	var c := size * 0.5
	var b := to_map(c)
	rot = wrapf(rot + a, -PI, PI)
	pan += c - to_screen(b)
	queue_redraw()


func _process(dt: float) -> void:
	_t += dt
	var redraw := not hot.is_empty() or sel_lord != ""
	for k in flash.keys():
		flash[k] -= dt
		if flash[k] <= 0:
			flash.erase(k)
		redraw = true
	if e != null:
		for id in e.L:
			if e.L[id]["stato"] != "mappa":
				anim_pos.erase(id)
				continue
			var target: Vector2 = D.LOCALI[e.L[id]["loc"]]["pos"]
			if not anim_pos.has(id):
				anim_pos[id] = target
			elif anim_pos[id].distance_to(target) > 1.0:
				anim_pos[id] = anim_pos[id].lerp(target, minf(1.0, dt * 4.0))
				redraw = true
			else:
				anim_pos[id] = target
	if redraw:
		queue_redraw()


# ================================================================ input

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventScreenDrag or ev is InputEventMagnifyGesture or ev is InputEventPanGesture:
		_fitted = true
	if ev is InputEventScreenTouch:
		if ev.pressed:
			_touches[ev.index] = ev.position
			if _touches.size() == 1:
				_press_pos = ev.position
				_dragging = false
			_pinch = {}
		else:
			var tap: bool = _touches.size() == 1 and not _dragging and ev.position.distance_to(_press_pos) < 14.0
			_touches.erase(ev.index)
			_pinch = {}
			if tap:
				_click(ev.position)
		accept_event()
		return
	if ev is InputEventScreenDrag:
		_touches[ev.index] = ev.position
		if _touches.size() == 1:
			if ev.position.distance_to(_press_pos) > 10.0:
				_dragging = true
			if _dragging:
				pan += ev.relative
				queue_redraw()
		elif _touches.size() >= 2:
			_dragging = true
			var keys := _touches.keys()
			var a: Vector2 = _touches[keys[0]]
			var b: Vector2 = _touches[keys[1]]
			var mid := (a + b) * 0.5
			var d := a.distance_to(b)
			var ang := (b - a).angle()
			if not _pinch.is_empty():
				var f: float = d / maxf(1.0, _pinch["d"])
				var bp := to_map(_pinch["mid"])
				zoom = clampf(zoom * f, 0.1, 2.5)
				rot = wrapf(rot + (ang - _pinch["ang"]), -PI, PI)
				pan += mid - to_screen(bp)
				queue_redraw()
			_pinch = {"d": d, "ang": ang, "mid": mid}
		accept_event()
		return
	if ev is InputEventMagnifyGesture:
		zoom_at(ev.position, ev.factor)
		accept_event()
		return
	if ev is InputEventPanGesture:
		_fitted = true
		pan -= ev.delta * 12.0
		queue_redraw()
		accept_event()
		return
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			zoom_at(ev.position, 1.12)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			zoom_at(ev.position, 1.0 / 1.12)
		elif ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			if ev.pressed:
				_press_pos = ev.position
				_dragging = false
			else:
				if not _dragging and ev.button_index == MOUSE_BUTTON_LEFT and ev.position.distance_to(_press_pos) < 8.0 and _touches.is_empty():
					_click(ev.position)
				_dragging = false
		accept_event()
	elif ev is InputEventMouseMotion and ev.button_mask != 0 and _touches.is_empty():
		if ev.position.distance_to(_press_pos) > 8.0:
			_dragging = true
			_fitted = true
		if _dragging:
			if ev.button_mask & MOUSE_BUTTON_MASK_RIGHT:
				rotate_by(ev.relative.x * 0.005)
			else:
				pan += ev.relative
			queue_redraw()
		accept_event()


func _click(s: Vector2) -> void:
	var b := to_map(s)
	# prima i Signori (cilindri), poi le località selezionabili
	var best := ""
	var bd := 1e9
	for l in hot:
		var dd: float = b.distance_to(D.LOCALI[l]["pos"])
		if dd < maxf(70.0, 26.0 / zoom) and dd < bd:
			bd = dd
			best = l
	if best != "":
		spot_pressed.emit(best)
		return
	for id in _lord_rects:
		var r: Array = _lord_rects[id]
		if b.distance_to(r[0]) < r[1]:
			lord_pressed.emit(id)
			return


# ================================================================ disegno

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#16100b"))
	if e == null:
		return
	draw_set_transform(pan - (Vector2(W, H) * 0.5).rotated(rot) * zoom, rot, Vector2(zoom, zoom))
	if tex_map != null:
		draw_texture_rect(tex_map, Rect2(0, 0, W, H), false)
	# misura dei pezzi: crescono quando la mappa è piccola, così restano leggibili
	var k := clampf(0.42 / zoom, 1.0, 2.2)
	_lord_rects.clear()
	for l in D.LOCALI:
		_draw_locale(l, k)
	for l in D.LOCALI:
		_draw_lords(l, k)
	for l in hot:
		var p: Vector2 = D.LOCALI[l]["pos"]
		var pulse := 0.5 + 0.5 * sin(_t * 5.0)
		draw_arc(p, 62.0 * k, 0, TAU, 40, Color(UI.ORO_L, 0.55 + 0.45 * pulse), 9.0 * k)
		draw_arc(p, 74.0 * k, 0, TAU, 40, Color(UI.ROSSO, 0.5), 4.0 * k)
	for l in flash:
		var p: Vector2 = D.LOCALI[l]["pos"]
		var a: float = clampf(flash[l], 0.0, 1.0)
		draw_circle(p, 90.0 * k * (1.6 - a * 0.6), Color(UI.ROSSO_L, 0.35 * a))
	if not e.battaglia.is_empty() and e.battaglia.get("esito", "") == "":
		var p: Vector2 = D.LOCALI[e.battaglia["loc"]]["pos"]
		var tx := UI.segnalino("battaglia" if e.battaglia["tipo"] != "assalto" else "assalto")
		if tx:
			draw_texture_rect(tx, Rect2(p + Vector2(-60, -150) * k, Vector2(120, 120) * k), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _tile(tx: Texture2D, c: Vector2, s: float, n := 1) -> void:
	if tx == null:
		return
	for i in n:
		var o := Vector2(i * 6, -i * 6)
		draw_texture_rect(tx, Rect2(c - Vector2(s, s) * 0.5 + o, Vector2(s, s)), false)


func _draw_locale(l: String, k: float) -> void:
	var x: Dictionary = e.loc[l]
	var p: Vector2 = D.LOCALI[l]["pos"]
	var s := 58.0 * k
	if x["all_n"] > 0:
		_tile(UI.segnalino("alleanza_G" if x["all_l"] == 0 else "alleanza_H"), p + Vector2(-70, -58) * k, s, x["all_n"])
		if x["all_n"] > 1:
			_num(p + Vector2(-96, -86) * k, str(x["all_n"]), k)
	if x["rovine"] >= 0:
		_tile(UI.segnalino("rovine_G" if x["rovine"] == 0 else "rovine_H"), p + Vector2(0, -8) * k, s * 1.05)
	if x["dev"] >= 0:
		_tile(UI.segnalino("devastato_G" if x["dev"] == 0 else "devastato_H"), p + Vector2(68, -58) * k, s)
	if x["mura"] >= 0:
		_tile(UI.segnalino("mura_G" if x["mura"] == 0 else "mura_H"), p + Vector2(68, 6) * k, s * 0.9)
	if x["assedio"] > 0:
		var tx := UI.segnalino("assedio")
		_tile(tx, p + Vector2(-70, 8) * k, s, x["assedio"])
		_num(p + Vector2(-98, -18) * k, str(x["assedio"]), k)


func _num(c: Vector2, t: String, k: float) -> void:
	draw_circle(c, 17.0 * k, UI.ROSSO)
	draw_arc(c, 17.0 * k, 0, TAU, 20, UI.PERG, 3.0 * k)
	var f := UI.font_head
	var fs := int(24 * k)
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, c + Vector2(-w * 0.5, fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _draw_lords(l: String, k: float) -> void:
	var ids: Array = e.signori_in(l, -1, false)
	if ids.is_empty():
		return
	var fuori := []
	var dentro := []
	for id in ids:
		if e.L[id]["dentro"]:
			dentro.append(id)
		else:
			fuori.append(id)
	var r := 34.0 * k
	var base: Vector2 = D.LOCALI[l]["pos"]
	for i in dentro.size():
		var id: String = dentro[i]
		var c := base + Vector2((i - (dentro.size() - 1) * 0.5) * r * 1.7, -6 * k)
		c = _anim(id, c, base)
		draw_circle(c, r * 1.12, Color("#5b544c"))
		_disc(id, c, r * 0.92)
		draw_arc(c, r * 1.12, 0, TAU, 32, Color("#cfc6b4"), 4.0 * k)
	for i in fuori.size():
		var id: String = fuori[i]
		var c := base + Vector2((i - (fuori.size() - 1) * 0.5) * r * 2.1, 78 * k)
		c = _anim(id, c, base)
		_disc(id, c, r)
		if e.L[id]["aggira"]:
			_tile(UI.segnalino("aggiramento"), c + Vector2(r * 0.85, -r * 0.85), r * 0.9)


func _anim(id: String, c: Vector2, base: Vector2) -> Vector2:
	if anim_pos.has(id):
		return c + (anim_pos[id] - base)
	return c


func _disc(id: String, c: Vector2, r: float) -> void:
	var s: int = e.lato(id)
	# il Comune sta sotto il suo Comandante: un cerchio più grande dietro
	var cm: String = e.comune(id)
	if cm != "":
		draw_circle(c + Vector2(r * 0.25, r * 0.3), r * 1.08, UI.lato_col(s).darkened(0.35))
		draw_arc(c + Vector2(r * 0.25, r * 0.3), r * 1.08, 0, TAU, 32, UI.ORO_L if s == 0 else UI.PORPORA, 3.0)
	draw_circle(c + Vector2(4, 6), r, Color(0, 0, 0, 0.45))
	var tx := UI.stemma(id)
	if tx:
		draw_texture_rect(tx, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false)
	else:
		draw_circle(c, r, UI.lato_col(s))
	if id == sel_lord or (e.sig_attivo == id and e.fase == "campagna"):
		var pulse := 0.5 + 0.5 * sin(_t * 6.0)
		draw_arc(c, r * 1.18, 0, TAU, 32, Color(UI.ORO_L, 0.6 + 0.4 * pulse), 6.0)
	_lord_rects[id] = [c, r * 1.1]
	# Mosso / combattuto
	if e.L[id]["mosso"]:
		draw_circle(c + Vector2(-r * 0.8, -r * 0.8), r * 0.28, UI.ROSSO)
