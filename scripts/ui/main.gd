extends Control
## Корінь гри: перемикає екрани меню, гри, перемоги та налаштування.

@onready var menu: Control = $Menu
@onready var game: Control = $Game
@onready var win_screen: Control = $WinScreen
@onready var settings_popup: PopupBase = $SettingsPopup

## Останній пройдений рівень був з debug-меню («Далі» — наступний debug-рівень).
var _last_win_debug := false
## Debug-меню (лише в debug-збірці, інакше null).
var debug_menu: Control

const DEBUG_MENU_PATH := "res://scripts/debug/debug_menu.gd"
var _toast: Label
var _toast_tween: Tween


func _ready() -> void:
	theme = UiTheme.build()
	PressFx.install(get_tree())
	_install_debug_menu()
	menu.play_pressed.connect(func() -> void: _start(GameState.level))
	menu.settings_pressed.connect(_open_overlay.bind(settings_popup))
	game.level_won.connect(_on_level_won)
	game.exit_requested.connect(_show_menu)
	game.settings_requested.connect(_open_overlay.bind(settings_popup))
	settings_popup.closed.connect(_on_overlay_closed)
	win_screen.next_pressed.connect(_on_next)
	_build_toast()
	AdManager.message.connect(func(key: String) -> void: show_toast(tr(key)))
	_show_menu()


## Коротке повідомлення поверх будь-якого екрана (реклама, конфіденційність).
func _build_toast() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_toast = Label.new()
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.anchor_left = 0.0
	_toast.anchor_right = 1.0
	_toast.offset_left = 24
	_toast.offset_right = -24
	_toast.offset_top = -340
	_toast.offset_bottom = -250
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_font_size_override("font_size", 28)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.03, 0.18, 0.92)
	sb.set_corner_radius_all(24)
	sb.set_content_margin_all(16)
	sb.border_color = UiTheme.GOLD
	sb.set_border_width_all(3)
	_toast.add_theme_stylebox_override("normal", sb)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	layer.add_child(_toast)


func show_toast(text: String) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(2.4)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)


func _open_overlay(overlay: Control) -> void:
	menu.paused = true
	overlay.open()


func _on_overlay_closed() -> void:
	menu.paused = false
	menu.refresh()


func _start(level: int) -> void:
	menu.hide()
	win_screen.hide()
	game.show()
	game.start_level(level)


## Debug-меню підключається лише в debug-збірці. У release-AAB файлу
## scripts/debug/debug_menu.gd немає взагалі (виключений у пресеті експорту).
func _install_debug_menu() -> void:
	if not OS.is_debug_build() or not ResourceLoader.exists(DEBUG_MENU_PATH):
		return
	debug_menu = load(DEBUG_MENU_PATH).new()
	debug_menu.name = "DebugMenu"
	add_child(debug_menu)
	debug_menu.attach_corner_button(menu.get_node("TopBar"))
	debug_menu.play_level.connect(_start_debug)


## Рівень з debug-меню: збережений прогрес не змінюється.
func _start_debug(level: int) -> void:
	menu.hide()
	win_screen.hide()
	game.show()
	game.start_level(level, true)


func _show_menu() -> void:
	game.hide()
	win_screen.hide()
	menu.refresh()
	menu.show()
	# Поточний рівень генерується у фоні, поки гравець у меню, — «Грати» відкриє його одразу.
	game.prefetch(GameState.level)


func _on_level_won(summary: Dictionary) -> void:
	_last_win_debug = summary.get("debug", false)
	win_screen.show_win(summary)


func _on_next() -> void:
	# Debug-рівень: без реклами й нагород — одразу наступний debug-рівень.
	if _last_win_debug:
		_start_debug(game.level + 1)
		return
	await AdManager.on_level_completed()
	_start(GameState.level)


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if settings_popup.visible:
		settings_popup.close()
	elif game.lose_popup.visible:
		return
	elif win_screen.visible:
		win_screen._on_next()
	elif game.visible:
		game.request_exit()
	else:
		get_tree().quit()
