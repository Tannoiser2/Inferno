# Inferno — Guelfi e Ghibellini si contendono la Toscana, 1259-1261

Versione digitale, per uso personale della ludoteca, di **Inferno** (GMT Games, Enrico Acerbi e Volko Ruhnke),
terzo volume della serie *Leva e Campagna*. Firenze guelfa contro Siena ghibellina, fino a Montaperti e oltre.

Si gioca nel browser: https://tannoiser2.github.io/inferno/ (e dalla ludoteca https://tannoiser2.github.io).

## Che cosa c'è

- **Tutti e sei gli scenari** (A *Dolenti note* … F *Di sangue t'empio*, la campagna completa di 16 turni).
- **Leva**: Arte della Guerra (Capacità ed Eventi), Paga, Smobilitazione, Raduno di Signori e Vassalli,
  Chiamata alle armi dei Comuni con il Carroccio.
- **Campagna**: piano segreto con le carte Comando e le carte Passare, marce su strade e sentieri,
  avvicinamento e battaglie campali, assedi, assalti, sortite, aggiramento, rifornimento, foraggiamento,
  devastazione, Cavallata, tasse, mura, movimento per mare, carte Tradimento, rivolte.
- **Fine della campagna**: crescita, riscatto dei cavalieri catturati, riparazioni, Punti Vittoria.
- **Carte e regole in italiano**: le 52 carte Arte della Guerra, le carte Comando, le schede dei Signori
  e i segnalini vengono dal materiale italiano; la mappa originale ha le scritte tradotte.
- **Mappa 2D** (la mappa originale) e **Toscana in 3D** con città, castelli, mura e armate modellate;
  si passa dall'una all'altra in ogni momento. Pan, zoom e rotazione anche al tocco su iPad
  (un dito per spostare, due per pizzicare e ruotare).
- **Battaglie in 3D**: si apre una mini mappa del luogo dello scontro con le miniature delle armate, che entrano in campo,
  tirano frecce e quadrelli, caricano e cadono in rotta; nell'Assalto ci sono la fortezza, le mura e la Guarnigione.
  Le miniature definitive vanno in `assets/miniature/` (vedi `assets/miniature/LEGGIMI.txt`).
- **Avversario IA** in tre livelli (facile, normale, esperta) per una o entrambe le fazioni.
- **Due persone sullo stesso dispositivo**: le scelte segrete si fanno passandosi il dispositivo.
- **Online** con un amico (stanza con codice di 4 lettere) e **partite salvate** su Firebase
  (codice di 6 lettere, si riprendono da qualsiasi dispositivo).

### Semplificazioni rispetto al gioco da tavolo

- Niente Luogotenenti e niente regole avanzate di servizio dei Vassalli.
- L'assegnazione dei colpi e lo schieramento in battaglia sono automatici (secondo le priorità del regolamento).
- La regola speciale dello scenario C sulla resa di Grosseto non è implementata.

## Struttura

| Cartella | Contenuto |
|---|---|
| `scripts/data/inf_data.gd` | Dati del gioco: località, vie, Signori, Vassalli, calendario, carte, scenari |
| `scripts/core/` | Motore delle regole (`stato.gd` → `battaglia.gd` → `engine.gd`) e IA (`ai.gd`) |
| `scripts/net/` | Firebase (REST) per online e salvataggi, radice `inferno/` |
| `scripts/ui/` | Menu, tavolo di gioco, mappe 2D e 3D, regole |
| `assets/` | Mappa, carte, schede, stemmi, segnalini, caratteri (OFL) |
| `tools/` | Estrazione del materiale dal mod TTS e dai PDF, controllo dei glifi, pubblicazione |
| `tests/` | Partite automatiche, schermate, prova online e salvataggio |
| `ludoteca/` | Scheda e copertina per la ludoteca |

## Prove

```
godot --headless --path . -s tests/sim.gd -- F 4 1          # 4 partite IA contro IA, scenario F
xvfb-run godot --path . -s tests/shot.gd -- /tmp/shots F 1366 1024 2d 12
python3 tests/firebase_mock.py &                            # finto Firebase per online e salvataggi
INF_DB_URL=http://127.0.0.1:8765/db INF_AUTH_URL=http://127.0.0.1:8765/signup \
INF_REFRESH_URL=http://127.0.0.1:8765/refresh godot --headless --path . -s tests/save_load.gd
python3 tools/controlla_glifi.py                            # ogni carattere usato esiste nei font
```

## Pubblicazione

Godot 4.7, rendering `gl_compatibility`, esportazione web. Il workflow *Pubblica* parte a mano
(Actions → Pubblica → Run workflow) oppure con un commit che nel messaggio contiene `[pubblica]`.

## Crediti

Gioco originale © GMT Games — design di Enrico Acerbi e Volko Ruhnke, grafica di Robert Altbauer e
Matthew Wallhead. Caratteri Grenze Gotisch, Almendra ed EB Garamond (SIL Open Font License).
Versione digitale amatoriale, non ufficiale, per uso personale.
