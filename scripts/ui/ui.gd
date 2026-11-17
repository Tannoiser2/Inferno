class_name UI
extends RefCounted
## Helper grafici condivisi. Tema «codice miniato toscano»: pergamena e inchiostro bruno, la porpora
## dei Guelfi e l'oro dei Ghibellini, il rosso delle rubriche.
## Caratteri liberi (OFL): Grenze Gotisch per i titoli (la gotica delle schede e della mappa),
## Almendra per le intestazioni, EB Garamond per i testi.

const D = preload("res://scripts/data/inf_data.gd")

const BG := Color("#1c130d")
const BG_L := Color("#33241a")
const PANEL := Color("#2a1d14")
const PANEL_L := Color("#3c2b1f")
const PERG := Color("#efe0bd")
const PERG_D := Color("#d8c391")
const INK := Color("#2b1a10")
const ORO := Color("#e2ae1c")
const ORO_L := Color("#f7d77a")
const PORPORA := Color("#7b3fa0")
const PORPORA_L := Color("#b98ad6")
const ROSSO := Color("#a8261d")
const ROSSO_L := Color("#e2584a")
const TEXT := Color("#f5ead2")
const MUTED := Color("#bba98a")
const VERDE := Color("#8fbf6a")

static var _tex := {}
static var font_title: Font
static var font_head: Font
static var font_head_r: Font
static var font_body: Font
static var font_semi: Font
static var font_bold: Font
static var font_italic: Font


static func _var(path: String, w: int) -> Font:
	var base: FontFile = load(path)
	var fv := FontVariation.new()
	fv.base_font = base
	var tag := TextServerManager.get_primary_interface().name_to_tag("wght")
	fv.variation_opentype = {tag: w}
	return fv


static func init_fonts() -> void:
	if font_title != null:
		return
	font_title = _var("res://assets/fonts/GrenzeGotisch.ttf", 700)
	font_head = load("res://assets/fonts/Almendra-Bold.ttf")
	font_head_r = load("res://assets/fonts/Almendra-Regular.ttf")
	font_body = _var("res://assets/fonts/EBGaramond.ttf", 450)
	font_semi = _var("res://assets/fonts/EBGaramond.ttf", 600)
	font_bold = _var("res://assets/fonts/EBGaramond.ttf", 750)
	font_italic = _var("res://assets/fonts/EBGaramond-Italic.ttf", 450)


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


static func stemma(id: String) -> Texture2D:
	return tex("res://assets/stemmi/%s.png" % id)


static func scudo(id: String) -> Texture2D:
	var base := id
	if id.ends_with("_c"):
		base = id.trim_suffix("_c")
	return tex("res://assets/stemmi/scudo_%s.png" % base)


static func carta(c: String) -> Texture2D:
	return tex("res://assets/carte/%s.jpg" % c)


static func carta_comando(card: Dictionary) -> Texture2D:
	match card["t"]:
		"cmd":
			return tex("res://assets/carte/cmd_%s.jpg" % card["l"])
		"trad":
			return tex("res://assets/carte/tradimento_%s.jpg" % card["l"])
	return tex("res://assets/carte/passa_%s.jpg" % ("G" if str(card.get("lato", "G")) == "G" else "H"))


static func segnalino(n: String) -> Texture2D:
	return tex("res://assets/segnalini/%s.png" % n)


static func lato_col(s: int) -> Color:
	return D.COL_LATO[s] if s >= 0 else MUTED


static func panel_style(bg: Color, border: Color = ORO, bw := 2, radius := 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(12)
	return sb


static func dark_style(radius := 8, alpha := 0.95) -> StyleBoxFlat:
	var sb := panel_style(Color(PANEL, alpha), Color(ORO, 0.6), 2, radius)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 10
	return sb


static func perg_style(radius := 6) -> StyleBoxFlat:
	var sb := panel_style(PERG, Color("#8a6a3a"), 2, radius)
	sb.set_content_margin_all(10)
	return sb


static func label(text: String, size := 20, col := TEXT, font: Font = null) -> Label:
	init_fonts()
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if font != null:
		l.add_theme_font_override("font", font)
	return l


static func title(text: String, size := 48, col := ORO_L) -> Label:
	init_fonts()
	var l := label(text, size, col, font_title)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", maxi(2, size / 20))
	l.add_theme_constant_override("shadow_offset_y", maxi(2, size / 16))
	return l


static func heading(text: String, size := 22, col := ORO_L) -> Label:
	init_fonts()
	return label(text, size, col, font_head)


## Etichetta che va a capo: larghezza minima fissata, così non si schiaccia mai in colonna.
static func wrap(l: Label, w: float) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = w
	return l


static func icon_rect(t: Texture2D, sz: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = sz
	r.size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func button(text: String, w := 200.0, h := 46.0, size := 20) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", size)
	b.clip_text = false
	return b


static func primary(b: Button) -> Button:
	init_fonts()
	b.add_theme_stylebox_override("normal", _btn(ROSSO, ORO))
	b.add_theme_stylebox_override("hover", _btn(ROSSO_L, ORO_L))
	b.add_theme_stylebox_override("pressed", _btn(ORO, INK))
	b.add_theme_stylebox_override("disabled", _btn(Color("#3a2a26"), Color("#2a1e1a")))
	b.add_theme_color_override("font_color", PERG)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_font_override("font", font_head)
	return b


static func lato_btn(b: Button, s: int) -> Button:
	init_fonts()
	var c: Color = D.COL_LATO[s]
	b.add_theme_stylebox_override("normal", _btn(c.darkened(0.25), c.lightened(0.3)))
	b.add_theme_stylebox_override("hover", _btn(c, ORO_L))
	b.add_theme_stylebox_override("pressed", _btn(ORO_L, INK))
	b.add_theme_color_override("font_color", D.COL_TESTO_LATO[s])
	b.add_theme_color_override("font_hover_color", D.COL_TESTO_LATO[s])
	b.add_theme_font_override("font", font_head)
	return b


static func _btn(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 3
	sb.content_margin_bottom = 5
	return sb


static func make_theme() -> Theme:
	init_fonts()
	var th := Theme.new()
	th.default_font = font_semi
	th.default_font_size = 21
	th.set_stylebox("normal", "Button", _btn(Color("#4a3322"), Color("#8a6a3a")))
	th.set_stylebox("hover", "Button", _btn(Color("#5e4129"), ORO))
	th.set_stylebox("pressed", "Button", _btn(ORO, ORO_L))
	th.set_stylebox("hover_pressed", "Button", _btn(ORO_L, ORO_L))
	th.set_stylebox("disabled", "Button", _btn(Color("#2a1f17"), Color("#3a2b20")))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", TEXT)
	th.set_color("font_hover_color", "Button", ORO_L)
	th.set_color("font_pressed_color", "Button", INK)
	th.set_color("font_hover_pressed_color", "Button", INK)
	th.set_color("font_disabled_color", "Button", Color("#6d5a45"))
	th.set_font("font", "Button", font_semi)
	th.set_font_size("font_size", "Button", 21)
	th.set_color("font_color", "Label", TEXT)
	var pn := StyleBoxFlat.new()
	pn.bg_color = PANEL
	th.set_stylebox("panel", "Panel", pn)
	th.set_stylebox("panel", "PanelContainer", pn)
	th.set_font("normal_font", "RichTextLabel", font_body)
	th.set_font("bold_font", "RichTextLabel", font_bold)
	th.set_font("italics_font", "RichTextLabel", font_italic)
	th.set_font("mono_font", "RichTextLabel", font_head_r)
	for k in ["normal_font_size", "bold_font_size", "italics_font_size", "mono_font_size"]:
		th.set_font_size(k, "RichTextLabel", 21)
	th.set_color("default_color", "RichTextLabel", TEXT)
	th.set_font("font", "LineEdit", font_semi)
	th.set_font_size("font_size", "LineEdit", 24)
	th.set_color("font_color", "LineEdit", INK)
	th.set_color("font_placeholder_color", "LineEdit", Color("#8b7a5e"))
	th.set_color("caret_color", "LineEdit", INK)
	th.set_stylebox("normal", "LineEdit", panel_style(PERG, ORO, 2, 4))
	th.set_stylebox("focus", "LineEdit", panel_style(Color("#fff7e3"), ORO_L, 2, 4))
	th.set_font("font", "TooltipLabel", font_body)
	th.set_font_size("font_size", "TooltipLabel", 19)
	th.set_color("font_color", "TooltipLabel", INK)
	var tp := panel_style(PERG, ORO, 2, 4)
	tp.set_content_margin_all(8)
	th.set_stylebox("panel", "TooltipPanel", tp)
	var sc := StyleBoxFlat.new()
	sc.bg_color = Color(ORO, 0.85)
	sc.set_corner_radius_all(3)
	for k in ["grabber", "grabber_highlight", "grabber_pressed"]:
		th.set_stylebox(k, "VScrollBar", sc)
		th.set_stylebox(k, "HScrollBar", sc)
		th.set_stylebox(k, "HSlider", sc)
	var sct := StyleBoxFlat.new()
	sct.bg_color = Color(1, 1, 1, 0.06)
	th.set_stylebox("scroll", "VScrollBar", sct)
	th.set_stylebox("scroll", "HScrollBar", sct)
	th.set_constant("separation", "HBoxContainer", 8)
	th.set_constant("separation", "VBoxContainer", 6)
	return th


## Sfondo: legno scuro del tavolo con le venature (disegnato).
class Backdrop extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var n := 24
		for i in n:
			var c := UI.BG_L.lerp(UI.BG, float(i) / n)
			draw_rect(Rect2(0, size.y * i / n, size.x, size.y / n + 1), c)
		var col := Color(0, 0, 0, 0.12)
		for k in 16:
			var pts := PackedVector2Array()
			var y0 := size.y * (0.03 + k * 0.065)
			for i in 41:
				var x := size.x * i / 40.0
				pts.append(Vector2(x, y0 + sin(i * 0.21 + k * 1.7) * 9.0 + cos(i * 0.07 + k) * 14.0))
			draw_polyline(pts, col, 3.0)


## Pergamena: rettangolo color carta con bordo bruno e qualche macchia (per pannelli e finestre).
class Pergamena extends PanelContainer:
	func _init() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = UI.PERG
		sb.border_color = Color("#7a5530")
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(6)
		sb.set_content_margin_all(16)
		sb.shadow_color = Color(0, 0, 0, 0.5)
		sb.shadow_size = 14
		add_theme_stylebox_override("panel", sb)


## Testo inchiostro su pergamena.
static func ink(text: String, size := 20, font: Font = null) -> Label:
	init_fonts()
	return label(text, size, INK, font if font != null else font_body)
