class_name UiTheme
extends RefCounted
## Єдина тема інтерфейсу в стилі студії Alderwood (як Arrows Away):
## шрифт Nunito Black, білий текст з легкою тінню, соковиті плоскі кнопки
## з темнішим нижнім краєм, білі округлі панелі з темно-синіми заголовками,
## напівпрозорі круглі іконки-кнопки та «пігулки» лічильників.

## Палітра Alderwood.
const PRIMARY := Color("3d8bff")   # синя кнопка
const PURPLE := Color("8a4bff")    # фіолетова кнопка
const ACCENT := Color("ff4f8b")    # рожева
const GOLD := Color("ffc233")      # жовта (підказка, монети)
const GREEN := Color("2ecc80")     # зелена («Далі», «Увімк.»)
const ORANGE := Color("ff8a2b")    # помаранчева («Закрити», ціни)
const GLASS := Color(1, 1, 1, 0.22)  # напівпрозорі круглі іконки на фоні
const PANEL := Color("ffffff")     # білі вікна
const NAVY := Color("2a1f5c")      # заголовки й текст на білому
const MUTED := Color("b9b3d1")     # неактивна вкладка / вимкнено
const CARD_SHADOW := Color("dcd5f2")
const PILL := Color(0.02, 0.22, 0.32, 0.32)  # «пігулки» лічильників на фоні
const DARK_TEXT := Color("2a1f5c")
## «Золотий» акцентний текст на білих вікнах (жовтий там не читається).
const GOLD_TEXT := Color("ff8a2b")
const OUTLINE := Color("12395c")
## Фон за замовчуванням: бірюза → синій.
const BG_TOP := Color("23c9c8")
const BG_BOTTOM := Color("1863ae")

const FONT_PATH := "res://assets/fonts/Nunito.ttf"
const ICON_DIR := "res://assets/icons/"

## Іконки й назви бустерів запасу.
const BOOSTER_ICONS := {"hint": "lightbulb", "tube": "tube_add", "undo": "undo"}
const BOOSTER_NAMES := {"hint": "BOOSTER_HINT", "tube": "BOOSTER_TUBE", "undo": "BOOSTER_UNDO"}

## Шрифт Nunito заданої товщини (змінний шрифт, вісь wght).
## Для ієрогліфів, арабської та деванагарі використовуються системні шрифти.
static func font(weight: int = 800) -> Font:
	var base: FontFile = load(FONT_PATH)
	base.allow_system_fallback = true
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return fv


static func icon(name: String) -> Texture2D:
	return load(ICON_DIR + name + ".svg")


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = font(900)
	t.default_font_size = 30
	_apply_button_styles(t, "Button", PRIMARY, Color.WHITE)
	t.set_constant("outline_size", "Button", 0)
	t.set_color("font_outline_color", "Button", OUTLINE)
	t.set_color("font_shadow_color", "Button", Color(0, 0, 0, 0.12))
	t.set_constant("shadow_offset_x", "Button", 0)
	t.set_constant("shadow_offset_y", "Button", 2)
	t.set_constant("icon_max_width", "Button", 56)
	t.set_constant("h_separation", "Button", 12)
	# Текст на кольоровому фоні: білий, без контуру, з легкою тінню.
	t.set_color("font_color", "Label", Color.WHITE)
	t.set_color("font_outline_color", "Label", OUTLINE)
	t.set_constant("outline_size", "Label", 0)
	t.set_color("font_shadow_color", "Label", Color(0.02, 0.15, 0.3, 0.28))
	t.set_constant("shadow_offset_x", "Label", 0)
	t.set_constant("shadow_offset_y", "Label", 3)
	t.set_stylebox("panel", "PanelContainer", panel_style(PANEL))
	var scroll := StyleBoxFlat.new()
	scroll.bg_color = Color(1, 1, 1, 0.35)
	scroll.set_corner_radius_all(6)
	t.set_stylebox("grabber", "VScrollBar", scroll)
	t.set_stylebox("grabber_highlight", "VScrollBar", scroll)
	t.set_stylebox("grabber_pressed", "VScrollBar", scroll)
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	return t


## Біле округле вікно з м'якою тінню (`border_color` — тонка рамка, якщо не прозора).
static func panel_style(color: Color, radius: int = 48, border_color: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color = color
	panel.set_corner_radius_all(radius)
	if border_color.a > 0.0:
		panel.set_border_width_all(5)
		panel.border_color = border_color
	panel.shadow_color = Color(0.02, 0.1, 0.25, 0.35)
	panel.shadow_size = 28
	panel.shadow_offset = Vector2(0, 8)
	panel.set_content_margin_all(36)
	panel.corner_detail = 12
	return panel


## Тема для вмісту білих вікон: темно-синій текст без тіні.
## Призначається вузлу вікна (`node.theme`) — решту бере з головної теми.
static func panel_theme() -> Theme:
	var t := Theme.new()
	t.set_color("font_color", "Label", NAVY)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	t.set_constant("outline_size", "Label", 0)
	t.set_color("default_color", "RichTextLabel", NAVY)
	return t


## Біла картка (магазин, щоденний бонус) з лавандовою «підкладкою» знизу.
static func card_style(selected: bool = false, radius: int = 30) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 10
	sb.border_width_bottom = 8
	sb.border_color = CARD_SHADOW
	if selected:
		sb.set_border_width_all(6)
		sb.border_width_bottom = 8
		sb.border_color = GREEN
	sb.set_content_margin_all(14)
	return sb


## Перефарбовує окрему кнопку (кольорові кнопки поверх загальної теми).
static func paint_button(button: Button, color: Color, font_color: Color = Color.WHITE, outline: bool = true) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, _style_for(state, color))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		button.add_theme_color_override(c, font_color)
	button.add_theme_color_override("font_disabled_color", Color(font_color, 0.45))
	button.add_theme_color_override("icon_disabled_color", Color(font_color, 0.45))
	button.add_theme_constant_override("outline_size", 0)


## Кнопки верхньої панелі (налаштування, додому, назад) — однакові на всіх екранах.
const TOP_BUTTON_SIDE := 92.0


## Кругла напівпрозора кнопка з білою іконкою (налаштування, додому, рестарт).
static func top_button(button: Button, icon_name: String) -> void:
	button.icon = icon(icon_name)
	button.text = ""
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(TOP_BUTTON_SIDE, TOP_BUTTON_SIDE)
	button.add_theme_constant_override("icon_max_width", int(TOP_BUTTON_SIDE * 0.56))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.3 if state == "pressed" else 0.22)
		sb.set_corner_radius_all(int(TOP_BUTTON_SIDE / 2.0))
		sb.corner_detail = 16
		sb.set_content_margin_all(10)
		button.add_theme_stylebox_override(state, sb if state != "focus" else StyleBoxEmpty.new())
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		button.add_theme_color_override(c, Color.WHITE)
	button.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.4))


## Напівпрозора темна «пігулка»/плашка під текстом — як лічильники Arrows Away.
static func plate_style(alpha: float = 0.32) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PILL, alpha)
	sb.set_corner_radius_all(30)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	sb.corner_detail = 10
	return sb


## Округлий прогрес-бар із заданим кольором заповнення.
static func style_progress(bar: ProgressBar, color: Color, radius: int = 18) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.12)
	bg.set_corner_radius_all(radius)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(radius)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)


## Квадратна кнопка-іконка.
static func icon_button(button: Button, icon_name: String, color: Color = PRIMARY, side: float = 96.0) -> void:
	button.icon = icon(icon_name)
	button.text = ""
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(side, side)
	button.add_theme_constant_override("icon_max_width", int(side * 0.58))
	paint_button(button, color)


static func _apply_button_styles(t: Theme, type: String, color: Color, font_color: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.set_stylebox(state, type, _style_for(state, color))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, type, font_color)
	t.set_color("font_disabled_color", type, Color(font_color, 0.45))


static func _style_for(state: String, color: Color) -> StyleBox:
	if state == "focus":
		return StyleBoxEmpty.new()
	var c := color
	match state:
		"hover":
			c = color.lightened(0.1)
		"pressed":
			c = color.darkened(0.12)
		"disabled":
			c = Color(color.darkened(0.3), color.a * 0.5)
	# Плоска «соковита» кнопка з темнішим нижнім краєм (як в Arrows Away).
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(34)
	sb.corner_detail = 12
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 18 if state != "pressed" else 12
	if c.a > 0.5:
		sb.border_width_bottom = 9 if state != "pressed" else 3
		sb.border_color = color.darkened(0.22)
	else:
		sb.set_border_width_all(3)
		sb.border_color = Color(1, 1, 1, 0.35)
	return sb
