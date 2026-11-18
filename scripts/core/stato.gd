class_name InfStato
extends Node
## Stato della partita di Inferno e funzioni di servizio (mappa, Signori, Supporti, Vittoria, Rivolta).
## Il flusso del gioco sta in engine.gd, la battaglia in battaglia.gd.
##
## Ogni scelta passa da decide(lato, req): l'IA risponde subito; per le persone viene emesso
## decision_requested e si attende provide_decision(). Quasi tutte le scelte sono del tipo generico
## «scelta»: req = {type: "scelta", k: tipo, titolo, testo, opzioni: [{id, t, loc?, sig?, carta?, dett?}]}
## e la risposta è l'id dell'opzione. Il piano di campagna ha una richiesta sua: {type: "piano"}.

const D = preload("res://scripts/data/inf_data.gd")

signal changed
signal log_added(text: String)
signal decision_requested(req: Dictionary)
signal decision_provided(result)
signal game_ended(result: Dictionary)
signal fx(kind: String, data: Dictionary)

var players: Array = []          # [{name, ai, level}] per Guelfi (0) e Ghibellini (1)
var ais: Array = []
var online = null
var ai_delay := 0.5
var anim := 1.0
## Mostrare le battaglie in 3D (solo il ritmo della partita: non cambia le regole né l'online).
var mostra_battaglie := true
var headless := false
var abort := false
var rng := RandomNumberGenerator.new()
var replay: Array = []
var replay_i := 0
var record: Array = []
var log_lines: Array = []

# --- partita
var scen := "F"
var S: Dictionary = {}           # dati dello scenario
var turno := 1
var turno_fine := 16
var fine_box := -1              # segnalino Fine dell'Esaurimento (scenario F)
var fase := "leva"               # "leva", "campagna", "fine"
var passo := ""                  # descrizione del momento (per l'interfaccia)
var prima_leva := true
var attivo := -1                 # lato attivo in campagna
var sig_attivo := ""             # signore attivo
var over := false
var result := {}

# --- mappa: per località {all_l, all_n, rovine, dev, mura, assedio, assedio_l}
var loc := {}
var adj := {}                    # località -> {vicina: "S"|"T"}
# --- Signori: id -> stato
var L := {}
# --- Vassalli: id -> {stato: "pronto"|"radunato"|"nonpronto"|"fuori", presso: signore}
var V := {}
# --- carte
var mazzo_aow := [[], []]        # carte Arte della Guerra nel mazzo di pesca
var tenute := [[], []]           # Eventi Tenuti (nascosti)
var cap_lato := [[], []]         # Capacità di parte in gioco
var ev_attivi := []              # {id, lato, fino: "leva"|"campagna"}
var tradimento := [[], []]       # Signori la cui carta Tradimento è nel mazzo Comando
var piano := [[], []]            # carte del piano: {t: "cmd"|"trad"|"passa", l: signore}
var giocate := [[], []]          # carte già girate in questa Campagna
var catturati := [{"cav": 0, "ritter": 0}, {"cav": 0, "ritter": 0}]   # Cavalieri di quel lato catturati
var carroccio_preso := [false, false]
var bonus_sign := {}             # Signoria aggiuntiva in questa Leva
var chiamata_fatta := false
var guerra := [false, false]     # Evento Guerra pescato in questa Leva
var tesori := [false, false]
var no_tasse := [false, false]
var frati := false
var lavori := [false, false]
var maremma_blocco := false
var pool := {}                   # unità ancora nel contenitore
var battaglia := {}              # battaglia o assalto in corso (per l'interfaccia)
var dadi_ultimi := []


# ================================================================ utilità generali

func log_msg(t: String) -> void:
	log_lines.append(t)
	log_added.emit(t)


func pname(s: int) -> String:
	if s < 0 or s >= players.size():
		return ""
	var nm: String = str(players[s].get("name", ""))
	return nm if nm != "" else D.LATI[s]


func nome(id: String) -> String:
	return D.SIGNORI[id]["nome"]


func lnome(l: String) -> String:
	return D.LOCALI[l]["nome"]


func d6() -> int:
	return rng.randi_range(1, 6)


func _pace(sec: float) -> void:
	if headless or anim <= 0.0 or abort or not is_inside_tree():
		return
	if online != null and online.catchup:
		return
	if replay_i < replay.size():
		return
	await get_tree().create_timer(sec / anim).timeout


## Pause delle battaglie: con la scena visibile hanno il loro ritmo (anche se l'IA va veloce),
## con le battaglie spente non si aspetta.
func _pace_b(sec: float) -> void:
	if not mostra_battaglie:
		return
	var a := anim
	anim = minf(maxf(anim, 0.0), 1.25) if anim > 0.0 else 0.0
	await _pace(sec)
	anim = a


func decide(side: int, req: Dictionary):
	req["side"] = side
	changed.emit()
	var r
	if replay_i < replay.size():
		r = replay[replay_i]
		replay_i += 1
	elif abort:
		r = ais[side].decide(self, side, req)
	elif online != null:
		r = await online.decide(self, side, req)
	elif players[side]["ai"]:
		if ai_delay > 0.0 and not headless and is_inside_tree():
			await get_tree().create_timer(ai_delay).timeout
		r = ais[side].decide(self, side, req)
	else:
		decision_requested.emit(req)
		r = await decision_provided
		if r == null:
			r = ais[side].decide(self, side, req)
	record.append(r)
	return r


func provide_decision(r) -> void:
	decision_provided.emit(r)


## Scelta generica: restituisce l'id dell'opzione scelta (la prima se la risposta non è valida).
func scegli(side: int, k: String, titolo: String, testo: String, opzioni: Array, extra := {}) -> String:
	if opzioni.is_empty():
		return ""
	if opzioni.size() == 1 and extra.get("auto1", false):
		return str(opzioni[0]["id"])
	var req := {"type": "scelta", "k": k, "titolo": titolo, "testo": testo, "opzioni": opzioni}
	for x in extra:
		req[x] = extra[x]
	var r = await decide(side, req)
	for o in opzioni:
		if str(o["id"]) == str(r):
			return str(r)
	return str(opzioni[0]["id"])


func opz(id: String, t: String, extra := {}) -> Dictionary:
	var o := {"id": id, "t": t}
	for x in extra:
		o[x] = extra[x]
	return o


# ================================================================ mappa

func costruisci_adiacenze() -> void:
	adj.clear()
	for l in D.LOCALI:
		adj[l] = {}
	for v in D.VIE:
		adj[v[0]][v[1]] = v[2]
		adj[v[1]][v[0]] = v[2]


func vicine(l: String) -> Array:
	return adj[l].keys()


func avamposto(l: String) -> bool:
	return D.LOCALI[l]["tipo"] == "avamposto"


func valore(l: String) -> int:
	return int(D.LOCALI[l]["valore"])


## Caposaldo (Città, Cittadina, Castello) non in Rovina.
func caposaldo(l: String) -> bool:
	return not avamposto(l) and loc[l]["rovine"] < 0


func lato_stampato(l: String) -> int:
	return int(D.LOCALI[l]["lato"])


## Alleanza corrente: i segnalini Alleanza o, se non ci sono, il colore stampato.
func alleanza(l: String) -> int:
	if loc[l]["all_n"] > 0:
		return loc[l]["all_l"]
	return lato_stampato(l)


func amica(l: String, s: int) -> bool:
	return alleanza(l) == s


func caposaldo_nemico(l: String, s: int) -> bool:
	return caposaldo(l) and not amica(l, s)


func distanza(a: String, b: String) -> int:
	if a == b:
		return 0
	var seen := {a: 0}
	var q := [a]
	while not q.is_empty():
		var x: String = q.pop_front()
		for y in adj[x]:
			if not seen.has(y):
				seen[y] = seen[x] + 1
				if y == b:
					return seen[y]
				q.append(y)
	return 99


## Distanze da una località a tutte (BFS); filtro facoltativo sulle località attraversabili.
func distanze(a: String, passa: Callable = Callable()) -> Dictionary:
	var seen := {a: 0}
	var q := [a]
	while not q.is_empty():
		var x: String = q.pop_front()
		for y in adj[x]:
			if seen.has(y):
				continue
			if passa.is_valid() and not passa.call(y):
				continue
			seen[y] = seen[x] + 1
			q.append(y)
	return seen


# ================================================================ Signori

func L_(id: String) -> Dictionary:
	return L[id]


func lato(id: String) -> int:
	return int(D.SIGNORI[id]["lato"])


func sulla_mappa(id: String) -> bool:
	return L.has(id) and L[id]["stato"] == "mappa"


func podesta(id: String) -> bool:
	return bool(D.SIGNORI[id].get("podesta", false))


func comandante(id: String) -> bool:
	return bool(D.SIGNORI[id].get("comandante", false))


func comune_di(id: String) -> String:
	return str(D.SIGNORI[id].get("comune_di", ""))


func comune(id: String) -> String:
	var c: String = D.COMUNE.get(id, "")
	return c if c != "" and sulla_mappa(c) else ""


## Signori sulla mappa (con i Comuni se richiesto).
func signori_mappa(s: int, comuni := false) -> Array:
	var out := []
	for id in L:
		if L[id]["stato"] == "mappa" and lato(id) == s:
			if comune_di(id) != "" and not comuni:
				continue
			out.append(id)
	return out


func signori_in(l: String, s := -1, comuni := true) -> Array:
	var out := []
	for id in L:
		var x: Dictionary = L[id]
		if x["stato"] == "mappa" and x["loc"] == l and (s < 0 or lato(id) == s):
			if comune_di(id) != "" and not comuni:
				continue
			out.append(id)
	return out


## Signori fuori dal Caposaldo (non dentro): sono quelli che si possono attaccare in battaglia.
func fuori_in(l: String, s: int) -> Array:
	var out := []
	for id in signori_in(l, s):
		if not L[id]["dentro"]:
			out.append(id)
	return out


func dentro_in(l: String, s: int) -> Array:
	var out := []
	for id in signori_in(l, s):
		if L[id]["dentro"]:
			out.append(id)
	return out


## Località assediata da s (segnalini Assedio di s).
func assediata_da(l: String, s: int) -> bool:
	return loc[l]["assedio"] > 0 and loc[l]["assedio_l"] == s


func assediato(id: String) -> bool:
	var x: Dictionary = L[id]
	return x["stato"] == "mappa" and x["dentro"] and assediata_da(x["loc"], 1 - lato(id))


## Signore dentro un Caposaldo aggirato dal nemico.
func aggirato(id: String) -> bool:
	var x: Dictionary = L[id]
	if not x["dentro"] or assediato(id):
		return false
	for e in fuori_in(x["loc"], 1 - lato(id)):
		if L[e]["aggira"]:
			return true
	return false


func unita(id: String) -> int:
	var t := 0
	for u in L[id]["forze"]:
		t += int(L[id]["forze"][u])
	return t


func unita_tot(id: String) -> int:
	var t := unita(id)
	for u in L[id]["rotte"]:
		t += int(L[id]["rotte"][u])
	return t


func supp(id: String, k: String) -> int:
	return int(L[id]["supp"].get(k, 0))


func add_supp(id: String, k: String, n: int) -> void:
	var v: int = clampi(supp(id, k) + n, 0, 16)
	L[id]["supp"][k] = v


## Forza indicativa di un Signore (per l'IA e le descrizioni).
const VAL_UNITA := {"ritter": 3.2, "cav": 2.0, "berr": 1.0, "cl": 0.7, "uia": 1.6, "arm": 1.3, "mil": 0.6, "vill": 0.3}

func forza(id: String) -> float:
	var t := 0.0
	for u in L[id]["forze"]:
		t += VAL_UNITA[u] * int(L[id]["forze"][u])
	return t


func forza_gruppo(ids: Array) -> float:
	var t := 0.0
	for id in ids:
		t += forza(id)
	return t


## Il Signore e il suo Comune contano come uno solo per Nutrire e Spreco.
func gruppo_comune(id: String) -> Array:
	var c := comune(id)
	return [id, c] if c != "" else [id]


func descr_forze(f: Dictionary) -> String:
	var parti := []
	for u in D.ORDINE_UNITA:
		var n: int = int(f.get(u, 0))
		if n > 0:
			parti.append("%d %s" % [n, D.UNITA[u]["plur"] if n > 1 else D.UNITA[u]["nome"]])
	return ", ".join(parti) if not parti.is_empty() else "nessuna"


func descr_supp(id: String) -> String:
	var parti := []
	for k in ["moneta", "bottino", "prov", "carro", "nave"]:
		var n := supp(id, k)
		if n > 0:
			parti.append("%d %s" % [n, D.SUPPORTI[k]])
	return ", ".join(parti) if not parti.is_empty() else "nessun supporto"


# ================================================================ unità e contenitore

func prendi_unita(id: String, f: Dictionary) -> void:
	for u in f:
		var n: int = mini(int(f[u]), int(pool[u]))
		pool[u] -= n
		L[id]["forze"][u] = int(L[id]["forze"].get(u, 0)) + n


func rendi_unita(id: String) -> void:
	for u in L[id]["forze"]:
		pool[u] += int(L[id]["forze"][u])
	for u in L[id]["rotte"]:
		pool[u] += int(L[id]["rotte"][u])
	L[id]["forze"] = {}
	L[id]["rotte"] = {}


func togli_unita(id: String, u: String, n := 1) -> int:
	var have: int = int(L[id]["forze"].get(u, 0))
	var k: int = mini(have, n)
	if k > 0:
		L[id]["forze"][u] = have - k
		if L[id]["forze"][u] == 0:
			L[id]["forze"].erase(u)
		pool[u] += k
	return k


# ================================================================ calendario e servizio

func sposta_servizio(id: String, n: int) -> void:
	# n > 0: a destra (più servizio), n < 0: a sinistra
	if not L.has(id):
		return
	var x: Dictionary = L[id]
	var v: int = x["svc"]
	if n > 0 and v >= 17:
		return
	if n < 0 and v <= 0:
		return
	x["svc"] = clampi(v + n, 0, 17)


func sposta_cilindro(id: String, n: int) -> void:
	var x: Dictionary = L[id]
	var v: int = x["cal"]
	if n > 0 and v >= 17:
		return
	if n < 0 and v <= 0:
		return
	x["cal"] = clampi(v + n, 0, 17)


## Pronto per il Raduno: cilindro sul calendario nella casella del turno o prima.
func pronto(id: String) -> bool:
	return L[id]["stato"] == "cal" and L[id]["cal"] <= turno


# ================================================================ Vittoria

func pv(s: int) -> float:
	var t := 0.0
	var dev := 0.0
	for l in loc:
		var x: Dictionary = loc[l]
		if x["all_n"] > 0 and x["all_l"] == s:
			t += x["all_n"]
		if x["rovine"] == s:
			t += 0.5
		if x["dev"] == s:
			dev += 0.5
	if carroccio_preso[1 - s]:
		t += 2.0
	if S.get("manfredi_pv", 0) and s == 1 and "H22" in cap_lato[1]:
		t += float(S["manfredi_pv"])
	if S.get("resistenza", false) and s == 0:
		t *= 2.0
	return t + dev


func pv_testo(s: int) -> String:
	var v := pv(s)
	if is_equal_approx(v, floor(v)):
		return "%d" % int(v)
	return "%d e 1/2" % int(floor(v))


# ================================================================ Rivolta (1.4)

## Caposaldo disponibile per la Rivolta: non Rovine né Avamposto, senza Signori del suo lato lì o adiacenti.
func disponibile_rivolta(l: String) -> bool:
	if not caposaldo(l):
		return false
	var s := alleanza(l)
	if not signori_in(l, s).is_empty():
		return false
	for v in adj[l]:
		if not signori_in(v, s).is_empty():
			return false
	return true


## Signore o segnalino Alleanza (solo segnalini) del lato s in l o adiacente.
func presenza(l: String, s: int) -> bool:
	for x in [l] + vicine(l):
		if not signori_in(x, s).is_empty():
			return true
		if loc[x]["all_n"] > 0 and loc[x]["all_l"] == s:
			return true
	return false


func presenza_signori(l: String, s: int) -> bool:
	for x in [l] + vicine(l):
		if not signori_in(x, s).is_empty():
			return true
	return false


## Il Caposaldo cambia Alleanza a favore di s (1.4.4). Restituisce il numero di segnalini mossi.
func cambia_alleanza(l: String, s: int, esilio := true) -> int:
	var x: Dictionary = loc[l]
	var n := 0
	var perdente := alleanza(l)
	if x["all_n"] > 0:
		n = x["all_n"]
		x["all_n"] = 0
		x["all_l"] = -1
	else:
		n = valore(l)
		x["all_n"] = n
		x["all_l"] = s
	# l'Assedio o l'Aggiramento lì finiscono
	if x["assedio"] > 0:
		x["assedio"] = 0
		x["assedio_l"] = -1
	for id in signori_in(l):
		L[id]["aggira"] = false
	fx.emit("alleanza", {"loc": l, "lato": s})
	if esilio and perdente != s:
		_esilio(perdente, n)
	return n


## Esilio: il lato che ha perso l'Alleanza sposta i suoi segnalini Servizio a destra o i cilindri a sinistra.
func _esilio(s: int, n: int) -> void:
	for i in n:
		var best := ""
		var best_v := 99
		for id in L:
			if lato(id) != s or comune_di(id) != "":
				continue
			if L[id]["stato"] == "mappa" and L[id]["svc"] < 17 and L[id]["svc"] - turno < best_v:
				best_v = L[id]["svc"] - turno
				best = id
		if best != "":
			sposta_servizio(best, 1)
			continue
		for id in L:
			if lato(id) == s and L[id]["stato"] == "cal" and L[id]["cal"] > turno:
				sposta_cilindro(id, -1)
				break


## Un tiro sulla tabella della Rivolta del lato s (contro il nemico). Restituisce la località o "".
func tiro_rivolta(s: int) -> String:
	var e := 1 - s
	var oro := d6()
	var porpora := d6()
	dadi_ultimi = [porpora, oro]
	var r: String = D.RIVOLTA[e][oro - 1][porpora - 1]
	var nemici := "Guelfi" if e == 0 else "Ghibellini"
	if r == "X":
		# Sottomissione: un Caposaldo con segnalini Alleanza nemici, disponibile, con un nostro Signore lì o adiacente
		var cand := []
		for l in loc:
			if loc[l]["all_n"] > 0 and loc[l]["all_l"] == e and disponibile_rivolta(l) and presenza_signori(l, s):
				cand.append(l)
		if cand.is_empty():
			log_msg("Rivolta contro i %s (%d, %d): sottomissione, ma nessun Caposaldo adatto." % [nemici, porpora, oro])
			return ""
		var o := []
		for l in cand:
			o.append(opz(l, lnome(l), {"loc": l}))
		var c := await scegli(s, "rivolta_x", "Sottomissione", "Scegli il Caposaldo che torna con te.", o)
		cambia_alleanza(c, s)
		log_msg("Rivolta (%d, %d): %s si sottomette ai %s." % [porpora, oro, lnome(c), D.LATI[s]])
		return c
	if amica(r, s):
		var cand := []
		for v in adj[r]:
			if caposaldo(v) and not amica(v, s) and valore(v) <= valore(r) and disponibile_rivolta(v):
				cand.append(v)
		if cand.is_empty():
			log_msg("Rivolta (%d, %d): %s è già con voi e non c'è un Caposaldo vicino adatto." % [porpora, oro, lnome(r)])
			return ""
		var o := []
		for l in cand:
			o.append(opz(l, lnome(l), {"loc": l}))
		var c := await scegli(s, "rivolta_vicina", "Rivolta", "%s è già con te: scegli un Caposaldo nemico adiacente che si ribella." % lnome(r), o)
		cambia_alleanza(c, s)
		log_msg("Rivolta (%d, %d): si ribella %s." % [porpora, oro, lnome(c)])
		return c
	if not disponibile_rivolta(r):
		log_msg("Rivolta (%d, %d): %s non può ribellarsi." % [porpora, oro, lnome(r)])
		return ""
	if not presenza(r, s):
		log_msg("Rivolta (%d, %d): a %s nessuno sostiene la ribellione." % [porpora, oro, lnome(r)])
		return ""
	cambia_alleanza(r, s)
	log_msg("Rivolta (%d, %d): %s passa ai %s!" % [porpora, oro, lnome(r), D.LATI[s]])
	return r


## Aggiungere n carte Tradimento al mazzo Comando di s (sceglie fra quelle messe da parte).
func aggiungi_tradimento(s: int, n: int, solo := []) -> void:
	for i in n:
		var cand := []
		for id in D.SIGNORI_LATO[s]:
			if L.has(id) and L[id]["stato"] != "rimosso" and not id in tradimento[s] and (solo.is_empty() or id in solo):
				cand.append(id)
		if cand.is_empty():
			return
		var o := []
		for id in cand:
			o.append(opz(id, nome(id), {"sig": id}))
		var c := await scegli(s, "tradimento", "Tradimento", "Scegli il Signore la cui carta Tradimento entra nel mazzo Comando.", o, {"auto1": true})
		tradimento[s].append(c)
		log_msg("I %s aggiungono una carta Tradimento al mazzo Comando." % D.LATI[s])


## Rimozione o Smobilitazione oltre il Servizio: tiri sulla Rivolta e Tradimento per il nemico.
func penalita_rimozione(id: String) -> void:
	var e := 1 - lato(id)
	var n := 3 if podesta(id) else 1
	for i in n:
		await tiro_rivolta(e)
	await aggiungi_tradimento(e, n)


## Impronta dello stato, per controllare che due copie della partita (online, salvataggi) coincidano.
func impronta() -> String:
	return "%d-%s-%d-%d" % [turno, fase, record.size(), hash(var_to_str([loc, L, pool, tenute, cap_lato]))]
