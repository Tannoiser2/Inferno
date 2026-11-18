extends Control
## Regole in breve (dal regolamento italiano) e guida all'interfaccia.

var main
## Titolo e testo da mostrare (vuoti = le regole in breve; il manuale «Strategie» usa la stessa pagina).
var titolo := ""
var testo := ""

const TESTO := """[font_size=30][color=#f7d77a]Lo scopo[/color][/font_size]
Guelfi (porpora, con Firenze) e Ghibellini (oro, con Siena) si contendono la Toscana fra il 1259 e il 1261. Si vince con più [b]Punti Vittoria[/b] alla fine dello scenario: 1 PV per ogni segnalino Alleanza conquistato, 1/2 PV per ogni Rovina e ogni Devastazione, 2 PV per il Carroccio nemico catturato. Chi resta senza Signori sulla mappa durante una Campagna perde subito.

[font_size=30][color=#f7d77a]Il turno (60 giorni)[/color][/font_size]
Ogni turno ha una [b]Leva[/b] (preparazione) e una [b]Campagna[/b] (operazioni). Il calendario in alto mostra i turni, la stagione, i cilindri dei Signori pronti al raduno (cerchi) e fin quando servono quelli in campo (scudi). I Guelfi agiscono sempre per primi.

[font_size=30][color=#f7d77a]La Leva[/color][/font_size]
[b]Arte della Guerra.[/b] Alla prima Leva ogni parte pesca 2 Capacità; poi, a ogni Leva, 2 Eventi. Gli eventi «Tenere» restano nascosti finché non li giochi; le Capacità «Questo Signore» stanno sotto la scheda di un Signore (al massimo 2).
[b]Paga.[/b] Ogni Moneta (o Bottino in una località amica non assediata) allunga di un turno il Servizio di un Signore nella stessa località; un Podestà costa il doppio.
[b]Smobilitazione.[/b] Chi è arrivato al limite del Servizio torna al calendario; chi l'ha superato è rimosso (un Podestà tornerà più avanti) e il nemico tira sulla Rivolta e prende carte Tradimento.
[b]Raduno.[/b] Ogni Signore in una località amica spende la sua Signoria: tirare la Fedeltà per chiamare un altro Signore pronto, radunare i Vassalli (la loro Sede dev'essere amica), aggiungere Carri (Pisa anche Navi) o prendere Capacità.
[b]Chiamata alle Armi.[/b] Se una parte è indietro di 4 PV o ha pescato un evento Guerra: i Signori si riuniscono verso la Città guida, il Comandante può tornare a casa e radunare il [b]Comune[/b] con il Carroccio e i Sestieri (Firenze) o i Terzi (Siena), poi arriva un alleato.

[font_size=30][color=#f7d77a]La Campagna[/color][/font_size]
Ogni parte compone un [b]piano[/b] di carte Comando (7 in primavera e autunno, 6 d'estate, 4 d'inverno). Le carte si girano a turno: la carta di un Signore gli dà tante azioni quanto il suo Comando.
[b]Marcia:[/b] 1 azione per una località adiacente, 2 se Carico (Bottino, o più Provviste che Carri su un Sentiero); la prima marcia per Strada senza carico è gratis. Chi entra dove c'è un'armata nemica la costringe a combattere, a ritirarsi nel suo Caposaldo o a evitare la battaglia.
[b]Assedio o Aggiramento:[/b] arrivando a un Caposaldo nemico si assedia (fine della carta) o lo si aggira e si continua. Un'azione Assedio (tutta la carta) tira per la Resa se dentro non c'è nessuno (tutti i dadi, uno per valore del Caposaldo, devono stare entro i segnalini Assedio, +1 se devastato) e altrimenti aggiunge opere d'assedio.
[b]Assalto:[/b] attacco al Caposaldo assediato, per tanti round quanti i segnalini Assedio. Se vince l'attaccante il Caposaldo è saccheggiato e diventa una Rovina.
[b]Rifornimento:[/b] Provviste dalle proprie Sedi, servono Carri per ogni via percorsa. [b]Foraggiare:[/b] 1 Provvista (d'estate sicura, in primavera e autunno con 1-3, mai d'inverno fuori dai Capisaldi amici). [b]Devastare:[/b] mezzo PV e Provviste (e Bottino nelle città). [b]Tassare:[/b] in una propria Sede, tutta la carta, 1 Moneta (2 un Podestà). [b]Per mare:[/b] Pisa da porto a porto.
[b]Tradimento:[/b] la carta Tradimento di un Signore permette di comprare la Rivolta di un Caposaldo nemico vicino (Monete contro dadi) o di corrompere un Vassallo nemico.
Dopo ogni carta, chi ha mosso o combattuto [b]mangia[/b]: 1 Provvista o Bottino ogni 6 unità (massimo 3). Chi non mangia perde un turno di Servizio.

[font_size=30][color=#f7d77a]La battaglia[/color][/font_size]
Fino a tre Signori per parte al fronte (sinistra, centro, destra), gli altri in riserva. In ogni round colpiscono prima gli arcieri (difensori, poi attaccanti), poi la cavalleria e infine la fanteria. I colpi sono automatici; ogni colpo si para con la protezione dell'unità (Ritter 1-4, Cavalieri e Uomini in Armi 1-3, Armigeri 1-2, le altre 1): se fallisce l'unità va in rotta. All'inizio di ogni round una parte può [b]lasciare il campo[/b]: perde, ma il nemico la insegue con metà dei colpi e le perdite sono minori. Alla fine le unità in rotta tirano per salvarsi; i cavalieri persi possono essere catturati e riscattati con le Monete.
Nell'[b]Assalto[/b] i difensori hanno le mura (1-4) e la guarnigione, gli attaccanti le opere d'assedio.

[font_size=30][color=#f7d77a]Rivolta[/color][/font_size]
Quando un Signore nemico è rimosso o un suo Caposaldo cade, si tira sulla tabella della Rivolta: un Caposaldo nemico vicino ai tuoi Signori o ai tuoi segnalini può passare dalla tua parte.

[font_size=30][color=#f7d77a]L'interfaccia[/color][/font_size]
In basso compaiono le scelte: si toccano i pulsanti oppure le località evidenziate sulla mappa. Toccando un Signore (sulla mappa o nella colonna della sua parte) si apre la sua scheda con forze, supporti, vassalli e capacità. «Carte» mostra le capacità in gioco e i tuoi eventi tenuti. La mappa si sposta trascinando, si ingrandisce con la rotella o pizzicando con due dita e si ruota con due dita; «2D / 3D» passa alla vista con le città e le armate modellate. «Menu» per salvare la partita (codice di 6 lettere) e per la velocità dell'IA.
"""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pc := UI.Pergamena.new()
	pc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pc.offset_left = 60
	pc.offset_right = -60
	pc.offset_top = 40
	pc.offset_bottom = -40
	add_child(pc)
	var vb := VBoxContainer.new()
	pc.add_child(vb)
	var top := HBoxContainer.new()
	var t := UI.label(titolo if titolo != "" else "Inferno — le regole in breve", 54, UI.INK, UI.font_title)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	var b := UI.primary(UI.button("Torna al menu", 300, 60, 24))
	b.pressed.connect(func(): main.show_menu())
	top.add_child(b)
	vb.add_child(top)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_color_override("default_color", UI.INK)
	r.add_theme_font_size_override("normal_font_size", 23)
	r.add_theme_font_size_override("bold_font_size", 23)
	r.text = (testo if testo != "" else TESTO).replace("#f7d77a", "#8a2a10")
	sc.add_child(r)
