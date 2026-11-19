class_name CoinCounter
extends Button
## Лічильник монет («пігулка» з монеткою). Анімовано рахує зміни балансу.
## Натискання відкриває магазин (сигнал `pressed`).

var _shown := 0
var _label: Label
var _icon: TextureRect
var _tween: Tween


func _ready() -> void:
	custom_minimum_size = Vector2(190, 76)
	# Числа та іконка завжди зліва направо, навіть для арабської.
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	focus_mode = Control.FOCUS_NONE
	_apply_style(UiTheme.PILL)
	_icon = TextureRect.new()
	_icon.texture = UiTheme.icon("coin")
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.custom_minimum_size = Vector2(70, 70)
	_icon.position = Vector2(-10, 3)
	_icon.size = Vector2(70, 70)
	_icon.pivot_offset = Vector2(35, 35)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 34)
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 64
	_label.offset_right = -20
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_shown = GameState.coins
	_label.text = str(_shown)
	GameState.coins_changed.connect(_on_coins_changed)


## «Пігулка» лічильника: напівпрозора на кольоровому фоні, темно-синя — на білому вікні.
func _apply_style(color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(38)
	style.corner_detail = 12
	for state in ["normal", "hover", "pressed", "focus"]:
		add_theme_stylebox_override(state, style)


func use_dark_style() -> void:
	_apply_style(Color("3b2f72"))
	if _label:
		_label.add_theme_color_override("font_color", Color.WHITE)


## Глобальний центр іконки — сюди летять монетки.
func icon_global_center() -> Vector2:
	return _icon.get_global_rect().get_center()


func pulse() -> void:
	var tw := create_tween()
	tw.tween_property(_icon, "scale", Vector2(1.3, 1.3), 0.08)
	tw.tween_property(_icon, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_coins_changed(coins: int) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_shown, _shown, coins, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pulse()


func _set_shown(v: int) -> void:
	_shown = v
	_label.text = str(v)
