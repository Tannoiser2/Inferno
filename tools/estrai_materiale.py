#!/usr/bin/env python3
"""Prepara il materiale grafico di Inferno a partire dalle fonti di Stefano.

Uso: python3 tools/estrai_materiale.py <cartella Inferno> <cartella estratto_tts> .

- <cartella Inferno>: contiene «Carte Inferno.pdf» e «ITA_INFERNO_Rules.pdf» (carte e regolamento in italiano)
- <cartella estratto_tts>: immagini estratte dal modulo di Tabletop Simulator (file .ttsmod, che è uno zip)

Produce in assets/:
- mappa/mappa.jpg            la mappa della Toscana (senza il calendario, ridisegnato dal gioco), con le
                             scritte inglesi rifatte in italiano
- carte/G01..G26, H01..H26   le carte Arte della Guerra in italiano (G = guelfe, H = ghibelline) e i dorsi
- carte/cmd_*.png            le carte Comando, ricomposte in italiano (stemma, nome, valore di Comando)
- schede/<signore>.jpg       le schede dei Signori in italiano (dal regolamento)
- stemmi/<signore>.png       gli stemmi dei cilindri
- vassalli/<id>.png          i segnalini Servizio dei Signori e dei Vassalli
- segnalini/*.png            i segnalini del gioco con le scritte in italiano
"""
import os, sys, subprocess, tempfile, glob
from PIL import Image, ImageDraw, ImageFont, ImageFilter

Image.MAX_IMAGE_PIXELS = None
SRC, TTS, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
A = os.path.join(OUT, 'assets')
F = os.path.join(A, 'fonts')


def font(name, size):
    return ImageFont.truetype(os.path.join(F, name), size)


def pdf_pages(pdf, dpi, first=None, last=None):
    d = tempfile.mkdtemp()
    cmd = ['pdftoppm', '-r', str(dpi), '-png']
    if first:
        cmd += ['-f', str(first), '-l', str(last)]
    subprocess.run(cmd + [pdf, d + '/p'], check=True)
    return [Image.open(f).convert('RGB') for f in sorted(glob.glob(d + '/p-*.png'))]


def tts(nome):
    return Image.open(os.path.join(TTS, nome)).convert('RGBA')


# ------------------------------------------------------------------ carte Arte della Guerra
def carte():
    os.makedirs(A + '/carte', exist_ok=True)
    pages = pdf_pages(os.path.join(SRC, 'Carte Inferno.pdf'), 200)
    xs = [0.0445, 0.3497, 0.6545]
    ys = [0.0468, 0.3490, 0.6510]
    cw, ch = 0.3015, 0.3015
    fronts = {0: ('H', 1), 2: ('H', 10), 4: ('H', 19), 6: ('G', 1), 8: ('G', 10), 10: ('G', 19)}
    for pi, (side, start) in fronts.items():
        pg = pages[pi]
        W, H = pg.size
        k = 0
        for r in range(3):
            for c in range(3):
                n = start + k
                k += 1
                box = (int(xs[c] * W), int(ys[r] * H), int((xs[c] + cw) * W), int((ys[r] + ch) * H))
                im = pg.crop(box)
                im = _trim_card(im)
                if n > 26:
                    im = im.resize((380, 532), Image.LANCZOS)
                    d = ImageDraw.Draw(im)
                    col = im.getpixel((190, 14))
                    d.rectangle((14, 12, 366, 96), fill=im.getpixel((40, 110)))
                    _text_c(d, (190, 56), 'Arte della Guerra', font('GrenzeGotisch.ttf', 50), (30, 20, 15))
                    im.save(A + '/carte/dorso_%s.jpg' % side, quality=88)
                else:
                    im.resize((380, 532), Image.LANCZOS).save(A + '/carte/%s%02d.jpg' % (side, n), quality=88)


def _trim_card(im):
    # toglie il bianco attorno alla carta (angoli arrotondati)
    g = im.convert('L').point(lambda v: 0 if v > 245 else 255)
    bb = g.getbbox()
    return im.crop(bb) if bb else im


# ------------------------------------------------------------------ schede dei Signori
SCHEDE = {56: 'firenze_comune', 57: 'guido', 58: 'colle', 59: 'orvieto', 60: 'arezzo', 61: 'lucca',
          62: 'firenze', 63: 'siena_comune', 64: 'provenzano', 65: 'astimberg', 66: 'santa_fiora',
          67: 'giordano', 68: 'pisa', 69: 'siena'}


def schede():
    os.makedirs(A + '/schede', exist_ok=True)
    pages = pdf_pages(os.path.join(SRC, 'ITA_INFERNO_Rules.pdf'), 130, 56, 69)
    for i, pg in enumerate(pages):
        W, H = pg.size
        reg = pg.crop((0, int(H * 0.08), W, int(H * 0.9)))
        g = reg.convert('L').point(lambda v: 0 if v > 238 else 255)
        bb = g.getbbox()
        m = reg.crop(bb)
        m.thumbnail((900, 900), Image.LANCZOS)
        m.save(A + '/schede/%s.jpg' % SCHEDE[56 + i], quality=86)


# ------------------------------------------------------------------ stemmi e segnalini servizio
STEMMI = {'100_Siena': 'siena', '101_Siena_Comune': 'siena_comune', '102_Provenzano': 'provenzano',
          '103_Pisa': 'pisa', '104_Giordano': 'giordano', '105_Santa_Fiora': 'santa_fiora',
          '106_Astimberg': 'astimberg', '107_Firenze_Comune': 'firenze_comune', '108_Firenze': 'firenze',
          '109_Arezzo': 'arezzo', '110_Orvieto': 'orvieto', '111_Guido_Guerra': 'guido',
          '112_Colle': 'colle', '113_Lucca': 'lucca'}
SERVIZIO = {'114_Provenzano': 'provenzano', '118_Siena': 'siena', '121_Santa_Fiora': 'santa_fiora',
            '124_Giordano': 'giordano', '131_Pisa': 'pisa', '134_Astimberg': 'astimberg',
            '137_Firenze': 'firenze', '141_Colle': 'colle', '146_Arezzo': 'arezzo',
            '149_Guido_Guerra': 'guido', '160_Orvieto': 'orvieto', '163_Lucca': 'lucca'}
VASSALLI = {'115_Provenzano_vassal_-_Siena': 'guido_novello', '116_Provenzano_vassal_-_Siena': 'farinata',
            '117_Provenzano_vassal_-_San_Quirico': 'ubertini', '119_Siena_vassal_-_Siena': 'guastelloni',
            '120_Siena_vassal_-_Asinalunga': 'cacciaconti', '122_Santa_Fiora_vassal_-_Grosseto': 'grosseto',
            '123_Santa_Fiora_vassal_-_Santa_Fiora': 'casali', '125_Giordano_vassal_-_Massa_Marittima': 'massa',
            '126_Giordano_vassal_-_Siena': 'hohenstaufen', '127_Carrocio': 'carroccio_H',
            '128_Siena_Terzo': 'terzo_citta', '129_Siena_Terzo': 'terzo_camollia', '130_Siena_Terzo': 'terzo_martino',
            '132_Pisa_vassal_-_Pontedera': 'gherardo', '133_Pisa_vassal_-_Pisa': 'pisa_comune',
            '135_Astimberg_vassal_-_Siena': 'heinrich', '136_Astimberg_vassal_-_Siena': 'berchtold',
            '138_Firenze_vassal_-_Prato': 'prato', '139_Firenze_vassal_-_Firenze': 'cerchi',
            '140_Firenze_vassal_-_Firenze': 'adimari', '142_Colle_vassal_-_San_Miniato': 'san_miniato',
            '143_Colle_vassal_-_Colle': 'rosso', '144_Colle_vassal_-_Colle': 'incontri',
            '145_Colle_vassal_-_San_Gimignano': 'san_gimignano', '147_Arezzo_vassal_-_Arezzo': 'carlatti',
            '148_Arezzo_vassal_-_Montevarchi': 'montevarchi', '150_Guido_Guerra_vassal_-_Poppi_Lombardia_Bologna': 'bologna',
            '151_Guido_Guerra_vassal_-_Lombardia_Bologna': 'pistoia', '152_Guido_Guerra_vassal_-_Poppi_Lombardia_Bologna': 'lombardia',
            '153_Carrocio': 'carroccio_G', '154_Firenze_vassal_-_Sestiere': 'sest_1', '155_Firenze_vassal_-_Sestiere': 'sest_2',
            '156_Firenze_vassal_-_Sestiere': 'sest_3', '157_Firenze_vassal_-_Sestiere': 'sest_4',
            '158_Firenze_vassal_-_Sestiere': 'sest_5', '159_Firenze_vassal_-_Sestiere': 'sest_6',
            '161_Orvieto_vassal_-_Orvieto': 'rubini', '162_Orvieto_vassal_-_Orvieto': 'perugini',
            '164_Lucca_vassal_-_Lucca': 'obizzi', '165_Tau_Company_-_Altopascio': 'altopascio'}


def stemmi():
    for d in ('stemmi', 'vassalli'):
        os.makedirs(A + '/' + d, exist_ok=True)
    for k, v in STEMMI.items():
        im = tts(k + '.png')
        im.thumbnail((256, 256), Image.LANCZOS)
        im.save(A + '/stemmi/%s.png' % v)
    for k, v in SERVIZIO.items():
        im = tts(k + '.png')
        im.thumbnail((300, 150), Image.LANCZOS)
        im.save(A + '/vassalli/servizio_%s.png' % v)
    for k, v in VASSALLI.items():
        im = tts(k + '.png')
        im.thumbnail((300, 150), Image.LANCZOS)
        im.save(A + '/vassalli/%s.png' % v)
        # lo scudo del vassallo (in alto a destra del segnalino) per i pannelli
    # scudo dei signori: la parte sinistra del segnalino servizio
    for k, v in SERVIZIO.items():
        im = tts(k + '.png')
        W, H = im.size
        s = im.crop((int(W * 0.02), int(H * 0.08), int(W * 0.32), int(H * 0.92)))
        s = _shield_only(s)
        s.thumbnail((160, 200), Image.LANCZOS)
        s.save(A + '/stemmi/scudo_%s.png' % v)


def _shield_only(im):
    # rende trasparente lo sfondo uniforme del segnalino attorno allo scudo
    im = im.convert('RGBA')
    px = im.load()
    W, H = im.size
    bg = px[1, H // 2]
    from collections import deque
    seen = set()
    q = deque([(0, y) for y in range(H)] + [(W - 1, y) for y in range(H)] + [(x, 0) for x in range(W)] + [(x, H - 1) for x in range(W)])
    while q:
        x, y = q.popleft()
        if (x, y) in seen or not (0 <= x < W and 0 <= y < H):
            continue
        seen.add((x, y))
        c = px[x, y]
        if abs(c[0] - bg[0]) + abs(c[1] - bg[1]) + abs(c[2] - bg[2]) < 70:
            px[x, y] = (0, 0, 0, 0)
            q.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])
    bb = im.getbbox()
    return im.crop(bb) if bb else im


# ------------------------------------------------------------------ segnalini in italiano
def segnalini():
    os.makedirs(A + '/segnalini', exist_ok=True)
    fb = lambda s: font('Almendra-Bold.ttf', s)
    # (file, nuova scritta, zona dell'immagine da tenere (frazioni), colore testo, posizione testo)
    voci = [
        ('025_Custom_Token.png', 'bottino', 'Bottino'), ('026_Custom_Token.png', 'bottino3', 'Bottino'),
        ('027_Custom_Token.png', 'provviste', 'Provviste'), ('028_Custom_Token.png', 'provviste3', 'Provviste'),
        ('029_Custom_Token.png', 'carro', 'Carro'), ('030_Custom_Token.png', 'carro3', 'Carri'),
        ('031_Custom_Token.png', 'moneta', 'Moneta'), ('032_Custom_Token.png', 'moneta3', 'Monete'),
        ('033_Custom_Token.png', 'nave', 'Nave'), ('034_Custom_Token.png', 'nave3', 'Navi'),
        ('012_Custom_Token.png', 'assedio', 'Assedio'),
    ]
    for fn, out, label in voci:
        im = tts(fn).resize((256, 256), Image.LANCZOS)
        d = ImageDraw.Draw(im)
        # copre la scritta inglese in alto con il colore di fondo e scrive in italiano
        top = (0, 0, 256, 92) if out != 'assedio' else (0, 168, 256, 256)
        col = im.getpixel((128, 6 if out != 'assedio' else 250))
        _band(im, top, col)
        f = fb(46 if len(label) < 8 else 38)
        y = 46 if out != 'assedio' else 212
        _text_c(d, (128, y), label, f, (40, 20, 10) if out != 'assedio' else (250, 240, 220))
        im.save(A + '/segnalini/%s.png' % out)
    # gettoni tondi e quadrati disegnati da capo con le scritte italiane
    _round_token('vittoria_G', 'Vittoria', (110, 60, 150), (240, 210, 90), tts('018_Guelphs.png'))
    _round_token('vittoria_H', 'Vittoria', (230, 180, 40), (150, 30, 20), tts('020_Ghibellines.png'))
    _round_token('leva', 'Leva', (150, 110, 60), (60, 30, 10), tts('035_Custom_Tile.png'))
    _round_token('campagna', 'Campagna', (60, 90, 110), (240, 225, 200), tts('036_Custom_Tile_B.png'))
    _round_token('fine', 'Fine', (150, 110, 60), (60, 30, 10), tts('022_End_Scenario.png'))
    _round_token('battaglia', 'Battaglia', (140, 120, 100), (250, 240, 220), tts('016_Battle_Storm.png'))
    _round_token('assalto', 'Assalto', (140, 120, 100), (250, 240, 220), tts('017_Battle_Storm_B.png'))
    _square('rovine_G', 'Rovine', '½ PV', (120, 70, 160), (250, 245, 235), tts('005_Custom_Tile.png'))
    _square('rovine_H', 'Rovine', '½ PV', (235, 200, 100), (40, 20, 10), tts('006_Custom_Tile_B.png'))
    _square('devastato_G', 'Devastato', '½ PV', (110, 60, 150), (250, 240, 220), tts('008_Ravaged_1_2_VP.png'))
    _square('devastato_H', 'Devastato', '½ PV', (235, 195, 40), (130, 20, 10), tts('009_Ravaged_1_2_VP_B.png'))
    _square('alleanza_G', 'Guelfo', '1 PV', (110, 60, 150), (250, 245, 235), tts('013_Custom_Token.png'))
    _square('alleanza_H', 'Ghibellino', '1 PV', (235, 195, 40), (40, 20, 10), None)
    _square('mura_G', '+1 Mura', '', (120, 70, 160), (250, 245, 235), tts('014_Custom_Token.png'))
    _square('mura_H', '+1 Mura', '', (235, 200, 100), (40, 20, 10), tts('015_Custom_Token.png'))
    _square('aggiramento', 'Aggirato', '', (140, 125, 105), (250, 245, 235), tts('004_bypass.png'))
    _square('nutrire2', 'Nutrire', 'x2', (20, 110, 180), (255, 255, 255), None)
    _square('nutrire3', 'Nutrire', 'x3', (20, 110, 180), (255, 255, 255), None)
    im = tts('024_Custom_Token.png')
    im.save(A + '/segnalini/inseguimento_src.png')


def _band(im, box, col):
    d = ImageDraw.Draw(im)
    d.rectangle(box, fill=col)


def _text_c(d, xy, t, f, fill, stroke=None):
    bb = d.textbbox((0, 0), t, font=f)
    w, h = bb[2] - bb[0], bb[3] - bb[1]
    kw = {}
    if stroke:
        kw = {'stroke_width': 3, 'stroke_fill': stroke}
    d.text((xy[0] - w / 2 - bb[0], xy[1] - h / 2 - bb[1]), t, font=f, fill=fill, **kw)


def _round_token(name, label, bg, fg, src):
    S = 256
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((4, 4, S - 4, S - 4), fill=bg, outline=(60, 40, 20), width=8)
    d.ellipse((22, 22, S - 22, S - 22), outline=fg, width=4)
    if False and src is not None:
        # il disegno centrale dell'originale, schiarito sotto la scritta
        s = src.resize((S, S), Image.LANCZOS)
        mask = Image.new('L', (S, S), 0)
        ImageDraw.Draw(mask).ellipse((40, 40, S - 40, S - 40), fill=90)
        im.paste(s, (0, 0), mask)
    f = font('Almendra-Bold.ttf', 58 if len(label) < 7 else (44 if len(label) < 9 else 38))
    _text_c(d, (S / 2, S / 2), label, f, fg, stroke=(0, 0, 0) if bg[0] < 200 else (255, 250, 230))
    im.save(A + '/segnalini/%s.png' % name)


def _square(name, label, sub, bg, fg, src):
    S = 256
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((4, 4, S - 4, S - 4), radius=28, fill=bg, outline=(50, 35, 20), width=8)
    if False and src is not None:
        s = src.resize((S, S), Image.LANCZOS)
        mask = Image.new('L', (S, S), 0)
        ImageDraw.Draw(mask).rounded_rectangle((26, 26, S - 26, S - 26), radius=18, fill=70)
        im.paste(s, (0, 0), mask)
    f = font('Almendra-Bold.ttf', 54 if len(label) < 8 else 42)
    yl = S / 2 - (28 if sub else 0)
    st = (0, 0, 0) if sum(bg) < 450 else (255, 248, 225)
    _text_c(d, (S / 2, yl), label, f, fg, stroke=st)
    if sub:
        _text_c(d, (S / 2, S / 2 + 46), sub, font('Almendra-Bold.ttf', 56), fg, stroke=st)
    im.save(A + '/segnalini/%s.png' % name)


# ------------------------------------------------------------------ carte Comando
COMANDO = {
    'G': [('firenze', 'Firenze', 'Podestà', 2), ('arezzo', 'Arezzo', 'Podestà', 2), ('colle', 'Colle', 'Podestà', 2),
          ('lucca', 'Lucca', 'Podestà', 2), ('guido', 'Guido Guerra', 'Capitano', 2), ('orvieto', 'Orvieto', 'Capitano', 3)],
    'H': [('siena', 'Siena', 'Podestà', 2), ('pisa', 'Pisa', 'Podestà', 2), ('provenzano', 'Provenzano', 'Salvani', 2),
          ('giordano', 'Giordano', "d'Agliano", 3), ('astimberg', 'Astimberg', 'Walther von', 3),
          ('santa_fiora', 'Santa Fiora', 'Aldobrandeschi', 2)],
}


def carte_comando():
    for side, lords in COMANDO.items():
        bg = (106, 62, 150) if side == 'G' else (226, 180, 40)
        ink = (250, 245, 235) if side == 'G' else (60, 30, 10)
        for lid, nome, sotto, cmd in lords:
            for kind in ('cmd', 'tradimento'):
                im = _card_base(bg)
                d = ImageDraw.Draw(im)
                sc = Image.open(A + '/stemmi/scudo_%s.png' % lid).convert('RGBA')
                sc.thumbnail((150, 180), Image.LANCZOS)
                im.paste(sc, (190 - sc.width // 2, 70), sc)
                _text_c(d, (190, 300), nome, font('GrenzeGotisch.ttf', 58 if len(nome) < 11 else 48), ink)
                _text_c(d, (190, 352), sotto, font('Almendra-Regular.ttf', 32), ink)
                if kind == 'cmd':
                    d.rounded_rectangle((140, 392, 240, 492), radius=14, fill=(250, 245, 230), outline=(50, 30, 15), width=4)
                    _text_c(d, (190, 440), str(cmd), font('GrenzeGotisch.ttf', 84), (60, 30, 10))
                    _text_c(d, (190, 34), 'Comando', font('Almendra-Bold.ttf', 34), ink)
                else:
                    _text_c(d, (190, 34), 'Comando', font('Almendra-Bold.ttf', 34), ink)
                    d.rounded_rectangle((40, 400, 340, 480), radius=14, fill=(120, 20, 20), outline=(40, 10, 10), width=4)
                    _text_c(d, (190, 438), 'Tradimento', font('GrenzeGotisch.ttf', 56), (250, 230, 200))
                im.convert('RGB').save(A + '/carte/%s_%s.jpg' % (kind, lid), quality=88)
        # Passare e dorso
        im = _card_base(bg)
        d = ImageDraw.Draw(im)
        _text_c(d, (190, 34), 'Comando', font('Almendra-Bold.ttf', 34), ink)
        _text_c(d, (190, 266), 'Passare', font('GrenzeGotisch.ttf', 80), ink)
        _text_c(d, (190, 350), 'nessuna azione', font('Almendra-Regular.ttf', 32), ink)
        im.convert('RGB').save(A + '/carte/passa_%s.jpg' % side, quality=88)
        im = _card_base(bg)
        d = ImageDraw.Draw(im)
        _text_c(d, (190, 220), 'Inferno', font('GrenzeGotisch.ttf', 92), ink)
        _text_c(d, (190, 320), 'Guelfi' if side == 'G' else 'Ghibellini', font('Almendra-Bold.ttf', 48), ink)
        im.convert('RGB').save(A + '/carte/dorso_cmd_%s.jpg' % side, quality=88)


def _card_base(bg):
    W, H = 380, 532
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, W - 1, H - 1), radius=26, fill=(40, 25, 15))
    d.rounded_rectangle((10, 10, W - 11, H - 11), radius=20, fill=bg)
    # trama di pergamena leggera
    import random
    rnd = random.Random(7)
    for _ in range(900):
        x, y = rnd.randrange(14, W - 14), rnd.randrange(14, H - 14)
        a = rnd.randrange(8, 22)
        d.point((x, y), fill=(255, 255, 255, a))
    d.rounded_rectangle((22, 22, W - 23, H - 23), radius=16, outline=(250, 235, 200, 160), width=3)
    return im


# ------------------------------------------------------------------ mappa
def mappa():
    os.makedirs(A + '/mappa', exist_ok=True)
    b = Image.open(os.path.join(TTS, '166_board.jpg')).convert('RGB')
    m = b.crop((0, 2300, 5400, 6900))          # la mappa senza il calendario
    d = ImageDraw.Draw(m)
    # le scritte inglesi della mappa rifatte in italiano: (riquadro, testo, font, misura, colore, punto per il fondo)
    L = lambda x0, y0, x1, y1: (int(2600 + x0 * 1.4), int(3400 + y0 * 1.4), int(2600 + x1 * 1.4), int(3400 + y1 * 1.4))
    ink = (30, 20, 15)
    ross = (150, 30, 30)
    marr = (150, 80, 35)
    vio = (140, 40, 140)
    G, AB = 'GrenzeGotisch.ttf', 'Almendra-Bold.ttf'
    voci = [
        (L(1322, 232, 1482, 284), ['Località'], G, 66, ink),
        (L(1333, 298, 1472, 332), ['Valore'], AB, 38, ink),
        (L(1476, 336, 1600, 390), ['Città'], G, 64, ross),
        (L(1476, 446, 1600, 498), ['Cittadina'], G, 52, ink),
        (L(1476, 548, 1600, 598), ['Castello'], G, 54, marr),
        (L(1296, 603, 1408, 642), ['Ghibellino'], AB, 34, (185, 140, 60)),
        (L(1410, 603, 1510, 642), ['Guelfo'], AB, 34, vio),
        (L(1698, 306, 1814, 384), ['Città', 'guida'], G, 44, ink),
        (L(1698, 446, 1814, 488), ['Avamposto'], G, 40, ink),
        (L(1716, 566, 1800, 607), ['Porto'], G, 46, ink),
        (L(975, 503, 1110, 555), ['Vie'], G, 72, ink),
        (L(1055, 561, 1165, 603), ['Strada'], G, 50, ink),
        (L(1055, 607, 1170, 652), ['Sentiero'], G, 50, ink),
        (L(222, 428, 348, 478), ['Sedi'], G, 70, ink),
        (L(105, 506, 212, 584), ['Signore', '(grande)'], AB, 34, ink),
        (L(356, 506, 466, 584), ['Vassallo', '(piccolo)'], AB, 34, ink),
        (L(148, 612, 424, 660), ['Sede del Podestà'], G, 50, ink),
        (L(1536, 100, 1648, 205), ['Via Cassia', 'per Roma'], AB, 40, (110, 100, 95)),
        ((3328, 2410, 3545, 2465), ['4 sett. 1260'], G, 58, (165, 35, 35)),
        ((4750, 660, 5115, 885), ['Cavalieri', 'Guelfi', 'Catturati'], G, 66, (170, 70, 160)),
        ((222, 2494, 575, 2700), ['Cavalieri', 'Ghibellini', 'Catturati'], G, 66, (175, 85, 30)),
        ((395, 3850, 1020, 4015), ['Guelfi e Ghibellini', 'si contendono la Toscana'], G, 64, ink),
    ]
    for box, righe, fnt, sz, col in voci:
        x0, y0, x1, y1 = box
        # colore di fondo: mediana dei bordi del riquadro
        px = [m.getpixel((x, y0 - 2)) for x in range(x0, x1, 7)] + [m.getpixel((x, y1 + 2)) for x in range(x0, x1, 7)]
        px.sort(key=lambda c: sum(c))
        bg = px[len(px) // 2]
        _patch(m, box, bg, px)
        f = font(fnt, sz)
        h = (y1 - y0) / len(righe)
        for i, t in enumerate(righe):
            ff = f
            while d.textlength(t, font=ff) > (x1 - x0) + 30 and ff.size > 16:
                ff = font(fnt, ff.size - 2)
            _text_c(d, ((x0 + x1) / 2, y0 + h * (i + 0.5)), t, ff, col)
    m = m.resize((4096, int(4096 * m.height / m.width)), Image.LANCZOS)
    m.save(A + '/mappa/mappa.jpg', quality=90)
    s = m.resize((2048, int(2048 * m.height / m.width)), Image.LANCZOS)
    s.save(A + '/mappa/mappa_piccola.jpg', quality=88)


def _patch(m, box, bg, campioni):
    """Copre la scritta con il colore di fondo, la grana della carta e bordi sfumati."""
    import random
    x0, y0, x1, y1 = box
    pad = 14
    w, h = x1 - x0 + 2 * pad, y1 - y0 + 2 * pad
    sd = 0
    for c in campioni:
        sd += sum(abs(c[i] - bg[i]) for i in range(3)) / 3
    sd = max(4, min(18, sd / max(1, len(campioni))))
    rnd = random.Random(x0 * 7 + y0)
    tile = Image.new('RGB', (w, h), bg)
    tp = tile.load()
    for y in range(h):
        for x in range(w):
            n = rnd.gauss(0, sd)
            tp[x, y] = tuple(max(0, min(255, int(bg[i] + n))) for i in range(3))
    tile = tile.filter(ImageFilter.GaussianBlur(1.2))
    mask = Image.new('L', (w, h), 0)
    ImageDraw.Draw(mask).rectangle((pad, pad, w - pad, h - pad), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(pad / 2))
    m.paste(tile, (x0 - pad, y0 - pad), mask)


def _repaint(m, box, col):
    # copre una zona con il suo colore e una leggera trama
    d = ImageDraw.Draw(m)
    d.rectangle(box, fill=col)


def _legend_locales(m, box):
    d = ImageDraw.Draw(m)
    ink = (90, 50, 25)
    x0, y0, x1, y1 = box
    d.rectangle(box, outline=(120, 70, 30), width=10)
    _text_c(d, ((x0 + x1) / 2, y0 + 60), 'Località', font('GrenzeGotisch.ttf', 80), ink)
    righe = [('3', 'Città'), ('2', 'Cittadina'), ('1', 'Castello')]
    for i, (n, t) in enumerate(righe):
        y = y0 + 170 + i * 110
        for j, col in enumerate([(235, 170, 30), (125, 45, 135)]):
            cx = x0 + 90 + j * 110
            d.ellipse((cx - 42, y - 42, cx + 42, y + 42), fill=col, outline=(40, 25, 15), width=6)
            _text_c(d, (cx, y), n, font('Almendra-Bold.ttf', 58), (255, 255, 255) if j else (40, 20, 10))
        d.text((x0 + 280, y - 38), t, font=font('GrenzeGotisch.ttf', 66), fill=(150, 30, 30) if i == 0 else ink)
    d.text((x0 + 40, y1 - 70), 'Ghibellino   Guelfo', font=font('Almendra-Bold.ttf', 44), fill=ink)
    d.text((x0 + 620, y0 + 150), 'Città guida', font=font('Almendra-Bold.ttf', 46), fill=ink)
    d.text((x0 + 620, y0 + 270), 'Avamposto', font=font('Almendra-Bold.ttf', 46), fill=ink)
    d.text((x0 + 620, y0 + 390), 'Porto', font=font('Almendra-Bold.ttf', 46), fill=ink)
    # piccoli simboli disegnati (niente glifi speciali)
    import math
    pts = []
    for k in range(10):
        r = 38 if k % 2 == 0 else 16
        a = -math.pi / 2 + k * math.pi / 5
        pts.append((x0 + 570 + r * math.cos(a), y0 + 178 + r * math.sin(a)))
    d.polygon(pts, fill=(125, 45, 135), outline=(40, 25, 15))
    d.polygon([(x0 + 540, y0 + 298), (x0 + 580, y0 + 268), (x0 + 580, y0 + 285), (x0 + 605, y0 + 285),
               (x0 + 605, y0 + 311), (x0 + 580, y0 + 311), (x0 + 580, y0 + 328)], fill=(125, 45, 135), outline=(40, 25, 15))
    ax, ay = x0 + 570, y0 + 415
    d.line((ax, ay - 30, ax, ay + 28), fill=(50, 60, 70), width=9)
    d.ellipse((ax - 10, ay - 44, ax + 10, ay - 24), outline=(50, 60, 70), width=6)
    d.arc((ax - 30, ay - 10, ax + 30, ay + 36), 0, 180, fill=(50, 60, 70), width=8)


if __name__ == '__main__':
    stemmi()
    carte()
    schede()
    segnalini()
    carte_comando()
    mappa()
    print('materiale pronto')
