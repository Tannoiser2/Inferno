extends Control
## La battaglia in 3D: una mini mappa (il pezzo di Toscana dove si combatte) con le miniature delle armate.
## I Guelfi stanno a sinistra, i Ghibellini a destra; ogni Signore ha il suo reparto (una miniatura per unità)
## con lo stendardo. I reparti entrano in campo, si spostano quando si riposizionano, tirano frecce e
## quadrelli, caricano, e le unità in rotta cadono. Nell'Assalto c'è la fortezza con le mura e la Guarnigione.
##
## Miniature: se esiste res://assets/miniature/<unità>.glb (ritter, cav, berr, cl, uia, arm, mil, vill)
## si usa quel modello (alto quanto serve, appoggiato sulla basetta, rivolto verso il nemico); se il modello
## ha delle animazioni, si usano quelle con nomi come corsa/run/walk, attacco/attack/shoot, morte/death/die,
## riposo/idle. Altrimenti si costruisce una miniatura semplice nei colori dell'unità.
## Comandi: un dito o il tasto sinistro spostano la vista, due dita pizzicano e ruotano, la rotella fa lo zoom,
## il tasto destro ruota e inclina.

const D = preload("res://scripts/data/inf_data.gd")
const GUARN := "_guarnigione"
const CAV := ["ritter", "cav", "berr", "cl"]
const SC := 1.6       # scala dei reparti (miniature, stendardi, nomi) sulla mini mappa
const MODELLI := {"citta": "res://assets/modelli/citta.glb", "cittadina": "res://assets/modelli/cittadina.glb",
		"castello": "res://assets/modelli/castello.glb", "avamposto": "res://assets/modelli/castello.glb"}
const ANIM := {"corsa": ["corsa", "run", "gallop", "walk", "cammina", "marcia"], "attacco": ["attacco", "attack", "shoot", "tiro", "colpo", "slash"],
		"morte": ["morte", "death", "die", "muore"], "riposo": ["riposo", "idle", "fermo"]}

static var _mini_cache := {}

var e
var b: Dictionary = {}
var svc: SubViewportContainer
var vp: SubViewport
var cam: Camera3D
var mondo: Node3D
var effetti: Node3D
var reparti := {}       # holder -> {"s", "nodo", "mini": [{"n", "u"}], "lbl"}
var proiettili := []
var muro_x := 0.0
var _t := 0.0
var yaw := 0.0
var pitch := 0.8
var dist := 5.0
var target := Vector3(0, 0, 0.15)
var _touches := {}
var _pinch := {}
var _press := Vector2.ZERO
var _moved := false
var _mats := {}


func setup(eng) -> void:
	e = eng
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	svc = SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
	vp = SubViewport.new()
	vp.msaa_3d = Viewport.MSAA_2X
	vp.own_world_3d = true
	svc.add_child(vp)
	var env := WorldEnvironment.new()
	var en := Environment.new()
	en.background_mode = Environment.BG_COLOR
	en.background_color = Color("#140d08")
	en.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	en.ambient_light_color = Color("#f2dfc0")
	en.ambient_light_energy = 0.42
	en.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = en
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 0.85
	sun.light_color = Color("#fff1d6")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 12.0
	vp.add_child(sun)
	cam = Camera3D.new()
	cam.fov = 36
	vp.add_child(cam)
	mondo = Node3D.new()
	vp.add_child(mondo)
	effetti = Node3D.new()
	vp.add_child(effetti)
	_cam()


func _vel() -> float:
	return maxf(0.3, float(e.anim)) if e != null else 1.0


func _mat(c: Color, rough := 0.7) -> StandardMaterial3D:
	var k := c.to_html() + str(rough)
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		_mats[k] = m
	return _mats[k]


func _cam() -> void:
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.transform = Transform3D(Basis.looking_at(-off, Vector3.UP), target + off)


# ================================================================ campo

func inizia(bb: Dictionary) -> void:
	b = bb
	for c in mondo.get_children():
		c.queue_free()
	for c in effetti.get_children():
		c.queue_free()
	reparti.clear()
	proiettili.clear()
	yaw = 0.0
	pitch = 0.8
	dist = 5.0
	target = Vector3(0, 0, 0.15)
	_cam()
	_terreno(b["loc"])
	muro_x = 0.0
	if b["tipo"] in ["assalto", "sortita"]:
		var dentro: int = b["dif"] if b["tipo"] == "assalto" else b["att"]
		_fortezza(b["loc"], _dir(dentro))
		if b["tipo"] == "assalto":
			muro_x = _dir(dentro) * 0.42
			_mura(muro_x)
	for s in [0, 1]:
		for id in b["tutti"][s]:
			_nuovo_reparto(id, s)
	if b["tipo"] == "assalto" and e._vive(GUARN) > 0:
		_nuovo_reparto(GUARN, b["dif"])
	# entrata in campo: i reparti arrivano dai lati
	for h in reparti:
		var r: Dictionary = reparti[h]
		var dove := _slot(h)
		r["nodo"].position = dove + Vector3(_dir(r["s"]) * 2.2, 0, 0)
		_muovi(h, dove, 1.3)


func _dir(s: int) -> float:
	return -1.0 if s == 0 else 1.0


func _terreno(l: String) -> void:
	var p: Vector2 = D.LOCALI[l]["pos"]
	var lw := 6.4
	var lh := 4.2
	var px := 980.0
	var py := px * lh / lw
	var tab := MeshInstance3D.new()
	var tm := PlaneMesh.new()
	tm.size = Vector2(12, 9)
	tab.mesh = tm
	tab.material_override = _mat(Color("#4a2f1c"), 0.85)
	tab.position.y = -0.05
	mondo.add_child(tab)
	var pm := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(lw, lh)
	pm.mesh = plane
	var m := StandardMaterial3D.new()
	m.albedo_texture = UI.tex("res://assets/mappa/mappa_3d.jpg")
	m.albedo_color = Color(0.78, 0.76, 0.72)
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var sx := px / 4096.0
	var sy := py / 3489.0
	m.uv1_scale = Vector3(sx, sy, 1)
	m.uv1_offset = Vector3(clampf((p.x - px * 0.5) / 4096.0, 0.0, 1.0 - sx), clampf((p.y - py * 0.5) / 3489.0, 0.0, 1.0 - sy), 0)
	pm.material_override = m
	mondo.add_child(pm)
	var bordo := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(lw + 0.08, 0.04, lh + 0.08)
	bordo.mesh = bm
	bordo.material_override = _mat(Color("#2b1a10"), 0.8)
	bordo.position.y = -0.021
	mondo.add_child(bordo)


func _fortezza(l: String, d: float) -> void:
	var t: String = D.LOCALI[l]["tipo"]
	var sc: PackedScene = load(MODELLI.get(t, MODELLI["castello"]))
	var n: Node3D = sc.instantiate()
	var ab := _aabb(n, Transform3D.IDENTITY)
	var k := 1.3 / maxf(ab.size.x, 0.001)
	n.scale = Vector3.ONE * k
	n.rotation.y = -d * PI * 0.5
	var c := Vector3(d * 2.25, 0, -0.1)
	var ctr := Vector3(ab.position.x + ab.size.x * 0.5, ab.position.y, ab.position.z + ab.size.z * 0.5) * k
	n.position = c - n.basis * ctr
	mondo.add_child(n)


func _mura(x: float) -> void:
	var pietra := _mat(Color("#d9b98c"), 0.9)
	var muro := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.12, 0.16, 2.9)
	muro.mesh = bm
	muro.material_override = pietra
	muro.position = Vector3(x, 0.08, 0)
	mondo.add_child(muro)
	for i in 15:
		var mr := MeshInstance3D.new()
		var mm := BoxMesh.new()
		mm.size = Vector3(0.12, 0.05, 0.09)
		mr.mesh = mm
		mr.material_override = pietra
		mr.position = Vector3(x, 0.185, -1.4 + i * 0.2)
		mondo.add_child(mr)
	for z in [-1.45, 1.45]:
		var tw := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.13
		cm.bottom_radius = 0.15
		cm.height = 0.3
		tw.mesh = cm
		tw.material_override = pietra
		tw.position = Vector3(x, 0.15, z)
		mondo.add_child(tw)


## Dove sta un reparto: fronte (3 posizioni), riserva, in rotta (indietro), Guarnigione sulle mura.
func _slot(h: String) -> Vector3:
	var r: Dictionary = reparti[h]
	var s: int = r["s"]
	var d := _dir(s)
	if h == GUARN:
		return Vector3(muro_x + d * 0.02, 0.21, 0)
	var fortificato: bool = b["tipo"] == "assalto" and s == b["dif"]
	if h in b["rotti"][s]:
		var i: int = b["rotti"][s].find(h)
		return Vector3(d * 2.85, 0, -1.5 + i * 0.75)
	for p in 3:
		if b["fronte"][s][p] == h:
			var x := d * (1.0 if fortificato else 0.85)
			return Vector3(x, 0, (p - 1) * 1.25)
	var ris: Array = b["riserva"][s]
	var j := ris.find(h)
	if j < 0:
		j = 0
	var n := maxi(1, ris.size())
	return Vector3(d * 1.8, 0, clampf((j - (n - 1) * 0.5) * 1.05, -1.65, 1.65))


func _forze(h: String) -> Dictionary:
	return e._forze(h)


func _nome(h: String) -> String:
	return "Guarnigione" if h == GUARN else e.nome(h)


func _nuovo_reparto(h: String, s: int) -> void:
	var nodo := Node3D.new()
	nodo.scale = Vector3.ONE * SC
	mondo.add_child(nodo)
	var r := {"s": s, "nodo": nodo, "mini": [], "lbl": null}
	reparti[h] = r
	# stendardo
	if h != GUARN:
		var asta := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.006
		cm.bottom_radius = 0.006
		cm.height = 0.42
		asta.mesh = cm
		asta.material_override = _mat(Color("#3a2414"), 0.8)
		asta.position = Vector3(_dir(s) * 0.36, 0.21, 0)
		nodo.add_child(asta)
		var band := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.16, 0.2)
		band.mesh = qm
		var bm := StandardMaterial3D.new()
		var tx: Texture2D = UI.scudo(h)
		bm.albedo_texture = tx if tx != null else UI.stemma(h)
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		bm.cull_mode = BaseMaterial3D.CULL_DISABLED
		bm.roughness = 0.6
		band.material_override = bm
		band.position = Vector3(_dir(s) * 0.36, 0.34, 0.012)
		nodo.add_child(band)
		r["band"] = band
	var lbl := Label3D.new()
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font = UI.font_head
	lbl.font_size = 40
	lbl.pixel_size = 0.0016
	lbl.outline_size = 12
	lbl.outline_modulate = Color(0.08, 0.05, 0.03, 0.95)
	lbl.modulate = D.COL_LATO[s].lightened(0.55)
	lbl.position = Vector3(0, 0.48 if h != GUARN else 0.3, 0)
	lbl.no_depth_test = true
	nodo.add_child(lbl)
	r["lbl"] = lbl
	_allinea_numero(h, true)
	_etichetta(h)


func _etichetta(h: String) -> void:
	var r: Dictionary = reparti[h]
	var n := 0
	var f := _forze(h)
	for u in f:
		n += int(f[u])
	var t := "%s  %d" % [_nome(h), n]
	if h != GUARN and h in b["rotti"][r["s"]]:
		t = "%s  in rotta" % _nome(h)
	r["lbl"].text = t


## Le unità del reparto: una miniatura per unità, la cavalleria davanti, la fanteria dietro.
func _ordine(h: String) -> Array:
	var f := _forze(h)
	var out := []
	for u in D.ORDINE_UNITA:
		for i in int(f.get(u, 0)):
			out.append(u)
	return out


func _posto(h: String, i: int, n: int) -> Vector3:
	var r: Dictionary = reparti[h]
	var d := _dir(r["s"])
	if h == GUARN:
		var per := maxi(1, n)
		return Vector3(0, 0, (i - (per - 1) * 0.5) * minf(0.11, 1.5 / per))
	var per_fila := 6
	var col := i % per_fila
	var fila := i / per_fila
	var nf := mini(n - fila * per_fila, per_fila)
	return Vector3(-d * 0.2 + d * fila * 0.15, 0, (col - (nf - 1) * 0.5) * 0.12)


func _allinea_numero(h: String, subito := false) -> void:
	var r: Dictionary = reparti[h]
	var voluto := _ordine(h)
	var lista: Array = r["mini"]
	# toglie le unità che non ci sono più (per eventi o ritirate)
	var conta := {}
	for u in voluto:
		conta[u] = int(conta.get(u, 0)) + 1
	var tenere := []
	for m in lista:
		if int(conta.get(m["u"], 0)) > 0:
			conta[m["u"]] -= 1
			tenere.append(m)
		else:
			_svanisci(m["n"])
	for u in conta:
		for i in int(conta[u]):
			var mn := _miniatura(u, r["s"])
			r["nodo"].add_child(mn)
			tenere.append({"n": mn, "u": u})
	tenere.sort_custom(func(x, y): return D.ORDINE_UNITA.find(x["u"]) < D.ORDINE_UNITA.find(y["u"]))
	r["mini"] = tenere
	var d := _dir(r["s"])
	for i in tenere.size():
		var mn: Node3D = tenere[i]["n"]
		var p := _posto(h, i, tenere.size())
		mn.rotation.y = -d * PI * 0.5
		if subito or not mn.is_inside_tree():
			mn.position = p
		else:
			var tw := mn.create_tween()
			tw.tween_property(mn, "position", p, 0.4 / _vel())


func _muovi(h: String, dove: Vector3, dur: float) -> void:
	var r: Dictionary = reparti[h]
	var nodo: Node3D = r["nodo"]
	if nodo.position.distance_to(dove) < 0.01:
		return
	for m in r["mini"]:
		m["n"].set_meta("passo", true)
		_anim(m["n"], "corsa")
	var tw := nodo.create_tween()
	tw.tween_property(nodo, "position", dove, dur / _vel()).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		for m in r["mini"]:
			if is_instance_valid(m["n"]):
				m["n"].set_meta("passo", false)
				_anim(m["n"], "riposo"))


## Riallinea la scena allo stato della battaglia (nuovo round, riserve che entrano, Signori in rotta).
func sincronizza() -> void:
	if b.is_empty():
		return
	for s in [0, 1]:
		for id in b["tutti"][s]:
			if not reparti.has(id):
				_nuovo_reparto(id, s)
				reparti[id]["nodo"].position = _slot(id) + Vector3(_dir(s) * 2.0, 0, 0)
	for h in reparti:
		_allinea_numero(h)
		_etichetta(h)
		_muovi(h, _slot(h), 0.9)


# ================================================================ miniature

func _miniatura(u: String, s: int) -> Node3D:
	var root := Node3D.new()
	var cav: bool = u in CAV
	# basetta nel colore della fazione
	var base := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.05 if cav else 0.038
	bc.bottom_radius = bc.top_radius + 0.004
	bc.height = 0.012
	bc.radial_segments = 16
	base.mesh = bc
	base.material_override = _mat(D.COL_LATO[s], 0.5)
	base.position.y = 0.006
	root.add_child(base)
	var corpo := Node3D.new()
	corpo.name = "corpo"
	corpo.position.y = 0.012
	root.add_child(corpo)
	var path := "res://assets/miniature/%s.glb" % u
	if not _mini_cache.has(u):
		_mini_cache[u] = load(path) if ResourceLoader.exists(path) else null
	if _mini_cache[u] != null:
		var n: Node3D = _mini_cache[u].instantiate()
		var ab := _aabb(n, Transform3D.IDENTITY)
		var k := (0.2 if cav else 0.16) / maxf(ab.size.y, 0.001)
		n.scale = Vector3.ONE * k
		n.position = -Vector3(ab.position.x + ab.size.x * 0.5, ab.position.y, ab.position.z + ab.size.z * 0.5) * k
		corpo.add_child(n)
		var ap := _trova_ap(n)
		if ap != null:
			root.set_meta("ap", ap)
			_anim(root, "riposo")
	else:
		_procedurale(corpo, u, s)
	root.set_meta("passo", false)
	root.set_meta("fase", randf() * TAU)
	return root


func _trova_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var a := _trova_ap(c)
		if a != null:
			return a
	return null


func _anim(mn: Node3D, cosa: String) -> void:
	if not mn.has_meta("ap"):
		return
	var ap: AnimationPlayer = mn.get_meta("ap")
	if not is_instance_valid(ap):
		return
	for nome_a in ap.get_animation_list():
		var low := String(nome_a).to_lower()
		for k in ANIM[cosa]:
			if k in low:
				ap.play(nome_a)
				return


func _box(p: Node3D, sz: Vector3, at: Vector3, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = _mat(c, 0.7)
	mi.position = at
	mi.rotation = rot
	p.add_child(mi)
	return mi


func _cil(p: Node3D, r: float, h: float, at: Vector3, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 8
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = _mat(c, 0.7)
	mi.position = at
	mi.rotation = rot
	p.add_child(mi)
	return mi


func _sfera(p: Node3D, r: float, at: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2
	sm.radial_segments = 10
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = _mat(c, 0.6)
	mi.position = at
	p.add_child(mi)
	return mi


## Miniatura provvisoria: fante o cavaliere nei colori dell'unità, con scudo nel colore della fazione.
## Avanti è +z (come i modelli glTF).
func _procedurale(p: Node3D, u: String, s: int) -> void:
	var col: Color = D.UNITA[u]["col"]
	var pelle := Color("#e2b48c")
	var ferro := Color("#9aa0a6")
	var corazza: bool = D.UNITA[u]["cor"]
	var lato: Color = D.COL_LATO[s]
	if u in CAV:
		var manto := Color("#6b4528") if u != "ritter" else Color("#d8d4cc")
		_box(p, Vector3(0.04, 0.045, 0.11), Vector3(0, 0.075, 0), manto)
		for z in [-0.04, 0.04]:
			for x in [-0.014, 0.014]:
				_box(p, Vector3(0.011, 0.055, 0.011), Vector3(x, 0.027, z), manto.darkened(0.2))
		_box(p, Vector3(0.024, 0.05, 0.03), Vector3(0, 0.11, 0.06), manto, Vector3(-0.6, 0, 0))
		_box(p, Vector3(0.022, 0.022, 0.045), Vector3(0, 0.135, 0.085), manto)
		# gualdrappa nei colori dell'unità
		_box(p, Vector3(0.044, 0.03, 0.07), Vector3(0, 0.085, -0.005), col)
		# cavaliere
		_cil(p, 0.014, 0.06, Vector3(0, 0.13, -0.005), col)
		_sfera(p, 0.012, Vector3(0, 0.172, -0.005), ferro if corazza else pelle)
		if corazza:
			_cil(p, 0.0125, 0.012, Vector3(0, 0.18, -0.005), ferro)
		_box(p, Vector3(0.006, 0.04, 0.032), Vector3(-0.022, 0.13, 0.0), lato)
		if u in ["ritter", "cav"]:
			_cil(p, 0.0025, 0.2, Vector3(0.02, 0.15, 0.06), Color("#5a3b22"), Vector3(PI * 0.42, 0, 0))
		else:
			_box(p, Vector3(0.004, 0.06, 0.004), Vector3(0.02, 0.14, 0.02), ferro, Vector3(0.5, 0, 0))
	else:
		_cil(p, 0.008, 0.05, Vector3(-0.009, 0.025, 0), Color("#4a3a2a"))
		_cil(p, 0.008, 0.05, Vector3(0.009, 0.025, 0), Color("#4a3a2a"))
		_cil(p, 0.02, 0.06, Vector3(0, 0.08, 0), col)
		_sfera(p, 0.014, Vector3(0, 0.125, 0), pelle)
		if corazza:
			_sfera(p, 0.015, Vector3(0, 0.131, 0), ferro).scale = Vector3(1, 0.7, 1)
		match u:
			"mil":
				# arco
				var arco := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 0.034
				tm.outer_radius = 0.038
				arco.mesh = tm
				arco.material_override = _mat(Color("#5a3b22"), 0.8)
				arco.position = Vector3(-0.024, 0.09, 0.012)
				arco.rotation = Vector3(0, 0, PI * 0.5)
				arco.scale = Vector3(1, 1, 0.25)
				p.add_child(arco)
			"vill":
				_cil(p, 0.003, 0.16, Vector3(0.024, 0.09, 0), Color("#6b4a2a"))
				_box(p, Vector3(0.016, 0.02, 0.003), Vector3(0.024, 0.175, 0), ferro)
			_:
				_cil(p, 0.003, 0.2, Vector3(0.024, 0.1, 0.0), Color("#5a3b22"))
				_box(p, Vector3(0.006, 0.02, 0.006), Vector3(0.024, 0.205, 0.0), ferro)
				_box(p, Vector3(0.036, 0.05, 0.006), Vector3(0, 0.08, 0.024), lato)


# ================================================================ azioni

func _bersaglio_pos(h: String) -> Vector3:
	if not reparti.has(h):
		return Vector3.ZERO
	var r: Dictionary = reparti[h]
	var lista: Array = r["mini"]
	if lista.is_empty():
		return r["nodo"].position
	var m = lista[randi() % lista.size()]["n"]
	return m.global_position if m.is_inside_tree() else r["nodo"].position


## Un gruppo tira o carica contro un bersaglio.
func attacco(d: Dictionary) -> void:
	if b.is_empty():
		return
	var tipo: String = d["tipo"]
	var t: String = d["t"]
	var v := _vel()
	if tipo == "arc":
		var tiratori := []
		for h in d["da"]:
			if not reparti.has(h):
				continue
			for m in reparti[h]["mini"]:
				if m["u"] in ["mil", "arm", "uia"]:
					tiratori.append(m)
			if tiratori.is_empty():
				tiratori = reparti[h]["mini"].duplicate()
		if tiratori.is_empty():
			return
		for m in tiratori:
			_anim(m["n"], "attacco")
			var c: Node3D = m["n"].get_node_or_null("corpo")
			if c != null:
				var tw := c.create_tween()
				tw.tween_property(c, "rotation:x", -0.35, 0.25 / v)
				tw.tween_property(c, "rotation:x", 0.0, 0.2 / v)
		var n := mini(int(d["colpi"]) * 3 + 2, 32)
		var bal := int(d.get("bal", 0))
		for i in n:
			var m = tiratori[randi() % tiratori.size()]
			if not is_instance_valid(m["n"]):
				continue
			var da: Vector3 = m["n"].global_position + Vector3(0, 0.22, 0)
			var a := _bersaglio_pos(t) + Vector3(randf_range(-0.12, 0.12), 0.04, randf_range(-0.2, 0.2))
			_freccia(da, a, randf() * 0.45, i < bal * 3)
	else:
		var tipi: Array = CAV if tipo == "cav" else (["uia", "arm", "mil", "vill"] if tipo == "inf" else D.ORDINE_UNITA)
		var meta := Vector3.ZERO
		if reparti.has(t):
			meta = reparti[t]["nodo"].position
		var scintille := 0
		for h in d["da"]:
			if not reparti.has(h):
				continue
			var r: Dictionary = reparti[h]
			var nodo: Node3D = r["nodo"]
			var verso := meta - nodo.position
			verso.y = 0
			var lun := verso.length()
			var corsa := verso.normalized() * maxf(0.0, lun - 0.55) if lun > 0.01 else Vector3.ZERO
			if h == GUARN:
				corsa = Vector3.ZERO
			for m in r["mini"]:
				if not m["u"] in tipi:
					continue
				var mn: Node3D = m["n"]
				var casa := mn.position
				var arrivo := casa + nodo.basis.inverse() * corsa
				if muro_x != 0.0 and r["s"] == b["att"]:
					arrivo.x = (muro_x - _dir(r["s"]) * 0.16 - nodo.position.x) / SC
				mn.set_meta("passo", true)
				_anim(mn, "corsa")
				var tw := mn.create_tween()
				tw.tween_interval(randf() * 0.12 / v)
				tw.tween_property(mn, "position", arrivo, 0.5 / v).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw.tween_callback(func(): _anim(mn, "attacco"))
				tw.tween_property(mn, "position", arrivo + Vector3(randf_range(-0.03, 0.03), 0, randf_range(-0.03, 0.03)), 0.12 / v)
				tw.tween_property(mn, "position", arrivo, 0.12 / v)
				tw.tween_property(mn, "position", casa, 0.45 / v).set_trans(Tween.TRANS_SINE)
				tw.tween_callback(func():
					mn.set_meta("passo", false)
					_anim(mn, "riposo"))
				scintille += 1
		if scintille > 0:
			var punto := meta.lerp(reparti[d["da"][0]]["nodo"].position if reparti.has(d["da"][0]) else meta, 0.3)
			if muro_x != 0.0:
				punto.x = muro_x
			get_tree().create_timer(0.55 / v).timeout.connect(func():
				if is_instance_valid(effetti):
					for i in mini(scintille, 10):
						_lampo(punto + Vector3(randf_range(-0.2, 0.2), 0.12 + randf() * 0.15, randf_range(-0.5, 0.5)), Color("#fff2b0"), 0.04))


func _freccia(da: Vector3, a: Vector3, ritardo: float, quadrello: bool) -> void:
	var n := Node3D.new()
	var asta := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.008, 0.008, 0.17 if not quadrello else 0.11)
	asta.mesh = bm
	asta.material_override = _mat(Color("#3a2414") if quadrello else Color("#c9a46a"), 0.8)
	n.add_child(asta)
	var punta := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.016, 0.016, 0.026)
	punta.mesh = pm
	punta.material_override = _mat(Color("#8c9096"), 0.4)
	punta.position.z = 0.095 if not quadrello else 0.065
	n.add_child(punta)
	if not quadrello:
		var penna := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(0.026, 0.003, 0.036)
		penna.mesh = fm
		penna.material_override = _mat(Color("#f2eadc"), 0.8)
		penna.position.z = -0.075
		n.add_child(penna)
	n.visible = false
	n.position = da
	effetti.add_child(n)
	var alto := 0.3 + da.distance_to(a) * (0.2 if not quadrello else 0.06)
	proiettili.append({"n": n, "a": da, "b": a, "t": -ritardo, "dur": (0.75 if not quadrello else 0.5) / _vel(), "h": alto})


func _lampo(at: Vector3, c: Color, r := 0.03) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2
	sm.radial_segments = 8
	sm.rings = 4
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 1.5
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.position = at
	effetti.add_child(mi)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 2.6, 0.35 / _vel())
	tw.tween_property(m, "albedo_color:a", 0.0, 0.35 / _vel())
	tw.chain().tween_callback(mi.queue_free)


func _svanisci(mn: Node3D) -> void:
	if not is_instance_valid(mn):
		return
	var tw := mn.create_tween()
	tw.tween_property(mn, "scale", Vector3.ONE * 0.01, 0.3 / _vel())
	tw.tween_callback(mn.queue_free)


## Gli esiti dei colpi uno per uno: mura che fermano, protezioni che reggono, unità in rotta che cadono.
func esiti(d: Dictionary) -> void:
	var t: String = d["t"]
	if b.is_empty() or not reparti.has(t):
		return
	var r: Dictionary = reparti[t]
	var v := _vel()
	var lista: Array = d.get("esiti", [])
	var cadono := []
	for i in lista.size():
		var x: Dictionary = lista[i]
		var ritardo := i * 0.16 / v
		match x["x"]:
			"mura":
				var p := Vector3(muro_x, 0.22, randf_range(-1.2, 1.2))
				get_tree().create_timer(ritardo).timeout.connect(func(): if is_instance_valid(effetti): _lampo(p, Color("#f4ead2"), 0.05))
			"salvo":
				var m := _trova(r, x["u"], cadono)
				if m.is_empty():
					continue
				var mn: Node3D = m["n"]
				get_tree().create_timer(ritardo).timeout.connect(func():
					if is_instance_valid(mn):
						_lampo(mn.global_position + Vector3(0, 0.2, 0), Color("#e8f0ff"), 0.035)
						var tw := mn.create_tween()
						tw.tween_property(mn, "position:x", mn.position.x + _dir(r["s"]) * 0.025, 0.08)
						tw.tween_property(mn, "position:x", mn.position.x, 0.12))
			_:
				var m := _trova(r, x["u"], cadono)
				if m.is_empty():
					continue
				cadono.append(m)
				var mn: Node3D = m["n"]
				get_tree().create_timer(ritardo).timeout.connect(func(): _cade(mn, r["s"]))
	for m in cadono:
		r["mini"].erase(m)
	get_tree().create_timer(0.5 + lista.size() * 0.16 / v).timeout.connect(func():
		if reparti.has(t):
			_allinea_numero(t)
			_etichetta(t))


func _trova(r: Dictionary, u: String, esclusi: Array) -> Dictionary:
	var lista: Array = r["mini"]
	for i in range(lista.size() - 1, -1, -1):
		var m: Dictionary = lista[i]
		if m["u"] == u and not m in esclusi:
			return m
	return {}


func _cade(mn: Node3D, s: int) -> void:
	if not is_instance_valid(mn):
		return
	_anim(mn, "morte")
	_lampo(mn.global_position + Vector3(0, 0.12, 0), Color("#c0392b"), 0.04)
	var tw := mn.create_tween()
	tw.tween_property(mn, "rotation:z", _dir(s) * 1.45, 0.35 / _vel()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.5 / _vel())
	tw.tween_property(mn, "position:y", -0.08, 0.5 / _vel())
	tw.tween_callback(mn.queue_free)


## Fine della battaglia: i vincitori esultano, i vinti lasciano il campo.
func fine(bb: Dictionary) -> void:
	b = bb
	if b.is_empty():
		return
	var vince := -1
	for s in [0, 1]:
		if b.get("esito", "") == D.LATI[s]:
			vince = s
	for h in reparti:
		var r: Dictionary = reparti[h]
		if r["s"] == vince:
			for m in r["mini"]:
				var mn: Node3D = m["n"]
				_anim(mn, "attacco")
				var tw := mn.create_tween()
				tw.tween_interval(randf() * 0.3)
				for k in 2:
					tw.tween_property(mn, "position:y", 0.07, 0.16 / _vel()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
					tw.tween_property(mn, "position:y", 0.0, 0.16 / _vel()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		elif h != GUARN:
			_muovi(h, r["nodo"].position + Vector3(_dir(r["s"]) * 2.6, 0, 0), 2.2)


# ================================================================ ciclo

func _process(dt: float) -> void:
	if not is_visible_in_tree():
		return
	_t += dt
	var tenere := []
	for p in proiettili:
		var n: Node3D = p["n"]
		if not is_instance_valid(n):
			continue
		p["t"] += dt
		if p["t"] < 0.0:
			tenere.append(p)
			continue
		n.visible = true
		var k: float = clampf(p["t"] / p["dur"], 0.0, 1.0)
		var pos: Vector3 = p["a"].lerp(p["b"], k) + Vector3(0, 4.0 * p["h"] * k * (1.0 - k), 0)
		var dopo: Vector3 = p["a"].lerp(p["b"], minf(1.0, k + 0.02)) + Vector3(0, 4.0 * p["h"] * minf(1.0, k + 0.02) * (1.0 - minf(1.0, k + 0.02)), 0)
		n.position = pos
		if dopo.distance_to(pos) > 0.0001:
			n.look_at(dopo, Vector3.UP, true)
		if k >= 1.0:
			_lampo(pos, Color("#d8c8a8"), 0.02)
			n.queue_free()
		else:
			tenere.append(p)
	proiettili = tenere
	# passo: le miniature che si muovono ondeggiano
	for h in reparti:
		for m in reparti[h]["mini"]:
			var mn: Node3D = m["n"]
			if not is_instance_valid(mn):
				continue
			var c: Node3D = mn.get_node_or_null("corpo")
			if c == null or mn.has_meta("ap"):
				continue
			if mn.get_meta("passo", false):
				c.position.y = 0.012 + absf(sin(_t * 16.0 + float(mn.get_meta("fase", 0.0)))) * 0.012
			else:
				c.position.y = 0.012


func _aabb(n: Node, tr: Transform3D) -> AABB:
	var out := AABB()
	var primo := true
	var t2: Transform3D = tr * (n.transform if n is Node3D else Transform3D.IDENTITY)
	if n is MeshInstance3D and n.mesh != null:
		out = t2 * n.mesh.get_aabb()
		primo = false
	for c in n.get_children():
		var b2 := _aabb(c, t2)
		if b2.size != Vector3.ZERO:
			out = b2 if primo else out.merge(b2)
			primo = false
	return out


# ================================================================ comandi

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if ev.pressed:
			_touches[ev.index] = ev.position
		else:
			_touches.erase(ev.index)
		_pinch = {}
		accept_event()
		return
	if ev is InputEventScreenDrag:
		_touches[ev.index] = ev.position
		if _touches.size() == 1:
			_trascina(ev.relative)
		elif _touches.size() >= 2:
			var keys := _touches.keys()
			var a: Vector2 = _touches[keys[0]]
			var c: Vector2 = _touches[keys[1]]
			var mid := (a + c) * 0.5
			var dd := a.distance_to(c)
			var ang := (c - a).angle()
			if not _pinch.is_empty():
				dist = clampf(dist * _pinch["d"] / maxf(1.0, dd), 1.4, 9.0)
				yaw -= ang - _pinch["ang"]
				pitch = clampf(pitch + (mid.y - _pinch["mid"].y) * 0.004, 0.2, 1.45)
				_cam()
			_pinch = {"d": dd, "ang": ang, "mid": mid}
		accept_event()
		return
	if ev is InputEventMagnifyGesture:
		dist = clampf(dist / ev.factor, 1.4, 9.0)
		_cam()
		accept_event()
		return
	if ev is InputEventPanGesture:
		_trascina(-ev.delta * 12.0)
		accept_event()
		return
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			dist = clampf(dist / 1.12, 1.4, 9.0)
			_cam()
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			dist = clampf(dist * 1.12, 1.4, 9.0)
			_cam()
		accept_event()
	elif ev is InputEventMouseMotion and ev.button_mask != 0 and _touches.is_empty():
		if ev.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			yaw -= ev.relative.x * 0.006
			pitch = clampf(pitch + ev.relative.y * 0.004, 0.2, 1.45)
			_cam()
		else:
			_trascina(ev.relative)
		accept_event()


func _trascina(rel: Vector2) -> void:
	var k := dist * 0.0012
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	target -= right * rel.x * k
	target -= fwd * rel.y * k
	target.x = clampf(target.x, -3.0, 3.0)
	target.z = clampf(target.z, -2.0, 2.0)
	_cam()
