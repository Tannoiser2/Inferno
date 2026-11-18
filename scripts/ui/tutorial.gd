class_name Tutorial
extends RefCounted
## I tutorial di Inferno:
## - la «campagna guidata»: lo scenario A (Dolenti note, 2 turni) con i Guelfi, contro l'IA facile; a ogni
##   decisione nuova si apre una lezione, e il riquadro «Consiglio del tutor» propone la mossa dell'IA esperta
##   spiegandone il perché;
## - la «battaglia guidata»: una battaglia campale e un Assalto preparati, per imparare il combattimento con calma;
## - il manuale «Strategie», raccolto dai resoconti di partita di Volko Ruhnke e Christophe Correia (InsideGMT,
##   The Boardgames Chronicle) e dai consigli del regolamento.

const D = preload("res://scripts/data/inf_data.gd")

const SEED_CAMPAGNA := 1263
const SEED_BATTAGLIA := 1260


static func config_campagna() -> Dictionary:
	return {"scen": "A", "tutorial": "campagna", "seed": SEED_CAMPAGNA, "ai_delay": 0.6, "anim": 1.0,
		"seats": [{"name": "Tu (Guelfi)", "ai": false, "level": 1}, {"name": "Ghibellini (IA)", "ai": true, "level": 0}]}


static func config_battaglia() -> Dictionary:
	return {"scen": "F", "tutorial": "battaglia", "lezione": "battaglia", "seed": SEED_BATTAGLIA, "ai_delay": 0.6, "anim": 1.0,
		"seats": [{"name": "Tu (Guelfi)", "ai": false, "level": 1}, {"name": "Ghibellini (IA)", "ai": true, "level": 0}]}


# ================================================================ lezioni
## chiave -> elenco di pagine [titolo, testo]
const LEZIONI := {
	"intro": [
		["Benvenuto in Inferno", """Toscana, 1259. [b]Firenze[/b] guida i [b]Guelfi[/b], fedeli al Papa; [b]Siena[/b] guida i [b]Ghibellini[/b], fedeli all'Imperatore. In questa partita guidata comandi i Guelfi; i Ghibellini li muove l'IA (al livello facile).

È lo scenario introduttivo [b]A. Dolenti note[/b]: due turni di 60 giorni ciascuno, nella primavera del 1259. [b]Cortona[/b], città guelfa, si è ribellata e ha alzato le insegne ghibelline; [b]Arezzo[/b] e [b]Firenze[/b] devono riprenderla, mentre Siena ha i suoi problemi con [b]Montalcino[/b] e [b]Montepulciano[/b], ribelli ai Ghibellini.

Vince chi ha più [b]Punti Vittoria[/b] alla fine. Si fanno punti con i Capisaldi (città, cittadine e castelli) che passano alla tua parte nel territorio nemico, con le devastazioni e con le rovine delle città nemiche saccheggiate.

Ogni volta che arriva una decisione nuova si apre una lezione come questa. Nel riquadro [b]Consiglio del tutor[/b], sopra i pulsanti, trovi la mossa che farebbe un giocatore esperto e il perché: puoi seguirla con un tocco oppure fare di testa tua."""],
		["La mappa e il calendario", """[b]La mappa[/b] è quella del gioco: le località collegate da [b]strade[/b] (linee piene, veloci) e [b]sentieri[/b] (tratteggiati, più lenti). Il piccolo stemma accanto a un Caposaldo dice a quale parte appartiene; i segnalini Alleanza sopra lo cambiano.

Per muoverti: trascina con un dito o con il mouse, pizzica con due dita o usa la rotella per ingrandire, ruota con due dita. «Tutta» rimette la mappa intera, «2D / 3D» cambia vista. Tocca un Signore (sulla mappa o nei pannelli laterali) per aprire la sua [b]scheda[/b].

[b]Il calendario[/b], in alto, ha una casella per ogni turno di 60 giorni. Lo scudo di ogni Signore sta nella casella del turno in cui il suo [b]Servizio[/b] finisce: quando il turno arriva lì, il Signore torna a casa con le sue truppe. Il tempo è la risorsa più preziosa del gioco: ogni Signore ha un Servizio limitato, e mangia."""],
		["Come si svolge un turno", """Ogni turno ha tre parti:
1. [b]Leva[/b]: si pescano le carte Arte della Guerra (Capacità ed Eventi), si pagano i Signori per allungarne il Servizio, si radunano nuovi Signori, Vassalli, carri e Capacità.
2. [b]Campagna[/b]: ognuno prepara in segreto un [b]Piano[/b] di carte Comando; poi le carte si scoprono una alla volta, alternandosi, e il Signore della carta compie le sue azioni: marciare, rifornirsi, assediare, combattere…
3. [b]Fine della campagna[/b]: si contano le perdite, si riscattano i prigionieri, i Signori senza Servizio tornano a casa.

Cominciamo dalla Leva."""],
	],
	"leva": [
		["La Leva: l'Arte della Guerra", """All'inizio della Leva ogni parte pesca due carte [b]Arte della Guerra[/b]. Nel primo turno di uno scenario sono [b]Capacità[/b]: specialisti e risorse che restano in gioco (balestrieri, guastatori, cavalieri feditori…). Dai turni seguenti sono [b]Eventi[/b]: alcuni accadono subito, altri si tengono nascosti e si giocano al momento giusto, come la [b]Sorpresa[/b] che i Guelfi hanno già in mano in questo scenario.

Le Capacità «[b]Questo Signore[/b]» si assegnano a un Signore preciso, che ne può avere al massimo due; le altre valgono per tutta la parte."""],
		["Il Raduno", """Poi ogni Signore sulla mappa, in una località amica e libera da nemici, fa tante azioni di [b]Raduno[/b] quanta è la sua [b]Signoria[/b] (il numero sulla scheda):
- chiamare un altro [b]Signore[/b] in servizio: si tira un dado, serve un risultato pari o inferiore alla sua [b]Fedeltà[/b];
- radunare un [b]Vassallo[/b] con le sue truppe (se la sua Sede è amica);
- prendere un [b]carro[/b] o una [b]nave[/b] per trasportare le provviste;
- aggiungere una [b]Capacità[/b] presa dal mazzo.

[b]Consiglio[/b]: radunate pensando al piano di campagna. Per prendere Cortona servono uomini e specialisti d'assedio (Guastatori, Balestrieri); per una lunga marcia servono carri."""],
	],
	"sede": [
		["Dove si raduna", """Un Signore appena chiamato si raduna in una delle sue [b]Sedi[/b] amiche. Sceglietene una vicina all'azione: le prime carte della campagna non andranno sprecate in marce di avvicinamento."""],
	],
	"paga": [
		["Il Servizio e la Paga", """Ogni Signore resta in campo fino alla casella del calendario del suo [b]Servizio[/b]. Spendendo una [b]Moneta[/b] (o un Bottino) il Servizio si allunga di un turno; i [b]Podestà[/b] (i capi delle città: Firenze, Arezzo, Siena…) costano il doppio, 2 Monete.

Un Signore che arriva alla fine del Servizio [b]smobilita[/b]: torna a casa e potrà essere richiamato più tardi. Se smobilita [b]oltre[/b] il Servizio (perché non è stato nutrito o pagato) la parte nemica ottiene tiri di Rivolta e carte Tradimento: uno per un Signore qualsiasi, [b]tre per un Podestà[/b]. Proteggete i Podestà dalla fame e dalla bancarotta."""],
	],
	"evento": [
		["Gli Eventi da tenere", """Alcuni Eventi si tengono in mano, nascosti, e si giocano quando conviene: la [b]Sorpresa[/b] permette di assediare un Caposaldo senza Signori dentro con due segnalini e di assaltarlo subito con le mura indebolite. Un Evento giocato al momento giusto può decidere la campagna."""],
	],
	"piano": [
		["Il Piano di campagna", """Ora entrambe le parti preparano in segreto il [b]Piano[/b]: una pila di carte Comando, tante quante la stagione permette (7 in primavera e in autunno, 6 d'estate, 4 d'inverno). Ogni Signore sulla mappa ha [b]tre carte Comando[/b]; le carte [b]Passare[/b] riempiono i buchi.

Le carte si scoprono [b]una alla volta, alternandosi[/b] con l'avversario: quando esce la carta di un Signore, lui (con chi marcia con lui) compie tante azioni quanto il suo [b]Comando[/b]. Il piano non si cambia più: è la nebbia della guerra medievale. Una carta di un Signore che nel frattempo è stato sconfitto va persa."""],
		["Come si costruisce un buon piano", """- [b]Un obiettivo chiaro[/b]: Volko Ruhnke, l'autore della serie, in questo scenario punta su Cortona; l'altra ribelle guelfa è [b]Poggio Bonizio[/b], vicina a Firenze. Disperdere i Signori su tre obiettivi diversi di solito non porta a niente.
- [b]Concentrate le forze[/b]: un Signore che marcia insieme a un altro (o lo raggiunge) è molto più forte, e una cittadina (valore 2) si assedia bene solo in due. Da soli conviene la [b]Sorpresa[/b], che vi siete tenuti in mano.
- [b]Prima i rifornimenti[/b]: un'armata senza provviste perde Servizio. Nella prima carta conviene spesso rifornirsi nella propria Sede.
- [b]Le ultime carte[/b] servono a tornare in una località amica, dove al turno dopo si potrà fare la Leva.

Il pulsante [b]Suggerisci[/b] costruisce il piano che farebbe il tutor."""],
	],
	"azione": [
		["Le azioni di un Signore", """Il Signore attivo ha tante azioni quanto il suo [b]Comando[/b]:
- [b]Marciare[/b] in una località vicina. Su [b]strada[/b] la prima marcia senza carico è gratis; i sentieri costano di più; carri e provviste rallentano.
- [b]Rifornirsi[/b]: prendere provviste da una Sede amica (tante quanto il suo valore), lì o raggiungibile con i carri.
- [b]Foraggiare[/b]: cercare cibo nella campagna (sicuro in località amiche e d'estate).
- [b]Tassare[/b] (tutta la carta): +1 Moneta, [b]+2 per un Podestà[/b]. Le Monete pagano il Servizio e i Tradimenti.
- [b]Devastare[/b] una località nemica: mezzo Punto Vittoria, provviste per l'armata e un aiuto all'assedio.
- [b]Assediare[/b] o [b]Assaltare[/b] un Caposaldo nemico (tutta la carta).

Ogni azione che fa marciare o combattere fa anche [b]mangiare[/b] l'armata: tenete d'occhio le provviste sulla scheda."""],
	],
	"assedia": [
		["Assedio o aggiramento", """Marciando su un [b]Caposaldo nemico[/b] potete [b]assediarlo[/b] (vi fermate e cominciano i segnalini Assedio) oppure [b]aggirarlo[/b] e proseguire.

Nell'assedio, ogni carta il Caposaldo deve tirare per la [b]Resa[/b]: un dado per ogni punto di valore, e si arrende solo se [b]tutti[/b] i dadi sono pari o inferiori ai segnalini Assedio (più uno se la località è devastata). Se la Resa fallisce i segnalini crescono, ma [b]solo se ci sono tanti Signori quanto il valore[/b] del Caposaldo (o i Genieri di Guerra).

Una Resa vale Punti Vittoria, fa tirare per le Rivolte vicine e dà [b]carte Tradimento[/b]."""],
	],
	"assalto": [
		["L'Assalto", """Invece di aspettare la Resa si può [b]assaltare[/b]: si combatte contro la Guarnigione e i Signori assediati, con tanti round quanti sono i segnalini Assedio (più due con i Guastatori).

[b]Vantaggi[/b] (dai resoconti di Christophe Correia): il [b]Saccheggio[/b] dà subito Monete, Bottino e Provviste pari al valore della località, e la lascia in [b]rovina[/b]: non potrà più ribellarsi.
[b]Svantaggi[/b]: le perdite sono pesanti (gli attaccanti in rotta si salvano solo con un 1), la rovina dà mezzo punto all'avversario, e nell'Assalto ogni Signore fa al massimo 6 colpi in mischia.

Volko Ruhnke ha assaltato Cortona perché Arezzo era senza provviste: il Saccheggio era l'unico modo di sfamare l'armata. Più preparate l'assalto (segnalini Assedio, Guastatori, Torri), meno perdite avrete."""],
	],
	"avvicinamento": [
		["Arriva il nemico", """Un'armata nemica marcia sulla vostra località. Potete:
- [b]combattere[/b] in campo aperto;
- [b]ritirarvi dentro[/b] le mura di un Caposaldo amico (al massimo tanti Signori quanto il suo valore): niente battaglia, ma il nemico può assediarvi;
- [b]evitare[/b] la battaglia spostandovi in una località vicina libera.

Combattere accanto a un Caposaldo amico è poco rischioso: chi perde può ritirarsi dentro. Se la battaglia è persa in partenza, evitatela: un'armata intera vale più di una località."""],
	],
	"battaglia": [
		["La battaglia: lo schieramento", """Si apre la [b]mini mappa[/b] del luogo dello scontro, divisa come la plancia di battaglia: l'[b]attaccante[/b] a sinistra, il [b]difensore[/b] a destra con la sua località alle spalle.

Ogni parte ha un [b]Fronte[/b] di tre settori, [b]ala sinistra, centro, ala destra[/b], e dietro la [b]Riserva[/b]. Il Signore che attacca sta al centro; gli altri attaccanti vanno sulle ali o restano in Riserva. Poi il difensore mette un suo Signore davanti a ogni attaccante. Quando una posizione si svuota, chi è in Riserva avanza; un centro vuoto si riempie da un'ala.

Un Signore che non ha nessuno davanti [b]aggira sul Fianco[/b]: colpisce il nemico più vicino, sommando i suoi colpi a quelli di chi gli sta davanti."""],
		["La battaglia: i round", """Ogni round si combatte in quest'ordine, prima il difensore e poi l'attaccante:
1. [b]Tiro[/b]: arcieri e balestrieri (Milizia, Armigeri…).
2. [b]Cavalleria[/b]: Ritter, Cavalieri, Berrovieri, Cavalleria leggera.
3. [b]Fanteria[/b]: Uomini in Armi, Armigeri, Milizia, Villici.

Ogni colpo si para con un dado: le unità con [b]Corazza[/b] si salvano con 1-4 (Ritter), 1-3 (Cavalieri, Uomini in Armi) o 1-2 (Berrovieri, Armigeri; 1-4 con i Palvesari); le altre solo con un 1; i Villici cadono senza tiro. I [b]Balestrieri[/b] tolgono 2 alla Corazza. Chi subisce i colpi sceglie quale unità li prende (con i Balestrieri sceglie chi tira).

A inizio round ciascuno può decidere di [b]lasciare il campo[/b]: i suoi colpi di quel round valgono la metà, ma salva carri e provviste."""],
		["Dopo la battaglia", """Chi perde [b]si ritira[/b] in una località vicina, perde una parte del [b]Servizio[/b] e lascia al vincitore il [b]bottino[/b]. Le unità in rotta tornano in parte (dado per dado); i Cavalieri e i Ritter possono essere [b]catturati[/b] e andranno riscattati a fine campagna.

[b]Consigli[/b]: combattete in superiorità (le cifre accanto ai nomi sono le unità); mettete al centro il Signore più forte; i Feditori e la Riserva d'Armata cambiano le battaglie; se la battaglia è persa, lasciate il campo presto per salvare le salmerie."""],
	],
	"assalto_battaglia": [
		["L'Assalto sulla mini mappa", """Nell'[b]Assalto[/b] il difensore sta sulle [b]mura[/b]: la [b]Guarnigione[/b] della località e i Signori al Fronte combattono dal camminamento. Prima di ogni colpo contro di loro si tira per le [b]mura[/b]: con 1-4 il colpo è fermato (1-5 con le mura riparate, uno in meno se gli assedianti hanno i Trabucchi); gli attaccanti sono protetti allo stesso modo dalle loro [b]opere d'assedio[/b].

Si comincia con un solo Signore per parte al Fronte e se ne aggiunge uno a ogni round. I difensori combattono in mischia per primi (gli attaccanti con le Torri d'Assedio, dal secondo round). Gli attaccanti mettono avanti le unità corazzate. L'Assalto dura tanti round quanti sono i segnalini Assedio: se la Guarnigione non cade, l'assedio continua."""],
	],
	"colpo": [
		["Chi subisce il colpo", """Tocca a voi decidere quale unità prende il colpo. In genere conviene farlo prendere a un'unità [b]corazzata[/b] (che ha buone probabilità di salvarsi) e tenere al riparo la cavalleria migliore. Un'unità può prendere più colpi di fila finché si salva.

Potete anche toccare una miniatura di quel tipo sulla mini mappa, oppure scegliere «[b]Decidi tu fino alla fine della battaglia[/b]»: il gioco sceglie per voi con la stessa regola."""],
	],
	"lascia": [
		["Lasciare il campo?", """Prima di ogni round si può [b]lasciare il campo[/b]: in quel round i vostri colpi contano la metà, poi la battaglia finisce con la vostra ritirata, ma salvate carri, provviste e monete e le truppe in rotta si salvano più facilmente. Christophe Correia consiglia di farlo quando si sta perdendo nettamente, [b]non troppo presto[/b]."""],
	],
	"schiera": [
		["Schierare i Signori", """Scegliete dove mettere i vostri Signori: il più forte al centro, chi deve affrontare il nemico più pericoloso davanti a lui. Chi resta in Riserva entrerà quando una posizione del Fronte si svuota. Potete toccare i reparti evidenziati sulla mini mappa."""],
	],
	"tradimento": [
		["Tradimento e Rivolte", """Una carta [b]Tradimento[/b] nel piano permette al suo Signore di tentare la [b]Rivolta[/b] di un Caposaldo nemico vicino (o di corrompere un Vassallo nemico). Si impegnano delle [b]Monete[/b]: si tira un dado per ogni punto di valore del Caposaldo, e la Rivolta riesce se [b]tutti[/b] i dadi sono pari o inferiori alle Monete impegnate. Con 3 Monete un castello passa una volta su due, una cittadina una volta su quattro.

Le carte Tradimento si guadagnano con le Rese, i Saccheggi, alcuni Eventi e quando un Signore nemico smobilita oltre il Servizio. Si può [b]bloccare[/b] il Tradimento nemico tenendo un Signore vicino ai propri Capisaldi o radunando nelle città minacciate."""],
	],
	"rivolta": [
		["Le Rivolte", """Dopo una Resa o un Saccheggio si tira sulle tabelle delle [b]Rivolte[/b]: un Caposaldo nemico può passare dalla vostra parte. Può farlo solo se non ha Signori nemici dentro o accanto. Le Rivolte si propagano: più segnalini Alleanza avete nel territorio nemico, più i Capisaldi vicini sono a rischio. Ricordate: un'armata amica accanto a un Caposaldo lo protegge."""],
	],
	"campagna": [
		["La Campagna comincia", """I piani sono pronti. Le carte si scoprono una alla volta, alternandosi: guardate il [b]diario[/b] in basso a destra per seguire tutto quello che fa l'avversario. Quando esce una carta vostra, i pulsanti in basso mostrano le azioni possibili e le località cerchiate sulla mappa si possono toccare."""],
	],
	"turno2": [
		["Fine della prima campagna", """Alla fine di ogni campagna ogni armata [b]mangia[/b] e si [b]paga[/b]: chi non ha provviste o monete perde Servizio. Poi le campagne si riprendono un po' (in primavera metà delle devastazioni sparisce), si riscattano i prigionieri e i Signori al termine del Servizio tornano a casa.

Ora siamo al [b]secondo e ultimo turno[/b]: dalla Leva arrivano Eventi invece di Capacità. Guardate i Punti Vittoria nei pannelli laterali: se siete in vantaggio difendete quello che avete, se siete indietro è il momento di rischiare (un Tradimento, un Assalto, una devastazione in più)."""],
	],
	"fine": [
		["Fine della partita guidata", """Avete giocato una partita intera di Inferno: Leva, Piano, Campagna, assedi e (forse) battaglie. Il risultato è nel riquadro finale.

Da qui potete:
- giocare lo scenario A di nuovo, con i Ghibellini o contro l'IA normale;
- provare la [b]battaglia guidata[/b] dal menu, per vedere con calma schieramento, round e Assalto;
- leggere il manuale [b]Strategie[/b] (dal menu principale o dal menu in partita);
- passare agli scenari brevi C, D ed E, e poi alla campagna completa F.

Buona guerra, e che non sia un [i]Inferno[/i]."""],
	],
	"intro_battaglia": [
		["La battaglia guidata", """In questa lezione comandate i Guelfi in due scontri preparati: prima una [b]battaglia campale[/b] contro un'armata ghibellina, poi l'[b]Assalto[/b] a un castello ghibellino assediato.

Fate voi tutte le scelte: chi va sulle ali e chi resta in Riserva, chi subisce i colpi, quando lasciare il campo. Il riquadro [b]Consiglio del tutor[/b] propone ogni volta la scelta migliore e il perché.

La mini mappa si muove come la mappa: trascinate, pizzicate, ruotate; «Vista iniziale» la rimette com'era."""],
	],
	"fine_battaglia": [
		["Fine della battaglia guidata", """Avete visto schieramento, round, colpi, aggiramento e Assalto. Nelle partite vere le battaglie nascono dal [b]Piano[/b]: le cerca chi è più forte, le evita chi è più debole. Provate ora la [b]campagna guidata[/b] o leggete il manuale [b]Strategie[/b]."""],
	],
}


# ================================================================ manuale di strategia

const STRATEGIE := [
	["Strategie: il tempo", """In Inferno, come in tutta la serie Leva e Campagna, la risorsa più scarsa è il [b]tempo[/b]: il Servizio dei Signori, le provviste nei carri, le Monete per pagare. Un'armata che non mangia perde Servizio; un Signore che smobilita oltre il Servizio regala al nemico Rivolte e Tradimenti.

Prima di ogni campagna chiedetevi: dove sarà ogni Signore alla fine? Avrà da mangiare? Potrà tornare in una località amica per la Leva del turno dopo?

[i]Questi consigli vengono dai resoconti di partita di Volko Ruhnke («Cavallata per Cortona», InsideGMT) e di Christophe Correia (InsideGMT e The Boardgames Chronicle), e dal regolamento.[/i]"""],
	["Strategie: la Leva", """- [b]Radunate per il piano[/b]: Guastatori, Genieri e Torri se volete assediare; Feditori, Balestrieri e Palvesari se cercate la battaglia; carri se marcerete lontano.
- [b]Balestrieri e Armigeri[/b] insieme sono la fanteria migliore; i Palvesari li proteggono.
- Ogni Signore tiene al massimo [b]due Capacità «Questo Signore»[/b]: pensateci prima di assegnarle.
- [b]Radunare in una città[/b] la protegge dal Tradimento nemico (i Guelfi radunano a Colle per difendere San Gimignano).
- Un [b]Podestà[/b] nella sua Sede può radunare anche sotto assedio: è un'armata d'emergenza. Tenetelo dentro le mura se il nemico è più forte."""],
	["Strategie: il Piano e la logistica", """- [b]Un obiettivo per campagna[/b], e le forze concentrate per raggiungerlo. Le armate separate sono vulnerabili.
- [b]Rifornitevi prima di partire[/b]: una Sede dà tante provviste quanto il suo valore. In Toscana le strade sono buone: la prima marcia senza carico è gratis.
- I [b]Podestà tassano il doppio[/b] (2 Monete) e le possono passare agli altri Signori: un Podestà che tassa mentre l'esercito marcia finanzia la guerra.
- D'inverno le carte sono solo 4: pochi movimenti, buoni per tassare e tenere gli assedi.
- Le [b]ultime carte[/b] del piano riportano i Signori in località amiche, dove potranno fare la Leva."""],
	["Strategie: assedio o assalto", """[b]Assedio[/b]: lento, ma senza perdite. La Resa vale più Punti Vittoria e dà Rivolte e carte Tradimento. Servono tanti Signori quanto il valore del Caposaldo perché le opere crescano. [b]Devastate[/b] attorno all'assedio: ogni devastazione conta come un segnalino in più per la Resa.

[b]Assalto[/b]: veloce e sanguinoso. Il Saccheggio dà Monete, Bottino e Provviste e lascia la località in rovina (non si ribellerà più, ma dà mezzo punto all'avversario). Preparatelo: più segnalini Assedio, Guastatori (due round in più), Torri d'Assedio (si colpisce per primi). Assaltate quando l'armata non ha più da mangiare e il Saccheggio è l'unico modo di nutrirla.

La [b]Sorpresa[/b] permette un assalto immediato, ma due round possono non bastare contro la Guarnigione."""],
	["Strategie: la battaglia", """- Davanti a un'armata più forte: [b]ritiratevi dentro[/b] un Caposaldo amico o [b]evitate[/b] la battaglia. Accanto a un Caposaldo amico combattere costa poco: chi perde rientra.
- Il [b]Signore più forte al centro[/b]; sulle ali chi può reggere. Un Signore senza nessuno davanti aggira e colpisce il nemico più vicino.
- I [b]Balestrieri[/b] tolgono 2 alla Corazza: contro i Ritter sono preziosi.
- [b]Lasciate il campo[/b] quando state perdendo nettamente, non prima: salvate le salmerie.
- La [b]palude[/b] impedisce alla cavalleria di colpire nel primo round.
- I Cavalieri e i Ritter catturati vanno riscattati, altrimenti il nemico guadagna Rivolte o Tradimenti."""],
	["Strategie: Tradimento e Rivolte", """- La Rivolta riesce se [b]tutti[/b] i dadi (uno per punto di valore) sono pari o inferiori alle Monete: con 3 Monete un castello passa il 50% delle volte, una cittadina il 25%. Con poche Monete è un azzardo.
- Le carte Tradimento sono rare: arrivano da Rese, Saccheggi, Eventi e Podestà nemici smobilitati oltre il Servizio. Giocatele quando la Rivolta è possibile e le Monete bastano.
- Un'armata nemica accanto a un Caposaldo [b]lo protegge[/b] dalla Rivolta: parcheggiate un Signore vicino ai Capisaldi a rischio.
- Le Rivolte si propagano: segnalini Alleanza e armate nel territorio nemico rendono più probabili le ribellioni vicine. Un Saccheggio (rovina) ferma la propagazione."""],
	["Strategie: i Punti Vittoria", """- I Capisaldi passati alla vostra parte nel territorio nemico valgono 1 punto per segnalino; le devastazioni e le rovine mezzo punto; il Carroccio nemico catturato 2.
- [b]In vantaggio[/b], difendete: tornate verso casa, bloccate le incursioni e le Rivolte. [b]Indietro[/b], rischiate: un Assalto, un Tradimento audace.
- Chi è indietro di 4 punti o più può dichiarare la [b]Guerra[/b] e fare la Chiamata alle Armi: il Comune scende in campo con il Carroccio.
- Nella campagna completa, dal turno 9 il tiro di Esaurimento può accorciare la partita: non contate sull'ultimo turno.
- All'ultima carta, una devastazione è mezzo punto: spesso decide la partita."""],
	["Strategie: Guelfi e Ghibellini", """[b]Guelfi[/b]: Firenze è la città più ricca e popolosa, con un Comune enorme; Lucca, Arezzo e Colle tengono i fianchi. Il pericolo viene dal sud (Siena) e dalle ribellioni nel proprio territorio: tenete un'armata pronta a correre dove scoppia una Rivolta.

[b]Ghibellini[/b]: meno numerosi, ma con i [b]Ritter[/b] tedeschi di Manfredi (Giordano, Astimberg), la cavalleria più forte del gioco, e con Pisa sul mare. Cercano la battaglia decisiva (come a Montaperti, settembre 1260) e i Tradimenti nelle città guelfe divise.

Per entrambi: le città ribelli nel proprio territorio valgono punti all'avversario finché non tornano all'ovile. Riprenderle è spesso la prima mossa."""],
]


# ================================================================ quando mostrare le lezioni

## Le lezioni da mostrare per una decisione (non ancora viste).
static func chiavi_decisione(e, req: Dictionary, viste: Dictionary, modo: String) -> Array:
	var out := []
	if modo == "campagna" and not viste.has("intro"):
		out.append("intro")
	if modo == "battaglia" and not viste.has("intro_battaglia"):
		out.append("intro_battaglia")
	var k: String = req.get("k", req.get("type", ""))
	match k:
		"cap_a_chi", "raduno", "raduno_chi", "scarta_cap":
			out.append("leva")
		"sede":
			out.append("sede")
		"paga":
			out.append("paga")
		"evento", "ev_scelta":
			out.append("evento")
		"azione":
			out.append("azione")
			if req.has("opzioni"):
				for o in req["opzioni"]:
					if str(o["id"]) == "assalto":
						out.append("assalto")
		"assedia":
			out.append("assedia")
		"avvicinamento":
			out.append("avvicinamento")
		"schiera", "avanza", "al_centro", "aggiungi", "fianco", "assorbe":
			out.append("schiera")
		"colpo":
			out.append("colpo")
		"lascia":
			out.append("lascia")
		"tradimento_az", "tradimento":
			out.append("tradimento")
		"rivolta_x", "rivolta_vicina":
			out.append("rivolta")
	if req.get("type", "") == "piano":
		out.append("piano")
	var res := []
	for x in out:
		if LEZIONI.has(x) and not viste.has(x) and not x in res:
			res.append(x)
	return res


## Le lezioni legate a ciò che succede in partita (inizio della campagna, battaglie, nuovo turno).
static func chiavi_fx(e, kind: String, d: Dictionary, viste: Dictionary) -> Array:
	var out := []
	match kind:
		"campagna":
			out.append("campagna")
		"turno":
			if int(d.get("turno", 0)) == 2:
				out.append("turno2")
		"battaglia_inizio":
			out.append("battaglia")
			if d.get("tipo", "") == "assalto":
				out.append("assalto_battaglia")
	var res := []
	for x in out:
		if LEZIONI.has(x) and not viste.has(x):
			res.append(x)
	return res


# ================================================================ consiglio del tutor

## [titolo, perché] per la scelta r che il tutor propone per la decisione req.
static func consiglio(e, s: int, req: Dictionary, r) -> Array:
	if req.get("type", "") == "piano":
		var nomi := []
		for c in r:
			var cs := str(c)
			if cs.begins_with("passa"):
				nomi.append("Passare")
			else:
				for x in req["carte"]:
					if x["id"] == cs:
						nomi.append(("Tradimento di " if x["t"] == "trad" else "") + e.nome(x["l"]))
		return ["Piano: " + ", ".join(nomi), "Prima i Signori più importanti e chi deve muoversi per primo; le carte Tradimento solo se c'è una Rivolta possibile con abbastanza Monete; le Passare alla fine."]
	var o: Array = req.get("opzioni", [])
	var testo := str(r)
	for x in o:
		if str(x["id"]) == str(r):
			testo = str(x["t"])
	var k: String = req.get("k", "")
	var id: String = str(req.get("sig", ""))
	var perche := ""
	match k:
		"azione":
			perche = _perche_azione(e, s, id, str(r))
		"avvicinamento":
			var l: String = e.L[id]["loc"] if e.L.has(id) else ""
			var mia: float = e.forza_gruppo(e.fuori_in(l, s)) if l != "" else 0.0
			var loro: float = e.forza_gruppo(e.fuori_in(l, 1 - s)) if l != "" else 0.0
			if str(r) == "combatti":
				perche = "Le vostre forze (%.0f) reggono il confronto con quelle nemiche (%.0f)." % [mia, loro]
			elif str(r) == "_dentro":
				perche = "Il nemico è più forte (%.0f contro %.0f): dentro le mura non c'è battaglia e il nemico dovrà assediarvi." % [loro, mia]
			else:
				perche = "Il nemico è più forte (%.0f contro %.0f): meglio salvare l'armata in una località vicina." % [loro, mia]
		"assedia":
			perche = "Assediare conviene quando ci sono abbastanza Signori per far crescere le opere (tanti quanto il valore del Caposaldo) e nessuna armata nemica più forte dentro; altrimenti si aggira."
		"lascia":
			perche = "Si lascia il campo solo quando si sta perdendo nettamente: le forze in campo dicono %s." % ("di sì" if str(r) == "si" else "di restare")
		"paga":
			perche = "Si paga il Servizio di chi sta per smobilitare e serve ancora, prima di tutto i Podestà (smobilitati oltre il Servizio danno al nemico 3 Rivolte e 3 Tradimenti)." if str(r) != "fine" else "Nessuno rischia di smobilitare: meglio tenere le Monete per i Tradimenti e la prossima paga."
		"raduno", "raduno_chi":
			perche = "Le truppe e le Capacità che servono al piano (assedio di Cortona, battaglia) valgono più di tutto; un Signore in più se la parte ha pochi Signori in campo."
		"cap_a_chi":
			perche = "La Capacità va al Signore con l'armata più forte, che la userà di più."
		"tradimento_az":
			perche = "Si tenta la Rivolta quando la probabilità (tutti i dadi sotto le Monete impegnate) vale il rischio; un castello (1 dado) è il bersaglio più facile."
		"schiera", "avanza", "aggiungi":
			perche = "Il Signore più forte va dove serve di più: al centro, o davanti al nemico più pericoloso."
		"al_centro":
			perche = "Il centro non deve restare vuoto: ci va il Signore più forte delle ali."
		"fianco":
			perche = "Conviene aggirare l'ala nemica più debole: con i colpi sommati la si manda in rotta prima."
		"assorbe":
			perche = "I colpi li prende il Signore con le unità meglio corazzate, che ha più probabilità di salvarle."
		"colpo":
			perche = "L'unità con la Corazza migliore ha le maggiori probabilità di salvarsi; i Villici e le unità senza Corazza si sacrificano solo quando non c'è altro."
		"sede":
			perche = "La Sede più vicina all'azione: le prime carte non andranno sprecate in marce."
		"evento":
			perche = "L'Evento conviene ora, quando il suo effetto serve davvero."
	return ["Il tutor sceglierebbe: " + testo, perche]


static func _perche_azione(e, s: int, id: String, r: String) -> String:
	if not e.L.has(id):
		return ""
	var need: int = e._fabbisogno(id)
	var cibo: int = e.supp(id, "prov") + e.supp(id, "bottino")
	if r.begins_with("marcia"):
		return "Avvicina l'armata al suo obiettivo (un Caposaldo nemico alla portata o un'armata più debole), senza finire accanto a un nemico più forte%s." % (", e tutti insieme si è più forti" if r.begins_with("marcia_tutti") else "")
	if r.begins_with("rifornisci"):
		return "L'armata ha %d provviste e ne mangia %d per azione di marcia o di assedio: senza cibo il Servizio si accorcia." % [cibo, need]
	if r == "foraggia":
		return "Mancano provviste (%d, ne servono %d) e non c'è una Sede vicina: si cerca cibo nella campagna." % [cibo, need]
	if r == "tassa":
		return "Le Monete pagano il Servizio e i Tradimenti; %s" % ("un Podestà incassa 2 Monete per Tassa." if e.podesta(id) else "un Signore ne incassa 1.")
	if r == "assedio":
		return "La Resa riesce se tutti i dadi (uno per punto di valore) sono pari o inferiori ai segnalini Assedio: ogni carta di assedio avvicina la Resa."
	if r == "assalto":
		return "Le opere d'assedio sono pronte e l'armata è abbastanza forte: il Saccheggio dà subito Monete, Bottino e Provviste."
	if r == "devasta":
		return "Mezzo Punto Vittoria, provviste per l'armata e, attorno a un assedio, un segnalino in più per la Resa."
	if r == "passa":
		return "Nessuna azione utile in questo momento: meglio non consumare provviste."
	if r == "accampa":
		return "Fermarsi qui comincia l'assedio del Caposaldo."
	return ""


## Il manuale di strategia tutto in un testo (per la pagina di pergamena).
static func strategie_bbcode() -> String:
	var out := []
	for p in STRATEGIE:
		out.append("[font_size=30][color=#f7d77a]%s[/color][/font_size]\n%s" % [_maiuscola(str(p[0]).replace("Strategie: ", "")), p[1]])
	return "\n\n".join(out)


static func _maiuscola(t: String) -> String:
	return t.substr(0, 1).to_upper() + t.substr(1)
