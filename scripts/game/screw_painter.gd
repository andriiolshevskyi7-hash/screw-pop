class_name ScrewPainter
extends RefCounted
## Спільне малювання гвинтів, пластин і коробок (на полі, в польоті, в меню).

## Кольори гвинтів (і коробок) — «Класика» з Кульок у колбах: соковиті, розрізнені
## при дальтонізмі; сусідні за номером відрізняються ще й яскравістю.
## Червоний, синій, жовтий, зелений, фіолетовий, помаранчевий, блакитний, рожевий.
const COLORS := ["f93e40", "3e8eff", "fdc919", "24c265", "a640cc", "ff731b", "4fd8f5", "ff8ec5"]

## Пастельні відтінки пластин (декор, не пов'язані з кольорами гвинтів).
const PLATE_TINTS := ["c9f2e6", "dccfff", "ffd9bf", "c6e6ff", "fff0b0", "ffd3e4"]
const PLATE_ALPHA := 0.9

## Режим для дальтоніків: символ кольору замість хрестика на головці.
static var show_symbols := false


static func color_of(index: int) -> Color:
	return Color(COLORS[index % COLORS.size()])


static func tint_of(index: int) -> Color:
	return Color(PLATE_TINTS[index % PLATE_TINTS.size()])


## Головка гвинта зверху: тінь, темніший обідок, сама головка з відблиском
## і хрестоподібний шліц (`angle` — поворот шліца, крутиться при відкручуванні).
## `lift` 0…1 — наскільки гвинт піднявся (тінь відходить і м'якшає).
static func draw_screw(ci: CanvasItem, c: Vector2, r: float, color_index: int, angle: float = 0.0, lift: float = 0.0) -> void:
	var col := color_of(color_index)
	var sh := Vector2(r * (0.08 + lift * 0.25), r * (0.16 + lift * 0.45))
	ci.draw_circle(c + sh, r * (1.0 + lift * 0.1), Color(0.02, 0.08, 0.2, 0.28 - lift * 0.12))
	ci.draw_circle(c, r, col.darkened(0.32))
	ci.draw_circle(c - Vector2(0, r * 0.07), r * 0.86, col)
	# Світла верхня частина головки.
	ci.draw_colored_polygon(_ellipse(c + Vector2(0, -r * 0.36), r * 0.6, r * 0.32, 0.0), Color(col.lightened(0.35), 0.8))
	ci.draw_colored_polygon(_ellipse(c + Vector2(-r * 0.38, -r * 0.42), r * 0.15, r * 0.08, -0.6), Color(1, 1, 1, 0.8))
	var inner := c - Vector2(0, r * 0.04)
	if show_symbols:
		draw_symbol(ci, inner, r * 0.42, color_index, col)
		return
	# Хрестоподібний шліц: темне заглиблення зі світлим нижнім краєм.
	var slot := col.darkened(0.55)
	var w := r * 0.2
	for k in 2:
		var d := Vector2.from_angle(angle + k * PI / 2.0) * r * 0.5
		ci.draw_line(inner - d + Vector2(0, 1.5), inner + d + Vector2(0, 1.5), Color(col.lightened(0.4), 0.6), w)
		ci.draw_line(inner - d, inner + d, slot, w)


## Дірка в пластині або в коробці / буфері.
static func draw_hole(ci: CanvasItem, c: Vector2, r: float, alpha: float = 1.0) -> void:
	ci.draw_circle(c, r, Color(0.05, 0.12, 0.25, 0.32 * alpha))
	ci.draw_circle(c + Vector2(0, r * 0.12), r * 0.86, Color(0.02, 0.06, 0.16, 0.42 * alpha))


## Контур пластини (локальні координати, центр у 0).
static func plate_outline(shape: String, size: Vector2) -> PackedVector2Array:
	if shape == "disc":
		return _ellipse(Vector2.ZERO, size.x * 0.5, size.y * 0.5, 0.0, 40)
	var half := size * 0.5
	var r := minf(minf(half.x, half.y), 44.0)
	var pts := PackedVector2Array()
	var centers := [Vector2(half.x - r, half.y - r), Vector2(-half.x + r, half.y - r), Vector2(-half.x + r, -half.y + r), Vector2(half.x - r, -half.y + r)]
	for k in 4:
		for i in 9:
			var a := PI / 2.0 * k + PI / 2.0 * i / 8.0
			pts.append(centers[k] + Vector2(cos(a), sin(a)) * r)
	return pts


## Пластина: м'яка тінь, «товщина» знизу, напівпрозоре скло-пластик з білим краєм
## і відблиском. `holes` — локальні центри дірок.
static func draw_plate(ci: CanvasItem, shape: String, size: Vector2, tint: Color, holes: Array, r: float, rot: float, alpha: float = 1.0) -> void:
	var outline := plate_outline(shape, size)
	# Тінь і товщина зміщені «вниз» у координатах екрана (пластина повернута на rot).
	var down := Vector2(0, 1).rotated(-rot)
	ci.draw_colored_polygon(_offset(outline, down * 12.0), Color(0.02, 0.08, 0.2, 0.18 * alpha))
	ci.draw_colored_polygon(_offset(outline, down * 6.0), Color(tint.darkened(0.28), PLATE_ALPHA * alpha))
	ci.draw_colored_polygon(outline, Color(tint, PLATE_ALPHA * alpha))
	var inner := _scaled(outline, size, 10.0)
	if inner.size() > 2:
		ci.draw_colored_polygon(_offset(inner, -down * 3.0), Color(tint.lightened(0.35), 0.35 * alpha))
	var loop := outline.duplicate()
	loop.append(outline[0])
	ci.draw_polyline(loop, Color(1, 1, 1, 0.75 * alpha), 3.0, true)
	for h in holes:
		draw_hole(ci, h, r * 1.02, alpha)


## Коробка зверху: кольоровий ящик з трьома гніздами. `lid` 0…1 — кришка закривається.
static func draw_box(ci: CanvasItem, rect: Rect2, color_index: int, lid: float = 0.0) -> void:
	var col := color_of(color_index) if color_index >= 0 else Color(1, 1, 1, 0.25)
	var radius := rect.size.y * 0.24
	_round_rect(ci, Rect2(rect.position + Vector2(0, 10), rect.size), radius, Color(0.02, 0.08, 0.2, 0.18))
	_round_rect(ci, Rect2(rect.position + Vector2(0, 7), rect.size), radius, col.darkened(0.3))
	_round_rect(ci, rect, radius, col)
	_round_rect(ci, Rect2(rect.position + Vector2(10, 8), Vector2(rect.size.x - 20, rect.size.y * 0.3)), radius * 0.6, Color(col.lightened(0.35), 0.45))
	if lid > 0.0:
		var h := rect.size.y * lid
		_round_rect(ci, Rect2(rect.position, Vector2(rect.size.x, h)), radius, col.lightened(0.12))
		ci.draw_line(rect.position + Vector2(radius, h - 2), rect.position + Vector2(rect.size.x - radius, h - 2), col.darkened(0.25), 4.0)


static func box_slot_center(rect: Rect2, slot: int) -> Vector2:
	var step := rect.size.x / 3.0
	return rect.position + Vector2(step * (slot + 0.5), rect.size.y * 0.56)


static func _round_rect(ci: CanvasItem, rect: Rect2, radius: float, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(radius))
	sb.corner_detail = 8
	sb.anti_aliasing = true
	ci.draw_style_box(sb, rect)


static func _offset(pts: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + d)
	return out


## Зменшений до центру контур (для світлої «грані»).
static func _scaled(pts: PackedVector2Array, size: Vector2, inset: float) -> PackedVector2Array:
	var kx := maxf(0.0, (size.x - inset * 2.0) / size.x)
	var ky := maxf(0.0, (size.y - inset * 2.0) / size.y)
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p.x * kx, p.y * ky))
	return out


static func _ellipse(c: Vector2, rx: float, ry: float, angle: float, n: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n:
		var a := TAU * k / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(angle))
	return pts


## Символ кольору (режим для дальтоніків): 8 різних форм.
static func draw_symbol(ci: CanvasItem, c: Vector2, s: float, index: int, color: Color) -> void:
	var ink := Color(0.08, 0.05, 0.2, 0.9) if color.get_luminance() > 0.5 else Color(1, 1, 1, 0.95)
	var w := maxf(2.0, s * 0.26)
	match index % 8:
		0:  # точка
			ci.draw_circle(c, s * 0.5, ink)
		1:  # квадрат
			ci.draw_rect(Rect2(c - Vector2(s, s) * 0.58, Vector2(s, s) * 1.16), ink)
		2:  # трикутник
			ci.draw_colored_polygon(_poly(c, s * 0.95, 3, -PI / 2.0), ink)
		3:  # ромб
			ci.draw_colored_polygon(_poly(c, s * 0.9, 4, -PI / 2.0), ink)
		4:  # плюс
			ci.draw_line(c - Vector2(s * 0.85, 0), c + Vector2(s * 0.85, 0), ink, w)
			ci.draw_line(c - Vector2(0, s * 0.85), c + Vector2(0, s * 0.85), ink, w)
		5:  # хрестик
			ci.draw_line(c - Vector2(s, s) * 0.62, c + Vector2(s, s) * 0.62, ink, w)
			ci.draw_line(c + Vector2(-s, s) * 0.62, c + Vector2(s, -s) * 0.62, ink, w)
		6:  # зірка
			var pts := PackedVector2Array()
			for k in 10:
				var a := -PI / 2.0 + k * PI / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * (s if k % 2 == 0 else s * 0.45))
			ci.draw_colored_polygon(pts, ink)
		7:  # кільце
			ci.draw_arc(c, s * 0.62, 0, TAU, 24, ink, w, true)


static func _poly(c: Vector2, r: float, n: int, start: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n:
		var a := start + TAU * k / n
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


# --- Механіки ------------------------------------------------------------------

static var _font: Font


static func _num_font() -> Font:
	if _font == null:
		_font = UiTheme.font(900)
	return _font


## Текст по центру точки `c` (розмір шрифту `fs`).
static func draw_centered(ci: CanvasItem, c: Vector2, text: String, fs: int, color: Color, outline: int = 0, outline_color: Color = Color.BLACK) -> void:
	var f := _num_font()
	var sz := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var at := c + Vector2(-sz.x / 2.0, fs * 0.36)
	if outline > 0:
		ci.draw_string_outline(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline, outline_color)
	ci.draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


## Гвинт-хамелеон: головка поточного кольору, широке кільце — колір після ходу,
## дві стрілочки «обміну» на кільці. Видно обидва кольори.
static func draw_chameleon(ci: CanvasItem, c: Vector2, r: float, current: int, next: int, angle: float = 0.0, lift: float = 0.0) -> void:
	var ring := color_of(next)
	ci.draw_circle(c + Vector2(r * 0.1, r * 0.2), r * 1.12, Color(0.02, 0.08, 0.2, 0.28 - lift * 0.12))
	ci.draw_circle(c, r * 1.12, ring.darkened(0.3))
	ci.draw_circle(c - Vector2(0, r * 0.05), r * 1.04, ring)
	# Стрілки обміну на кільці (білі дуги з наконечниками).
	for k in 2:
		var a0 := PI * k + 0.35
		var a1 := a0 + PI * 0.55
		ci.draw_arc(c, r * 0.99, a0, a1, 10, Color(1, 1, 1, 0.9), r * 0.09, true)
		var tip := c + Vector2.from_angle(a1) * r * 0.99
		var dir := Vector2.from_angle(a1 + PI / 2.0)
		ci.draw_colored_polygon(PackedVector2Array([tip + dir * r * 0.16, tip + dir.orthogonal() * r * 0.13, tip - dir.orthogonal() * r * 0.13]), Color(1, 1, 1, 0.9))
	draw_screw(ci, c, r * 0.8, current, angle, lift)


## Бомба на головці: темне кільце-корпус і гніт з іскрою.
static func draw_bomb_ring(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_arc(c, r * 1.04, 0, TAU, 32, Color(0.12, 0.12, 0.16, 0.95), r * 0.2, true)
	var base := c + Vector2(r * 0.7, -r * 0.7)
	ci.draw_line(base, base + Vector2(r * 0.22, -r * 0.25), Color(0.55, 0.42, 0.25), r * 0.1)
	ci.draw_circle(base + Vector2(r * 0.26, -r * 0.3), r * 0.13, Color("ffc233"))


## Лічильник бомби (малюється над пластинами — його видно завжди): великий
## червоний кружок з числом ходів; `pulse` 0…1 — збільшення й світіння (на ≤ 3).
static func draw_bomb_counter(ci: CanvasItem, c: Vector2, r: float, left: int, pulse: float) -> void:
	var at := c + Vector2(0, -r * 1.25)
	var rr := r * (0.78 + 0.25 * pulse)
	var hot := left <= 3
	var col := Color("e5383b") if hot else Color("2a1f5c")
	if pulse > 0.0:
		ci.draw_circle(at, rr * 1.5, Color(1.0, 0.3, 0.2, 0.35 * pulse))
	ci.draw_circle(at + Vector2(0, 3), rr, Color(0.02, 0.08, 0.2, 0.3))
	ci.draw_circle(at, rr, Color.WHITE)
	ci.draw_circle(at, rr * 0.82, col)
	draw_centered(ci, at, str(left), int(rr * 1.2), Color.WHITE)


## Сейф на місці коробки: сталеві дверцята з кольоровою міткою (якого кольору
## коробку заповнити) і колесом-ручкою. `open` 0…1 — дверцята відчиняються.
static func draw_safe(ci: CanvasItem, rect: Rect2, color_index: int, open: float = 0.0) -> void:
	var radius := rect.size.y * 0.24
	_round_rect(ci, Rect2(rect.position + Vector2(0, 10), rect.size), radius, Color(0.02, 0.08, 0.2, 0.18))
	_round_rect(ci, Rect2(rect.position + Vector2(0, 7), rect.size), radius, Color("5b6474"))
	_round_rect(ci, rect, radius, Color("8a94a6"))
	# Дверцята «від'їжджають» убік, коли сейф відкривається.
	var door := Rect2(rect.position + Vector2(10 + open * rect.size.x * 0.7, 8), Vector2(rect.size.x - 20, rect.size.y - 16))
	var a := 1.0 - open
	_round_rect(ci, door, radius * 0.7, Color("aab4c4", a))
	var col := color_of(color_index)
	var mark := door.position + Vector2(door.size.y * 0.55, door.size.y * 0.5)
	ci.draw_circle(mark, door.size.y * 0.36, Color(1, 1, 1, a))
	ci.draw_circle(mark, door.size.y * 0.29, Color(col, a))
	var wheel := door.position + Vector2(door.size.x - door.size.y * 0.6, door.size.y * 0.5)
	ci.draw_arc(wheel, door.size.y * 0.27, 0, TAU, 20, Color(0.25, 0.28, 0.35, a), 5.0, true)
	for k in 3:
		var d := Vector2.from_angle(k * PI / 3.0 + open * 3.0) * door.size.y * 0.27
		ci.draw_line(wheel - d, wheel + d, Color(0.25, 0.28, 0.35, a), 4.0)
	# Замкова щілина посередині.
	var mid := door.get_center() + Vector2(-door.size.y * 0.05, 0)
	ci.draw_circle(mid, door.size.y * 0.1, Color(0.2, 0.22, 0.28, a))


## Позначка хиткої пластини в її центрі: дуга-маятник зі стрілками в обидва боки.
static func draw_swing_mark(ci: CanvasItem, size: Vector2, shape: String) -> void:
	var r := minf(minf(size.x, size.y) * 0.32, 22.0)
	var col := Color(0.16, 0.2, 0.36, 0.55)
	ci.draw_arc(Vector2(0, -r * 0.4), r, PI * 0.2, PI * 0.8, 12, col, 4.0, true)
	for k in 2:
		var a := PI * (0.2 if k == 0 else 0.8)
		var tip := Vector2(0, -r * 0.4) + Vector2.from_angle(a) * r
		var dir := Vector2.from_angle(a + (-PI / 2.0 if k == 0 else PI / 2.0))
		ci.draw_colored_polygon(PackedVector2Array([tip + dir * 9.0, tip + dir.orthogonal() * 6.0, tip - dir.orthogonal() * 6.0]), col)
	ci.draw_line(Vector2(0, -r * 0.4), Vector2(0, r * 0.7), col, 3.0, true)
	ci.draw_circle(Vector2(0, r * 0.7), 5.0, col)
