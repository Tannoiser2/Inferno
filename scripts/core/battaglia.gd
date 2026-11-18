class_name InfBattaglia
extends InfStato
## Battaglia campale (4.4), Assalto (4.5.2) e Sortita (4.5.3).
## Chi combatte è un «gruppo di unità»: un Signore (le sue forze sulla scheda) oppure la Guarnigione
## del Caposaldo nell'Assalto. Le posizioni del fronte sono 0 sinistra, 1 centro, 2 destra.

const GUARN := "_guarnigione"


func _forze(h: String) -> Dictionary:
	return battaglia["guarn"]["forze"] if h == GUARN else L[h]["forze"]


func _rotte(h: String) -> Dictionary:
	return battaglia["guarn"]["rotte"] if h == GUARN else L[h]["rotte"]


func _lato_h(h: String) -> int:
	return battaglia["dif"] if h == GUARN else lato(h)


func _n(h: String, u: String) -> int:
	return int(_forze(h).get(u, 0))


func _vive(h: String) -> int:
	var t := 0
	for u in _forze(h):
		t += int(_forze(h)[u])
	return t


func ha_cap(id: String, nome_cap: String) -> bool:
	if id == GUARN or not L.has(id):
		return false
	for c in L[id]["caps"]:
		if D.CARTE[c]["cap"] == nome_cap:
			return true
	return false


func cap_parte(s: int, nome_cap: String) -> bool:
	for c in cap_lato[s]:
		if D.CARTE[c]["cap"] == nome_cap:
			return true
	return false


# ================================================================ preparazione

## Battaglia campale in l: att è il lato che Marcia. Restituisce il lato vincitore.
func battaglia_campale(l: String, att: int, attivo_id: String, via_da: String, soccorso := []) -> int:
	var dif := 1 - att
	var a_lords := fuori_in(l, att)
	var d_lords := fuori_in(l, dif)
	battaglia = {"tipo": "battaglia", "loc": l, "att": att, "dif": dif, "round": 0, "lascia": -1,
		"fronte": [["", "", ""], ["", "", ""]], "riserva": [a_lords.duplicate(), d_lords.duplicate()], "rotti": [[], []],
		"tutti": [a_lords.duplicate(), d_lords.duplicate()],
		"via_da": via_da, "eventi": {}, "perse": {}, "righe": [], "soccorso": soccorso, "opere": 0, "mura": 0,
		"guarn": {"forze": {}, "rotte": {}}, "esito": "", "sortiti": [], "sortiti_ris": [], "auto_colpi": [false, false],
		"fianco_c": ["", ""]}
	if att == 1:
		battaglia["riserva"] = [d_lords.duplicate(), a_lords.duplicate()]
		battaglia["tutti"] = [d_lords.duplicate(), a_lords.duplicate()]
	# Sortita di soccorso: gli assediati escono dal Caposaldo dietro i difensori
	for id in soccorso:
		battaglia["tutti"][att].append(id)
		battaglia["sortiti_ris"].append(id)
	battaglia["opere"] = loc[l]["assedio"] if not soccorso.is_empty() else 0
	log_msg("BATTAGLIA a %s: %s contro %s." % [lnome(l), _elenco(battaglia["tutti"][att]), _elenco(battaglia["tutti"][dif])])
	fx.emit("battaglia_inizio", battaglia)
	await _schiera_campale(att, attivo_id, a_lords)
	await _schiera_difesa(dif, d_lords)
	if not soccorso.is_empty():
		await _esce_sortita(true)
	return await _combatti()


## Assalto a un Caposaldo assediato. Restituisce il lato vincitore.
func assalto(l: String, att: int, attivo_id: String, max_round := -1, mura_mod := 0) -> int:
	var dif := 1 - att
	var a_lords := fuori_in(l, att)
	var d_lords := dentro_in(l, dif)
	var v := valore(l)
	var g := {}
	match v:
		3:
			g = {"uia": 3, "arm": 3, "cav": 3}
		2:
			g = {"uia": 2, "arm": 2, "cav": 2}
		_:
			g = {"uia": 1, "mil": 1, "cav": 1}
	if v == 1 and dif == 1 and cap_parte(1, "Sovrintendente") and g.has("mil"):
		g.erase("mil")
		g["arm"] = 1
	var mura := 4 + (1 if loc[l]["mura"] == dif else 0) + mura_mod
	battaglia = {"tipo": "assalto", "loc": l, "att": att, "dif": dif, "round": 0, "lascia": -1,
		"fronte": [["", "", ""], ["", "", ""]], "riserva": [[], []], "rotti": [[], []], "tutti": [[], []],
		"via_da": "", "eventi": {}, "perse": {}, "righe": [], "soccorso": [],
		"opere": loc[l]["assedio"], "mura": mura, "max_round": max_round if max_round > 0 else loc[l]["assedio"],
		"guarn": {"forze": g, "rotte": {}}, "esito": ""}
	var aa := a_lords.duplicate()
	aa.erase(attivo_id)
	battaglia["fronte"][att][1] = attivo_id
	battaglia["riserva"][att] = aa
	battaglia["tutti"][att] = a_lords
	battaglia["tutti"][dif] = d_lords
	battaglia["riserva"][dif] = d_lords.duplicate()
	for k in ["sortiti", "sortiti_ris"]:
		battaglia[k] = []
	battaglia["auto_colpi"] = [false, false]
	battaglia["fianco_c"] = ["", ""]
	log_msg("ASSALTO a %s: %s contro la guarnigione%s." % [lnome(l), _elenco(a_lords), (" e " + _elenco(d_lords)) if not d_lords.is_empty() else ""])
	fx.emit("battaglia_inizio", battaglia)
	await _primo_difensore(dif)
	return await _combatti()


## Sortita: gli assediati (att) attaccano gli assedianti. Restituisce il lato vincitore.
func sortita(l: String, att: int, attivo_id: String) -> int:
	var dif := 1 - att
	var a_lords := dentro_in(l, att)
	var d_lords := fuori_in(l, dif)
	battaglia = {"tipo": "sortita", "loc": l, "att": att, "dif": dif, "round": 0, "lascia": -1,
		"fronte": [["", "", ""], ["", "", ""]], "riserva": [[], []], "rotti": [[], []], "tutti": [[], []],
		"via_da": "", "eventi": {}, "perse": {}, "righe": [], "soccorso": [],
		"opere": loc[l]["assedio"], "mura": 0, "guarn": {"forze": {}, "rotte": {}}, "esito": ""}
	var aa := a_lords.duplicate()
	aa.erase(attivo_id)
	battaglia["fronte"][att][1] = attivo_id
	battaglia["riserva"][att] = aa
	battaglia["tutti"][att] = a_lords
	battaglia["tutti"][dif] = d_lords
	battaglia["riserva"][dif] = d_lords.duplicate()
	for k in ["sortiti", "sortiti_ris"]:
		battaglia[k] = []
	battaglia["auto_colpi"] = [false, false]
	battaglia["fianco_c"] = ["", ""]
	log_msg("SORTITA da %s: %s contro %s." % [lnome(l), _elenco(a_lords), _elenco(d_lords)])
	fx.emit("battaglia_inizio", battaglia)
	await _primo_difensore(dif)
	return await _combatti()


func _elenco(ids: Array) -> String:
	var n := []
	for id in ids:
		n.append(nome(id))
	return ", ".join(n) if not n.is_empty() else "nessuno"


func _piu_forte(ids: Array) -> String:
	var best := ""
	var bv := -1.0
	for id in ids:
		if forza(id) > bv:
			bv = forza(id)
			best = id
	return best


## Nome della posizione del Fronte vista da chi ci sta: i Guelfi guardano verso est, i Ghibellini verso ovest.
func nome_pos(s: int, p: int) -> String:
	if p == 1:
		return "centro"
	return "ala sinistra" if (p == 0) == (s == 0) else "ala destra"


## Una scelta di battaglia: le fazioni dell'IA usano subito il consiglio (niente attese a ogni colpo).
func _scelta_batt(s: int, k: String, titolo: String, testo: String, o: Array, consiglio: String, extra := {}) -> String:
	if o.is_empty():
		return ""
	if players[s]["ai"] or o.size() == 1:
		return consiglio if consiglio != "" else str(o[0]["id"])
	extra["consiglio"] = consiglio
	return await scegli(s, k, titolo, testo, o, extra)


func _opz_signori(ids: Array) -> Array:
	var o := []
	for id in ids:
		o.append(opz(id, "%s (%d unità)" % [nome(id), _vive(id)], {"sig": id}))
	return o


## Schieramento dell'attaccante: il Signore Attivo al centro, poi chi va sulle ali; gli altri in Riserva.
func _schiera_campale(s: int, attivo_id: String, ids: Array) -> void:
	var b := battaglia
	var resto: Array = b["riserva"][s]
	var centro := attivo_id if attivo_id in ids else _piu_forte(ids)
	b["fronte"][s][1] = centro
	resto.erase(centro)
	fx.emit("battaglia_round", b)
	for pos in [0, 2]:
		if resto.is_empty():
			break
		var x := await _scelta_batt(s, "schiera", "Schieramento: %s" % nome_pos(s, pos),
			"%s è al centro del Fronte. Chi metti sull'%s? Chi non va al Fronte resta in Riserva." % [nome(centro), nome_pos(s, pos)],
			_opz_signori(resto), _piu_forte(resto), {"t": centro})
		b["fronte"][s][pos] = x
		resto.erase(x)
		fx.emit("battaglia_round", b)


## Schieramento del difensore: un Signore davanti a ogni attaccante del Fronte, prima al centro poi sulle ali.
func _schiera_difesa(s: int, ids: Array) -> void:
	var b := battaglia
	var att := 1 - s
	var resto: Array = b["riserva"][s]
	for pos in [1, 0, 2]:
		if b["fronte"][att][pos] != "" and not resto.is_empty():
			var nemico: String = b["fronte"][att][pos]
			var x := await _scelta_batt(s, "schiera", "Schieramento: %s" % nome_pos(s, pos),
				"Chi affronta %s (%d unità) sul tuo %s? Il difensore deve mettere un Signore davanti a ogni attaccante del Fronte." % [nome(nemico), _vive(nemico), nome_pos(s, pos)],
				_opz_signori(resto), _piu_forte(resto), {"t": nemico})
			b["fronte"][s][pos] = x
			resto.erase(x)
			fx.emit("battaglia_round", b)


## Assalto e Sortita: il difensore sceglie chi sta al Fronte (al centro); gli altri in Riserva.
func _primo_difensore(s: int) -> void:
	var b := battaglia
	var resto: Array = b["riserva"][s]
	if resto.is_empty():
		return
	var x := await _scelta_batt(s, "schiera", "Schieramento: chi difende sul Fronte?",
		"Ogni parte comincia con un solo Signore sul Fronte; gli altri restano in Riserva ed entrano un round alla volta.",
		_opz_signori(resto), _piu_forte(resto))
	b["fronte"][s][1] = x
	resto.erase(x)
	fx.emit("battaglia_round", b)


## Sortita di soccorso: un Signore assediato esce dietro i difensori (all'inizio è obbligatorio, poi uno a round
## fino alla dimensione del Caposaldo).
func _esce_sortita(obbligo: bool) -> void:
	var b := battaglia
	var att: int = b["att"]
	var ris: Array = b["sortiti_ris"]
	var attivi := []
	for id in b["sortiti"]:
		if not id in b["rotti"][att] and _vive(id) > 0:
			attivi.append(id)
	if ris.is_empty() or (attivi.size() >= valore(b["loc"]) and not attivi.is_empty()):
		return
	var o := _opz_signori(ris)
	if not obbligo and not attivi.is_empty():
		o.append(opz("no", "Nessuno esce in questo round"))
	var x := await _scelta_batt(att, "sortita_esce", "Sortita di soccorso",
		"Quale Signore esce da %s e attacca i difensori alle spalle?" % lnome(b["loc"]), o, _piu_forte(ris))
	if x == "no" or x == "":
		return
	ris.erase(x)
	b["sortiti"].append(x)
	_riga("%s esce da %s e attacca alle spalle." % [nome(x), lnome(b["loc"])])
	fx.emit("battaglia_round", b)


# ================================================================ svolgimento

func _riga(t: String) -> void:
	battaglia["righe"].append(t)
	log_msg("   " + t)
	fx.emit("battaglia_riga", {"t": t})


func _combatti() -> int:
	var b := battaglia
	await _pace_b(1.6)
	await _eventi_inizio()
	await _pace_b(0.8)
	while true:
		b["round"] += 1
		var r: int = b["round"]
		_riga("Round %d." % r)
		# Lasciare il campo?
		if r > 1 or b["tipo"] == "battaglia":
			for s in [b["att"], b["dif"]]:
				if b["lascia"] >= 0:
					break
				if b["tipo"] == "assalto" and (s != b["att"] or r == 1):
					continue
				if b["tipo"] == "battaglia" or (b["tipo"] == "assalto" and s == b["att"]) or b["tipo"] == "sortita":
					if await _chiedi_lascia(s):
						b["lascia"] = s
						_riga("I %s lasciano il campo dopo questo round." % D.LATI[s])
			if b["tipo"] == "assalto" and b["lascia"] == b["att"]:
				_riga("Gli attaccanti rinunciano all'Assalto.")
				return await _fine(b["dif"])
		if r > 1:
			await _riposiziona()
		fx.emit("battaglia_round", b)
		await _scegli_fianchi()
		for ph in _fasi(r):
			await _fase(ph[0], ph[1], r)
			var p := _perdente()
			if p >= 0 and b["tipo"] != "assalto":
				pass
		await _distringitores()
		var perde := _perdente()
		if perde >= 0:
			return await _fine(1 - perde)
		if b["lascia"] >= 0:
			return await _fine(1 - b["lascia"])
		if b["tipo"] == "assalto" and r >= b["max_round"]:
			_riga("L'Assalto si esaurisce: il Caposaldo resiste.")
			return await _fine(b["dif"])
		if r >= 12:
			return await _fine(b["dif"])
		await _pace_b(0.6)
	return b["dif"]


## Il lato che ha perso tutti i Signori (nell'Assalto i difensori perdono con la Guarnigione in Rotta).
func _perdente() -> int:
	var b := battaglia
	for s in [b["att"], b["dif"]]:
		var vivi := 0
		for id in b["tutti"][s]:
			if not id in b["rotti"][s] and _vive(id) > 0:
				vivi += 1
		if b["tipo"] == "assalto" and s == b["dif"] and _vive(GUARN) > 0:
			vivi += 1
		if vivi == 0:
			return s
	return -1


func _chiedi_lascia(s: int) -> bool:
	var b := battaglia
	var t := "Round %d a %s. Le tue forze: %s. Il nemico: %s." % [b["round"], lnome(b["loc"]), _stato_lato(s), _stato_lato(1 - s)]
	if b["tipo"] == "assalto":
		t += " Rinunciando all'Assalto perdi, ma resti ad assediare."
	else:
		t += " Lasciando il campo perdi la battaglia dopo questo round, ma con meno perdite (il nemico ti insegue)."
	var r := await scegli(s, "lascia", "Lasciare il campo?", t,
		[opz("no", "Continua a combattere"), opz("si", "Rinuncia" if b["tipo"] == "assalto" else "Lascia il campo")])
	return r == "si"


func _stato_lato(s: int) -> String:
	var b := battaglia
	var parti := []
	for id in b["tutti"][s]:
		if id in b["rotti"][s]:
			parti.append("%s in rotta" % nome(id))
		else:
			parti.append("%s %d unità" % [nome(id), _vive(id)])
	if b["tipo"] == "assalto" and s == b["dif"]:
		parti.append("guarnigione %d" % _vive(GUARN))
	return ", ".join(parti)


func _riposiziona() -> void:
	var b := battaglia
	# Rotta: i Signori in rotta lasciano lo Schieramento
	for s in [b["att"], b["dif"]]:
		for p in 3:
			var id: String = b["fronte"][s][p]
			if id != "" and (id in b["rotti"][s] or _vive(id) == 0):
				b["fronte"][s][p] = ""
		for id in b["riserva"][s].duplicate():
			if id in b["rotti"][s] or _vive(id) == 0:
				b["riserva"][s].erase(id)
	if b["tipo"] == "battaglia":
		# Avanzata: dalla Riserva in ogni posizione vuota del Fronte (prima l'attaccante, poi il difensore)
		for s in [b["att"], b["dif"]]:
			if s == b["dif"] and _sortiti_attivi().size() > 0:
				continue    # i difensori in Riserva stanno affrontando la sortita alle spalle
			for p in [1, 0, 2]:
				var ris: Array = b["riserva"][s]
				if b["fronte"][s][p] == "" and not ris.is_empty():
					var x := await _scelta_batt(s, "avanza", "Avanzata: %s" % nome_pos(s, p),
						"Il tuo %s è vuoto: quale Signore avanza dalla Riserva?" % nome_pos(s, p), _opz_signori(ris), _piu_forte(ris))
					b["fronte"][s][p] = x
					ris.erase(x)
					fx.emit("battaglia_round", b)
		# Centro: se è vuoto, ci va un Signore da un'ala
		for s in [b["att"], b["dif"]]:
			if b["fronte"][s][1] == "":
				var ali := []
				for p in [0, 2]:
					if b["fronte"][s][p] != "":
						ali.append(b["fronte"][s][p])
				if not ali.is_empty():
					var o := []
					for id in ali:
						o.append(opz(id, "%s, dall'%s (%d unità)" % [nome(id), nome_pos(s, b["fronte"][s].find(id)), _vive(id)], {"sig": id}))
					var x := await _scelta_batt(s, "al_centro", "Centro vuoto", "Il centro del tuo Fronte è vuoto: quale Signore ci si sposta da un'ala?", o, _piu_forte(ali))
					var p0: int = b["fronte"][s].find(x)
					b["fronte"][s][p0] = ""
					b["fronte"][s][1] = x
					fx.emit("battaglia_round", b)
		if not b["sortiti_ris"].is_empty():
			await _esce_sortita(_sortiti_attivi().is_empty())
	else:
		# Assalto e Sortita: si può aggiungere un Signore per round, fino alla dimensione del Caposaldo
		var cap := valore(b["loc"])
		for s in [b["att"], b["dif"]]:
			var ris: Array = b["riserva"][s]
			if ris.is_empty():
				continue
			var occ := 0
			for p in 3:
				if b["fronte"][s][p] != "":
					occ += 1
			if occ >= cap and occ > 0:
				continue
			var o := _opz_signori(ris)
			if occ > 0:
				o.append(opz("no", "Nessuno in questo round"))
			var x := await _scelta_batt(s, "aggiungi", "Rinforzi al Fronte",
				("Il tuo Fronte è vuoto: un Signore dalla Riserva deve avanzare." if occ == 0 else "Puoi portare un Signore dalla Riserva al Fronte (al massimo %d sul Fronte)." % cap),
				o, _piu_forte(ris))
			if x == "no" or x == "":
				continue
			for p in [1, 0, 2]:
				if b["fronte"][s][p] == "":
					b["fronte"][s][p] = x
					break
			ris.erase(x)
			fx.emit("battaglia_round", b)


func _sortiti_attivi() -> Array:
	var b := battaglia
	var out := []
	for id in b.get("sortiti", []):
		if not id in b["rotti"][b["att"]] and _vive(id) > 0:
			out.append(id)
	return out


## Difensori in Riserva che affrontano la sortita di soccorso alle spalle.
func _retro_difesa() -> Array:
	var b := battaglia
	var out := []
	if _sortiti_attivi().is_empty():
		return out
	for id in b["riserva"][b["dif"]]:
		if not id in b["rotti"][b["dif"]] and _vive(id) > 0:
			out.append(id)
	return out


## All'inizio del round: un centro senza nemico davanti, con entrambe le ali nemiche, sceglie chi aggirare.
func _scegli_fianchi() -> void:
	var b := battaglia
	b["fianco_c"] = ["", ""]
	if b["tipo"] != "battaglia":
		return
	for s in [b["att"], b["dif"]]:
		var c: String = b["fronte"][s][1]
		if c == "" or c in b["rotti"][s] or _vive(c) == 0:
			continue
		var e = 1 - s
		var fe := {}
		for x in _fronte(e):
			fe[x[0]] = x[1]
		if fe.has(1) or not (fe.has(0) and fe.has(2)):
			continue
		var o := []
		for p in [0, 2]:
			o.append(opz(fe[p], "%s (%s nemica, %d unità)" % [nome(fe[p]), nome_pos(e, p), _vive(fe[p])], {"sig": fe[p]}))
		var debole: String = fe[0] if forza(fe[0]) <= forza(fe[2]) else fe[2]
		b["fianco_c"][s] = await _scelta_batt(s, "fianco", "Aggiramento sul Fianco",
			"%s al centro non ha nemici davanti: quale ala nemica aggira?" % nome(c), o, debole, {"t": c})


func _prendi_riserva(s: int) -> String:
	var b := battaglia
	var r: Array = b["riserva"][s]
	r.sort_custom(func(x, y): return forza(x) > forza(y))
	return r.pop_front()


func _fasi(r: int) -> Array:
	var b := battaglia
	var a: int = b["att"]
	var d: int = b["dif"]
	var out := []
	var torri: bool = b["tipo"] == "assalto" and r >= 2 and _fronte_ha_cap(a, "Torri d'Assedio")
	var scontro: int = int(b["eventi"].get("scontro", -1))
	if b["tipo"] == "assalto":
		if torri:
			out = [["arc", a], ["arc", d], ["mel", a], ["mel", d]]
		else:
			out = [["arc", d], ["arc", a], ["mel", d], ["mel", a]]
	else:
		out = [["arc", d], ["arc", a], ["cav", d], ["cav", a], ["inf", d], ["inf", a]]
		if r == 1 and scontro >= 0:
			out.erase(["cav", scontro])
			out.push_front(["cav", scontro])
	return out


func _fronte_ha_cap(s: int, c: String) -> bool:
	for id in battaglia["fronte"][s]:
		if id != "" and ha_cap(id, c):
			return true
	return false


func _fronte(s: int) -> Array:
	var out := []
	for p in 3:
		var id: String = battaglia["fronte"][s][p]
		if id != "" and not id in battaglia["rotti"][s] and _vive(id) > 0:
			out.append([p, id])
	return out


## Colpi di un gruppo in una fase: {"arco": x, "bal": y, "mel": z}
func _colpi(h: String, tipo: String, r: int) -> Dictionary:
	var b := battaglia
	var s := _lato_h(h)
	var storm: bool = b["tipo"] == "assalto"
	var garr := h == GUARN
	var out := {"arco": 0.0, "bal": 0.0, "mel": 0.0}
	if tipo == "arc":
		var mil := _n(h, "mil")
		if garr:
			out["arco"] += mil
			out["bal"] += 0.5 * _n(h, "uia") + 0.5 * _n(h, "arm")
		else:
			if ha_cap(h, "Luceria"):
				out["arco"] += 1.5 * mini(3, mil)
			elif ha_cap(h, "Arcieri"):
				out["arco"] += mil
			if ha_cap(h, "Balestrieri"):
				out["bal"] += mini(3, _n(h, "arm"))
			if storm and ha_cap(h, "Balestre grosse"):
				out["bal"] += 0.5 * _n(h, "uia")
		if b["eventi"].get("colline", -1) == s and s == b["dif"]:
			out["arco"] = (out["arco"] + out["bal"]) * 2.0
			out["bal"] = 0.0
		return out
	var cav := tipo in ["cav", "mel"]
	var inf := tipo in ["inf", "mel"]
	if cav:
		if r == 1 and b["eventi"].get("palude", -1) == 1 - s:
			pass
		else:
			out["mel"] += _n(h, "ritter") * (1.0 if storm else 2.0)
			var nc := _n(h, "cav")
			var dbl := 0
			if not storm and not garr:
				if r <= 2 and ha_cap(h, "Feditori"):
					dbl = mini(nc, 4 if s == 0 else 3)
				if r >= 3 and _riserva_armata(h):
					dbl = nc
			out["mel"] += nc + dbl
			if storm:
				out["mel"] += _n(h, "berr") * (1.0 if s == b["att"] else 0.5)
			else:
				out["mel"] += _n(h, "berr") * 0.5
			out["mel"] += _n(h, "cl") * 0.5
	if inf:
		out["mel"] += _n(h, "uia") + _n(h, "arm") + 0.5 * _n(h, "mil") + 0.5 * _n(h, "vill")
	return out


func _riserva_armata(id: String) -> bool:
	var s := lato(id)
	var base := id
	if comune_di(id) != "":
		base = comune_di(id)
	for c in cap_lato[s]:
		if D.CARTE[c]["cap"] in ["Riserva di Armata", "Riserva dell'Armata"] and base in D.CARTE[c].get("cap_sig", []):
			return true
	return false


## Bersaglio di un Signore del fronte: chi gli sta di fronte, altrimenti il più vicino (aggiramento).
func _bersaglio(s: int, pos: int) -> String:
	var e := 1 - s
	var fe := _fronte(e)
	if fe.is_empty():
		return ""
	for x in fe:
		if x[0] == pos:
			return x[1]
	if pos == 1 and battaglia.has("fianco_c") and battaglia["fianco_c"][s] != "":
		for x in fe:
			if x[1] == battaglia["fianco_c"][s]:
				return x[1]
	var best := ""
	var bd := 9
	for x in fe:
		var dd: int = abs(int(x[0]) - pos)
		if dd < bd:
			bd = dd
			best = x[1]
	return best


func _fase(tipo: String, s: int, r: int) -> void:
	var b := battaglia
	var e := 1 - s
	var attaccanti := []      # [posizione, signore]; -1 = sortita alle spalle, -2 = Riserva che affronta la sortita
	for x in _fronte(s):
		attaccanti.append(x)
	if b["tipo"] == "battaglia":
		if s == b["att"]:
			for id in _sortiti_attivi():
				attaccanti.append([-1, id])
		else:
			for id in _retro_difesa():
				attaccanti.append([-2, id])
	# la Guarnigione combatte con i difensori dell'Assalto
	if b["tipo"] == "assalto" and s == b["dif"] and _vive(GUARN) > 0:
		attaccanti.append([1, GUARN])
	var gruppi := {}     # bersaglio (+ "|s" se dalla sortita) -> {"t", "arco", "bal", "mel", "da": [], "sortita"}
	var ordine := []
	for x in attaccanti:
		var h: String = x[1]
		var c := _colpi(h, tipo, r)
		if c["arco"] + c["bal"] + c["mel"] <= 0.0:
			continue
		if b["tipo"] == "assalto" and tipo == "mel":
			c["mel"] = minf(c["mel"], 6.0)
		var t := _bersaglio_di(s, x[0])
		if t == "":
			continue
		var k := t + ("|s" if x[0] == -1 else "")
		if not gruppi.has(k):
			gruppi[k] = {"t": t, "arco": 0.0, "bal": 0.0, "mel": 0.0, "da": [], "sortita": x[0] == -1}
			ordine.append(k)
		for q in ["arco", "bal", "mel"]:
			gruppi[k][q] += c[q]
		gruppi[k]["da"].append(h)
	for k in ordine:
		var g: Dictionary = gruppi[k]
		var tot: float = g["arco"] + g["bal"] + g["mel"]
		if b["lascia"] == s:
			tot *= 0.5
			g["bal"] *= 0.5
		var colpi := int(ceil(tot - 0.0001))
		var bal := mini(colpi, int(ceil(g["bal"] - 0.0001))) if tipo == "arc" else 0
		if colpi <= 0:
			continue
		var t: String = g["t"]
		if t != GUARN and (_vive(t) == 0 or t in b["rotti"][e]):
			t = _nuovo_bersaglio(s, g["da"])
			if t == "":
				continue
		t = await _chi_assorbe(t, g["da"])
		var nomi := []
		for h in g["da"]:
			nomi.append("la guarnigione" if h == GUARN else nome(h))
		var cosa = {"arc": "tiro", "cav": "cavalleria", "inf": "fanteria", "mel": "mischia"}[tipo]
		_riga("%s: %s colpisce %s con %d colpi%s%s." % [cosa.capitalize(), ", ".join(nomi), "la guarnigione" if t == GUARN else nome(t), colpi,
			(" (%d di balestra)" % bal) if bal > 0 else "", " alle spalle" if g["sortita"] else ""])
		var scelta_att: bool = (bal > 0 and (_scelgono_bersaglio(g["da"]))) or (tipo == "cav" and r == 1 and b["eventi"].get("scontro", -1) == s)
		var mura_ok := true
		var primo := true
		var giri := 0
		# i Colpi che restano quando un Signore va in rotta passano alla nuova situazione di aggiramento
		while colpi > 0 and t != "" and giri < 6:
			giri += 1
			if not primo:
				_riga("%d colpi rimasti passano a %s." % [colpi, "la guarnigione" if t == GUARN else nome(t)])
			# la scena della battaglia anima il tiro o la carica, poi si vedono gli esiti
			fx.emit("battaglia_attacco", {"tipo": tipo, "s": s, "da": g["da"].duplicate(), "t": t, "colpi": colpi, "bal": bal, "sortita": g["sortita"]})
			await _pace_b(1.3 if primo else 0.7)
			var res := await _applica_colpi(t, colpi, bal, scelta_att, g["sortita"], mura_ok)
			fx.emit("battaglia_colpi", {"t": t, "n": colpi, "esiti": res["esiti"], "tipo": tipo})
			await _pace_b(clampf(0.5 + 0.18 * res["esiti"].size(), 0.6, 2.0))
			colpi = res["resto"]
			bal = res["resto_bal"]
			mura_ok = false
			primo = false
			if colpi > 0:
				t = _nuovo_bersaglio(s, g["da"])
				if t != "":
					t = await _chi_assorbe(t, g["da"])


## Il bersaglio di un attaccante: chi gli sta di fronte, o chi aggira; la sortita di soccorso colpisce la Riserva.
func _bersaglio_di(s: int, pos: int) -> String:
	var b := battaglia
	var e := 1 - s
	if b["tipo"] == "assalto" and e == b["dif"] and _vive(GUARN) > 0:
		return GUARN
	if pos == -1:
		var rd := _retro_difesa()
		if not rd.is_empty():
			return _piu_forte(rd)
		return _bersaglio(s, 1)
	if pos == -2:
		var so := _sortiti_attivi()
		return so[0] if not so.is_empty() else ""
	return _bersaglio(s, pos)


## Dopo una rotta: il nuovo bersaglio degli stessi attaccanti (nell'Assalto, dopo la Guarnigione, il Signore al Fronte).
func _nuovo_bersaglio(s: int, da: Array) -> String:
	var b := battaglia
	var e := 1 - s
	for h in da:
		var pos := -9
		if h == GUARN:
			pos = 1
		elif h in b["fronte"][s]:
			pos = b["fronte"][s].find(h)
		elif h in b.get("sortiti", []):
			pos = -1
		elif h in b["riserva"][s]:
			pos = -2
		if pos == -9:
			continue
		var t := _bersaglio_di(s, pos)
		if t != "" and (t == GUARN or (_vive(t) > 0 and not t in b["rotti"][e])):
			return t
	return ""


## Un Signore amico che aggira sul Fianco tutti gli attaccanti può assorbire i Colpi al posto del bersaglio:
## lo sceglie chi li subisce.
func _chi_assorbe(t: String, da: Array) -> String:
	var b := battaglia
	if t == GUARN or b["tipo"] != "battaglia":
		return t
	var st := _lato_h(t)
	var s := 1 - st
	var cand := [t]
	for x in _fronte(st):
		var f: String = x[1]
		if f == t:
			continue
		var opposto := false
		for y in _fronte(s):
			if y[0] == x[0]:
				opposto = true
		if opposto:
			continue
		var tutti_aggirati := true
		for h in da:
			if h == GUARN or _bersaglio(st, x[0]) != h:
				tutti_aggirati = false
		if tutti_aggirati and not da.is_empty():
			cand.append(f)
	if cand.size() < 2:
		return t
	var o := []
	var best := t
	var bv := -1.0
	for id in cand:
		o.append(opz(id, "%s (%d unità)%s" % [nome(id), _vive(id), "" if id == t else ", che aggira sul Fianco"], {"sig": id}))
		var v := _resistenza(id)
		if v > bv:
			bv = v
			best = id
	return await _scelta_batt(st, "assorbe", "Chi assorbe i colpi?",
		"I colpi nemici sono diretti a %s; un Signore che aggira sul Fianco può prenderli al suo posto." % nome(t), o, best, {"t": t})


## Quanto regge un Signore: media della Protezione delle sue unità.
func _resistenza(id: String) -> float:
	var f := _forze(id)
	var tot := 0.0
	var n := 0
	for u in f:
		var k := int(f[u])
		tot += k * (float(_prot(id, u, false)) if u != "vill" else 0.0)
		n += k
	return tot / maxf(1.0, n) + n * 0.05


func _scelgono_bersaglio(da: Array) -> bool:
	var b := battaglia
	for h in da:
		if h == GUARN:
			return true
		if ha_cap(h, "Palvesari") and ha_cap(h, "Balestrieri"):
			return true
		if b["tipo"] == "assalto" and _lato_h(h) == b["dif"]:
			return true
	return false


## Tiri per le Mura (Assalto/Sortita, o le Opere contro la Sortita di soccorso), poi un tiro di Protezione per colpo.
## Restituisce {"esiti": [{"u", "x": "mura"|"salvo"|"rotta"|"vill"}], "resto": colpi non assegnati, "resto_bal"}:
## restano colpi quando il bersaglio va in rotta prima di averli presi tutti.
func _applica_colpi(t: String, colpi: int, bal: int, scelta_att: bool, da_sortita := false, mura_ok := true) -> Dictionary:
	var b := battaglia
	var esiti := []
	var s := _lato_h(t)
	var mura := 0
	if b["tipo"] == "assalto":
		if s == b["dif"]:
			mura = b["mura"]
			if _fronte_ha_cap(b["att"], "Trabucchi") and b["opere"] >= 3:
				mura -= 1
		else:
			mura = b["opere"]
			if _fronte_ha_cap(b["dif"], "Trabucchi") and b["opere"] >= 3:
				mura -= 1
	elif b["tipo"] == "sortita" and s == b["dif"]:
		mura = b["opere"]
	elif b["tipo"] == "battaglia" and da_sortita and s == b["dif"]:
		mura = b["opere"]
	if mura > 0 and mura_ok:
		var salvati := 0
		var dd := []
		for i in colpi:
			var x := d6()
			dd.append(x)
			if x <= mura:
				salvati += 1
		if salvati > 0:
			_riga("%s (1-%d) fermano %d colpi su %d (dadi %s)." % ["Le mura" if b["tipo"] == "assalto" and s == b["dif"] else "Le opere d'assedio", mura, salvati, colpi, _dadi(dd)])
			for i in salvati:
				esiti.append({"u": "", "x": "mura"})
		var restano := colpi - salvati
		bal = mini(bal, restano)
		colpi = restano
	var dadi := []
	var rotte := 0
	var usati := 0
	for i in colpi:
		if _vive(t) == 0:
			break
		var balestra := i < bal
		var u := await _scegli_unita_dec(t, balestra, scelta_att, i, colpi)
		if u == "":
			break
		usati += 1
		if u == "vill":
			_forze(t)["vill"] -= 1
			if _forze(t)["vill"] == 0:
				_forze(t).erase("vill")
			if t != GUARN:
				_perdita(t, "vill")
			dadi.append("V")
			esiti.append({"u": u, "x": "vill"})
			continue
		var prot := _prot(t, u, balestra)
		var x := d6()
		dadi.append(str(x))
		if x <= prot:
			esiti.append({"u": u, "x": "salvo"})
			continue
		esiti.append({"u": u, "x": "rotta"})
		# in Rotta
		_forze(t)[u] -= 1
		if _forze(t)[u] == 0:
			_forze(t).erase(u)
		if t == GUARN:
			if u in ["cav", "ritter"]:
				b["guarn"]["rotte"][u] = int(b["guarn"]["rotte"].get(u, 0)) + 1
		else:
			_rotte(t)[u] = int(_rotte(t).get(u, 0)) + 1
		rotte += 1
	if not dadi.is_empty():
		_riga("%s: protezione %s, %d unità in rotta." % ["Guarnigione" if t == GUARN else nome(t), " ".join(dadi), rotte])
	if t != GUARN and _vive(t) == 0 and not t in b["rotti"][s]:
		b["rotti"][s].append(t)
		_riga("%s va in rotta!" % nome(t))
		await _fiume_rosso(t)
	return {"esiti": esiti, "resto": colpi - usati, "resto_bal": maxi(0, bal - usati)}


## Chi subisce il colpo: lo sceglie il possessore (o l'attaccante con i Balestrieri o lo Scontro Improvviso),
## colpo per colpo; si può lasciar decidere al gioco per il resto della battaglia.
func _scegli_unita_dec(t: String, balestra: bool, scelta_att: bool, i: int, n: int) -> String:
	var b := battaglia
	var consiglio := _scegli_unita(t, balestra, scelta_att)
	if consiglio == "":
		return ""
	var chi := _lato_h(t)
	if scelta_att:
		chi = 1 - chi
	if players[chi]["ai"] or b["auto_colpi"][chi]:
		return consiglio
	var f := _forze(t)
	var cand := []
	for u in f:
		if int(f[u]) > 0:
			cand.append(u)
	if b["tipo"] == "assalto" and _lato_h(t) == b["att"]:
		var cor := []
		for u in cand:
			if D.UNITA[u]["cor"]:
				cor.append(u)
		if not cor.is_empty():
			cand = cor
	if cand.size() == 1:
		return cand[0]
	var o := []
	for u in D.ORDINE_UNITA:
		if not u in cand:
			continue
		var p := _prot(t, u, balestra)
		var dett := "tolti senza tiro" if u == "vill" else ("Corazza 1-%d" % p if D.UNITA[u]["cor"] else "si salvano solo con 1")
		o.append(opz(u, "%s ×%d — %s" % [D.UNITA[u]["plur"], int(f[u]), dett], {"u": u}))
	o.append(opz("auto", "Decidi tu fino alla fine della battaglia"))
	var chi_t := "la guarnigione" if t == GUARN else nome(t)
	var testo := ("Colpo %d di %d%s contro %s: quale unità lo subisce? Un'unità può prendere più colpi di fila finché si salva." % [i + 1, n, " di balestra" if balestra else "", chi_t])
	if scelta_att:
		testo = "Scegli tu il bersaglio: " + testo
	var x := await scegli(chi, "colpo", "Chi subisce il colpo?", testo, o, {"t": t, "consiglio": consiglio})
	if x == "auto":
		b["auto_colpi"][chi] = true
		return consiglio
	return x


func _dadi(dd: Array) -> String:
	var p := []
	for x in dd:
		p.append(str(x))
	return " ".join(p)


func _prot(t: String, u: String, balestra: bool) -> int:
	if not D.UNITA[u]["cor"]:
		return 1
	var p: int = D.UNITA[u]["prot"]
	if u == "arm" and t != GUARN and ha_cap(t, "Palvesari"):
		p = 4
	if balestra:
		p = maxi(1, p - 2)
	if battaglia["tipo"] == "assalto" and _lato_h(t) == battaglia["att"]:
		pass
	return p


## Sceglie l'unità che subisce il colpo: il difensore protegge le migliori, l'attaccante (Balestre) le più deboli.
func _scegli_unita(t: String, balestra: bool, scelta_att: bool) -> String:
	var f := _forze(t)
	var cand := []
	for u in f:
		if int(f[u]) > 0:
			cand.append(u)
	if cand.is_empty():
		return ""
	# Attacco di Assalto: i colpi contro gli attaccanti vanno prima alle unità corazzate
	if battaglia["tipo"] == "assalto" and _lato_h(t) == battaglia["att"]:
		var cor := []
		for u in cand:
			if D.UNITA[u]["cor"]:
				cor.append(u)
		if not cor.is_empty():
			cand = cor
	var best := ""
	var bv := -99.0
	for u in cand:
		var v: float
		if u == "vill":
			v = 0.45
		else:
			v = float(_prot(t, u, balestra)) / 6.0
			v -= VAL_UNITA[u] * 0.01
		if scelta_att:
			v = -v - (VAL_UNITA[u] * 0.05 if u != "vill" else 0.0)
		if v > bv:
			bv = v
			best = u
	return best


func _perdita(id: String, u: String) -> void:
	var p: Dictionary = battaglia["perse"].get(id, {})
	p[u] = int(p.get(u, 0)) + 1
	battaglia["perse"][id] = p


## Distringitores: dopo gli Arcieri un Podestà guelfo tira la Corazza di 2 unità in Rotta.
func _distringitores() -> void:
	if not cap_parte(0, "Distringitores"):
		return
	for id in battaglia["tutti"][0]:
		if id in ["firenze", "arezzo", "lucca", "colle"] and _vive(id) > 0:
			var rec := 0
			for i in 2:
				var u := ""
				for k in ["cav", "uia", "arm", "berr"]:
					if int(_rotte(id).get(k, 0)) > 0:
						u = k
						break
				if u == "":
					break
				if d6() <= D.UNITA[u]["prot"]:
					_rotte(id)[u] -= 1
					_forze(id)[u] = int(_forze(id).get(u, 0)) + 1
					rec += 1
			if rec > 0:
				_riga("Distringitores: %s rimette in riga %d unità." % [nome(id), rec])
			return


func _fiume_rosso(id: String) -> void:
	if lato(id) != 0 or battaglia["eventi"].get("fiume", false):
		return
	if not "G16" in tenute[0]:
		return
	var r := await scegli(0, "evento", "Un fiume rosso di sangue", "%s va in rotta: giocare l'evento per tirare la Protezione di ogni sua unità e recuperarla?" % nome(id),
		[opz("si", "Gioca l'evento"), opz("no", "Tieni la carta")])
	if r != "si":
		return
	tenute[0].erase("G16")
	_scarta_evento("G16")
	battaglia["eventi"]["fiume"] = true
	var rec := 0
	for u in _rotte(id).keys():
		var n: int = _rotte(id)[u]
		for i in n:
			if d6() <= (D.UNITA[u]["prot"] if D.UNITA[u]["cor"] else 1):
				_rotte(id)[u] -= 1
				_forze(id)[u] = int(_forze(id).get(u, 0)) + 1
				rec += 1
	_riga("Un fiume rosso di sangue: %s recupera %d unità." % [nome(id), rec])
	if _vive(id) > 0:
		battaglia["rotti"][0].erase(id)


func _scarta_evento(c: String) -> void:
	var s := 0 if c.begins_with("G") else 1
	if not c in mazzo_aow[s]:
		mazzo_aow[s].append(c)


# ================================================================ eventi all'inizio della battaglia

func _eventi_inizio() -> void:
	var b := battaglia
	for s in [b["att"], b["dif"]]:
		for c in tenute[s].duplicate():
			var ev: String = D.CARTE[c]["ev"]
			var ok := false
			match ev:
				"Colline":
					ok = b["tipo"] == "battaglia" and s == b["dif"]
				"Palude":
					ok = b["tipo"] == "battaglia" and s == b["dif"] and D.STAGIONE[turno] != "E"
				"Attacco al Campo", "Attacco al campo":
					ok = b["tipo"] == "battaglia"
				"Scontro Improvviso":
					ok = b["tipo"] == "battaglia"
				"Bocca degli Abati":
					ok = b["tipo"] == "battaglia" and s == 1
			if not ok:
				continue
			var r := await scegli(s, "evento", ev, "Evento tenuto: %s Giocarlo ora?" % D.CARTE[c]["ev_x"],
				[opz("si", "Gioca «%s»" % ev), opz("no", "Tienilo")])
			if r != "si":
				continue
			tenute[s].erase(c)
			_scarta_evento(c)
			match ev:
				"Colline":
					b["eventi"]["colline"] = s
					_riga("Colline: gli Arcieri dei %s raddoppiano i colpi." % D.LATI[s])
				"Palude":
					b["eventi"]["palude"] = s
					_riga("Palude: la cavalleria nemica non colpisce nel primo round.")
				"Scontro Improvviso":
					b["eventi"]["scontro"] = s
					_riga("Scontro improvviso: la cavalleria dei %s colpisce per prima e sceglie i bersagli." % D.LATI[s])
				"Attacco al Campo", "Attacco al campo":
					for e in b["tutti"][1 - s]:
						var presi := 0
						for k in ["prov", "moneta", "bottino", "carro"]:
							while presi < 4 and supp(e, k) > 0:
								add_supp(e, k, -1)
								if presi < 2:
									add_supp(b["tutti"][s][0], "bottino", 1)
								presi += 1
					_riga("Attacco al campo: i %s saccheggiano le salmerie nemiche." % D.LATI[s])
				"Bocca degli Abati":
					var bersaglio := ""
					for e in b["tutti"][0]:
						if _n(e, "cav") > 0:
							bersaglio = e
							break
					if bersaglio != "":
						var n := _n(bersaglio, "cav")
						var rotti := 0
						for i in n:
							if d6() > 3:
								_forze(bersaglio)["cav"] -= 1
								_rotte(bersaglio)["cav"] = int(_rotte(bersaglio).get("cav", 0)) + 1
								rotti += 1
						if rotti > 0 and not b["tutti"][1].is_empty():
							_rotte(bersaglio)["cav"] -= 1
							L[b["tutti"][1][0]]["forze"]["cav"] = int(L[b["tutti"][1][0]]["forze"].get("cav", 0)) + 1
						if _forze(bersaglio).get("cav", 0) == 0:
							_forze(bersaglio).erase("cav")
						_riga("Bocca degli Abati: tradimento fra i cavalieri di %s (%d in rotta)." % [nome(bersaglio), rotti])


# ================================================================ fine della battaglia

func _fine(vince: int) -> int:
	var b := battaglia
	var perde := 1 - vince
	var l: String = b["loc"]
	b["esito"] = D.LATI[vince]
	_riga("Vincono i %s." % D.LATI[vince])
	fx.emit("battaglia_fine", b)
	await _pace_b(0.8)
	var rimossi := []
	var lasciato: bool = b["lascia"] == perde
	if b["tipo"] == "assalto":
		if vince == b["att"]:
			await _saccheggio()
			return vince
		# gli attaccanti perdono: restano ad assediare
		await _perdite_tutti(perde, false)
		await _perdite_tutti(vince, false)
		_esito_finale()
		return vince
	# Battaglia o Sortita: i perdenti Arretrano, si Ritirano o sono rimossi
	var ritirati := []
	var arretrati := []
	for id in b["tutti"][perde]:
		if comune_di(id) != "" and comune_di(id) in b["tutti"][perde]:
			continue
		var dove := await _destino(id, perde)
		var grp := gruppo_comune(id)
		if dove == "_dentro":
			for x in grp:
				L[x]["dentro"] = true
				L[x]["aggira"] = false
			ritirati.append(id)
		elif dove == "":
			for x in grp:
				rimossi.append(x)
		else:
			for x in grp:
				L[x]["loc"] = dove
				L[x]["dentro"] = false
				L[x]["aggira"] = false
			arretrati.append(id)
			log_msg("%s arretra a %s." % [nome(id), lnome(dove)])
	# Perdite
	await _perdite_tutti(perde, not lasciato)
	await _perdite_tutti(vince, false)
	# Bottino
	var vincitori := []
	for id in b["tutti"][vince]:
		if sulla_mappa(id):
			vincitori.append(id)
	for id in rimossi:
		_bottino_tutto(id, vincitori)
	for id in arretrati:
		if lasciato:
			_bottino_parziale(id, vincitori)
		else:
			_bottino_tutto(id, vincitori)
	# Servizio di chi arretra
	for id in arretrati:
		var dado := d6()
		var n := int(ceil(dado / 2.0))
		if lasciato and comune(id) != "" and _ha_carroccio(comune(id)):
			n = 1
		sposta_servizio(id, -n)
		log_msg("%s perde %d caselle di Servizio (dado %d)." % [nome(id), n, dado])
	# Sortita sconfitta: Raid
	if b["tipo"] == "sortita" and perde == b["att"]:
		loc[l]["assedio"] = mini(loc[l]["assedio"], 1)
		log_msg("Raid: le opere d'assedio sono danneggiate, resta 1 segnalino Assedio.")
	if b["tipo"] == "battaglia" and not b["soccorso"].is_empty() and perde == b["att"]:
		loc[l]["assedio"] = maxi(1, loc[l]["assedio"] - 1)
	# rimozioni in combattimento
	for id in rimossi:
		if sulla_mappa(id):
			await rimuovi_signore(id, true, true)
	for s in [0, 1]:
		for id in b["tutti"][s]:
			if sulla_mappa(id) and unita(id) == 0:
				await rimuovi_signore(id, true, true)
	_esito_finale()
	return vince


func _ha_carroccio(id: String) -> bool:
	for v in V:
		if V[v]["presso"] == id and V[v]["stato"] == "radunato" and D.VASSALLI[v].get("speciale", "") == "carroccio":
			return true
	return false


func _esito_finale() -> void:
	var b := battaglia
	var l: String = b["loc"]
	for s in [0, 1]:
		for id in b["tutti"][s]:
			if sulla_mappa(id):
				L[id]["mosso"] = true
	# l'Assedio finisce se non restano assedianti fuori
	if loc[l]["assedio"] > 0:
		var sl: int = loc[l]["assedio_l"]
		if fuori_in(l, sl).is_empty():
			loc[l]["assedio"] = 0
			loc[l]["assedio_l"] = -1
	if not caposaldo(l):
		for id in signori_in(l):
			L[id]["dentro"] = false
	changed.emit()


## Dove va un Signore sconfitto: una località adiacente, dentro il Caposaldo ("_dentro") o rimosso ("").
func _destino(id: String, s: int) -> String:
	var b := battaglia
	var l: String = b["loc"]
	var o := []
	var sortita_att: bool = (b["tipo"] == "sortita" and s == b["att"]) or (id in b["soccorso"])
	if sortita_att:
		return "_dentro"
	if caposaldo(l) and amica(l, s):
		var dentro := dentro_in(l, s).size()
		if dentro + gruppo_comune(id).size() <= valore(l):
			o.append(opz("_dentro", "Ritirati dentro %s (niente perdita di Servizio)" % lnome(l), {"loc": l}))
	for v in vicine(l):
		if s == b["dif"] and v == b["via_da"]:
			continue
		if not _arretramento_ok(v, s, id):
			continue
		o.append(opz(v, "Arretra a %s" % lnome(v), {"loc": v}))
	if o.is_empty():
		log_msg("%s non ha dove arretrare ed è rimosso." % nome(id))
		return ""
	var r := await scegli(s, "arretra", "Dove va %s?" % nome(id), "Sconfitto a %s: scegli dove arretrare." % lnome(l), o, {"auto1": true, "sig": id})
	return r


func _arretramento_ok(v: String, s: int, id: String) -> bool:
	if not fuori_in(v, 1 - s).is_empty():
		return false
	if caposaldo_nemico(v, s) and loc[v]["assedio"] == 0 and not _aggirata(v, s):
		return false
	if avamposto(v) and not v in D.SIGNORI[id if comune_di(id) == "" else comune_di(id)]["sedi"]:
		return false
	return true


func _aggirata(v: String, s: int) -> bool:
	for x in fuori_in(v, s):
		if L[x]["aggira"]:
			return true
	return false


## Tiri per le unità in Rotta (4.4.4). duro = arretrati senza lasciare il campo (salvano solo con 1).
func _perdite_tutti(s: int, duro: bool) -> void:
	var b := battaglia
	var morti_tot := 0
	var catt := 0
	for id in b["tutti"][s]:
		if not L.has(id):
			continue
		var rotte: Dictionary = L[id]["rotte"]
		var duro_id := duro
		if b["tipo"] == "assalto" and s == b["att"]:
			duro_id = true
		for u in rotte.keys():
			var n: int = rotte[u]
			for i in n:
				var x := d6()
				var p: int = D.UNITA[u]["prot"] if D.UNITA[u]["cor"] else 1
				if b["tipo"] == "assalto" and s == b["dif"]:
					duro_id = false
				var salva := (x == 1) if duro_id else (x <= p)
				if salva:
					L[id]["forze"][u] = int(L[id]["forze"].get(u, 0)) + 1
				else:
					morti_tot += 1
					_perdita(id, u)
					if u in ["cav", "ritter"] and b["tipo"] != "assalto" and x >= 3:
						catturati[s][u] += 1
						catt += 1
					else:
						pool[u] += 1
			rotte.erase(u)
	if morti_tot > 0:
		log_msg("I %s perdono %d unità%s." % [D.LATI[s], morti_tot, (" (%d cavalieri catturati)" % catt) if catt > 0 else ""])
	await _dottori(s)


func _dottori(s: int) -> void:
	var c := "G24" if s == 0 else "H24"
	if not c in tenute[s]:
		return
	var chi := ["firenze", "arezzo"] if s == 0 else ["siena", "pisa"]
	var perse := 0
	for id in chi:
		if battaglia["perse"].has(id):
			for u in battaglia["perse"][id]:
				perse += int(battaglia["perse"][id][u])
	if perse == 0:
		return
	var r := await scegli(s, "evento", "Dottori", "Giocare Dottori per ripristinare metà delle unità perse da %s?" % (" e ".join(chi)),
		[opz("si", "Gioca Dottori"), opz("no", "Tieni la carta")])
	if r != "si":
		return
	tenute[s].erase(c)
	_scarta_evento(c)
	for id in chi:
		if not battaglia["perse"].has(id) or not sulla_mappa(id):
			continue
		var tot := 0
		for u in battaglia["perse"][id]:
			tot += int(battaglia["perse"][id][u])
		var k := int(ceil(tot / 2.0))
		for u in battaglia["perse"][id]:
			while k > 0 and int(battaglia["perse"][id][u]) > 0 and pool[u] > 0:
				battaglia["perse"][id][u] -= 1
				pool[u] -= 1
				L[id]["forze"][u] = int(L[id]["forze"].get(u, 0)) + 1
				k -= 1
	log_msg("Dottori: i %s curano i feriti." % D.LATI[s])


func _bottino_tutto(id: String, vincitori: Array) -> void:
	if vincitori.is_empty():
		return
	for k in ["moneta", "bottino", "prov", "carro"]:
		var n := supp(id, k)
		if n > 0:
			L[id]["supp"][k] = 0
			_distribuisci(vincitori, k, n)
	# il Carroccio
	var c := comune(id) if comune_di(id) == "" else id
	if c != "" and _ha_carroccio(c):
		_cattura_carroccio(lato(id))


func _bottino_parziale(id: String, vincitori: Array) -> void:
	if vincitori.is_empty():
		return
	var n := supp(id, "bottino")
	if n > 0:
		L[id]["supp"]["bottino"] = 0
		_distribuisci(vincitori, "bottino", n)
	var ecc := supp(id, "prov") - supp(id, "carro")
	if ecc > 0:
		add_supp(id, "prov", -ecc)
		_distribuisci(vincitori, "prov", ecc)


func _distribuisci(ids: Array, k: String, n: int) -> void:
	var i := 0
	while n > 0 and i < 40:
		var id: String = ids[i % ids.size()]
		if supp(id, k) < 16:
			add_supp(id, k, 1)
			n -= 1
		i += 1


func _cattura_carroccio(s: int) -> void:
	if carroccio_preso[s]:
		return
	carroccio_preso[s] = true
	var v := "carroccio_G" if s == 0 else "carroccio_H"
	V[v]["stato"] = "fuori"
	log_msg("Il Carroccio dei %s è catturato! (+2 PV ai %s)" % [D.LATI[s], D.LATI[1 - s]])
	fx.emit("carroccio", {"lato": s})


## Saccheggio dopo un Assalto vinto (4.5.2).
func _saccheggio() -> void:
	var b := battaglia
	var l: String = b["loc"]
	var att: int = b["att"]
	var dif: int = b["dif"]
	var v := valore(l)
	log_msg("%s è SACCHEGGIATA!" % lnome(l))
	loc[l]["rovine"] = 1 - lato_stampato(l)
	loc[l]["all_n"] = 0
	loc[l]["all_l"] = -1
	loc[l]["mura"] = -1
	loc[l]["assedio"] = 0
	loc[l]["assedio_l"] = -1
	fx.emit("saccheggio", {"loc": l})
	var vincitori := fuori_in(l, att)
	for k in ["bottino", "prov", "moneta"]:
		_distribuisci(vincitori, k, v)
	# cavalieri della guarnigione e dei difensori catturati
	catturati[dif]["cav"] += v
	for id in b["tutti"][dif]:
		for u in ["cav", "ritter"]:
			var n: int = int(L[id]["forze"].get(u, 0)) + int(L[id]["rotte"].get(u, 0))
			catturati[dif][u] += n
			L[id]["forze"].erase(u)
			L[id]["rotte"].erase(u)
	await _perdite_tutti(att, true)
	for id in b["tutti"][dif]:
		if sulla_mappa(id):
			_bottino_tutto(id, vincitori)
	for id in b["tutti"][dif]:
		if sulla_mappa(id):
			await rimuovi_signore(id, true, true)
	for id in signori_in(l):
		L[id]["dentro"] = false
		L[id]["aggira"] = false
	# Rivolta e Tradimento per il saccheggio
	for i in v:
		await tiro_rivolta(att)
	await aggiungi_tradimento(att, v)
	_esito_finale()


## Rimozione di un Signore (combattimento o oltre il Servizio, 3.3.1 / 4.4.5).
func rimuovi_signore(id: String, penalita: bool, combattimento := false) -> void:
	if not L.has(id) or L[id]["stato"] != "mappa":
		return
	var c := comune(id)
	if comune_di(id) != "":
		_via_dalla_mappa(id, "fuori")
		log_msg("%s si scioglie." % nome(id))
		return
	if c != "":
		_via_dalla_mappa(c, "fuori")
	if podesta(id):
		_via_dalla_mappa(id, "cal")
		L[id]["cal"] = mini(17, turno + 3)
		log_msg("%s è rimosso%s: il Podestà tornerà disponibile più avanti." % [nome(id), " in combattimento" if combattimento else ""])
	else:
		_via_dalla_mappa(id, "rimosso")
		log_msg("%s è rimosso dal gioco%s." % [nome(id), " in combattimento" if combattimento else ""])
	fx.emit("rimosso", {"sig": id})
	if penalita:
		await penalita_rimozione(id)
	controlla_vittoria_campagna()


func _via_dalla_mappa(id: String, stato: String) -> void:
	var x: Dictionary = L[id]
	# cavalieri in rotta di un Signore rimosso in battaglia
	rendi_unita(id)
	x["supp"] = {}
	for c in x["caps"]:
		_scarta_evento(c)
	x["caps"] = []
	x["stato"] = stato
	x["dentro"] = false
	x["aggira"] = false
	x["mosso"] = false
	# i suoi Vassalli tornano disponibili, i Voltagabbana tornano al loro Signore
	for v in V:
		if V[v]["presso"] == id:
			var orig: String = D.VASSALLI[v]["sig"]
			if V[v]["stato"] == "fuori":
				continue
			V[v]["presso"] = orig
			V[v]["stato"] = "pronto"


## Vittoria nella Campagna: un lato senza Signori sulla mappa perde subito.
func controlla_vittoria_campagna() -> void:
	if fase != "campagna" or over:
		return
	for s in [0, 1]:
		if signori_mappa(s).is_empty():
			over = true
			result = {"vince": 1 - s, "motivo": "I %s non hanno più Signori sulla mappa." % D.LATI[s]}
			return
