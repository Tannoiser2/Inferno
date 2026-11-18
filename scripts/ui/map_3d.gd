extends Control
## Vista 3D: la mappa della Toscana su un tavolo, in rilievo (colline e montagne si alzano, gli alberi
## sono piantati dove erano disegnati), con i modelli 3D di città, cittadine e castelli, i cilindri dei Signori con il loro stemma e le loro armate (cunei per la cavalleria,
## barre per la fanteria, nei colori del gioco), i segnalini come tessere.
## Comandi: un dito o il tasto sinistro trascinano; due dita pizzicano per lo zoom e ruotano;
## due dita in verticale o il tasto destro inclinano la vista; rotella per lo zoom.

const D = preload("res://scripts/data/inf_data.gd")
const PX := 1000.0
const W := 4096.0
const H := 3489.0

signal spot_pressed(id: String)
signal lord_pressed(id: String)

var e
var hot := {}
var sel_lord := ""
var svc: SubViewportContainer
var vp: SubViewport
var cam: Camera3D
var pieces: Node3D
var hot_node: Node3D
var yaw := 0.0
var pitch := 0.95
var dist := 4.2
var target := Vector3.ZERO
var _touches := {}
var _pinch := {}
var _press := Vector2.ZERO
var _moved := false
var _t := 0.0
var _dirty := true
var _mats := {}
var _lord_pos := {}


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
	en.ambient_light_energy = 0.36
	en.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = en
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -40, 0)
	sun.light_energy = 0.8
	sun.light_color = Color("#fff1d6")
	sun.shadow_enabled = true
	vp.add_child(sun)
	cam = Camera3D.new()
	cam.fov = 38
	vp.add_child(cam)
	# tavolo di legno
	var table := MeshInstance3D.new()
	var tm := PlaneMesh.new()
	tm.size = Vector2(9, 8)
	table.mesh = tm
	table.material_override = _mat(Color("#4a2f1c"), 0.85)
	table.position.y = -0.04
	vp.add_child(table)
	# la mappa in rilievo: colline e montagne si alzano, gli alberi disegnati diventano alberi veri
	_carica_rilievo()
	var board := MeshInstance3D.new()
	board.mesh = _mesh_terreno()
	var bmat := StandardMaterial3D.new()
	bmat.albedo_texture = UI.tex("res://assets/mappa/mappa_3d.jpg")
	bmat.albedo_color = Color(0.74, 0.73, 0.71)
	bmat.roughness = 1.0
	bmat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	board.material_override = bmat
	vp.add_child(board)
	var edge := MeshInstance3D.new()
	var em := BoxMesh.new()
	em.size = Vector3(W / PX + 0.03, 0.035, H / PX + 0.03)
	edge.mesh = em
	edge.material_override = _mat(Color("#2b1a10"), 0.8)
	edge.position.y = -0.019
	vp.add_child(edge)
	_pianta_alberi()
	_costruisci_citta()
	pieces = Node3D.new()
	vp.add_child(pieces)
	hot_node = Node3D.new()
	vp.add_child(hot_node)
	_cam()
	refresh()


func _mat(c: Color, rough := 0.7, tx: Texture2D = null) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if tx != null:
		m.albedo_texture = tx
	return m


func _mat_c(key: String, c: Color, rough := 0.7) -> StandardMaterial3D:
	if not _mats.has(key):
		_mats[key] = _mat(c, rough)
	return _mats[key]


func to3(p: Vector2, y := 0.0) -> Vector3:
	return Vector3((p.x - W * 0.5) / PX, altezza(p) + y, (p.y - H * 0.5) / PX)


# ================================================================ rilievo

const AL = preload("res://scripts/data/inf_alberi.gd")
const ESAGERA := 1.3
const GX := 320
const GZ := 272
var _ril: Image
var _rw := 1
var _rh := 1


func _carica_rilievo() -> void:
	_ril = (load("res://assets/mappa/rilievo.png") as Texture2D).get_image()
	if _ril.is_compressed():
		_ril.decompress()
	_rw = _ril.get_width()
	_rh = _ril.get_height()


## Altezza del terreno (in unità del mondo 3D) nel punto p della mappa (in pixel), interpolata.
func altezza(p: Vector2) -> float:
	if _ril == null:
		return 0.0
	var fx := clampf(p.x / W * (_rw - 1), 0.0, _rw - 1.001)
	var fy := clampf(p.y / H * (_rh - 1), 0.0, _rh - 1.001)
	var x0 := int(fx)
	var y0 := int(fy)
	var tx := fx - x0
	var ty := fy - y0
	var a := lerpf(_ril.get_pixel(x0, y0).r, _ril.get_pixel(x0 + 1, y0).r, tx)
	var b := lerpf(_ril.get_pixel(x0, y0 + 1).r, _ril.get_pixel(x0 + 1, y0 + 1).r, tx)
	return lerpf(a, b, ty) * AL.RILIEVO_MAX / PX * ESAGERA


func _mesh_terreno() -> ArrayMesh:
	var n := (GX + 1) * (GZ + 1)
	var vtx := PackedVector3Array()
	var nor := PackedVector3Array()
	var uv := PackedVector2Array()
	vtx.resize(n)
	nor.resize(n)
	uv.resize(n)
	var hs := PackedFloat32Array()
	hs.resize(n)
	for j in GZ + 1:
		for i in GX + 1:
			var p := Vector2(W * i / GX, H * j / GZ)
			hs[j * (GX + 1) + i] = altezza(p)
	var dx := W / GX / PX
	var dz := H / GZ / PX
	for j in GZ + 1:
		for i in GX + 1:
			var k := j * (GX + 1) + i
			var u := float(i) / GX
			var v := float(j) / GZ
			vtx[k] = Vector3((u - 0.5) * W / PX, hs[k], (v - 0.5) * H / PX)
			uv[k] = Vector2(u, v)
			var hl: float = hs[j * (GX + 1) + maxi(i - 1, 0)]
			var hr: float = hs[j * (GX + 1) + mini(i + 1, GX)]
			var hu: float = hs[maxi(j - 1, 0) * (GX + 1) + i]
			var hd: float = hs[mini(j + 1, GZ) * (GX + 1) + i]
			nor[k] = Vector3((hl - hr) / (2.0 * dx), 1.0, (hu - hd) / (2.0 * dz)).normalized()
	var idx := PackedInt32Array()
	idx.resize(GX * GZ * 6)
	var c := 0
	for j in GZ:
		for i in GX:
			var a := j * (GX + 1) + i
			var b := a + 1
			var d := a + GX + 1
			var e2 := d + 1
			idx[c] = a
			idx[c + 1] = b
			idx[c + 2] = d
			idx[c + 3] = b
			idx[c + 4] = e2
			idx[c + 5] = d
			c += 6
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vtx
	arr[Mesh.ARRAY_NORMAL] = nor
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## Gli alberi disegnati sulla mappa (tolti dalla texture) piantati in 3D: chiome tonde e cipressi.
func _pianta_alberi() -> void:
	var tondi := []
	var cipressi := []
	for a in AL.ALBERI:
		(tondi if a[0] == "tondo" else cipressi).append(a)
	var tronco := CylinderMesh.new()
	tronco.top_radius = 0.35
	tronco.bottom_radius = 0.5
	tronco.height = 1.0
	tronco.radial_segments = 6
	tronco.rings = 1
	var chioma := SphereMesh.new()
	chioma.radius = 0.5
	chioma.height = 1.0
	chioma.radial_segments = 10
	chioma.rings = 6
	var mt := _mat(Color("#5a3b22"), 0.9)
	var verdi := [_mat(Color("#62743a"), 0.9), _mat(Color("#475a2a"), 0.9)]
	for g in 2:
		var lista: Array = tondi if g == 0 else cipressi
		if lista.is_empty():
			continue
		var mm_t := MultiMesh.new()
		mm_t.transform_format = MultiMesh.TRANSFORM_3D
		mm_t.mesh = tronco
		mm_t.instance_count = lista.size()
		var mm_c := MultiMesh.new()
		mm_c.transform_format = MultiMesh.TRANSFORM_3D
		mm_c.mesh = chioma
		mm_c.instance_count = lista.size()
		for i in lista.size():
			var a: Array = lista[i]
			var base := to3(Vector2(a[1], a[2]))
			var w: float = a[3] / PX
			var hh: float = a[4] / PX
			var ht: float = hh * (0.55 if g == 0 else 0.18)
			var tw: float = w * (0.16 if g == 0 else 0.3)
			mm_t.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(tw, ht, tw)), base + Vector3(0, ht * 0.5, 0)))
			var cs := Vector3(w * 1.1, hh * 1.05, w * 1.1) if g == 0 else Vector3(w * 1.0, hh * 1.15, w * 1.0)
			var rot := Basis(Vector3.UP, float(i) * 1.7)
			mm_c.set_instance_transform(i, Transform3D(rot * Basis.from_scale(cs), base + Vector3(0, ht * 0.85 + cs.y * 0.5, 0)))
		var it := MultiMeshInstance3D.new()
		it.multimesh = mm_t
		it.material_override = mt
		vp.add_child(it)
		var ic := MultiMeshInstance3D.new()
		ic.multimesh = mm_c
		ic.material_override = verdi[g]
		vp.add_child(ic)


func to2(v: Vector3) -> Vector2:
	return Vector2(v.x * PX + W * 0.5, v.z * PX + H * 0.5)


func _cam() -> void:
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.position = target + off
	cam.look_at(target, Vector3.UP)


func rotate_by(a: float) -> void:
	yaw += a
	_cam()


func zoom_by(f: float) -> void:
	dist = clampf(dist / f, 0.5, 7.0)
	_cam()


func fit() -> void:
	yaw = 0.0
	pitch = 0.95
	dist = 4.2
	target = Vector3.ZERO
	_cam()


func focus(p: Vector2, _z := -1.0) -> void:
	target = to3(p)
	dist = minf(dist, 1.6)
	_cam()


# ================================================================ città, cittadine e castelli

## I modelli 3D di città, cittadine e castelli al posto dei disegni della mappa
## (larghezza in pixel di mappa, come il disegno originale). Gli avamposti restano disegnati.
const MODELLI := {"citta": ["res://assets/modelli/citta.glb", 270.0], "cittadina": ["res://assets/modelli/cittadina.glb", 200.0],
		"castello": ["res://assets/modelli/castello.glb", 110.0]}
var _alto := {}


func _costruisci_citta() -> void:
	var scene := {}
	for t in MODELLI:
		scene[t] = load(MODELLI[t][0])
		# la seconda versione del modello (<tipo>_b.glb), per varietà: metà delle località la usano
		var pb: String = MODELLI[t][0].replace(".glb", "_b.glb")
		if ResourceLoader.exists(pb):
			scene[t + "_b"] = load(pb)
	for l in D.LOCALI:
		var info: Dictionary = D.LOCALI[l]
		var t: String = info["tipo"]
		if not scene.has(t):
			_alto[l] = 0.0
			continue
		var n: Node3D = (scene[t + "_b"] if scene.has(t + "_b") and hash(l) % 2 == 1 else scene[t]).instantiate()
		var ab := _aabb(n, Transform3D.IDENTITY)
		var k: float = MODELLI[t][1] / PX / maxf(ab.size.x, 0.001)
		n.scale = Vector3.ONE * k
		var c := to3(info["pos"])
		n.position = c - Vector3((ab.position.x + ab.size.x * 0.5) * k, ab.position.y * k, (ab.position.z + ab.size.z * 0.5) * k)
		vp.add_child(n)
		_alto[l] = ab.size.y * k


func _aabb(n: Node, tr: Transform3D) -> AABB:
	var out := AABB()
	var primo := true
	var t2: Transform3D = tr * (n.transform if n is Node3D else Transform3D.IDENTITY)
	if n is MeshInstance3D and n.mesh != null:
		var b: AABB = t2 * n.mesh.get_aabb()
		out = b
		primo = false
	for c in n.get_children():
		var b2 := _aabb(c, t2)
		if b2.size != Vector3.ZERO:
			out = b2 if primo else out.merge(b2)
			primo = false
	return out


# ================================================================ pezzi

func refresh() -> void:
	_dirty = true


func _process(dt: float) -> void:
	_t += dt
	if _dirty and is_visible_in_tree():
		_dirty = false
		_ricostruisci()
	for c in hot_node.get_children():
		c.scale = Vector3.ONE * (1.0 + 0.12 * sin(_t * 5.0))


func _ricostruisci() -> void:
	for c in pieces.get_children():
		c.queue_free()
	for c in hot_node.get_children():
		c.queue_free()
	_lord_pos.clear()
	if e == null:
		return
	for l in D.LOCALI:
		_segnalini(l)
		_signori(l)
	for l in hot:
		var r := MeshInstance3D.new()
		var tm := TorusMesh.new()
		var rr: float = MODELLI[D.LOCALI[l]["tipo"]][1] * 0.5 / PX + 0.012 if MODELLI.has(D.LOCALI[l]["tipo"]) else 0.06
		tm.inner_radius = rr
		tm.outer_radius = rr + 0.014
		r.mesh = tm
		var m := _mat(UI.ORO_L, 0.3)
		m.emission_enabled = true
		m.emission = UI.ORO
		m.emission_energy_multiplier = 0.8
		r.material_override = m
		r.position = to3(D.LOCALI[l]["pos"], 0.004)
		hot_node.add_child(r)


func _tessera(tx: Texture2D, at: Vector3, s := 0.05, n := 1) -> void:
	for i in n:
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(s, 0.006, s)
		b.mesh = bm
		var m := _mat(Color.WHITE, 0.7, tx)
		b.material_override = m
		b.position = at + Vector3(0, 0.003 + i * 0.0065, 0)
		pieces.add_child(b)


func _segnalini(l: String) -> void:
	var x: Dictionary = e.loc[l]
	var p: Vector2 = D.LOCALI[l]["pos"]
	if x["all_n"] > 0:
		_tessera(UI.segnalino("alleanza_G" if x["all_l"] == 0 else "alleanza_H"), to3(p + Vector2(-75, -60)), 0.05, x["all_n"])
	if x["rovine"] >= 0:
		_tessera(UI.segnalino("rovine_G" if x["rovine"] == 0 else "rovine_H"), to3(p + Vector2(0, -70)), 0.05)
	if x["dev"] >= 0:
		_tessera(UI.segnalino("devastato_G" if x["dev"] == 0 else "devastato_H"), to3(p + Vector2(75, -60)), 0.05)
	if x["mura"] >= 0:
		_tessera(UI.segnalino("mura_G" if x["mura"] == 0 else "mura_H"), to3(p + Vector2(75, 10)), 0.045)
	if x["assedio"] > 0:
		_tessera(UI.segnalino("assedio"), to3(p + Vector2(-75, 15)), 0.05, x["assedio"])


func _signori(l: String) -> void:
	var ids: Array = e.signori_in(l, -1, false)
	if ids.is_empty():
		return
	var base: Vector2 = D.LOCALI[l]["pos"]
	var fuori := []
	var dentro := []
	for id in ids:
		if e.L[id]["dentro"]:
			dentro.append(id)
		else:
			fuori.append(id)
	for i in dentro.size():
		var id: String = dentro[i]
		var p := base + Vector2((i - (dentro.size() - 1) * 0.5) * 60, -20)
		_cilindro(id, to3(p, 0.09), true)
	for i in fuori.size():
		var id: String = fuori[i]
		var p := base + Vector2((i - (fuori.size() - 1) * 0.5) * 100, 110)
		_cilindro(id, to3(p), false)
		_armata(id, to3(p + Vector2(0, 70)))


func _cilindro(id: String, at: Vector3, piccolo: bool) -> void:
	var s: int = e.lato(id)
	var r := 0.036 if not piccolo else 0.026
	var h := 0.05 if not piccolo else 0.034
	var cyl := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cyl.mesh = cm
	cyl.material_override = _mat_c("lato%d" % s, UI.lato_col(s), 0.45)
	cyl.position = at + Vector3(0, h * 0.5, 0)
	pieces.add_child(cyl)
	# l'adesivo con lo stemma sul coperchio
	var top := MeshInstance3D.new()
	var qm := PlaneMesh.new()
	qm.size = Vector2(r * 1.9, r * 1.9)
	top.mesh = qm
	var tm := StandardMaterial3D.new()
	tm.albedo_texture = UI.stemma(id)
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	tm.roughness = 0.5
	top.material_override = tm
	top.position = at + Vector3(0, h + 0.0012, 0)
	pieces.add_child(top)
	# il Comune: secondo cilindro sotto il Comandante
	if e.comune(id) != "":
		var c2 := MeshInstance3D.new()
		var cm2 := CylinderMesh.new()
		cm2.top_radius = r * 1.15
		cm2.bottom_radius = r * 1.15
		cm2.height = h * 0.7
		c2.mesh = cm2
		c2.material_override = _mat_c("com%d" % s, UI.lato_col(s).darkened(0.3), 0.5)
		c2.position = at + Vector3(0, h * 0.35, 0)
		cyl.position.y += h * 0.7
		top.position.y += h * 0.7
		pieces.add_child(c2)
	if id == sel_lord or (e.sig_attivo == id and e.fase == "campagna"):
		var ring := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = r * 1.25
		tor.outer_radius = r * 1.55
		ring.mesh = tor
		var m := _mat(UI.ORO_L, 0.3)
		m.emission_enabled = true
		m.emission = UI.ORO
		ring.material_override = m
		ring.position = at + Vector3(0, 0.003, 0)
		pieces.add_child(ring)
	_lord_pos[id] = at


## Le armate: cunei (cavalleria) e barre (fanteria) nei colori del gioco, in file dietro al cilindro.
func _armata(id: String, at: Vector3) -> void:
	var f: Dictionary = e.L[id]["forze"]
	var lista := []
	for u in D.ORDINE_UNITA:
		for i in int(f.get(u, 0)):
			lista.append(u)
	var c = e.comune(id)
	if c != "":
		for u in D.ORDINE_UNITA:
			for i in int(e.L[c]["forze"].get(u, 0)):
				lista.append(u)
	var per_fila := 5
	for i in mini(lista.size(), 25):
		var u: String = lista[i]
		var col := i % per_fila
		var row := i / per_fila
		var p := at + Vector3((col - (per_fila - 1) * 0.5) * 0.018, 0, row * 0.02)
		var mi := MeshInstance3D.new()
		if D.UNITA[u]["cav"]:
			var pm := PrismMesh.new()
			pm.size = Vector3(0.015, 0.02, 0.014)
			mi.mesh = pm
			mi.position = p + Vector3(0, 0.01, 0)
		else:
			var bm := BoxMesh.new()
			bm.size = Vector3(0.016, 0.008, 0.009)
			mi.mesh = bm
			mi.position = p + Vector3(0, 0.004, 0)
		mi.material_override = _mat_c("u_" + u, D.UNITA[u]["col"], 0.6)
		pieces.add_child(mi)


# ================================================================ input

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if ev.pressed:
			_touches[ev.index] = ev.position
			if _touches.size() == 1:
				_press = ev.position
				_moved = false
			_pinch = {}
		else:
			var tap: bool = _touches.size() == 1 and not _moved and ev.position.distance_to(_press) < 14.0
			_touches.erase(ev.index)
			_pinch = {}
			if tap:
				_click(ev.position)
		accept_event()
		return
	if ev is InputEventScreenDrag:
		_touches[ev.index] = ev.position
		if _touches.size() == 1:
			if ev.position.distance_to(_press) > 10.0:
				_moved = true
			if _moved:
				_trascina(ev.relative)
		elif _touches.size() >= 2:
			_moved = true
			var keys := _touches.keys()
			var a: Vector2 = _touches[keys[0]]
			var b: Vector2 = _touches[keys[1]]
			var mid := (a + b) * 0.5
			var d := a.distance_to(b)
			var ang := (b - a).angle()
			if not _pinch.is_empty():
				dist = clampf(dist * _pinch["d"] / maxf(1.0, d), 0.5, 7.0)
				yaw -= ang - _pinch["ang"]
				pitch = clampf(pitch + (mid.y - _pinch["mid"].y) * 0.004, 0.3, 1.45)
				_cam()
			_pinch = {"d": d, "ang": ang, "mid": mid}
		accept_event()
		return
	if ev is InputEventMagnifyGesture:
		zoom_by(ev.factor)
		accept_event()
		return
	if ev is InputEventPanGesture:
		_trascina(-ev.delta * 12.0)
		accept_event()
		return
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			zoom_by(1.12)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			zoom_by(1.0 / 1.12)
		elif ev.pressed:
			_press = ev.position
			_moved = false
		elif ev.button_index == MOUSE_BUTTON_LEFT and not _moved and _touches.is_empty():
			_click(ev.position)
		accept_event()
	elif ev is InputEventMouseMotion and ev.button_mask != 0 and _touches.is_empty():
		if ev.position.distance_to(_press) > 6.0:
			_moved = true
		if ev.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			yaw -= ev.relative.x * 0.006
			pitch = clampf(pitch + ev.relative.y * 0.004, 0.3, 1.45)
			_cam()
		elif _moved:
			_trascina(ev.relative)
		accept_event()


func _trascina(rel: Vector2) -> void:
	var k := dist * 0.0011
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	target -= right * rel.x * k
	target -= fwd * rel.y * k
	target.x = clampf(target.x, -2.2, 2.2)
	target.z = clampf(target.z, -2.0, 2.0)
	_cam()


func _click(s: Vector2) -> void:
	var sz := vp.size
	var sp := s * Vector2(sz) / size
	var from := cam.project_ray_origin(sp)
	var dir := cam.project_ray_normal(sp)
	# prima i cilindri
	var best := ""
	var bd := 0.04
	for id in _lord_pos:
		var p: Vector3 = _lord_pos[id] + Vector3(0, 0.02, 0)
		var t := (p - from).dot(dir)
		var dd := (from + dir * t).distance_to(p)
		if dd < bd:
			bd = dd
			best = id
	if abs(dir.y) < 0.0001:
		return
	var t0 := -from.y / dir.y
	var hit := from + dir * t0
	for _i in 4:
		var hy := altezza(to2(hit))
		hit = from + dir * ((hy - from.y) / dir.y)
	var m := to2(hit)
	var bl := ""
	var bld := 85.0
	for l in hot:
		var dd: float = m.distance_to(D.LOCALI[l]["pos"])
		if dd < bld:
			bld = dd
			bl = l
	if bl != "":
		spot_pressed.emit(bl)
	elif best != "":
		lord_pressed.emit(best)
