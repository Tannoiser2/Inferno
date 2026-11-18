class_name InfAI
extends RefCounted
## Intelligenza artificiale per Inferno. Decide con regole euristiche: valuta forza delle armate,
## distanze, rifornimenti, durata del servizio e punti vittoria. Tre livelli (0 facile, 1 normale,
## 2 esperto): il facile sbaglia di più, l'esperto è più prudente e sfrutta meglio Assedi e Tradimenti.

const D = preload("res://scripts/data/inf_data.gd")

var level := 1
## Consigli strategici raccolti dai resoconti di partita (Volko Ruhnke, Christophe Correia) e dal regolamento:
## tenere i Podestà in servizio, devastare attorno agli assedi, assaltare per saccheggiare quando mancano le
## provviste, difendere quando si è in vantaggio e rischiare quando si è indietro, devastare a fine partita.
## Con false l'IA gioca come la prima versione (serve a confrontarle: tests/sim.gd).
var strategia := true
## Quali consigli usare (vuoto = tutti), per misurarli uno per uno con tests/confronto_ia.gd.
## Misurati contro la prima versione (fino a 200 partite per scenario, metà per parte), nessuno ha dato un
## vantaggio netto oltre il caso, e alcuni (Sorpresa, assalto, tasse) peggiorano: si tiene «concentra» (unirsi
## agli assedi amici, non sprecare carte in piccoli rifornimenti), neutro o positivo e più simile ai resoconti.
## Gli altri restano nel codice, spenti.
const CONSIGLI_SCELTI := ["concentra"]
var consigli := CONSIGLI_SCELTI.duplicate()


func _c(k: String) -> bool:
	return strategia and (consigli.is_empty() or k in consigli)
var rng := RandomNumberGenerator.new()


func decide(e, s: int, req: Dictionary):
	rng.seed = hash([e.turno, e.record.size(), s, level])
	if req.get("type", "") == "piano":
		return _piano(e, s, req)
	var o: Array = req.get("opzioni", [])
	if o.is_empty():
		return null
	var k: String = req.get("k", "")
	var best := ""
	match k:
		"azione":
			best = _azione(e, s, req)
		"avvicinamento":
			best = _avvicinamento(e, s, req)
		"lascia":
			best = _lascia(e, s)
		"arretra":
			best = _arretra(e, s, req)
		"assedia":
			best = _assedia(e, s, req)
		"paga":
			best = _paga(e, s, o)
		"raduno":
			best = _raduno(e, s, req)
		"raduno_chi":
			best = _raduno_chi(e, o)
		"tradimento_az":
			best = _tradimento(e, s, o)
		"tradimento":
			best = _miglior_signore_trad(e, o)
		"cap_a_chi":
			best = _cap_a_chi(e, o)
		"chiamata", "comune", "riscatto":
			best = "si"
		"comandante":
			best = "si" if not e.sulla_mappa(D.CITTA_GUIDA[s]) else "no"
		"riunirsi":
			var id: String = req.get("sig", "")
			best = "si" if id != "" and not e.L[id]["aggira"] and e.loc[e.L[id]["loc"]]["assedio"] == 0 else "no"
		"alleati":
			best = _alleati(e, o)
		"abbandono":
			best = "rivolta"
		"evento":
			best = _evento(e, s, req)
		"rivolta_x", "rivolta_vicina", "ev_loc":
			best = _loc_valore_max(e, o)
		"sede":
			best = _sede(e, s, req)
	if (best == "" or not _ha(o, best)) and req.has("consiglio"):
		best = str(req["consiglio"])
	if best == "" or not _ha(o, best):
		best = str(o[0]["id"])
	return best


func _ha(o: Array, id: String) -> bool:
	for x in o:
		if str(x["id"]) == id:
			return true
	return false


## Vantaggio in Punti Vittoria della parte s (positivo = in testa).
func _vantaggio(e, s: int) -> float:
	return e.pv(s) - e.pv(1 - s)


func _ultimo_turno(e) -> bool:
	return e.turno >= e.turno_fine


func _rumore(x: float) -> float:
	var amp = [2.5, 0.8, 0.2][clampi(level, 0, 2)]
	return x + rng.randf_range(-amp, amp)


# ================================================================ piano

func _piano(e, s: int, req: Dictionary) -> Array:
	var n: int = req["n"]
	var carte: Array = req["carte"]
	var lords: Array = e.signori_mappa(s)
	lords.sort_custom(func(a, b): return _importanza(e, a) > _importanza(e, b))
	var per := {}
	for c in carte:
		if c["t"] == "cmd":
			if not per.has(c["l"]):
				per[c["l"]] = []
			per[c["l"]].append(c["id"])
	var scelte := []
	# Tradimento prima, se c'è qualcosa da tramare
	for c in carte:
		if c["t"] == "trad" and e.sulla_mappa(c["l"]) and _tradimento_utile(e, c["l"]) and scelte.size() < n:
			scelte.append(c["id"])
	var giro := 0
	while scelte.size() < n and giro < 3:
		for id in lords:
			if scelte.size() >= n:
				break
			if per.has(id) and per[id].size() > giro:
				# chi è assediato senza speranza usa meno carte
				if giro >= 1 and e.assediato(id):
					continue
				scelte.append(per[id][giro])
		giro += 1
	var k := 1
	while scelte.size() < n:
		scelte.append("passa:%d" % k)
		k += 1
	return scelte


func _importanza(e, id: String) -> float:
	var x: float = e.forza(id) + D.SIGNORI[id]["cmd"] * 2.0
	if e.comune(id) != "":
		x += e.forza(e.comune(id))
	return x


func _tradimento_utile(e, id: String) -> bool:
	var s: int = e.lato(id)
	var l: String = e.L[id]["loc"]
	var monete := 0
	for x in e.signori_in(l, s):
		monete += e.supp(x, "moneta")
	if monete < 1:
		return false
	for v in [l] + e.vicine(l):
		if e.caposaldo(v) and not e.amica(v, s) and e.disponibile_rivolta(v) and e.valore(v) <= 2 and monete >= 3:
			return true
	return false


# ================================================================ azioni di campagna

func _azione(e, s: int, req: Dictionary) -> String:
	var id: String = req["sig"]
	var o: Array = req["opzioni"]
	var best := "passa"
	var bv := -1e9
	for x in o:
		var v := _valuta(e, s, id, x)
		v = _rumore(v)
		if v > bv:
			bv = v
			best = x["id"]
	return best


func _valuta(e, s: int, id: String, x: Dictionary) -> float:
	var v := _valuta_base(e, s, id, x)
	var r: String = x["id"]
	# ultima carta e nessuno a casa: meglio tornare che restare all'assedio
	if r in ["assedio", "accampa"] and _carte_rimaste(e, s, id) == 0 and not e.amica(e.L[id]["loc"], s) and _nessuno_a_casa(e, s, id):
		v -= 4.0
	# le azioni che fanno mangiare: senza provviste il Servizio si accorcia e il Signore può smobilitare
	if r.begins_with("marcia") or r in ["assedio", "assalto", "sortita", "sortita_agg", "accampa"] or r.begins_with("mare:"):
		var need: int = e._fabbisogno(id)
		var cibo: int = e.supp(id, "prov") + e.supp(id, "bottino")
		for y in e.signori_in(e.L[id]["loc"], s):
			if y != id:
				cibo += maxi(0, e.supp(y, "prov") - e._fabbisogno(y))
		if cibo < need:
			var resto: int = e.L[id]["svc"] - e.turno
			v -= 6.0
			if resto <= 2:
				v -= 10.0
				if e.signori_mappa(s).size() <= 2:
					v -= 25.0
	return v


func _valuta_base(e, s: int, id: String, x: Dictionary) -> float:
	var r: String = x["id"]
	var l: String = e.L[id]["loc"]
	var need: int = e._fabbisogno(id)
	var cibo: int = e.supp(id, "prov") + e.supp(id, "bottino")
	var svc_resto: int = e.L[id]["svc"] - e.turno
	var forza_mia: float = e.forza_gruppo(e.gruppo_comune(id))
	if r == "passa":
		return 0.6 if cibo < need else 0.0
	if r == "rifornisci":
		var n = e.stima_rifornimento(id)
		if cibo >= need * 3:
			return 0.3
		# rifornirsi di una o due provviste alla volta spreca le carte: meglio muoversi
		if _c("concentra") and cibo >= need * 2 and n <= 2:
			return 0.7
		return 2.5 + n * 0.6 - cibo * 0.3
	if r == "foraggia":
		return (2.6 if cibo < need else (1.6 if cibo < need * 2 else 0.3))
	if r == "tassa":
		var v := 0.6
		var costo := 2 if e.podesta(id) else 1
		if e.supp(id, "moneta") < costo:
			v += 1.0
		if svc_resto <= 1:
			v += 2.0
		if _c("tassa"):
			# le Monete servono al Tradimento (ogni dado deve stare sotto le Monete impegnate)
			if _ha_tradimento(e, s) and e.supp(id, "moneta") < 3:
				v += 1.0
			if e.podesta(id):
				v += 0.4      # il Podestà incassa 2 Monete per Tassa
		return v
	if r == "mura":
		return 0.9
	if r == "costruttori":
		return 2.0
	if r == "devasta":
		var vd: float = 3.0 + (0.8 if cibo < need * 2 else 0.0) - x.get("costo", 1) * 0.3
		if _c("devasta"):
			# devastare attorno a un assedio avvicina la Resa (conta come un segnalino in più);
			# a fine partita ogni devastazione è mezzo Punto Vittoria
			if e.loc[l]["assedio"] > 0 and e.caposaldo_nemico(l, s):
				vd += 2.0
			if _ultimo_turno(e):
				vd += 1.5
		return vd
	if r.begins_with("cavallata:"):
		return 2.6
	if r == "accampa":
		var v2: String = l
		var dentro: Array = e.dentro_in(v2, 1 - s)
		if dentro.is_empty() and e.valore(v2) <= 2:
			return 2.8
		return 1.0
	if r == "assedio":
		var dentro: Array = e.dentro_in(l, 1 - s)
		var sg: int = e.loc[l]["assedio"] + (1 if e.loc[l]["dev"] >= 0 else 0)
		if dentro.is_empty():
			var p := pow(minf(sg, 6) / 6.0, e.valore(l))
			var vs: float = 2.0 + p * 10.0 * e.valore(l)
			if _c("assedio") and e.fuori_in(l, s).size() >= e.valore(l):
				vs += 1.0     # le opere crescono anche se la Resa fallisce
			return vs
		return 1.8
	if r == "assalto":
		var p := _prob_assalto(e, s, l)
		var va: float = -3.0 + p * 7.0 * e.valore(l) - (3.0 if e.loc[l]["assedio"] <= 1 else 0.0)
		if _c("assalto"):
			# senza provviste e fuori dalle mura nemiche, il Saccheggio è l'unico modo di sfamare l'armata
			if cibo < need and p > 0.35:
				va += 3.0
			# nel proprio territorio un Saccheggio lascia rovine che danno mezzo punto al nemico: meglio la Resa
			if e.lato_stampato(l) == s and cibo >= need:
				va -= 2.0
			# se ci sono abbastanza Signori per far crescere le opere, l'assedio è più economico dell'assalto
			if e.fuori_in(l, s).size() >= e.valore(l) and not _ultimo_turno(e) and cibo >= need:
				va -= 1.5
		return va
	if r == "sortita" or r == "sortita_agg":
		var fe = e.forza_gruppo(e.fuori_in(l, 1 - s))
		var fm = e.forza_gruppo(e.dentro_in(l, s))
		return (fm - fe * 1.2) * 0.5
	if r == "genieri":
		return 1.5
	if r.begins_with("mare:"):
		var p: String = r.substr(5)
		var v := 0.0
		if e.caposaldo_nemico(p, s) and e.loc[p]["assedio"] == 0 and e.signori_in(p, 1 - s).is_empty():
			v = 2.5 + e.valore(p)
		return v - 1.0
	if r.begins_with("marcia"):
		return _valuta_marcia(e, s, id, x, need, cibo, svc_resto, forza_mia)
	return 0.0


func _ha_tradimento(e, s: int) -> bool:
	for c in e.piano[s]:
		if c["t"] == "trad":
			return true
	return false


## Nessun altro Signore della parte potrà fare la Leva (tutti in località nemiche).
func _nessuno_a_casa(e, s: int, id: String) -> bool:
	for x in e.signori_mappa(s):
		if x != id and e.amica(e.L[x]["loc"], s) and not e.assediato(x):
			return false
	return true


func _carte_rimaste(e, s: int, id: String) -> int:
	var n := 0
	for c in e.piano[s]:
		if c["l"] == id and c["t"] == "cmd":
			n += 1
	return n


## La località amica più vicina dove un Signore può fare la Leva (meglio una sua Sede).
func _rifugio(e, s: int, id: String) -> String:
	var l: String = e.L[id]["loc"]
	var dist: Dictionary = e.distanze(l)
	var best := ""
	var bd := 99.0
	for v in e.loc:
		if not e.amica(v, s) or e.avamposto(v) and not v in D.SIGNORI[id if e.comune_di(id) == "" else e.comune_di(id)].get("sedi", []):
			continue
		if not e.caposaldo(v) and not e.avamposto(v):
			continue
		if not e.fuori_in(v, 1 - s).is_empty():
			continue
		var d: float = dist.get(v, 99)
		if v in D.SIGNORI[id if e.comune_di(id) == "" else e.comune_di(id)].get("sedi", []):
			d -= 1.5
		if d < bd:
			bd = d
			best = v
	return best


func _prob_assalto(e, s: int, l: String) -> float:
	var att: float = e.forza_gruppo(e.fuori_in(l, s))
	var v: int = e.valore(l)
	var garn = {3: 12.0, 2: 8.0, 1: 4.5}[v]
	var dif: float = garn + e.forza_gruppo(e.dentro_in(l, 1 - s))
	var mura := 1.6 + (0.3 if e.loc[l]["mura"] >= 0 else 0.0)
	var opere: int = e.loc[l]["assedio"]
	var ratio := att * (0.6 + 0.15 * opere) / (dif * mura)
	return clampf((ratio - 0.6) / 1.4, 0.0, 0.95)


func _valuta_marcia(e, s: int, id: String, x: Dictionary, need: int, cibo: int, svc_resto: int, forza_mia: float) -> float:
	var v: String = x["loc"]
	var l: String = e.L[id]["loc"]
	var tutti: bool = str(x["id"]).begins_with("marcia_tutti")
	if tutti:
		forza_mia = e.forza_gruppo(e.gruppo_marcia(id, true))
	var score := 0.0
	# battaglia
	var nemici: Array = e.fuori_in(v, 1 - s)
	if not nemici.is_empty():
		var fe: float = e.forza_gruppo(nemici)
		var rapporto := forza_mia / maxf(1.0, fe)
		var soglia = [1.0, 1.2, 1.35][clampi(level, 0, 2)]
		if rapporto < soglia:
			return -6.0 + rapporto
		score += 4.0 + (rapporto - 1.0) * 3.0
	# pericolo: nemici forti vicino alla destinazione
	for w in [v] + e.vicine(v):
		var fe2: float = e.forza_gruppo(e.fuori_in(w, 1 - s))
		if fe2 > forza_mia * 1.3:
			score -= 2.5 if w != v else 0.0
	# obiettivo
	var ob := _obiettivo(e, s, id)
	if ob != "":
		var d0: int = e.distanza(l, ob)
		var d1: int = e.distanza(v, ob)
		score += (d0 - d1) * 1.6
		if v == ob:
			score += 1.5
	# fame: chi marcia deve mangiare; senza provviste il Servizio si accorcia
	if cibo < need:
		score -= 4.0 if svc_resto <= 1 else 2.0
	if nemici.is_empty() and cibo < need * 2 and e.stima_rifornimento(id) > 0:
		score -= 1.0
	# fine della campagna o del servizio: tornare in una località amica (per la Leva e la Paga)
	var ultime := _carte_rimaste(e, s, id)
	if svc_resto <= 1 or ultime <= 1:
		var casa := _rifugio(e, s, id)
		if casa != "":
			var peso := 2.2 if svc_resto <= 1 else 1.2
			if ultime <= 1 and _nessuno_a_casa(e, s, id):
				peso = 3.5
			score += (e.distanza(l, casa) - e.distanza(v, casa)) * peso
			if e.amica(v, s) and e.caposaldo(v):
				score += 1.0
	# caposaldo nemico da devastare / assediare
	if e.caposaldo_nemico(v, s) and e.loc[v]["dev"] < 0:
		score += 0.8
	score -= x.get("costo", 1) * 0.35
	if x.get("costo", 1) == 0:
		score += 0.4
	if tutti:
		score += 0.3
	return score


## Località obiettivo per un Signore: un Caposaldo nemico vicino e alla portata, o un'armata nemica debole.
func _obiettivo(e, s: int, id: String) -> String:
	var l: String = e.L[id]["loc"]
	var forza_mia: float = e.forza_gruppo(e.gruppo_comune(id))
	var dist: Dictionary = e.distanze(l)
	var best := ""
	var bv := -1e9
	for v in e.loc:
		var d: int = dist.get(v, 99)
		if d >= 8:
			continue
		var val := 0.0
		if e.caposaldo_nemico(v, s):
			var dif: float = e.forza_gruppo(e.dentro_in(v, 1 - s)) + e.forza_gruppo(e.fuori_in(v, 1 - s))
			if dif > forza_mia * 1.1:
				continue
			val = 2.0 + e.valore(v) * 1.5
			if e.loc[v]["all_n"] > 0:
				val += 1.0
			if e.loc[v]["dev"] < 0:
				val += 1.2
			if e.assediata_da(v, s):
				val += 2.0
				# un assedio amico senza abbastanza Signori per far crescere le opere: raggiungerlo
				if _c("concentra") and e.fuori_in(v, s).size() < e.valore(v) and not id in e.fuori_in(v, s):
					val += 3.0 + e.valore(v)
		elif not e.fuori_in(v, 1 - s).is_empty():
			var fe: float = e.forza_gruppo(e.fuori_in(v, 1 - s))
			if fe * 1.3 < forza_mia:
				val = 3.0 + fe * 0.3
		elif e.loc[v]["dev"] < 0 and not e.amica(v, s) and not e.avamposto(v):
			val = 1.2
		# difesa delle proprie città assediate
		if e.assediata_da(v, 1 - s) and e.amica(v, s):
			var fe3: float = e.forza_gruppo(e.fuori_in(v, 1 - s))
			if fe3 < forza_mia:
				val = 5.0 + e.valore(v)
		if val <= 0.0:
			continue
		if _c("postura"):
			var vant := _vantaggio(e, s)
			# in vantaggio si difende vicino a casa, indietro si rischia di più lontano
			if vant >= 2.0 and not e.amica(v, s) and not e.assediata_da(v, 1 - s):
				val -= 1.0 + d * 0.3
			elif vant <= -2.0 or _ultimo_turno(e):
				val += 1.0
		val -= d * 1.1
		if val > bv:
			bv = val
			best = v
	return best


# ================================================================ reazioni

func _avvicinamento(e, s: int, req: Dictionary) -> String:
	var id: String = req["sig"]
	var l: String = e.L[id]["loc"]
	var mia: float = e.forza_gruppo(e.fuori_in(l, s))
	var loro: float = e.forza_gruppo(e.fuori_in(l, 1 - s))
	var o: Array = req["opzioni"]
	if mia >= loro * [0.8, 0.95, 1.05][clampi(level, 0, 2)]:
		return "combatti"
	if _ha(o, "_dentro"):
		return "_dentro"
	var best := "combatti"
	var bv := -1e9
	for x in o:
		if not str(x["id"]).begins_with("evita:"):
			continue
		var w: String = x["loc"]
		var v := 0.0
		if e.amica(w, s):
			v += 2.0
		for n in e.vicine(w):
			v -= e.forza_gruppo(e.fuori_in(n, 1 - s)) * 0.1
		if v > bv:
			bv = v
			best = x["id"]
	return best


func _lascia(e, s: int) -> String:
	var b: Dictionary = e.battaglia
	var mia := 0.0
	var loro := 0.0
	for id in b["tutti"][s]:
		if e.sulla_mappa(id):
			mia += e.forza(id)
	for id in b["tutti"][1 - s]:
		if e.sulla_mappa(id):
			loro += e.forza(id)
	if b["tipo"] == "assalto" and s == b["att"]:
		var g := 0.0
		for u in b["guarn"]["forze"]:
			g += InfStato.VAL_UNITA[u] * int(b["guarn"]["forze"][u])
		return "si" if mia < (loro + g) * 0.6 else "no"
	return "si" if mia < loro * [0.4, 0.55, 0.65][clampi(level, 0, 2)] else "no"


func _arretra(e, s: int, req: Dictionary) -> String:
	var o: Array = req["opzioni"]
	if _ha(o, "_dentro"):
		return "_dentro"
	var best: String = o[0]["id"]
	var bv := -1e9
	for x in o:
		var w: String = x["id"]
		if not e.loc.has(w):
			continue
		var v := 0.0
		if e.amica(w, s):
			v += 2.0
		if e.caposaldo(w) and e.amica(w, s):
			v += 1.0
		for n in e.vicine(w):
			v -= e.forza_gruppo(e.fuori_in(n, 1 - s)) * 0.1
		if v > bv:
			bv = v
			best = w
	return best


func _assedia(e, s: int, req: Dictionary) -> String:
	var id: String = req["sig"]
	var l: String = e.L[id]["loc"]
	var v: int = e.valore(l)
	var dentro: Array = e.dentro_in(l, 1 - s)
	var lords: int = e.fuori_in(l, s).size()
	if not dentro.is_empty():
		var fd: float = e.forza_gruppo(dentro)
		if fd > e.forza_gruppo(e.fuori_in(l, s)) * 0.8:
			return "aggira"
		return "assedia"
	if v == 1 or lords >= v or e.ha_cap(id, "Genieri di Guerra"):
		return "assedia"
	# con la Sorpresa in mano l'assedio diventa subito un Assalto (Volko Ruhnke la tiene per questo)
	if _c("sorpresa") and ("G03" if s == 0 else "H03") in e.tenute[s] and _prob_assalto(e, s, l) + 0.25 > 0.3:
		return "assedia"
	# senza abbastanza Signori per avanzare le opere: aggira e devasta
	return "aggira" if level >= 1 else "assedia"


# ================================================================ leva

func _paga(e, s: int, o: Array) -> String:
	for x in o:
		var r: String = x["id"]
		if r == "fine":
			continue
		var t: String = r.split(">")[1]
		var resto: int = e.L[t]["svc"] - e.turno
		if resto <= 0:
			return r
		if e.fase == "leva" and resto == 1 and (e.forza(t) >= 6.0 or e.signori_mappa(s).size() <= 2):
			return r
		# un Podestà che smobilita oltre il Servizio regala al nemico 3 Rivolte e 3 Tradimenti
		if _c("podesta") and e.podesta(t) and resto <= 1:
			return r
	return "fine"


func _raduno_chi(e, o: Array) -> String:
	var best: String = o[0]["id"]
	var bv := -1e9
	for x in o:
		if x["id"] == "fine":
			continue
		var v: float = e._signoria(x["id"]) + e.forza(x["id"]) * 0.1
		if v > bv:
			bv = v
			best = x["id"]
	return best


const CAP_BUONE := {"Feditori": 3.0, "Riserva di Armata": 3.0, "Riserva dell'Armata": 3.0, "Balestrieri": 2.2, "Palvesari": 2.0,
	"Astrologi": 2.5, "Manfredi": 3.0, "Via Francigena": 3.0, "Guastatori": 2.4, "Genieri di Guerra": 2.0, "Torri d'Assedio": 1.6,
	"Trabucchi": 1.2, "Arcieri": 1.5, "Luceria": 1.8, "Balestre grosse": 1.2, "Gualdana": 1.6, "Masnadieri": 2.0, "La Cavallata": 1.4,
	"Depositi e Pozzo": 1.8, "Distringitores": 2.0, "Compagnia Tau": 2.2, "Taglia": 1.5, "Mura rinforzate": 0.8, "Costruttori": 1.0,
	"Sovrintendente": 1.0}

func _raduno(e, s: int, req: Dictionary) -> String:
	var id: String = req["sig"]
	var o: Array = req["opzioni"]
	var best := "fine"
	var bv := 0.05
	for x in o:
		var r: String = x["id"]
		var v := 0.0
		if r.begins_with("sig:"):
			var t: String = r.substr(4)
			var p: float = D.SIGNORI[t]["fed"] / 6.0
			v = (3.0 + D.SIGNORI[t]["cmd"]) * p / float(x.get("costo", 1))
			if e.signori_mappa(s).size() <= 2:
				v += 2.5
		elif r.begins_with("vas:") or r == "alto" or r.begins_with("taglia:"):
			var vas: String = x.get("vas", "")
			var f := 0.0
			for u in D.VASSALLI[vas]["forze"]:
				f += InfStato.VAL_UNITA[u] * int(D.VASSALLI[vas]["forze"][u])
			v = 1.0 + f * 0.6
			if r == "alto":
				v += 3.0
		elif r.begins_with("sest:"):
			v = 2.0
		elif r == "carro":
			var c: int = e.supp(id, "carro")
			v = 1.6 if c < 2 else (0.9 if c < 4 else 0.3)
		elif r == "nave":
			v = 0.5 if e.supp(id, "nave") < 3 else 0.1
		elif r.begins_with("cap:"):
			var c2: String = r.substr(4)
			v = CAP_BUONE.get(D.CARTE[c2]["cap"], 1.0) * 0.7
		v = _rumore(v)
		if v > bv:
			bv = v
			best = r
	return best


func _alleati(e, o: Array) -> String:
	var best: String = o[0]["id"]
	var bv := -1e9
	for x in o:
		var r: String = x["id"]
		var v := 0.0
		if r.begins_with("ral:"):
			var t: String = r.substr(4)
			v = 4.0 + D.SIGNORI[t]["cmd"]
		elif r.begins_with("lev:"):
			v = 2.0 + e._signoria(r.substr(4))
		if v > bv:
			bv = v
			best = r
	return best


func _cap_a_chi(e, o: Array) -> String:
	var best: String = o[0]["id"]
	var bv := -1.0
	for x in o:
		var v: float = e.forza(x["id"])
		if v > bv:
			bv = v
			best = x["id"]
	return best


func _miglior_signore_trad(e, o: Array) -> String:
	var best: String = o[0]["id"]
	var bv := -1e9
	for x in o:
		var id: String = x["id"]
		var v := 0.0
		if e.sulla_mappa(id):
			v = 2.0 + e.supp(id, "moneta")
		if v > bv:
			bv = v
			best = id
	return best


func _tradimento(e, s: int, o: Array) -> String:
	var best := "passa"
	var bv := 0.3
	for x in o:
		var r: String = x["id"]
		var v := 0.0
		if r.begins_with("riv0:"):
			v = 10.0
		elif r.begins_with("riv:"):
			var p: PackedStringArray = r.split(":")
			var m := int(p[2])
			var prob := pow(m / 6.0, e.valore(p[1]))
			v = prob * e.valore(p[1]) * 3.0 - m * 0.15
			if _c("tradimento") and (_vantaggio(e, s) < 0.0 or _ultimo_turno(e)):
				v += prob * 1.5
		elif r.begins_with("cor:"):
			var vas: String = r.substr(4)
			var prob2: float = maxf(0.0, (6 - int(D.VASSALLI[vas]["serv"])) / 6.0)
			v = prob2 * 2.5
		if v > bv:
			bv = v
			best = r
	return best


func _evento(e, s: int, req: Dictionary) -> String:
	var o: Array = req["opzioni"]
	var titolo: String = req.get("titolo", "")
	if titolo == "Imboscata":
		return "si"
	if titolo == "Sorpresa" and _c("sorpresa"):
		# solo se l'assalto ha buone probabilità (Assedio 2 e Mura -2 aiutano)
		var l: String = req.get("loc", "")
		if l != "" and _prob_assalto(e, s, l) + 0.25 < 0.3:
			return "no"
		return "si"
	for x in o:
		if x["id"] != "no":
			return x["id"]
	return "no"


func _loc_valore_max(e, o: Array) -> String:
	var best: String = o[0]["id"]
	var bv := -1
	for x in o:
		var l: String = x["id"]
		if e.loc.has(l) and e.valore(l) > bv:
			bv = e.valore(l)
			best = l
	return best


func _sede(e, s: int, req: Dictionary) -> String:
	var o: Array = req["opzioni"]
	var best: String = o[0]["id"]
	var bv := -1e9
	for x in o:
		var l: String = x["id"]
		var v := 0.0
		if e.caposaldo(l):
			v += e.valore(l)
		# più vicino ai nemici, ma non accanto a un'armata più forte
		var dmin := 99
		for t in e.signori_mappa(1 - s):
			dmin = mini(dmin, e.distanza(e.L[t]["loc"], l))
		v -= dmin * 0.2
		if v > bv:
			bv = v
			best = l
	return best
