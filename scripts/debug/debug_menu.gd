extends Control
## Debug-меню (лише для debug-збірки). Створюється з main.gd, тільки коли
## OS.is_debug_build(); папка scripts/debug/ виключена з пресету «Android AAB»,
## тож у збірці для Google Play цього коду фізично немає.
##
## Можливості:
##  - зіграти будь-який рівень (поле + «Перейти», −1/+1/+10). Рівень грається
##    в debug-режимі: той самий генератор і сід, що й у звичайній грі, але
##    збережений прогрес (рівень, зірки, серії) не змінюється;
##  - нарахувати монети (+100, +1000, +10000);
##  - скинути навчання механік, щоб побачити їх знову.
##
## Навмисно без class_name: інакше клас потрапив би до глобального реєстру
## і в release-збірці лишилося б посилання на виключений файл.

signal play_level(level: int)

const MAX_LEVEL := 9999

var _corner_button: Button
var _panel: PanelContainer
var _dim: ColorRect
var _level_edit: LineEdit
var _status: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_panel()
	_panel_visible(false)


## Кнопка «Debug» у лівому верхньому куті головного екрана (у верхній панелі меню).
func attach_corner_button(top_bar: Container) -> void:
	_corner_button = Button.new()
	_corner_button.name = "DebugButton"
	_corner_button.text = "Debug"
	_corner_button.custom_minimum_size = Vector2(150, UiTheme.TOP_BUTTON_SIDE)
	_corner_button.add_theme_font_size_override("font_size", 26)
	UiTheme.paint_button(_corner_button, Color("e5484d"))
	_corner_button.pressed.connect(open)
	top_bar.add_child(_corner_button)
	top_bar.move_child(_corner_button, 0)


func open() -> void:
	_level_edit.text = str(GameState.level)
	_refresh_status()
	_panel_visible(true)


func close() -> void:
	_panel_visible(false)


func _panel_visible(on: bool) -> void:
	_dim.visible = on
	_panel.visible = on
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE


func _build_panel() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.6)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(_dim)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PANEL, 36, Color("e5484d")))
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(620, 0)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	_panel.add_child(box)

	var title := Label.new()
	title.text = "Debug"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	box.add_child(title)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 24)
	_status.add_theme_color_override("font_color", UiTheme.GOLD)
	box.add_child(_status)

	# Рівень.
	box.add_child(_section("Рівень (прогрес не змінюється)"))
	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 10)
	box.add_child(level_row)
	_level_edit = LineEdit.new()
	_level_edit.name = "LevelEdit"
	_level_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_level_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_edit.custom_minimum_size = Vector2(170, 84)
	_level_edit.add_theme_font_size_override("font_size", 34)
	_level_edit.text_submitted.connect(func(_t: String) -> void: _go())
	level_row.add_child(_level_edit)
	var go := _button("Перейти", UiTheme.GREEN, _go)
	go.name = "GoButton"
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_row.add_child(go)
	var steps := HBoxContainer.new()
	steps.add_theme_constant_override("separation", 10)
	box.add_child(steps)
	for d in [-1, 1, 10]:
		var b := _button(("%+d" % d), UiTheme.PRIMARY, _step.bind(d))
		b.name = "Step%s" % ("M1" if d < 0 else str(d))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		steps.add_child(b)

	# Монети.
	box.add_child(_section("Монети"))
	var coins_row := HBoxContainer.new()
	coins_row.add_theme_constant_override("separation", 10)
	box.add_child(coins_row)
	for amount in [100, 1000, 10000]:
		var b := _button("+%d" % amount, UiTheme.ORANGE, _add_coins.bind(amount))
		b.name = "Coins%d" % amount
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		coins_row.add_child(b)

	# Навчання.
	box.add_child(_section("Навчання механік"))
	var reset := _button("Скинути навчання", UiTheme.ACCENT, _reset_tutorials)
	reset.name = "ResetTutorials"
	box.add_child(reset)

	var close_button := _button("Закрити", Color("6b6490"), close)
	close_button.name = "CloseButton"
	box.add_child(close_button)


func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	return l


func _button(text: String, color: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 84)
	b.add_theme_font_size_override("font_size", 28)
	UiTheme.paint_button(b, color)
	b.pressed.connect(cb)
	return b


## Номер рівня з поля (1..MAX_LEVEL); некоректне значення — поточний рівень гравця.
func entered_level() -> int:
	var t := _level_edit.text.strip_edges()
	if not t.is_valid_int():
		return GameState.level
	return clampi(t.to_int(), 1, MAX_LEVEL)


func set_entered_level(n: int) -> void:
	_level_edit.text = str(clampi(n, 1, MAX_LEVEL))


func _step(delta: int) -> void:
	set_entered_level(entered_level() + delta)
	Sfx.play("tap")


func _go() -> void:
	var n := entered_level()
	set_entered_level(n)
	Sfx.play("select")
	close()
	play_level.emit(n)


func _add_coins(amount: int) -> void:
	GameState.add_coins(amount)
	Sfx.play("tap", 1.3)
	_refresh_status()


## Скидає всі навчання (перший хід, буфер, механіки) — вони з'являться знову.
func _reset_tutorials() -> void:
	GameState.tutorials_done = []
	GameState.save_game()
	Sfx.play("tap")
	_refresh_status("Навчання скинуто")


func _refresh_status(extra: String = "") -> void:
	var text := "Прогрес: рівень %d · монети %d" % [GameState.level, GameState.coins]
	if extra != "":
		text += "\n" + extra
	_status.text = text
