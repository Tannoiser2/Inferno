#!/usr/bin/env python3
"""Prepara il materiale della vista 3D a partire dalla mappa originale (assets/mappa/mappa.jpg):
- assets/mappa/mappa_3d.jpg: la mappa senza i disegni di città, cittadine e castelli e senza gli alberi
  (al loro posto ci sono i modelli 3D);
- assets/mappa/rilievo.png: le altezze di colline e montagne (grigio, 255 = RILIEVO_MAX pixel di mappa);
- scripts/data/inf_alberi.gd: posizione e forma degli alberi disegnati, per piantarli in 3D.
Uso: python3 tools/rilievo_3d.py"""
import cv2, numpy as np, re, sys, os

# ---------------------------------------------------------------- loc
def maschere_localita(im, loc):
    hsv=cv2.cvtColor(im,cv2.COLOR_BGR2HSV).astype(int)
    h,s,v=hsv[...,0],hsv[...,1],hsv[...,2]
    orange=((h>=5)&(h<=18)&(s>90)&(v>185))
    dark=(v<100)
    cream=(v>222)&(s>=22)&(s<90)&(h<30)
    ink=(orange|dark|cream).astype(np.uint8)
    R=200
    out={}
    for (lid,tipo,x,y) in loc:
        if tipo=="avamposto": continue
        x0,y0=max(0,x-R),max(0,y-R); x1,y1=min(im.shape[1],x+R),min(im.shape[0],y+R)
        win=ink[y0:y1,x0:x1].copy()
        cl=cv2.morphologyEx(win,cv2.MORPH_CLOSE,np.ones((5,5),np.uint8))
        # il corpo degli edifici: le strade sono strette e spariscono con l'apertura
        body=cv2.morphologyEx(cl,cv2.MORPH_OPEN,cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(17,17)))
        n,lab,st,cen=cv2.connectedComponentsWithStats(body)
        cx,cy=x-x0,y-y0
        sel=np.zeros_like(cl)
        for i in range(1,n):
            bx,by,bw,bh=st[i,:4]
            if bx-25<=cx<=bx+bw+25 and by-25<=cy<=by+bh+25 and st[i,4]>500:
                sel[lab==i]=1
        sel=cv2.dilate(sel,np.ones((15,15),np.uint8))&cl
        sel=cv2.dilate(sel,np.ones((7,7),np.uint8))
        # riempie i buchi (finestre, porte)
        ff=sel.copy(); m=np.zeros((ff.shape[0]+2,ff.shape[1]+2),np.uint8)
        cv2.floodFill(ff,m,(0,0),1); sel=sel|(1-ff)
        out[lid]=(x0,y0,sel)
    return out

# ---------------------------------------------------------------- alberi
def _comp(im,smin,vmax):
    hsv=cv2.cvtColor(im,cv2.COLOR_BGR2HSV).astype(int)
    h,s,v=hsv[...,0],hsv[...,1],hsv[...,2]
    t=((h>=18)&(h<=50)&(s>=smin)&(v<=vmax)&(v>=30)).astype(np.uint8)
    t=cv2.morphologyEx(t,cv2.MORPH_CLOSE,np.ones((3,3),np.uint8))
    t=cv2.morphologyEx(t,cv2.MORPH_OPEN,cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(5,5)))
    n,lab,st,cen=cv2.connectedComponentsWithStats(t)
    return st[1:]
def trova_alberi(im):
    alberi=[]
    for x,y,w,hh,a in _comp(im,78,172):
        fill=a/(w*hh)
        if 18<=w<=55 and hh>=18 and 0.7<=hh/w<=1.6 and fill>0.55:
            alberi.append(("tondo",x,y,w,hh))
    for smin,vmax in ((78,172),(55,195),(40,120)):
        for x,y,w,hh,a in _comp(im,smin,vmax):
            fill=a/(w*hh)
            if hh>=26 and hh/w>=2.3 and w<=22 and fill>0.45:
                if not any(abs(x+w/2-(b[1]+b[3]/2))<15 and abs(y+hh/2-(b[2]+b[4]/2))<25 for b in alberi):
                    alberi.append(("cipresso",x,y,w,hh))
    return alberi
def maschera_alberi(shape,alberi):
    m=np.zeros(shape[:2],np.uint8)
    for k,x,y,w,hh in alberi:
        cx=x+w//2
        if k=="tondo":
            cv2.ellipse(m,(cx,y+hh//2),(w//2+8,hh//2+8),0,0,360,1,-1)
            cv2.rectangle(m,(cx-7,y+hh-2),(cx+7,y+hh+int(hh*0.5)+6),1,-1)
        else:
            cv2.ellipse(m,(cx,y+hh//2),(w//2+7,hh//2+8),0,0,360,1,-1)
            cv2.rectangle(m,(cx-6,y+hh-2),(cx+6,y+hh+12),1,-1)
    return m

# ---------------------------------------------------------------- rilievo
ESCLUSI=[(2900,3080,3230,3320),(3700,2150,3990,2420),(3390,0,3920,470),(800,1640,1070,2210),(3270,1900,3510,2440),(140,2600,880,3330),(3200,2790,3930,3300),(2050,3010,2500,3300),(3520,480,3900,1040),(140,1860,520,2420)]
def esclusi(shape):
    m=np.zeros(shape[:2],np.uint8)
    for x0,y0,x1,y1 in ESCLUSI: m[y0:y1,x0:x1]=1
    return m
def rilievo(im, loc):
    hsv=cv2.cvtColor(im,cv2.COLOR_BGR2HSV).astype(np.float32)
    h,s,v=hsv[...,0],hsv[...,1],hsv[...,2]
    # colline: il riempimento verde chiaro e il tratteggio
    green=((h>=18)&(h<=50)&(s>=45)&(v>=60)).astype(np.uint8)
    green=cv2.morphologyEx(green,cv2.MORPH_CLOSE,np.ones((7,7),np.uint8))
    green=cv2.morphologyEx(green,cv2.MORPH_OPEN,np.ones((5,5),np.uint8))
    dt=cv2.distanceTransform(green,cv2.DIST_L2,5)
    colli=cv2.GaussianBlur(np.minimum(dt,30),(0,0),5)
    massa_c=cv2.GaussianBlur(green.astype(np.float32),(0,0),45)
    # montagne: tratteggio sottile scuro su pergamena
    loc_v=cv2.GaussianBlur(v,(0,0),6)
    linee=((v<loc_v-12)&(s<110)&((h<=22)|(h>=160))).astype(np.uint8)
    linee[esclusi(im.shape)>0]=0
    spesse=cv2.morphologyEx(linee,cv2.MORPH_OPEN,np.ones((5,5),np.uint8))
    sottili=linee&(1-cv2.dilate(spesse,np.ones((9,9),np.uint8)))
    sottili[green>0]=0
    dens=cv2.GaussianBlur(sottili.astype(np.float32),(0,0),20)
    monti=np.clip((dens-0.075)/0.17,0,1)**0.8
    monti=cv2.GaussianBlur(monti,(0,0),14)
    # creste: le linee stesse alzano un po' il profilo dentro le montagne
    cresta=cv2.GaussianBlur(sottili.astype(np.float32),(0,0),5)*monti
    H=colli*1.0+massa_c*30+monti*70+np.clip(cresta,0,0.5)*40
    # niente rilievo nel mare, nei riquadri e attorno alle località
    sea=((h>=95)&(h<=125)&(s>=25)).astype(np.uint8)
    sea=cv2.morphologyEx(sea,cv2.MORPH_OPEN,np.ones((15,15),np.uint8))
    fuori=np.ones(im.shape[:2],np.uint8); fuori[30:3355,125:3970]=0
    piatto=np.maximum(np.maximum(esclusi(im.shape),sea),fuori).astype(np.float32)
    piatto=cv2.GaussianBlur(piatto,(0,0),12)
    H=H*(1-np.clip(piatto*1.5,0,1))
    yy,xx=np.mgrid[0:im.shape[0],0:im.shape[1]]
    f=np.ones(H.shape,np.float32)
    for lid,tipo,x,y in loc:
        r0,r1=(130,230) if tipo=="citta" else (100,190)
        d=np.hypot(xx-x,yy-y)
        f=np.minimum(f,np.clip((d-r0)/(r1-r0),0,1))
    H=H*(f*f*(3-2*f))
    return H  # in pixel della mappa

RILIEVO_MAX = 100.0

if __name__ == "__main__":
    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    im = cv2.imread(os.path.join(base, "assets/mappa/mappa.jpg"))
    src = open(os.path.join(base, "scripts/data/inf_data.gd")).read()
    loc = [(m[0], m[1], int(m[2]), int(m[3])) for m in re.findall(r'"(\w+)": \{"nome": "[^"]*", "tipo": "(\w+)".*?"pos": Vector2\((\d+), (\d+)\)', src)]
    H = rilievo(im, loc)
    al = [a for a in trova_alberi(im) if not esclusi(im.shape)[a[2], a[1]]]
    m = maschera_alberi(im.shape, al)
    m = cv2.dilate(m, np.ones((3, 3), np.uint8))
    pulita = cv2.inpaint(im, m * 255, 9, cv2.INPAINT_TELEA)
    # le località: riempite con il colore della pergamena lì attorno (le strade finiscono sotto il modello)
    hsv = cv2.cvtColor(im, cv2.COLOR_BGR2HSV)
    fondo = (hsv[..., 1] < 60) & (hsv[..., 2] > 165)
    for lid, (x0, y0, sel) in maschere_localita(im, loc).items():
        sel = cv2.dilate(sel, np.ones((5, 5), np.uint8))
        hh_, ww_ = sel.shape
        anello = cv2.dilate(sel, np.ones((41, 41), np.uint8)) & (1 - sel)
        reg = pulita[y0:y0 + hh_, x0:x0 + ww_]
        f = fondo[y0:y0 + hh_, x0:x0 + ww_] & (anello > 0)
        col = np.median(reg[f], axis=0) if f.sum() > 50 else np.array([180, 195, 212])
        alpha = cv2.GaussianBlur(sel.astype(np.float32), (0, 0), 4)[..., None]
        alpha = np.clip(alpha * 1.6, 0, 1)
        reg[:] = (reg * (1 - alpha) + col[None, None, :] * alpha).astype(np.uint8)
        m[y0:y0 + hh_, x0:x0 + ww_] |= sel
    # un po' di grana della pergamena sopra le zone ricostruite, perché non sembrino macchie lisce
    rng = np.random.default_rng(7)
    grana = cv2.GaussianBlur(rng.normal(0, 7, im.shape[:2]).astype(np.float32), (0, 0), 1.2)
    mm = cv2.GaussianBlur(m.astype(np.float32), (0, 0), 3)[..., None]
    pulita = np.clip(pulita.astype(np.float32) + grana[..., None] * mm, 0, 255).astype(np.uint8)
    cv2.imwrite(os.path.join(base, "assets/mappa/mappa_3d.jpg"), pulita, [cv2.IMWRITE_JPEG_QUALITY, 88])
    small = cv2.resize(H, (1024, int(1024 * im.shape[0] / im.shape[1])), interpolation=cv2.INTER_AREA)
    cv2.imwrite(os.path.join(base, "assets/mappa/rilievo.png"), np.clip(small / RILIEVO_MAX * 255, 0, 255).astype(np.uint8))
    righe = []
    for k, x, y, w, hh in al:
        base_y = y + hh + (int(hh * 0.45) if k == "tondo" else 6)
        righe.append('\t["%s", %d, %d, %d, %d],' % (k, x + w // 2, base_y, w, hh))
    open(os.path.join(base, "scripts/data/inf_alberi.gd"), "w").write(
        "## Generato da tools/rilievo_3d.py: gli alberi disegnati sulla mappa [forma, x, y della base, larghezza, altezza della chioma].\n"
        "const RILIEVO_MAX := %.1f\nconst ALBERI := [\n%s\n]\n" % (RILIEVO_MAX, "\n".join(righe)))
    print("alberi", len(al), "rilievo max", H.max())
