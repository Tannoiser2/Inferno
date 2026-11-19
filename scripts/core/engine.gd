class_name InfEngine
extends InfBattaglia
## Motore delle regole di Inferno (Leva e Campagna, vol. III): preparazione degli scenari, Leva
## (Arte della Guerra, Paga, Smobilitazione, Raduno, Chiamata alle Armi), Campagna (piano, comandi,
## Nutrire/Pagare/Smobilitare) e fine del turno. Senza grafica: l'interfaccia ascolta i segnali.


# ================================================================ preparazione

var _da_rimettere := {}
## Lezione preparata del tutorial («battaglia»): niente scenario, solo gli scontri.
var lezione := ""


func setup(cfg: Dictionary) -> void:
	players = cfg.get("seats", [{"name": "", "ai": false}, {"name": "", "ai": true}])
	scen = str(cfg.get("scen", "F"))
	S = D.SCENARI[scen]
	if cfg.has("seed"):
		rng.seed = int(cfg["seed"])
	else:
		rng.randomize()
	seme = rng.seed
	ai_delay = float(cfg.get("ai_delay", 0.5))
	anim = float(cfg.get("anim", 1.0))
	replay = cfg.get("replay", [])
	lezione = str(cfg.get("lezione", ""))
	ais.resize(2)
	for s in 2:
		var a := InfAI.new()
		a.level = int(players[s].get("level", 1))
		a.strategia = bool(players[s].get("strategia", true))
		# l'IA esperta prova in anticipo le mosse importanti simulando la partita (mai dentro una simulazione)
		a.simula = bool(players[s].get("simula", a.level >= 2)) and not in_sim
		if players[s].has("consigli"):
			a.consigli = players[s]["consigli"]
		ais[s] = a
	costruisci_adiacenze()
	pool.clear()
	for u in D.UNITA:
		pool[u] = int(D.UNITA[u]["pool"])
	loc.clear()
	for l in D.LOCALI:
		loc[l] = {"all_l": -1, "all_n": 0, "rovine": -1, "dev": -1, "mura": -1, "assedio": 0, "assedio_l": -1}
	L.clear()
	for id in D.SIGNORI:
		L[id] = {"id": id, "stato": "rimosso" if comune_di(id) == "" else "fuori", "loc": "", "cal": 17, "svc": 0,
			"forze": {}, "rotte": {}, "supp": {}, "caps": [], "dentro": false, "aggira": false, "mosso": false,
			"radunato_ora": false, "prima_carta": true, "evitato": false}
	V.clear()
	for v in D.VASSALLI:
		V[v] = {"presso": D.VASSALLI[v]["sig"], "stato": "fuori" if D.VASSALLI[v].get("speciale", "") == "altopascio" else "pronto"}
	turno = int(S["da"])
	turno_fine = int(S["a"])
	if S.get("esaurimento", false):
		turno_fine = 16
	# scenario
	for id in S["cal"]:
		L[id]["stato"] = "cal"
		L[id]["cal"] = int(S["cal"][id])
	for id in S["mappa"]:
		_metti_in_gioco(id, S["mappa"][id])
		L[id]["svc"] = int(S["servizio"].get(id, turno + int(D.SIGNORI[id]["serv"])))
	for id in S["servizio"]:
		if L[id]["stato"] == "mappa":
			L[id]["svc"] = int(S["servizio"][id])
	for l in S.get("alleanza", {}):
		loc[l]["all_l"] = int(S["alleanza"][l][0])
		loc[l]["all_n"] = int(S["alleanza"][l][1])
	for l in S.get("devastato", {}):
		loc[l]["dev"] = int(S["devastato"][l])
	for l in S.get("rovine", {}):
		loc[l]["rovine"] = int(S["rovine"][l])
	for l in S.get("assedio", {}):
		loc[l]["assedio_l"] = int(S["assedio"][l][0])
		loc[l]["assedio"] = int(S["assedio"][l][1])
	for id in S.get("monete", {}):
		add_supp(id, "moneta", int(S["monete"][id]))
	# carte
	for s in 2:
		mazzo_aow[s] = []
		var p := "G" if s == 0 else "H"
		for i in range(1, 27):
			mazzo_aow[s].append("%s%02d" % [p, i])
	for s in S.get("tenute", {}):
		for c in S["tenute"][s]:
			tenute[int(s)].append(c)
			mazzo_aow[int(s)].erase(c)
	for s in S.get("capacita", {}):
		for c in S["capacita"][s]:
			mazzo_aow[int(s)].erase(c)
			if D.CARTE[c]["cap_lord"]:
				var chi := _cap_assegnabile(c, int(s))
				if not chi.is_empty():
					L[chi[0]]["caps"].append(c)
			else:
				cap_lato[int(s)].append(c)
	maremma_blocco = S.get("maremma", false)
	prima_leva = true


func _metti_in_gioco(id: String, l: String) -> void:
	var x: Dictionary = L[id]
	x["stato"] = "mappa"
	x["loc"] = l
	x["forze"] = {}
	x["rotte"] = {}
	x["supp"] = {}
	x["caps"] = []
	x["dentro"] = false
	x["aggira"] = false
	x["mosso"] = false
	x["evitato"] = false
	x["prima_carta"] = true
	prendi_unita(id, D.SIGNORI[id]["forze"])
	for k in D.SIGNORI[id]["supp"]:
		add_supp(id, k, int(D.SIGNORI[id]["supp"][k]))
	for v in D.SIGNORI[id]["vassalli"]:
		if V.has(v) and V[v]["stato"] != "fuori" and V[v]["presso"] == id:
			V[v]["stato"] = "pronto"
	# se la località è un Caposaldo amico assediato dal nemico il Signore è dentro
	if caposaldo(l) and amica(l, lato(id)) and assediata_da(l, 1 - lato(id)):
		x["dentro"] = true
	x["svc"] = mini(17, turno + int(D.SIGNORI[id]["serv"]))


# ================================================================ partita

func run() -> void:
	changed.emit()
	await _pace(0.4)
	if lezione == "battaglia":
		await _lezione_battaglia()
		return
	log_msg("Scenario %s — %s." % [S["nome"], S["sotto"]])
	if S.get("resistenza", false):
		for id in ["lucca", "arezzo"]:
			if sulla_mappa(id):
				log_msg("Resistenza: %s effettua un Raduno extra." % nome(id))
				await _raduno_signore(id, 0)
	while not over and not abort:
		await _leva()
		if over or abort:
			break
		await _campagna()
		if over or abort:
			break
		await _fine_campagna()
		if over or abort:
			break
		if turno >= limite_turno:
			abort = true
			break
		turno += 1
		prima_leva = false
	if abort:
		return
	_fine_partita()


## La battaglia guidata: una battaglia campale a Monteriggioni, poi l'Assalto al castello di Casole.
func _lezione_battaglia() -> void:
	fase = "campagna"
	for id in L:
		if L[id]["stato"] == "mappa":
			L[id]["stato"] = "rimosso"
	var guelfi := ["firenze", "colle", "arezzo"]
	var ghib := ["siena", "giordano"]
	for id in guelfi + ghib:
		_metti_in_gioco(id, "monteriggioni")
		L[id]["svc"] = turno + 3
	# i Guelfi hanno radunato i loro Vassalli: sono più numerosi, i Ghibellini hanno i Ritter
	prendi_unita("firenze", {"cav": 2, "arm": 2, "mil": 1})
	prendi_unita("arezzo", {"uia": 1, "arm": 1})
	prendi_unita("siena", {"arm": 1, "mil": 1})
	changed.emit()
	log_msg("Battaglia guidata: i Guelfi di Firenze, Colle e Arezzo attaccano i Ghibellini di Siena a Monteriggioni.")
	await _pace(1.0)
	await battaglia_campale("monteriggioni", 0, "firenze", "")
	if abort:
		return
	await _pace(2.0)
	# l'Assalto: i Guelfi, di nuovo in forze, assediano da due carte il castello di Casole
	for id in ghib:
		if L[id]["stato"] == "mappa":
			L[id]["stato"] = "rimosso"
	for id in guelfi:
		_metti_in_gioco(id, "casole")
		L[id]["svc"] = turno + 3
	prendi_unita("firenze", {"cav": 2, "arm": 2, "uia": 1})
	loc["casole"]["assedio"] = 3
	loc["casole"]["assedio_l"] = 0
	changed.emit()
	log_msg("Assalto guidato: i Guelfi assediano Casole (Assedio 3) e danno l'assalto alle mura.")
	await _pace(1.0)
	await assalto("casole", 0, "firenze")
	if abort:
		return
	result = {"vince": -1, "motivo": "Fine della battaglia guidata."}
	_fine_partita()


func _fine_partita() -> void:
	if fase == "fine":
		return
	fase = "fine"
	if result.is_empty():
		var g := pv(0)
		var h := pv(1)
		var v := -1
		if g > h:
			v = 0
		elif h > g:
			v = 1
		result = {"vince": v, "motivo": "Fine dello scenario: Guelfi %s PV, Ghibellini %s PV." % [pv_testo(0), pv_testo(1)]}
	result["pv"] = [pv(0), pv(1)]
	over = true
	log_msg("FINE DELLA PARTITA. " + str(result["motivo"]))
	changed.emit()
	game_ended.emit(result)


# ================================================================ LEVA (3.0)

func _leva() -> void:
	fase = "leva"
	passo = "Leva"
	bonus_sign.clear()
	guerra = [false, false]
	tesori = [false, false]
	for id in L:
		L[id]["radunato_ora"] = false
	log_msg("— Turno %d, %s: LEVA —" % [turno, D.MESI[turno]])
	fx.emit("turno", {"turno": turno})
	changed.emit()
	# Esaurimento (scenario F): il segnalino Fine entra al 16 e poi si sposta a sinistra
	if S.get("esaurimento", false) and turno >= 9:
		var x := d6()
		if x <= 3:
			fine_box = 16 if fine_box < 0 else fine_box - 1
			log_msg("Esaurimento (dado %d): il segnalino Fine è nella casella %d." % [x, fine_box])
		else:
			log_msg("Esaurimento (dado %d): nessun effetto." % x)
		if fine_box > 0 and fine_box <= turno:
			log_msg("La guerra si spegne per esaurimento.")
			_fine_partita()
			return
		if fine_box > 0:
			turno_fine = mini(16, fine_box)
	# Arte della Guerra
	passo = "Arte della Guerra"
	for s in [0, 1]:
		await _arte_della_guerra(s)
		if over:
			return
	# Paga
	passo = "Paga"
	for s in [0, 1]:
		await _paga(s, true)
	# Smobilitazione
	passo = "Smobilitazione"
	for s in [0, 1]:
		await _smobilita(s)
	if over:
		return
	# Raduno
	passo = "Raduno"
	for s in [0, 1]:
		await _held_leva(s)
		await _raduno(s)
	# Chiamata alle Armi
	passo = "Chiamata alle Armi"
	await _chiamata_alle_armi()
	for e in ev_attivi.duplicate():
		if e["fino"] == "leva":
			ev_attivi.erase(e)
			_scarta_evento(e["id"])
	changed.emit()


# ---------------------------------------------------------------- Arte della Guerra (3.1)

func _arte_della_guerra(s: int) -> void:
	var mazzo: Array = mazzo_aow[s]
	_mescola(mazzo)
	var improvvisa: bool = prima_leva and S.get("campagna_improvvisa", false)
	var pescate := []
	for i in 2:
		if mazzo.is_empty():
			break
		var c: String = mazzo.pop_back()
		pescate.append(c)
		var come_cap := prima_leva and not (improvvisa and i == 1)
		if come_cap:
			await _pesca_capacita(s, c)
		else:
			await _pesca_evento(s, c)
		changed.emit()
	# gli Eventi immediati tornano nel mazzo solo dopo entrambe le pesche
	for c in pescate:
		if _da_rimettere.has(c):
			_da_rimettere.erase(c)
			if not c in mazzo:
				mazzo.append(c)


func _mescola(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


## Signori a cui si può assegnare una Capacità «Questo Signore».
func _cap_assegnabile(c: String, s: int) -> Array:
	var out := []
	var chi = D.CARTE[c]["cap_chi"]
	for id in signori_mappa(s, true):
		var base = id if comune_di(id) == "" else comune_di(id)
		if chi is Array and not base in chi:
			continue
		var stessi := false
		for k in L[id]["caps"]:
			if D.CARTE[k]["cap"] == D.CARTE[c]["cap"]:
				stessi = true
		if stessi:
			continue
		out.append(id)
	return out


func _pesca_capacita(s: int, c: String) -> void:
	var card: Dictionary = D.CARTE[c]
	if not card["cap_lord"]:
		cap_lato[s].append(c)
		log_msg("I %s pescano la Capacità «%s»." % [D.LATI[s], card["cap"]])
		fx.emit("carta", {"id": c, "lato": s, "cap": true})
		return
	var chi := _cap_assegnabile(c, s)
	if chi.is_empty():
		_da_rimettere[c] = true
		log_msg("I %s pescano «%s», ma nessun Signore può usarla: è scartata." % [D.LATI[s], card["cap"]])
		return
	var o := []
	for id in chi:
		o.append(opz(id, nome(id), {"sig": id}))
	var r := await scegli(s, "cap_a_chi", "Capacità «%s»" % card["cap"], card["cap_x"] + " A quale Signore?", o, {"auto1": true, "carta": c})
	await _assegna_cap(r, c)
	log_msg("I %s pescano la Capacità «%s» per %s." % [D.LATI[s], card["cap"], nome(r)])
	fx.emit("carta", {"id": c, "lato": s, "cap": true})


func _assegna_cap(id: String, c: String) -> void:
	L[id]["caps"].append(c)
	if L[id]["caps"].size() > 2:
		var o := []
		for k in L[id]["caps"]:
			o.append(opz(k, D.CARTE[k]["cap"], {"carta": k}))
		var r := await scegli(lato(id), "scarta_cap", "Troppe Capacità", "%s può tenere solo 2 Capacità: quale scarti?" % nome(id), o)
		L[id]["caps"].erase(r)
		_scarta_evento(r)


func _pesca_evento(s: int, c: String) -> void:
	var card: Dictionary = D.CARTE[c]
	fx.emit("carta", {"id": c, "lato": s, "cap": false})
	match card["ev_t"]:
		"tenere":
			tenute[s].append(c)
			log_msg("I %s pescano un Evento e lo tengono nascosto." % D.LATI[s])
			return
		"campagna":
			ev_attivi.append({"id": c, "lato": s, "fino": "campagna"})
			log_msg("Evento dei %s: «%s» (questa Campagna)." % [D.LATI[s], card["ev"]])
			match c:
				"G05":
					lavori[0] = true
				"H05":
					lavori[1] = true
				"H14":
					frati = true
				"H23":
					no_tasse[0] = true
			return
	log_msg("Evento dei %s: «%s»." % [D.LATI[s], card["ev"]])
	await _evento_subito(s, c)
	if card["ev_t"] == "guerra":
		guerra[s] = true
	_da_rimettere[c] = true


## Sposta un Signore «a favore» (cilindro a sinistra o Servizio a destra) o «contro».
func _sposta(id: String, n: int, favore: bool) -> void:
	if not L.has(id):
		return
	var x: Dictionary = L[id]
	if x["stato"] == "mappa":
		sposta_servizio(id, n if favore else -n)
	elif x["stato"] == "cal":
		sposta_cilindro(id, -n if favore else n)


func _evento_subito(s: int, c: String) -> void:
	var e := 1 - s
	match c:
		"G02", "H02":
			for l in loc:
				if assediata_da(l, s):
					var r := await scegli(s, "ev_scelta", "Tradimenti", "Assedio a %s: tirare sulla Rivolta o aggiungere 1 Tradimento?" % lnome(l),
						[opz("rivolta", "Tira sulla Rivolta"), opz("trad", "Aggiungi 1 Tradimento")])
					if r == "rivolta":
						await tiro_rivolta(s)
					else:
						await aggiungi_tradimento(s, 1)
		"G09", "G13":
			var chi := ["firenze", "lucca", "colle"] if c == "G09" else ["firenze", "arezzo", "lucca"]
			var r := await scegli(s, "ev_scelta", D.CARTE[c]["ev"], D.CARTE[c]["ev_x"],
				[opz("sposta", "Sposta i tre Signori di 1 casella"), opz("trad", "Aggiungi 1 loro Tradimento")])
			if r == "sposta":
				for id in chi:
					_sposta(id, 1, true)
			else:
				await aggiungi_tradimento(s, 1, chi)
		"G10", "H22":
			# Cancelli chiusi: prima le Rovine che danno punti al nemico
			var nem := []
			var mie := []
			for l in loc:
				if loc[l]["rovine"] == e:
					nem.append(l)
				elif loc[l]["rovine"] == s:
					mie.append(l)
			if not nem.is_empty():
				var o := []
				for l in nem:
					o.append(opz(l, lnome(l), {"loc": l}))
				var r := await scegli(s, "ev_loc", "Cancelli chiusi", "Quale Rovina nemica rimuovi?", o, {"auto1": true})
				loc[r]["rovine"] = -1
				log_msg("Cancelli chiusi: %s è ricostruita." % lnome(r))
			elif not mie.is_empty():
				var o := []
				for l in mie:
					o.append(opz(l, lnome(l), {"loc": l}))
				var r := await scegli(s, "ev_loc", "Cancelli chiusi", "Quale tua Rovina rimuovi (il Caposaldo poi si ribella se può)?", o, {"auto1": true})
				loc[r]["rovine"] = -1
				if not amica(r, s) and disponibile_rivolta(r):
					cambia_alleanza(r, s)
				log_msg("Cancelli chiusi: %s riapre le porte." % lnome(r))
		"G14":
			var assedio := false
			for l in loc:
				if assediata_da(l, 0):
					assedio = true
			if assedio:
				var r := await scegli(s, "ev_scelta", "Provenzano", D.CARTE[c]["ev_x"],
					[opz("sposta", "Sposta Provenzano di 2 caselle"), opz("trad", "Aggiungi 1 Tradimento")])
				if r == "sposta":
					_sposta("provenzano", 2, false)
				else:
					await aggiungi_tradimento(s, 1)
		"G17":
			var o := [opz("guido", "Servizio di Guido Guerra +2"), opz("orvieto", "Servizio di Orvieto +2")]
			if not tradimento[0].is_empty():
				o.append(opz("cil", "Metti da parte 1 Tradimento: Guido e Orvieto pronti subito"))
			var r := await scegli(s, "ev_scelta", "Aiuto straniero", D.CARTE[c]["ev_x"], o)
			if r == "cil":
				tradimento[0].pop_back()
				for id in ["guido", "orvieto"]:
					if L[id]["stato"] == "cal" and L[id]["cal"] > turno:
						L[id]["cal"] = turno
			elif sulla_mappa(r):
				sposta_servizio(r, 2)
			else:
				_sposta(r, 2, true)
		"G20", "H20":
			var st: String = D.STAGIONE[turno]
			if st in ["E", "I"]:
				for id in signori_mappa(e, true):
					_spreco_uno(id)
				if st == "E":
					if c == "G20":
						for id in signori_mappa(1):
							if togli_unita(id, "ritter") > 0:
								log_msg("Il caldo uccide un Ritter di %s." % nome(id))
								break
					elif sulla_mappa("guido"):
						for u in ["mil", "arm", "cav"]:
							if togli_unita("guido", u) > 0:
								log_msg("Il caldo costa un'unità a Guido Guerra.")
								break
				log_msg("Caldo e gelo: i %s perdono parte dei rifornimenti." % D.LATI[e])
		"G21":
			var r := await scegli(s, "ev_scelta", "Primo Popolo", D.CARTE[c]["ev_x"],
				[opz("firenze", "Firenze di 2 caselle"), opz("arezzo", "Arezzo di 2 caselle"), opz("trad", "Aggiungi 1 Tradimento di Firenze o Arezzo")])
			if r == "trad":
				await aggiungi_tradimento(s, 1, ["firenze", "arezzo"])
			else:
				_sposta(r, 2, true)
		"G22":
			var o := []
			for id in ["provenzano", "giordano", "astimberg"]:
				if L[id]["stato"] in ["mappa", "cal"]:
					o.append(opz("s:" + id, "Sposta %s di 1 casella" % nome(id), {"sig": id}))
					if sulla_mappa(id):
						o.append(opz("x:" + id, "Togli 3 Supporti a %s" % nome(id), {"sig": id}))
			if not o.is_empty():
				var r := await scegli(s, "ev_scelta", "Manfredi si tiene indietro", D.CARTE[c]["ev_x"], o)
				var id := r.substr(2)
				if r.begins_with("s:"):
					_sposta(id, 1, false)
				else:
					for i in 3:
						_spreco_uno(id, true)
		"H09":
			var o := [opz("orvieto", "Orvieto di 3 caselle")]
			if not tradimento[1].is_empty():
				o.push_front(opz("due", "Metti da parte 1 Tradimento: due Signori guelfi di 1 casella"))
			var r := await scegli(s, "ev_scelta", "Il Papa all'angolo", D.CARTE[c]["ev_x"], o)
			if r == "orvieto":
				_sposta("orvieto", 3, false)
			else:
				tradimento[1].pop_back()
				var cand := []
				for id in D.SIGNORI_LATO[0]:
					if L[id]["stato"] in ["mappa", "cal"]:
						cand.append(id)
				cand.sort_custom(func(a, b): return _peso_signore(a) > _peso_signore(b))
				for id in cand.slice(0, 2):
					_sposta(id, 1, false)
		"H10", "H15":
			var chi := ["provenzano", "giordano", "astimberg", "santa_fiora"] if c == "H10" else ["provenzano", "siena", "giordano", "astimberg"]
			var o := []
			for id in chi:
				if L[id]["stato"] in ["mappa", "cal"]:
					o.append(opz("s:" + id, "%s di %d caselle" % [nome(id), 1 if c == "H10" else 2], {"sig": id}))
			for id in signori_mappa(1):
				o.append(opz("b:" + id, "Signoria +2 a %s" % nome(id), {"sig": id}))
			if not o.is_empty():
				var r := await scegli(s, "ev_scelta", D.CARTE[c]["ev"], D.CARTE[c]["ev_x"], o)
				if r.begins_with("b:"):
					bonus_sign[r.substr(2)] = int(bonus_sign.get(r.substr(2), 0)) + 2
				else:
					_sposta(r.substr(2), 1 if c == "H10" else 2, true)
					if c == "H10":
						for id in chi:
							if id != r.substr(2) and L[id]["stato"] in ["mappa", "cal"]:
								_sposta(id, 1, true)
								break
		"H11":
			if amica("volterra", 1):
				var r := await scegli(s, "ev_scelta", "Volterra", D.CARTE[c]["ev_x"],
					[opz("colle", "Servizio di Colle -2"), opz("pisa", "Pisa pronta subito"), opz("trad", "Aggiungi 1 Tradimento")])
				match r:
					"colle":
						_sposta("colle", 2, false)
					"pisa":
						if L["pisa"]["stato"] == "cal":
							L["pisa"]["cal"] = mini(L["pisa"]["cal"], turno)
					"trad":
						await aggiungi_tradimento(s, 1)
		"H13":
			await _riscatto(1, true)
		"H21":
			var r := await scegli(s, "ev_scelta", "Constituto", D.CARTE[c]["ev_x"],
				[opz("s:siena", "Siena di 2 caselle"), opz("s:pisa", "Pisa di 2 caselle"), opz("b:siena", "Signoria +3 a Siena"), opz("b:pisa", "Signoria +3 a Pisa")])
			if r.begins_with("b:"):
				bonus_sign[r.substr(2)] = int(bonus_sign.get(r.substr(2), 0)) + 3
			else:
				_sposta(r.substr(2), 2, true)
		"H25":
			var ok := not amica("grosseto", 1)
			for v in vicine("grosseto"):
				if D.LOCALI[v]["tipo"] == "castello" and loc[v]["all_n"] > 0 and loc[v]["all_l"] == 0:
					ok = true
			if ok:
				var n := 0
				for id in D.SIGNORI_LATO[1]:
					if n < 3 and L[id]["stato"] in ["mappa", "cal"]:
						_sposta(id, 1, true)
						n += 1
		"H26":
			var ok := false
			for l in loc:
				if D.LOCALI[l]["tipo"] in ["citta", "cittadina"] and loc[l]["all_n"] > 0 and loc[l]["all_l"] == 0:
					ok = true
			if ok:
				_sposta("siena", 1, true)
				_sposta("provenzano", 1, true)
		"G25":
			for l in loc:
				if D.LOCALI[l]["tipo"] == "castello" and loc[l]["all_n"] > 0 and loc[l]["all_l"] == 0:
					_sposta("colle", 3, true)
					break
		"G26":
			for l in loc:
				if D.LOCALI[l]["tipo"] == "cittadina" and loc[l]["all_n"] > 0 and loc[l]["all_l"] == 0:
					for id in ["firenze", "arezzo", "orvieto"]:
						_sposta(id, 1, true)
					break


func _peso_signore(id: String) -> float:
	if sulla_mappa(id):
		return forza(id) + 5.0
	return float(D.SIGNORI[id]["cmd"])


func _spreco_uno(id: String, anche_uno := false) -> void:
	var best := ""
	var bn := 1 if not anche_uno else 0
	for k in ["prov", "bottino", "carro", "moneta", "nave"]:
		if supp(id, k) > bn:
			bn = supp(id, k)
			best = k
	if best != "":
		add_supp(id, best, -1)


## Eventi tenuti che si possono usare all'inizio del Raduno.
func _held_leva(s: int) -> void:
	for c in tenute[s].duplicate():
		var opzioni := []
		match c:
			"G11":
				if amica("poggio_bonizio", 0):
					for id in signori_mappa(0):
						opzioni.append(opz("b:" + id, "Signoria +3 a %s" % nome(id), {"sig": id}))
					opzioni.append(opz("trad", "Aggiungi 1 Tradimento"))
			"G15":
				opzioni.append(opz("trad", "Aggiungi il Tradimento di Firenze"))
			"G18":
				if amica("grosseto", 0):
					opzioni.append(opz("santa_fiora", "Sposta Santa Fiora di 2 caselle"))
			"G19":
				if amica("volterra", 0):
					opzioni.append(opz("pisa", "Sposta Pisa di 2 caselle"))
			"H18":
				if amica("cortona", 1):
					opzioni.append(opz("rivolta", "Tira sulla tabella della Rivolta"))
					opzioni.append(opz("trad", "Aggiungi 1 Tradimento"))
			"G23":
				opzioni.append(opz("trad", "Aggiungi 1 Tradimento"))
			"H17":
				if sulla_mappa("provenzano") or sulla_mappa("santa_fiora"):
					for id in ["provenzano", "santa_fiora"]:
						if L[id]["stato"] in ["mappa", "cal"]:
							opzioni.append(opz("s:" + id, "Sposta %s di 2 caselle" % nome(id)))
					opzioni.append(opz("sign", "Signoria +2 a Provenzano e Santa Fiora"))
					opzioni.append(opz("trad", "Aggiungi un loro Tradimento"))
		if opzioni.is_empty():
			continue
		opzioni.append(opz("no", "Tieni la carta"))
		var r := await scegli(s, "evento", D.CARTE[c]["ev"], "Evento tenuto: %s Usarlo ora?" % D.CARTE[c]["ev_x"], opzioni)
		if r == "no":
			continue
		tenute[s].erase(c)
		_scarta_evento(c)
		log_msg("I %s giocano «%s»." % [D.LATI[s], D.CARTE[c]["ev"]])
		if r.begins_with("b:"):
			bonus_sign[r.substr(2)] = int(bonus_sign.get(r.substr(2), 0)) + 3
		elif r == "trad":
			var solo := []
			if c == "G15":
				solo = ["firenze"]
			elif c == "H17":
				solo = ["provenzano", "santa_fiora"]
			await aggiungi_tradimento(s, 1, solo)
		elif r == "rivolta":
			await tiro_rivolta(s)
		elif r == "sign":
			for id in ["provenzano", "santa_fiora"]:
				bonus_sign[id] = int(bonus_sign.get(id, 0)) + 2
		elif r.begins_with("s:"):
			_sposta(r.substr(2), 2, true)
		elif r in ["santa_fiora", "pisa"]:
			_sposta(r, 2, false)


# ---------------------------------------------------------------- Paga (3.2)

func _paga(s: int, leva: bool) -> void:
	var giri := 0
	while giri < 30:
		giri += 1
		var o := []
		for id in signori_mappa(s, true):
			var mon := supp(id, "moneta")
			var bot := supp(id, "bottino") if (amica(L[id]["loc"], s) and not assediato(id) and loc[L[id]["loc"]]["assedio"] == 0) else 0
			if mon + bot == 0:
				continue
			for t in signori_in(L[id]["loc"], s, false):
				if not sulla_mappa(t) or comune_di(t) != "":
					continue
				var costo := 2 if podesta(t) else 1
				if L[t]["svc"] >= 17:
					continue
				var k := "moneta" if mon >= costo else ("bottino" if bot >= costo else "")
				if mon > 0 and mon < costo and mon + bot >= costo:
					k = "misto"
				if k == "":
					continue
				o.append(opz("%s>%s>%s" % [id, t, k], "%s paga %s: Servizio di %s +1 (ora fino al turno %d)" % [nome(id),
					"%d %s" % [costo, "Monete" if k == "moneta" else ("Bottino" if k == "bottino" else "fra Monete e Bottino")], nome(t), L[t]["svc"]],
					{"sig": t, "loc": L[t]["loc"]}))
		if o.is_empty():
			return
		if not leva:
			# dopo una carta si chiede solo se qualcuno sta per Smobilitare
			var urgente := false
			for id in signori_mappa(s):
				if L[id]["svc"] <= turno:
					urgente = true
			if not urgente:
				return
		o.append(opz("fine", "Fine della Paga"))
		var r := await scegli(s, "paga", "Paga dei %s" % D.LATI[s], "Monete e Bottino allungano il Servizio dei Signori (un Podestà costa 2).", o)
		if r == "fine":
			return
		var p: PackedStringArray = r.split(">")
		var payer := p[0]
		var t := p[1]
		var costo := 2 if podesta(t) else 1
		for i in costo:
			if supp(payer, "moneta") > 0:
				add_supp(payer, "moneta", -1)
			else:
				add_supp(payer, "bottino", -1)
		sposta_servizio(t, 1)
		log_msg("%s paga: il Servizio di %s si allunga di un turno." % [nome(payer), nome(t)])
		changed.emit()


# ---------------------------------------------------------------- Smobilitazione (3.3)

func _smobilita(s: int) -> void:
	for id in signori_mappa(s):
		if not sulla_mappa(id):
			continue
		var svc: int = L[id]["svc"]
		if svc < turno:
			log_msg("%s è oltre il limite di Servizio e lascia il campo." % nome(id))
			await rimuovi_signore(id, true)
		elif svc == turno:
			_smobilita_al_limite(id)
		if over:
			return
	changed.emit()


func _smobilita_al_limite(id: String) -> void:
	var c := comune(id)
	if c != "":
		_via_dalla_mappa(c, "fuori")
	_via_dalla_mappa(id, "cal")
	L[id]["cal"] = mini(17, turno + int(D.SIGNORI[id]["serv"]))
	log_msg("%s Smobilita: tornerà pronto al turno %d." % [nome(id), L[id]["cal"]])
	controlla_vittoria_campagna()


# ---------------------------------------------------------------- Raduno (3.4)

func puo_radunare(id: String) -> bool:
	if not sulla_mappa(id) or comune_di(id) != "" or L[id]["radunato_ora"]:
		return false
	var l: String = L[id]["loc"]
	var s := lato(id)
	if podesta(id) and l == D.SIGNORI[id]["sedi"][0] and caposaldo(l) and amica(l, s):
		return true
	if not amica(l, s):
		return false
	if assediato(id):
		return false
	if not L[id]["dentro"] and caposaldo_nemico(l, s):
		return false
	return true


func _raduno(s: int) -> void:
	var fatti := {}
	while true:
		var cand := []
		for id in signori_mappa(s):
			if puo_radunare(id) and not fatti.has(id):
				cand.append(id)
		if cand.is_empty():
			return
		var id: String = cand[0]
		if cand.size() > 1:
			var o := []
			for x in cand:
				o.append(opz(x, "%s (Signoria %d)" % [nome(x), _signoria(x)], {"sig": x, "loc": L[x]["loc"]}))
			o.append(opz("fine", "Fine del Raduno"))
			id = await scegli(s, "raduno_chi", "Raduno dei %s" % D.LATI[s], "Quale Signore fa la Leva?", o)
			if id == "fine":
				return
		fatti[id] = true
		await _raduno_signore(id, _signoria(id))


func _signoria(id: String) -> int:
	var v: int = int(D.SIGNORI[id]["sign"]) + int(bonus_sign.get(id, 0))
	if id in ["firenze", "lucca"] and cap_parte(0, "Compagnia Tau"):
		v += 1
	return v


## Sedi libere di un Signore per il Raduno (3.4.1).
func sedi_libere(id: String) -> Array:
	var s := lato(id)
	var out := []
	for l in D.SIGNORI[id]["sedi"]:
		if avamposto(l):
			out.append(l)
			continue
		if not amica(l, s):
			continue
		if loc[l]["rovine"] >= 0 and not fuori_in(l, 1 - s).is_empty():
			continue
		if assediata_da(l, 1 - s) and not (podesta(id) and l == D.SIGNORI[id]["sedi"][0]):
			continue
		out.append(l)
	return out


func _pronto_raduno(x: String) -> bool:
	if L[x]["stato"] != "cal":
		return false
	if pronto(x):
		return true
	# Armata di emergenza: nemici nella Sede Principale di un Podestà
	if podesta(x):
		var ms: String = D.SIGNORI[x]["sedi"][0]
		if not signori_in(ms, 1 - lato(x)).is_empty():
			return true
	return false


func opzioni_raduno(id: String, azioni: int) -> Array:
	var s := lato(id)
	var o := []
	var l: String = L[id]["loc"]
	for x in D.SIGNORI_LATO[s]:
		if x == id or not _pronto_raduno(x):
			continue
		var sedi := sedi_libere(x)
		if sedi.is_empty():
			continue
		var costo := 1
		if podesta(x) and not amica(D.SIGNORI[x]["sedi"][0], s):
			costo = 2
		if costo > azioni:
			continue
		o.append(opz("sig:" + x, "Leva di %s (dado 1-%d, %d azion%s)" % [nome(x), D.SIGNORI[x]["fed"], costo, "e" if costo == 1 else "i"], {"sig": x, "costo": costo}))
	for v in V:
		var vv: Dictionary = V[v]
		if vv["presso"] != id or vv["stato"] != "pronto":
			continue
		var sp: String = D.VASSALLI[v].get("speciale", "")
		if sp in ["carroccio", "sestiere"]:
			continue
		if sp == "altopascio":
			continue
		var ok := false
		for sl in D.VASSALLI[v]["sedi"]:
			if avamposto(sl) or amica(sl, s):
				ok = true
		if not ok:
			continue
		o.append(opz("vas:" + v, "Vassallo: %s (%s)" % [D.VASSALLI[v]["nome"], descr_forze(D.VASSALLI[v]["forze"])], {"vas": v}))
	# Altopascio con la Compagnia Tau (0 azioni)
	if id in ["firenze", "lucca"] and cap_parte(0, "Compagnia Tau") and V["altopascio"]["stato"] in ["pronto", "fuori"] and amica("altopascio", 0):
		if V["altopascio"]["stato"] != "radunato":
			o.append(opz("alto", "Altopascio, Compagnia Tau (0 azioni)", {"vas": "altopascio", "costo": 0}))
	# Sestieri/Terzi fuori dalla Chiamata alle Armi
	var c := comune(id)
	if c != "" and L[id]["loc"] == D.SIGNORI[id]["sedi"][0] and not L[id]["aggira"]:
		for v in V:
			if V[v]["presso"] == c and V[v]["stato"] == "pronto" and D.VASSALLI[v].get("speciale", "") == "sestiere":
				o.append(opz("sest:" + v, "%s (dado 1-%d)" % [D.VASSALLI[v]["nome"], D.VASSALLI[v]["dado"]], {"vas": v}))
	# Taglia: un Vassallo non radunato di un altro Signore ghibellino
	if s == 1 and cap_parte(1, "Taglia") and not podesta(id) and not L[id].get("taglia", false):
		for v in V:
			var orig: String = D.VASSALLI[v]["sig"]
			if orig == id or lato(orig) != 1 or D.VASSALLI[v].get("speciale", "") != "" or V[v]["stato"] == "radunato" or V[v]["presso"] != orig:
				continue
			var ok := false
			for sl in D.VASSALLI[v]["sedi"]:
				if amica(sl, 1):
					ok = true
			if ok:
				o.append(opz("taglia:" + v, "Taglia: %s di %s (+2 Carri)" % [D.VASSALLI[v]["nome"], nome(orig)], {"vas": v}))
	if amica(l, s):
		o.append(opz("carro", "Un Carro (ora %d)" % supp(id, "carro")))
		if id == "pisa":
			o.append(opz("nave", "Una Nave (ora %d)" % supp(id, "nave")))
		for c2 in mazzo_aow[s]:
			var card: Dictionary = D.CARTE[c2]
			if _evento_attivo(c2):
				continue
			if card["cap_lord"]:
				if not id in _cap_assegnabile(c2, s) and not (comune(id) != "" and comune(id) in _cap_assegnabile(c2, s)):
					continue
			else:
				var cs: Array = card.get("cap_sig", [])
				if not cs.is_empty() and not id in cs:
					continue
				if cap_parte(s, card["cap"]):
					continue
			o.append(opz("cap:" + c2, "Capacità «%s»%s" % [card["cap"], " (questo Signore)" if card["cap_lord"] else " (per tutti)"], {"carta": c2, "dett": card["cap_x"]}))
	return o


func _evento_attivo(c: String) -> bool:
	for e in ev_attivi:
		if e["id"] == c:
			return true
	return false


func _raduno_signore(id: String, azioni: int) -> void:
	var s := lato(id)
	while azioni > 0 and sulla_mappa(id):
		var o := opzioni_raduno(id, azioni)
		o.append(opz("fine", "Fine della Leva di %s" % nome(id)))
		var r := await scegli(s, "raduno", "Leva di %s" % nome(id), "Azioni di Leva rimaste: %d. %s" % [azioni, _riassunto(id)], o, {"sig": id, "azioni": azioni})
		if r == "fine":
			return
		var costo := 1
		for x in o:
			if x["id"] == r:
				costo = int(x.get("costo", 1))
		azioni -= costo
		if r.begins_with("sig:"):
			var x := r.substr(4)
			var dado := d6()
			if dado <= int(D.SIGNORI[x]["fed"]):
				var sedi := sedi_libere(x)
				var dove: String = sedi[0]
				if sedi.size() > 1:
					var oo := []
					for sl in sedi:
						oo.append(opz(sl, lnome(sl), {"loc": sl}))
					dove = await scegli(s, "sede", "Dove si Raduna %s?" % nome(x), "Scegli la Sede.", oo, {"sig": x})
				_metti_in_gioco(x, dove)
				L[x]["radunato_ora"] = true
				log_msg("%s chiama %s (dado %d): si Raduna a %s, Servizio fino al turno %d." % [nome(id), nome(x), dado, lnome(dove), L[x]["svc"]])
				fx.emit("raduno", {"sig": x})
			else:
				log_msg("%s chiama %s, ma il dado (%d) non basta." % [nome(id), nome(x), dado])
		elif r.begins_with("vas:") or r == "alto":
			var v := "altopascio" if r == "alto" else r.substr(4)
			_raduna_vassallo(id, v)
		elif r.begins_with("sest:"):
			var v := r.substr(5)
			var dado := d6()
			if dado <= int(D.VASSALLI[v]["dado"]):
				_raduna_vassallo(comune(id), v)
			else:
				log_msg("%s non risponde (dado %d)." % [D.VASSALLI[v]["nome"], dado])
		elif r.begins_with("taglia:"):
			var v := r.substr(7)
			V[v]["presso"] = id
			_raduna_vassallo(id, v)
			add_supp(id, "carro", 2)
			L[id]["taglia"] = true
		elif r == "carro":
			add_supp(id, "carro", 1)
			log_msg("%s aggiunge un Carro." % nome(id))
		elif r == "nave":
			add_supp(id, "nave", 1)
			log_msg("Pisa arma una Nave.")
		elif r.begins_with("cap:"):
			var c := r.substr(4)
			mazzo_aow[s].erase(c)
			if D.CARTE[c]["cap_lord"]:
				var dest := id
				if not id in _cap_assegnabile(c, s) and comune(id) != "":
					dest = comune(id)
				elif comune(id) != "" and comune(id) in _cap_assegnabile(c, s):
					var oo := [opz(id, nome(id)), opz(comune(id), nome(comune(id)))]
					dest = await scegli(s, "cap_a_chi", "Capacità «%s»" % D.CARTE[c]["cap"], "Su quale scheda?", oo)
				await _assegna_cap(dest, c)
			else:
				cap_lato[s].append(c)
			log_msg("%s ottiene la Capacità «%s»." % [nome(id), D.CARTE[c]["cap"]])
			fx.emit("carta", {"id": c, "lato": s, "cap": true})
		changed.emit()


func _raduna_vassallo(id: String, v: String) -> void:
	V[v]["stato"] = "radunato"
	V[v]["presso"] = id
	prendi_unita(id, D.VASSALLI[v]["forze"])
	log_msg("%s raduna %s (%s)." % [nome(id), D.VASSALLI[v]["nome"], descr_forze(D.VASSALLI[v]["forze"])])


func _riassunto(id: String) -> String:
	return "%s: %s; %s; Servizio fino al turno %d." % [nome(id), descr_forze(L[id]["forze"]), descr_supp(id), L[id]["svc"]]


# ---------------------------------------------------------------- Chiamata alle Armi (3.5)

func _chiamata_alle_armi() -> void:
	var regola: String = S.get("chiamata", "")
	if regola == "no":
		return
	var puo := [false, false]
	for s in [0, 1]:
		if pv(s) <= pv(1 - s) - 4.0 or guerra[s]:
			puo[s] = true
		if regola == "escalation" and prima_leva:
			puo[s] = true
		if regola == "solo_ghib_prima":
			puo[s] = s == 1 and prima_leva
	# Tesori: pagare 2 Monete
	if not puo[0] and "G23" in tenute[0] and regola != "solo_ghib_prima":
		var chi := ""
		for id in signori_mappa(0):
			if supp(id, "moneta") >= 2:
				chi = id
		if chi != "":
			var r := await scegli(0, "evento", "Tesori", "Pagare 2 Monete di %s per dichiarare la Chiamata alle Armi?" % nome(chi), [opz("si", "Paga e dichiara"), opz("no", "No")])
			if r == "si":
				tenute[0].erase("G23")
				_scarta_evento("G23")
				add_supp(chi, "moneta", -2)
				puo[0] = true
	var dichiara := false
	for s in [0, 1]:
		if puo[s]:
			var r := await scegli(s, "chiamata", "Chiamata alle Armi", "Puoi dichiarare la Chiamata alle Armi: i Signori si riuniscono verso %s, il Comandante può radunare il Comune con il Carroccio, e un alleato arriva." % ("Firenze" if s == 0 else "Siena"),
				[opz("si", "Dichiara la Chiamata alle Armi"), opz("no", "Non ora")])
			if r == "si":
				dichiara = true
				log_msg("I %s dichiarano la CHIAMATA ALLE ARMI!" % D.LATI[s])
	if not dichiara:
		return
	fx.emit("chiamata", {})
	for s in [0, 1]:
		if regola == "solo_ghib_prima" and s == 0:
			continue
		await _chiamata_lato(s)


func _chiamata_lato(s: int) -> void:
	var citta: String = D.CITTA_GUIDA[s]
	var cmdr: String = D.CITTA_GUIDA[s]
	# a) Riunirsi
	for id in signori_mappa(s):
		if assediato(id) or L[id]["loc"] == citta:
			continue
		var dest := _verso(id, citta, int(D.SIGNORI[id]["cmd"]))
		if dest == L[id]["loc"]:
			continue
		var r := await scegli(s, "riunirsi", "Riunirsi", "%s può marciare verso %s fino a %s." % [nome(id), lnome(citta), lnome(dest)],
			[opz("si", "Marcia fino a %s" % lnome(dest), {"loc": dest}), opz("no", "Resta a %s" % lnome(L[id]["loc"]))], {"sig": id})
		if r == "si":
			for x in gruppo_comune(id):
				L[x]["loc"] = dest
				L[x]["dentro"] = false
				L[x]["aggira"] = false
			log_msg("%s si riunisce a %s." % [nome(id), lnome(dest)])
			changed.emit()
	# b) Comandante alle Armi
	if amica(citta, s) and caposaldo(citta):
		var stato: String = L[cmdr]["stato"]
		if (stato == "mappa" and L[cmdr]["loc"] != citta) or stato == "cal":
			var r := await scegli(s, "comandante", "Comandante alle Armi", "Il Podestà di %s può tornare in città e radunarsi lì." % citta.capitalize(),
				[opz("si", "Raduna il Comandante a %s" % lnome(citta), {"loc": citta}), opz("no", "No")])
			if r == "si":
				if stato == "mappa":
					_smobilita_al_limite(cmdr)
				_metti_in_gioco(cmdr, citta)
				L[cmdr]["radunato_ora"] = true
				log_msg("Il Comandante %s si raduna a %s." % [nome(cmdr), lnome(citta)])
	# c) Comune
	if sulla_mappa(cmdr) and L[cmdr]["loc"] == citta:
		var c: String = D.COMUNE[cmdr]
		var nuovi := []
		for v in V:
			if V[v]["presso"] == c and V[v]["stato"] == "pronto":
				nuovi.append(v)
		if not sulla_mappa(c) or not nuovi.is_empty():
			var r := await scegli(s, "comune", "Il Comune", "Radunare il %s con il Carroccio e le milizie dei %s?" % [nome(c), "Sestieri" if s == 0 else "Terzi"],
				[opz("si", "Raduna il Comune"), opz("no", "No")])
			if r == "si":
				if not sulla_mappa(c):
					var x: Dictionary = L[c]
					x["stato"] = "mappa"
					x["loc"] = citta
					x["forze"] = {}
					x["rotte"] = {}
					x["supp"] = {}
					x["caps"] = []
					x["dentro"] = L[cmdr]["dentro"]
					x["svc"] = 99
					for k in D.SIGNORI[c]["supp"]:
						add_supp(c, k, int(D.SIGNORI[c]["supp"][k]))
				for v in nuovi:
					_raduna_vassallo(c, v)
				log_msg("Il %s scende in campo con il Carroccio!" % nome(c))
				fx.emit("comune", {"sig": c})
	# d) Alleati
	var o := []
	for id in D.SIGNORI_LATO[s]:
		if id != cmdr and _pronto_raduno(id) and not sedi_libere(id).is_empty():
			o.append(opz("ral:" + id, "Raduna %s senza tiro" % nome(id), {"sig": id}))
	for id in signori_mappa(s):
		if puo_radunare(id):
			o.append(opz("lev:" + id, "Leva extra di %s (Signoria %d)" % [nome(id), _signoria(id)], {"sig": id}))
	if o.is_empty():
		return
	o.append(opz("no", "Nessun alleato"))
	var r := await scegli(s, "alleati", "Alleati", "Un ultimo aiuto per la Chiamata alle Armi.", o)
	if r.begins_with("ral:"):
		var x := r.substr(4)
		var sedi := sedi_libere(x)
		var dove: String = sedi[0]
		if sedi.size() > 1:
			var oo := []
			for sl in sedi:
				oo.append(opz(sl, lnome(sl), {"loc": sl}))
			dove = await scegli(s, "sede", "Dove si Raduna %s?" % nome(x), "Scegli la Sede.", oo, {"sig": x})
		_metti_in_gioco(x, dove)
		log_msg("%s accorre a %s." % [nome(x), lnome(dove)])
	elif r.begins_with("lev:"):
		var x := r.substr(4)
		L[x]["radunato_ora"] = false
		await _raduno_signore(x, _signoria(x))


## Località più vicina a dest raggiungibile in n passi senza entrare in luoghi nemici.
func _verso(id: String, dest: String, n: int) -> String:
	var s := lato(id)
	var cur: String = L[id]["loc"]
	var dist := distanze(dest)
	var d0: int = dist.get(cur, 99)
	var ok := func(l: String) -> bool:
		if caposaldo_nemico(l, s):
			return false
		if not fuori_in(l, 1 - s).is_empty():
			return false
		if avamposto(l) and not l in D.SIGNORI[id]["sedi"]:
			return false
		return true
	var raggiungibili := distanze(cur, ok)
	var best := cur
	var bd := d0
	for l in raggiungibili:
		if raggiungibili[l] <= n and dist.get(l, 99) < bd:
			bd = dist[l]
			best = l
	return best


# ================================================================ CAMPAGNA (4.0)

func _campagna() -> void:
	fase = "campagna"
	passo = "Pianificazione"
	log_msg("— Turno %d: CAMPAGNA (%s, %d carte) —" % [turno, D.NOME_STAGIONE[D.STAGIONE[turno]], D.CARTE_PIANO[D.STAGIONE[turno]]])
	fx.emit("campagna", {})
	controlla_vittoria_campagna()
	if over:
		return
	for id in L:
		L[id]["prima_carta"] = true
		L[id]["mosso"] = false
	# Capacità di parte oltre il numero di Signori
	for s in [0, 1]:
		while cap_lato[s].size() > signori_mappa(s).size():
			var o := []
			for c in cap_lato[s]:
				o.append(opz(c, D.CARTE[c]["cap"], {"carta": c}))
			var r := await scegli(s, "scarta_cap", "Troppe Capacità", "Hai più Capacità di parte che Signori sulla mappa: scartane una.", o)
			cap_lato[s].erase(r)
			_scarta_evento(r)
	# Piani
	for s in [0, 1]:
		piano[s] = await _pianifica(s)
		giocate[s] = []
	changed.emit()
	passo = "Comando"
	var i := 0
	while (not piano[0].is_empty() or not piano[1].is_empty()) and not over and not abort:
		var s := i % 2
		i += 1
		if piano[s].is_empty():
			continue
		var card: Dictionary = piano[s].pop_front()
		giocate[s].append(card)
		await _attiva(s, card)
		if over or abort:
			return
		await _nutri_paga_smobilita()
		controlla_vittoria_campagna()
		changed.emit()
	attivo = -1
	sig_attivo = ""


## Carte Comando disponibili per il piano.
func carte_comando(s: int) -> Array:
	var out := []
	for id in D.SIGNORI_LATO[s]:
		if L[id]["stato"] == "rimosso":
			continue
		for k in 3:
			out.append({"id": "cmd:%s:%d" % [id, k + 1], "t": "cmd", "l": id})
		if id in tradimento[s]:
			out.append({"id": "trad:" + id, "t": "trad", "l": id})
	for k in 4:
		out.append({"id": "passa:%d" % (k + 1), "t": "passa", "l": ""})
	return out


func _pianifica(s: int) -> Array:
	var n: int = D.CARTE_PIANO[D.STAGIONE[turno]]
	var carte := carte_comando(s)
	var req := {"type": "piano", "k": "piano", "carte": carte, "n": n, "titolo": "Piano di Campagna dei %s" % D.LATI[s]}
	var r = await decide(s, req)
	var scelte := []
	var ids := {}
	for c in carte:
		ids[c["id"]] = c
	if r is Array:
		for x in r:
			if ids.has(str(x)) and scelte.size() < n:
				scelte.append(ids[str(x)])
				ids.erase(str(x))
	# completa con carte Passare
	var k := 1
	while scelte.size() < n:
		var pid := "passa:%d" % k
		if ids.has(pid):
			scelte.append(ids[pid])
			ids.erase(pid)
		k += 1
		if k > 10:
			break
	if frati and s == 0:
		_mescola(scelte)
		log_msg("Frati: i Guelfi mescolano il loro piano.")
	log_msg("I %s preparano il piano di campagna (%d carte)." % [D.LATI[s], scelte.size()])
	return scelte


func _attiva(s: int, card: Dictionary) -> void:
	attivo = s
	var id: String = card["l"]
	fx.emit("carta_comando", {"lato": s, "carta": card})
	if card["t"] == "passa" or id == "" or not sulla_mappa(id):
		log_msg("I %s passano%s." % [D.LATI[s], (" (%s non è sulla mappa)" % nome(id)) if id != "" and card["t"] != "passa" else ""])
		sig_attivo = ""
		changed.emit()
		await _pace(0.5)
		return
	sig_attivo = id
	changed.emit()
	if card["t"] == "trad":
		tradimento[s].erase(id)
		await _carta_tradimento(id)
		return
	var azioni := int(D.SIGNORI[id]["cmd"]) + _bonus_comando(id)
	L[id]["prima_carta"] = false
	log_msg("%s è attivo (%d azioni)." % [nome(id), azioni])
	var prima_marcia := true
	var giri := 0
	while azioni > 0 and sulla_mappa(id) and not over and giri < 40:
		giri += 1
		var o := opzioni_azione(id, azioni, prima_marcia)
		var r := await scegli(s, "azione", "%s: %d azion%s" % [nome(id), azioni, "e" if azioni == 1 else "i"], _riassunto(id), o, {"sig": id, "azioni": azioni})
		var info := {}
		for x in o:
			if x["id"] == r:
				info = x
		var costo := int(info.get("costo", 1))
		var esito := await _esegui(id, r, info)
		if r.begins_with("marcia") and esito != "annulla":
			if costo == 0 or prima_marcia:
				prima_marcia = false
		if esito == "fine" or info.get("tutta", false):
			break
		azioni -= costo
		changed.emit()
	L[id]["prima_carta"] = false


func _bonus_comando(id: String) -> int:
	var s := lato(id)
	var b := 0
	var l: String = L[id]["loc"]
	if L[id]["prima_carta"]:
		if s == 0 and cap_parte(0, "Via Francigena") and not id in ["guido", "orvieto"] and l in D.SIGNORI[id]["sedi"]:
			b += 1
		if s == 1 and cap_parte(1, "Manfredi") and id != "pisa":
			for x in D.SIGNORI_LATO[1]:
				if l in D.SIGNORI[x]["sedi"] and not avamposto(l):
					b += 1
					break
		if cap_parte(s, "Astrologi"):
			var dado := d6()
			if dado <= 2:
				b += 1
				log_msg("Gli astrologi sono favorevoli a %s (dado %d): Comando +1." % [nome(id), dado])
	return b


# ---------------------------------------------------------------- azioni possibili

func carico(ids: Array, via: String) -> int:
	# 0 scarico, 1 carico, 2 non può muovere
	var s := lato(ids[0])
	var prov := 0
	var carri := 0
	var bott := 0
	for id in ids:
		prov += supp(id, "prov")
		carri += supp(id, "carro")
		bott += supp(id, "bottino")
	var strada = via == "S" or lavori[s]
	if prov > 2 * carri:
		return 2
	if lavori[s]:
		return 0
	if bott > 0:
		return 1
	if prov > carri and not strada:
		return 1
	return 0


func gruppo_marcia(id: String, con_tutti: bool) -> Array:
	var g := gruppo_comune(id)
	if con_tutti and comandante(id):
		for x in signori_in(L[id]["loc"], lato(id), false):
			if x != id and not assediato(x) and not L[x]["dentro"]:
				g.append(x)
				var c := comune(x)
				if c != "" and not c in g:
					g.append(c)
	return g


func puo_entrare(id: String, v: String) -> bool:
	if avamposto(v):
		var base := id if comune_di(id) == "" else comune_di(id)
		return v in D.SIGNORI[base]["sedi"]
	if maremma_blocco and lato(id) == 1:
		var dl: int = lato_stampato(L[id]["loc"])
		if dl == 1 and lato_stampato(v) == 0:
			return false
	return true


func opzioni_azione(id: String, azioni: int, prima_marcia: bool) -> Array:
	var s := lato(id)
	var l: String = L[id]["loc"]
	var o := []
	var stag: String = D.STAGIONE[turno]
	if assediato(id):
		if not fuori_in(l, 1 - s).is_empty():
			o.append(opz("sortita", "Sortita contro gli assedianti (fine della carta)", {"loc": l, "tutta": true}))
		if _puo_foraggiare(id):
			o.append(opz("foraggia", "Foraggiare (1 azione)", {"loc": l}))
		if ha_cap(id, "Genieri di Guerra") and loc[l]["assedio"] > 0:
			o.append(opz("genieri", "Genieri: riduci di 1 l'Assedio (tutta la carta)", {"loc": l, "tutta": true}))
		if cap_parte(s, "Depositi e Pozzo") and l in D.SIGNORI[id]["sedi"]:
			o.append(opz("rifornisci", "Rifornimento dai depositi (1 azione)", {"loc": l}))
		o.append(opz("passa", "Passare (fine della carta)", {"tutta": true}))
		return o
	# Marcia
	var ids := gruppo_marcia(id, false)
	var gruppo := gruppo_marcia(id, true)
	for v in vicine(l):
		if not puo_entrare(id, v):
			continue
		for g in ([ids, gruppo] if gruppo.size() > ids.size() else [ids]):
			var via: String = adj[l][v]
			var car := carico(g, via)
			var costo := 1
			if car == 2:
				costo = 1
			elif car == 1:
				costo = 2
			elif prima_marcia and (via == "S" or lavori[s]):
				costo = 0
			if costo > azioni:
				continue
			var tutti: bool = g.size() > ids.size()
			var t := "Marcia a %s (%s%s)" % [lnome(v), "gratis per strada" if costo == 0 else "%d azion%s" % [costo, "e" if costo == 1 else "i"], ", carico" if car == 1 else ""]
			if tutti:
				t += " con tutti i Signori"
			var nemici := fuori_in(v, 1 - s)
			if not nemici.is_empty():
				t += " — BATTAGLIA"
			elif caposaldo_nemico(v, s) and loc[v]["assedio"] == 0:
				t += " — Caposaldo nemico"
			o.append(opz(("marcia_tutti:" if tutti else "marcia:") + v, t, {"loc": v, "costo": costo}))
	# accamparsi (da aggiramento ad assedio)
	if L[id]["aggira"] and caposaldo_nemico(l, s):
		o.append(opz("accampa", "Accamparsi: l'Aggiramento diventa Assedio (fine della carta)", {"loc": l, "tutta": true}))
	# Sortita contro chi ci aggira
	if L[id]["dentro"] and not fuori_in(l, 1 - s).is_empty():
		o.append(opz("sortita_agg", "Sortita contro chi aggira %s (1 azione, battaglia)" % lnome(l), {"loc": l}))
	# Assedio e Assalto
	if not L[id]["dentro"] and assediata_da(l, s) and caposaldo(l):
		var dentro := dentro_in(l, 1 - s)
		var t := "Assedio: tira per la Resa e avanza le opere (tutta la carta)" if dentro.is_empty() else "Assedio: avanza le opere (tutta la carta)"
		o.append(opz("assedio", t, {"loc": l, "tutta": true}))
		o.append(opz("assalto", "Assalto a %s (Assedio %d: fino a %d round)" % [lnome(l), loc[l]["assedio"], loc[l]["assedio"]], {"loc": l, "tutta": true}))
	# Rifornimento
	var rif := stima_rifornimento(id)
	if rif > 0 and supp(id, "prov") < 16:
		var porta := 2 * supp(id, "carro") - supp(id, "prov")
		if porta > 0 and porta < rif:
			o.append(opz("rifornisci:%d" % porta, "Rifornimento: +%d Provviste (quante puoi trasportare)" % porta, {"loc": l}))
		o.append(opz("rifornisci", "Rifornimento: +%d Provviste" % rif, {"loc": l}))
	if _puo_foraggiare(id):
		o.append(opz("foraggia", "Foraggiare%s" % ("" if (caposaldo(l) and amica(l, s)) or stag == "E" else " (dado 1-3)"), {"loc": l}))
	# Devastazione
	if _puo_devastare(id, l):
		var costo := 0 if ha_cap(id, "Masnadieri") else (1 if D.LOCALI[l]["tipo"] == "castello" or avamposto(l) else 2)
		if costo <= azioni:
			o.append(opz("devasta", "Devastare %s (%d azion%s)" % [lnome(l), costo, "e" if costo == 1 else "i"], {"loc": l, "costo": costo}))
	if ha_cap(id, "La Cavallata") and supp(id, "prov") > 0:
		for v in vicine(l):
			if _puo_devastare(id, v, true):
				o.append(opz("cavallata:" + v, "La Cavallata: devasta %s (1 Provvista, tutta la carta)" % lnome(v), {"loc": v, "tutta": true}))
	# Tassare
	if l in D.SIGNORI[id]["sedi"] and not no_tasse[s] and (amica(l, s) or avamposto(l)) and not L[id]["dentro"] or (l in D.SIGNORI[id]["sedi"] and L[id]["dentro"] and not assediato(id) and not no_tasse[s]):
		o.append(opz("tassa", "Tassare: +%d Monet%s (tutta la carta)" % [2 if podesta(id) else 1, "e" if podesta(id) else "a"], {"loc": l, "tutta": true}))
		if cap_parte(s, "Mura rinforzate") and caposaldo(l) and loc[l]["mura"] < 0:
			o.append(opz("mura", "Mura rinforzate a %s invece di tassare (tutta la carta)" % lnome(l), {"loc": l, "tutta": true}))
	# Costruttori
	if cap_parte(s, "Costruttori") and loc[l]["rovine"] >= 0 and supp(id, "moneta") >= 1 and supp(id, "prov") >= 3:
		o.append(opz("costruttori", "Costruttori: ricostruisci %s (1 Moneta, 3 Provviste, tutta la carta)" % lnome(l), {"loc": l, "tutta": true}))
	# Movimento per mare
	if id == "pisa" and D.LOCALI[l]["porto"] and amica(l, s) and stag != "I" and _navi_bastano(id):
		for p in D.LOCALI:
			if p != l and D.LOCALI[p]["porto"] and fuori_in(p, 1 - s).is_empty():
				o.append(opz("mare:" + p, "Per mare a %s (tutta la carta)" % lnome(p), {"loc": p, "tutta": true}))
	o.append(opz("passa", "Passare (fine della carta)", {"tutta": true}))
	return o


func _navi_bastano(id: String) -> bool:
	var cav := 0
	for u in ["ritter", "cav", "berr", "cl"]:
		cav += int(L[id]["forze"].get(u, 0))
	return supp(id, "nave") >= cav + supp(id, "prov") + 2 * supp(id, "bottino")


func _puo_foraggiare(id: String) -> bool:
	var s := lato(id)
	var l: String = L[id]["loc"]
	if loc[l]["dev"] >= 0:
		return false
	if supp(id, "prov") >= 16:
		return false
	if assediato(id):
		var n := fuori_in(l, 1 - s).size()
		if n >= valore(l):
			return false
	if caposaldo(l) and amica(l, s) and loc[l]["assedio"] == 0:
		return true
	return D.STAGIONE[turno] != "I"


func _puo_devastare(id: String, l: String, lontano := false) -> bool:
	var s := lato(id)
	if loc[l]["dev"] >= 0:
		return false
	if amica(l, s):
		return false
	if avamposto(l) and not lontano:
		return false
	if lontano and not fuori_in(l, 1 - s).is_empty():
		return false
	if L[id]["dentro"]:
		return false
	return true


# ---------------------------------------------------------------- Rifornimento (4.6)

func _fonti(id: String) -> Array:
	var s := lato(id)
	var out := []
	for l in D.SIGNORI[id]["sedi"]:
		if avamposto(l):
			out.append([l, 1])
		elif caposaldo(l) and amica(l, s):
			var n := valore(l)
			if cap_parte(s, "Depositi e Pozzo"):
				n = 4
			out.append([l, n])
	return out


func _passabile(l: String, s: int) -> bool:
	if caposaldo_nemico(l, s) and loc[l]["assedio"] == 0 and not _aggirata(l, s):
		return false
	if not fuori_in(l, 1 - s).is_empty():
		return false
	return true


func stima_rifornimento(id: String) -> int:
	if assediato(id) and not cap_parte(lato(id), "Depositi e Pozzo"):
		return 0
	var s := lato(id)
	var l: String = L[id]["loc"]
	var carri := 0
	for x in signori_in(l, s):
		if not L[x]["dentro"] or x == id:
			carri += supp(x, "carro")
	var dist := distanze(l, func(x): return _passabile(x, s))
	var fonti := _fonti(id)
	fonti.sort_custom(func(a, b): return dist.get(a[0], 99) < dist.get(b[0], 99))
	var tot := 0
	for f in fonti:
		var d: int = dist.get(f[0], 99)
		if d >= 99:
			continue
		if d == 0:
			tot += f[1]
		else:
			var n: int = mini(f[1], carri / d)
			tot += n
			carri -= n * d
	# Navi di Pisa in un porto amico
	if D.STAGIONE[turno] != "I" and D.LOCALI[l]["porto"] and amica(l, s):
		for x in signori_in(l, s):
			if x == "pisa":
				tot += supp(x, "nave")
	return mini(tot, 16 - supp(id, "prov"))


# ---------------------------------------------------------------- esecuzione

func _esegui(id: String, r: String, info: Dictionary) -> String:
	var s := lato(id)
	var l: String = L[id]["loc"]
	if r.begins_with("marcia"):
		var v := r.get_slice(":", 1)
		var g := gruppo_marcia(id, r.begins_with("marcia_tutti"))
		return await marcia(id, g, v)
	match r:
		"passa":
			log_msg("%s passa." % nome(id))
			return "fine"
		"accampa":
			if await _sorpresa(id, l):
				L[id]["mosso"] = true
				return "fine"
			var n := 1
			if ha_cap(id, "Guastatori"):
				n = 2
			loc[l]["assedio"] = maxi(loc[l]["assedio"], n)
			loc[l]["assedio_l"] = s
			for x in fuori_in(l, s):
				L[x]["aggira"] = false
			L[id]["mosso"] = true
			log_msg("%s si accampa: inizia l'Assedio di %s." % [nome(id), lnome(l)])
			await _fuoco_greco(l, s)
			return "fine"
		"assedio":
			await _azione_assedio(id)
			return "fine"
		"assalto":
			L[id]["mosso"] = true
			await assalto(l, s, id)
			return "fine"
		"sortita":
			L[id]["mosso"] = true
			await sortita(l, s, id)
			return "fine"
		"sortita_agg":
			for x in dentro_in(l, s):
				L[x]["dentro"] = false
			L[id]["mosso"] = true
			await battaglia_campale(l, s, id, l)
			return "fine"
		"genieri":
			loc[l]["assedio"] = maxi(0, loc[l]["assedio"] - 1)
			log_msg("I genieri di %s distruggono le opere d'assedio (Assedio %d)." % [nome(id), loc[l]["assedio"]])
			if loc[l]["assedio"] == 0:
				loc[l]["assedio_l"] = -1
				for x in fuori_in(l, 1 - s):
					L[x]["aggira"] = true
			return "fine"
		"rifornisci":
			var n := stima_rifornimento(id)
			if assediato(id):
				n = mini(4, 16 - supp(id, "prov"))
			add_supp(id, "prov", n)
			log_msg("%s si rifornisce: +%d Provviste." % [nome(id), n])
			fx.emit("supporto", {"sig": id, "k": "prov", "n": n})
			return ""
		"foraggia":
			var ok := true
			var dado := 0
			if not (caposaldo(l) and amica(l, s) and loc[l]["assedio"] == 0) and D.STAGIONE[turno] != "E":
				dado = d6()
				ok = dado <= 3
			if ok:
				add_supp(id, "prov", 1)
				log_msg("%s foraggia: +1 Provvista%s." % [nome(id), (" (dado %d)" % dado) if dado > 0 else ""])
			else:
				log_msg("%s non trova nulla da foraggiare (dado %d)." % [nome(id), dado])
			return ""
		"devasta":
			_devasta(id, l)
			return ""
		"tassa":
			var n := 2 if podesta(id) else 1
			add_supp(id, "moneta", n)
			log_msg("%s riscuote le tasse: +%d Monet%s." % [nome(id), n, "e" if n > 1 else "a"])
			fx.emit("supporto", {"sig": id, "k": "moneta", "n": n})
			return "fine"
		"mura":
			loc[l]["mura"] = s
			log_msg("%s rinforza le mura di %s." % [nome(id), lnome(l)])
			return "fine"
		"costruttori":
			add_supp(id, "moneta", -1)
			add_supp(id, "prov", -3)
			loc[l]["rovine"] = -1
			log_msg("I costruttori di %s ricostruiscono %s." % [nome(id), lnome(l)])
			return "fine"
	if r.begins_with("rifornisci:"):
		var n := mini(int(r.substr(11)), stima_rifornimento(id))
		add_supp(id, "prov", n)
		log_msg("%s si rifornisce: +%d Provviste." % [nome(id), n])
		return ""
	if r.begins_with("cavallata:"):
		var v := r.substr(10)
		add_supp(id, "prov", -1)
		_devasta(id, v)
		return "fine"
	if r.begins_with("mare:"):
		var p := r.substr(5)
		for x in gruppo_comune(id):
			L[x]["loc"] = p
			L[x]["dentro"] = false
			L[x]["aggira"] = false
			L[x]["mosso"] = true
		log_msg("Pisa salpa e sbarca a %s." % lnome(p))
		_libera_assedio(l, s)
		if caposaldo_nemico(p, s) and loc[p]["assedio"] == 0:
			loc[p]["assedio"] = 1
			loc[p]["assedio_l"] = s
			log_msg("Pisa pone l'assedio a %s." % lnome(p))
		changed.emit()
		return "fine"
	return ""


func _devasta(id: String, l: String) -> void:
	var s := lato(id)
	loc[l]["dev"] = 1 - lato_stampato(l)
	var cav := false
	for u in ["ritter", "cav", "berr", "cl"]:
		if int(L[id]["forze"].get(u, 0)) > 0:
			cav = true
	var doppio: bool = int(L[id]["forze"].get("berr", 0)) > 0 or (ha_cap(id, "Gualdana") and cav)
	var k := 2 if doppio else 1
	if not ha_cap(id, "Masnadieri"):
		add_supp(id, "prov", k)
		if D.LOCALI[l]["tipo"] in ["citta", "cittadina"]:
			add_supp(id, "bottino", k)
	L[id]["mosso"] = L[id]["mosso"]
	log_msg("%s devasta %s." % [nome(id), lnome(l)])
	fx.emit("devasta", {"loc": l, "lato": s})


func _libera_assedio(l: String, s: int) -> void:
	if fuori_in(l, s).is_empty():
		if assediata_da(l, s):
			loc[l]["assedio"] = 0
			loc[l]["assedio_l"] = -1
			log_msg("L'assedio di %s è tolto." % lnome(l))


## Marcia di un gruppo; restituisce "fine" se la carta finisce (battaglia o assedio).
func marcia(id: String, g: Array, v: String) -> String:
	var s := lato(id)
	var da: String = L[id]["loc"]
	# scarta le Provviste in eccesso (oltre il doppio dei Carri)
	var via: String = adj[da][v]
	if carico(g, via) == 2:
		for x in g:
			var ecc := supp(x, "prov") - 2 * supp(x, "carro")
			if ecc > 0:
				add_supp(x, "prov", -ecc)
		log_msg("%s abbandona le Provviste che non riesce a trasportare." % nome(id))
	for x in g:
		L[x]["loc"] = v
		L[x]["dentro"] = false
		L[x]["aggira"] = false
		L[x]["mosso"] = true
	log_msg("%s marcia da %s a %s." % [_elenco(_senza_comuni(g)), lnome(da), lnome(v)])
	fx.emit("marcia", {"ids": g, "da": da, "a": v})
	_libera_assedio(da, s)
	changed.emit()
	await _pace(0.5)
	await _briganti(id, v)
	# Avvicinamento
	if not fuori_in(v, 1 - s).is_empty():
		await _avvicinamento(id, v, da)
		if not fuori_in(v, 1 - s).is_empty():
			var soccorso := []
			if assediata_da(v, 1 - s):
				for x in dentro_in(v, s):
					soccorso.append(x)
					L[x]["dentro"] = false
			var vince := await battaglia_campale(v, s, id, da, soccorso)
			if vince != s:
				return "fine"
			if caposaldo_nemico(v, s) and loc[v]["assedio"] == 0 and not fuori_in(v, s).is_empty():
				await _assedio_o_aggira(id, v)
			return "fine"
	# Caposaldo nemico
	if caposaldo_nemico(v, s):
		if assediata_da(v, s):
			log_msg("%s si unisce all'assedio di %s." % [nome(id), lnome(v)])
			return ""
		if _aggirata(v, s) and fuori_in(v, s).size() > g.size():
			for x in g:
				L[x]["aggira"] = true
			return ""
		return await _assedio_o_aggira(id, v)
	return ""


func _senza_comuni(g: Array) -> Array:
	var out := []
	for x in g:
		if comune_di(x) == "":
			out.append(x)
	return out


## Evento tenuto «Sorpresa»: cominciando l'assedio di un Caposaldo senza Signori dentro, Assedio 2 e Assalto
## subito, fino a 3 round con le Mura a -2. Restituisce true se è stato giocato.
func _sorpresa(id: String, v: String) -> bool:
	var s := lato(id)
	var sorpresa := "G03" if s == 0 else "H03"
	if not dentro_in(v, 1 - s).is_empty() or not sorpresa in tenute[s]:
		return false
	var rr := await scegli(s, "evento", "Sorpresa", "Giocare Sorpresa contro %s? Assedio 2 e Assalto subito fino a 3 round, Mura -2." % lnome(v), [opz("si", "Gioca Sorpresa"), opz("no", "No, tienila")], {"sig": id, "loc": v})
	if rr != "si":
		return false
	tenute[s].erase(sorpresa)
	_scarta_evento(sorpresa)
	loc[v]["assedio"] = 2
	loc[v]["assedio_l"] = s
	log_msg("SORPRESA! %s piomba su %s." % [nome(id), lnome(v)])
	await assalto(v, s, id, 3, -2)
	return true


func _assedio_o_aggira(id: String, v: String) -> String:
	var s := lato(id)
	var dentro := dentro_in(v, 1 - s)
	var o := [opz("assedia", "Assedia %s (fine della carta)" % lnome(v), {"loc": v}), opz("aggira", "Aggira %s e continua", {"loc": v})]
	o[1]["t"] = "Aggira %s e continua" % lnome(v)
	var r := await scegli(s, "assedia", "Caposaldo nemico: %s" % lnome(v),
		"%s (%s, valore %d)%s. Assediare blocca il Caposaldo; aggirarlo permette di continuare la carta." % [lnome(v), D.LOCALI[v]["tipo"], valore(v), (" con dentro " + _elenco(dentro)) if not dentro.is_empty() else ""], o, {"sig": id})
	if r == "assedia":
		var n := 2 if ha_cap(id, "Guastatori") else 1
		if await _sorpresa(id, v):
			return "fine"
		loc[v]["assedio"] = maxi(loc[v]["assedio"], n)
		loc[v]["assedio_l"] = s
		for x in fuori_in(v, s):
			L[x]["aggira"] = false
		log_msg("%s pone l'assedio a %s." % [nome(id), lnome(v)])
		fx.emit("assedio", {"loc": v})
		await _fuoco_greco(v, s)
		return "fine"
	for x in fuori_in(v, s):
		L[x]["aggira"] = true
	log_msg("%s aggira %s." % [nome(id), lnome(v)])
	return ""


func _fuoco_greco(l: String, s: int) -> void:
	var e := 1 - s
	var c := "G07" if e == 0 else "H07"
	if not c in tenute[e] or loc[l]["assedio"] == 0 or not amica(l, e):
		return
	var bers := fuori_in(l, s)
	if bers.is_empty():
		return
	var r := await scegli(e, "evento", "Fuoco greco", "Giocare Fuoco greco contro gli assedianti di %s?" % lnome(l), [opz("si", "Gioca Fuoco greco"), opz("no", "No")])
	if r != "si":
		return
	tenute[e].erase(c)
	_scarta_evento(c)
	loc[l]["assedio"] = maxi(0, loc[l]["assedio"] - 1)
	var b: String = bers[0]
	for u in ["mil", "vill", "arm", "uia", "cav"]:
		if togli_unita(b, u) > 0:
			break
	if not L[b]["caps"].is_empty():
		_scarta_evento(L[b]["caps"].pop_back())
	log_msg("Fuoco greco su %s!" % nome(b))
	if loc[l]["assedio"] == 0:
		loc[l]["assedio_l"] = -1
		for x in fuori_in(l, s):
			L[x]["aggira"] = true
	if unita(b) == 0:
		await rimuovi_signore(b, true)


func _briganti(id: String, v: String) -> void:
	var s := lato(id)
	if s != 0 or not "H19" in tenute[1]:
		return
	var vicino := false
	for x in ["giordano", "astimberg"]:
		if sulla_mappa(x) and distanza(L[x]["loc"], v) <= 2:
			vicino = true
	if not vicino:
		return
	var r := await scegli(1, "evento", "Briganti", "%s marcia vicino ai tuoi: giocare Briganti?" % nome(id),
		[opz("monete", "Prendi 2 Monete"), opz("bottino", "Prendi 2 Bottino"), opz("carri", "Prendi 4 Carri e 4 Provviste"), opz("no", "Tieni la carta")])
	if r == "no":
		return
	tenute[1].erase("H19")
	_scarta_evento("H19")
	var dest := ""
	for x in ["giordano", "astimberg"]:
		if sulla_mappa(x):
			dest = x
	var trasf = {"monete": [["moneta", 2]], "bottino": [["bottino", 2]], "carri": [["carro", 4], ["prov", 4]]}[r]
	for t in trasf:
		var n: int = mini(supp(id, t[0]), t[1])
		add_supp(id, t[0], -n)
		add_supp(dest, t[0], n)
	log_msg("Briganti! %s viene derubato." % nome(id))


## Avvicinamento (4.3.4): la parte inattiva può Evitare la Battaglia o Ritirarsi.
func _avvicinamento(id: String, v: String, da: String) -> void:
	var s := lato(id)
	var e := 1 - s
	var imboscata_usata := false
	for x in fuori_in(v, e):
		if comune_di(x) != "":
			continue
		if not sulla_mappa(x) or L[x]["dentro"] or L[x]["loc"] != v:
			continue
		var g := gruppo_comune(x)
		var o := [opz("combatti", "Resta e combatti")]
		if caposaldo(v) and amica(v, e):
			if dentro_in(v, e).size() + g.size() <= valore(v):
				o.append(opz("_dentro", "Ritirati dentro %s" % lnome(v), {"loc": v}))
		for w in vicine(v):
			if w == da or not puo_entrare(x, w):
				continue
			if not fuori_in(w, s).is_empty():
				continue
			o.append(opz("evita:" + w, "Evita la battaglia: a %s%s" % [lnome(w), " (lasciando il bottino)" if supp(x, "bottino") > 0 or supp(x, "prov") > supp(x, "carro") else ""], {"loc": w}))
		var r := await scegli(e, "avvicinamento", "%s si avvicina a %s!" % [nome(id), lnome(v)],
			"%s (forza %.0f) contro %s (forza %.0f). Che cosa fa %s?" % [_elenco(_senza_comuni(fuori_in(v, s))), forza_gruppo(fuori_in(v, s)), nome(x), forza_gruppo(g), nome(x)], o, {"sig": x})
		if r.begins_with("evita:"):
			var imb := "G01" if s == 0 else "H01"
			if not imboscata_usata and imb in tenute[s]:
				var rr := await scegli(s, "evento", "Imboscata", "%s cerca di evitare la battaglia: giocare Imboscata?" % nome(x), [opz("si", "Gioca Imboscata"), opz("no", "No")])
				if rr == "si":
					tenute[s].erase(imb)
					_scarta_evento(imb)
					imboscata_usata = true
					log_msg("IMBOSCATA! %s non riesce a sottrarsi." % nome(x))
					continue
			var w := r.substr(6)
			for y in g:
				# lascia il Bottino e le Provviste che non può portare
				var lb := supp(y, "bottino")
				var lp := maxi(0, supp(y, "prov") - supp(y, "carro"))
				add_supp(y, "bottino", -lb)
				add_supp(y, "prov", -lp)
				if lb + lp > 0:
					add_supp(id, "bottino", lb)
					add_supp(id, "prov", lp)
				L[y]["loc"] = w
				L[y]["mosso"] = true
				L[y]["aggira"] = false
				L[y]["dentro"] = false
			log_msg("%s evita la battaglia e ripiega a %s." % [nome(x), lnome(w)])
			if caposaldo_nemico(w, e) and loc[w]["assedio"] == 0:
				for y in g:
					L[y]["aggira"] = true
		elif r == "_dentro":
			for y in g:
				L[y]["dentro"] = true
				L[y]["aggira"] = false
			log_msg("%s si ritira dentro %s." % [nome(x), lnome(v)])
	changed.emit()


# ---------------------------------------------------------------- Assedio (4.5.1)

func _azione_assedio(id: String) -> void:
	var s := lato(id)
	var l: String = L[id]["loc"]
	var dentro := dentro_in(l, 1 - s)
	if dentro.is_empty():
		var n := valore(l)
		var soglia: int = loc[l]["assedio"] + (1 if loc[l]["dev"] >= 0 else 0)
		var dd := []
		var ok := true
		for i in n:
			var x := d6()
			dd.append(x)
			if x > soglia:
				ok = false
		log_msg("%s chiede la resa di %s: dadi %s contro %d." % [nome(id), lnome(l), _dadi(dd), soglia])
		dadi_ultimi = dd
		if ok:
			log_msg("%s SI ARRENDE!" % lnome(l))
			cambia_alleanza(l, s, true)
			loc[l]["assedio"] = 0
			loc[l]["assedio_l"] = -1
			fx.emit("resa", {"loc": l})
			for i in n:
				await tiro_rivolta(s)
			await aggiungi_tradimento(s, n)
			for x in signori_in(l, s):
				L[x]["mosso"] = true
			return
	var cap := valore(l)
	var assedianti := 0
	for x in fuori_in(l, s):
		assedianti += 1
		if ha_cap(x, "Genieri di Guerra"):
			assedianti = 99
	if assedianti >= cap and loc[l]["assedio"] < 4:
		var add := 2 if ha_cap(id, "Guastatori") else 1
		loc[l]["assedio"] = mini(4, loc[l]["assedio"] + add)
		log_msg("Le opere d'assedio attorno a %s crescono (Assedio %d)." % [lnome(l), loc[l]["assedio"]])
	else:
		log_msg("L'assedio di %s continua (servono %d Signori per avanzare le opere)." % [lnome(l), cap])
	for x in signori_in(l):
		L[x]["mosso"] = true


# ---------------------------------------------------------------- Tradimento (4.7.5 - 4.7.6)

func _carta_tradimento(id: String) -> void:
	var s := lato(id)
	var l: String = L[id]["loc"]
	log_msg("Carta TRADIMENTO di %s." % nome(id))
	if assediato(id):
		log_msg("%s è assediato e non può tramare." % nome(id))
		return
	var monete := 0
	for x in signori_in(l, s):
		monete += supp(x, "moneta")
	var o := []
	for v in [l] + vicine(l):
		if not caposaldo(v) or amica(v, s) or not disponibile_rivolta(v):
			continue
		var gratis := _tradimento_gratis(s, id, v)
		if gratis != "":
			o.append(opz("riv0:" + v, "Rivolta a %s gratis (evento «%s»)" % [lnome(v), D.CARTE[gratis]["ev"]], {"loc": v}))
		for m in range(1, mini(4, monete) + 1):
			var p := pow(m / 6.0, valore(v))
			o.append(opz("riv:%s:%d" % [v, m], "Rivolta a %s con %d Monet%s (%d%%)" % [lnome(v), m, "a" if m == 1 else "e", int(round(p * 100))], {"loc": v}))
	if monete > 0:
		for v in V:
			if not _corrompibile(id, v):
				continue
			var p: float = (6 - int(D.VASSALLI[v]["serv"])) / 6.0
			o.append(opz("cor:" + v, "Corrompi %s (%d%%)" % [D.VASSALLI[v]["nome"], int(round(maxf(0.0, p) * 100))], {"vas": v}))
	o.append(opz("passa", "Passare"))
	var r := await scegli(s, "tradimento_az", "Tradimento: %s" % nome(id), "Rivolta di un Caposaldo nemico vicino o Corruzione di un Vassallo nemico.", o, {"sig": id})
	if r.begins_with("riv0:"):
		var v := r.substr(5)
		var c := _tradimento_gratis(s, id, v)
		tenute[s].erase(c)
		_scarta_evento(c)
		cambia_alleanza(v, s)
		log_msg("Tradimento: %s apre le porte ai %s!" % [lnome(v), D.LATI[s]])
	elif r.begins_with("riv:"):
		var p: PackedStringArray = r.split(":")
		var v := p[1]
		var m := int(p[2])
		var dd := []
		var ok := true
		for i in valore(v):
			var x := d6()
			dd.append(x)
			if x > m:
				ok = false
		if ok:
			_paga_monete(l, s, m)
			cambia_alleanza(v, s)
			log_msg("Tradimento: %s passa ai %s (dadi %s)." % [lnome(v), D.LATI[s], _dadi(dd)])
		else:
			log_msg("Tradimento a %s fallito (dadi %s contro %d)." % [lnome(v), _dadi(dd), m])
	elif r.begins_with("cor:"):
		var v := r.substr(4)
		var x := d6()
		if x > int(D.VASSALLI[v]["serv"]):
			_paga_monete(l, s, 1)
			var da: String = V[v]["presso"]
			if V[v]["stato"] == "radunato" and sulla_mappa(da):
				for u in D.VASSALLI[v]["forze"]:
					var n := togli_unita(da, u, int(D.VASSALLI[v]["forze"][u]))
					pool[u] -= n
					L[id]["forze"][u] = int(L[id]["forze"].get(u, 0)) + n
				V[v]["presso"] = id
				V[v]["stato"] = "radunato"
				if unita(da) == 0:
					await rimuovi_signore(da, false)
			else:
				V[v]["presso"] = id
				_raduna_vassallo(id, v)
			log_msg("CORRUZIONE: %s passa con %s (dado %d)." % [D.VASSALLI[v]["nome"], nome(id), x])
		else:
			log_msg("%s rifiuta l'oro di %s (dado %d)." % [D.VASSALLI[v]["nome"], nome(id), x])
	else:
		log_msg("%s passa." % nome(id))
	changed.emit()


func _tradimento_gratis(s: int, id: String, v: String) -> String:
	var mappa := {"G15": "", "G18": "grosseto", "G19": "volterra", "H18": "cortona"}
	for c in tenute[s]:
		if not mappa.has(c):
			continue
		if c == "G15":
			if id == "firenze" and D.LOCALI[v]["tipo"] == "castello":
				return c
		elif mappa[c] == v:
			return c
	return ""


func _corrompibile(id: String, v: String) -> bool:
	var s := lato(id)
	var vd: Dictionary = D.VASSALLI[v]
	if vd.get("speciale", "") != "":
		return false
	var pr: String = V[v]["presso"]
	if V[v]["stato"] == "fuori":
		return false
	if lato(pr) == s:
		return false
	var l: String = L[id]["loc"]
	var area := [l] + vicine(l)
	if V[v]["stato"] == "radunato":
		return sulla_mappa(pr) and L[pr]["loc"] in area
	for sl in vd["sedi"]:
		if sl in area:
			return true
	return false


func _paga_monete(l: String, s: int, n: int) -> void:
	for x in signori_in(l, s):
		while n > 0 and supp(x, "moneta") > 0:
			add_supp(x, "moneta", -1)
			n -= 1


# ---------------------------------------------------------------- Nutrire / Pagare / Smobilitare (4.8)

func _nutri_paga_smobilita() -> void:
	for s in [0, 1]:
		_nutri(s)
	for s in [0, 1]:
		await _paga(s, false)
	for s in [0, 1]:
		await _smobilita(s)
		if over:
			return
	for id in L:
		L[id]["mosso"] = false


func _fabbisogno(id: String) -> int:
	var u := 0
	for x in gruppo_comune(id):
		u += unita(x)
	return mini(3, int(ceil(u / 6.0)))


func _nutri(s: int) -> void:
	var manca := {}
	for id in signori_mappa(s):
		var g := gruppo_comune(id)
		var mosso := false
		for x in g:
			if L[x]["mosso"]:
				mosso = true
		if not mosso:
			continue
		var need := _fabbisogno(id)
		for x in g:
			for k in ["prov", "bottino"]:
				while need > 0 and supp(x, k) > 0:
					add_supp(x, k, -1)
					need -= 1
		if need > 0:
			manca[id] = need
	# condivisione
	for id in manca.keys():
		var l: String = L[id]["loc"]
		for x in signori_in(l, s):
			if manca.has(x) or x == id:
				continue
			for k in ["prov", "bottino"]:
				while manca[id] > 0 and supp(x, k) > 0:
					add_supp(x, k, -1)
					manca[id] -= 1
		if manca[id] > 0:
			sposta_servizio(id, -1)
			log_msg("%s non ha da mangiare: il Servizio si accorcia (fino al turno %d)." % [nome(id), L[id]["svc"]])


# ================================================================ fine della Campagna (4.9)

func _fine_campagna() -> void:
	passo = "Fine della campagna"
	fase = "fine_campagna"
	# Crescita
	if turno in D.CRESCITA and not turno in S.get("no_crescita", []):
		for s in [0, 1]:
			var nem := []
			for l in loc:
				if loc[l]["dev"] == 1 - s:
					nem.append(l)
			var resta := int(ceil(nem.size() / 2.0))
			var togli := nem.size() - resta
			if togli > 0:
				# toglie prima quelle più vicine ai propri Signori
				nem.sort_custom(func(a, b): return _vicinanza(a, s) < _vicinanza(b, s))
				for i in togli:
					loc[nem[i]]["dev"] = -1
				log_msg("Crescita: i %s rimettono in sesto %d località devastate." % [D.LATI[s], togli])
	# Riscatto
	for s in [0, 1]:
		await _riscatto(s, false)
	# Fine della partita?
	if turno >= turno_fine:
		_fine_partita()
		return
	# Riparazioni
	for l in loc:
		if D.LOCALI[l]["tipo"] in ["citta", "cittadina"] and loc[l]["assedio"] >= 3:
			loc[l]["assedio"] -= 1
	# Spreco
	for s in [0, 1]:
		for id in signori_mappa(s, true):
			var troppo := false
			for k in L[id]["supp"]:
				if supp(id, k) > 1:
					troppo = true
			if troppo:
				_spreco_uno(id)
			elif L[id]["caps"].size() > 1:
				_scarta_evento(L[id]["caps"].pop_back())
	# Reset
	for s in [0, 1]:
		for c in piano[s]:
			if c["t"] == "trad":
				tradimento[s].erase(c["l"])
		piano[s] = []
	for e in ev_attivi.duplicate():
		if e["fino"] == "campagna":
			ev_attivi.erase(e)
			_scarta_evento(e["id"])
	lavori = [false, false]
	no_tasse = [false, false]
	frati = false
	if maremma_blocco:
		for l in loc:
			if (loc[l]["assedio"] > 0 and loc[l]["assedio_l"] == 0) or loc[l]["dev"] == 1 and lato_stampato(l) == 1:
				maremma_blocco = false
	changed.emit()


func _vicinanza(l: String, s: int) -> int:
	var best := 99
	for id in signori_mappa(s):
		best = mini(best, distanza(L[id]["loc"], l))
	return best


func _riscatto(s: int, evento: bool) -> void:
	var n: int = catturati[s]["cav"] + catturati[s]["ritter"]
	if n == 0:
		return
	var costo := int(ceil(n / 6.0))
	var monete := 0
	for id in signori_mappa(s, true):
		monete += supp(id, "moneta")
	var paga := false
	if monete >= costo:
		var r := await scegli(s, "riscatto", "Riscatto", "%d tuoi cavalieri sono prigionieri. Pagare %d Monet%s per riaverne la metà?" % [n, costo, "a" if costo == 1 else "e"],
			[opz("si", "Paga il riscatto"), opz("no", "Abbandonali")])
		paga = r == "si"
	if paga:
		var resto := costo
		for id in signori_mappa(s, true):
			while resto > 0 and supp(id, "moneta") > 0:
				add_supp(id, "moneta", -1)
				resto -= 1
		var dest := signori_mappa(1 - s)
		if not dest.is_empty():
			_distribuisci(dest, "moneta", costo)
		var torna := int(ceil(n / 2.0))
		var miei := signori_mappa(s)
		var i := 0
		for u in ["ritter", "cav"]:
			while catturati[s][u] > 0:
				catturati[s][u] -= 1
				if torna > 0 and not miei.is_empty():
					var id: String = miei[i % miei.size()]
					L[id]["forze"][u] = int(L[id]["forze"].get(u, 0)) + 1
					i += 1
					torna -= 1
				else:
					pool[u] += 1
		log_msg("I %s riscattano i loro cavalieri." % D.LATI[s])
		return
	if evento:
		return
	# Abbandono
	var volte := costo
	log_msg("I %s abbandonano i loro cavalieri prigionieri." % D.LATI[s])
	for u in ["ritter", "cav"]:
		pool[u] += catturati[s][u]
		catturati[s][u] = 0
	for i in volte:
		var r := await scegli(1 - s, "abbandono", "Abbandono", "Il nemico ha abbandonato i suoi cavalieri: tirare sulla Rivolta o aggiungere 1 Tradimento?",
			[opz("rivolta", "Tira sulla Rivolta"), opz("trad", "Aggiungi 1 Tradimento")])
		if r == "rivolta":
			await tiro_rivolta(1 - s)
		else:
			await aggiungi_tradimento(1 - s, 1)


# ================================================================ salvataggi

func stato_sintetico() -> Dictionary:
	return {"turno": turno, "fase": fase, "pv": [pv(0), pv(1)]}
