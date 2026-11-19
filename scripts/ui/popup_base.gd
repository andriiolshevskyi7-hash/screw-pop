class_name PopupBase
extends Control
## Базове модальне вікно: плавне затемнення фону, поява вікна
## з «пружинкою» (трохи більше за розмір — і назад), м'яке закриття.

signal closed

@export var panel_path: NodePath

var _panel: Control
var _dim: ColorRect
var _dim_alpha := 0.72
var _tween: Tween


func _ready() -> void:
	hide()
	_panel = get_node(panel_path)
	# Біле вікно Alderwood: темно-синій текст усередині.
	_panel.theme = UiTheme.panel_theme()
	var title := _panel.find_child("Title", true, false) as Label
	if title:
		title.uppercase = true
		title.add_theme_color_override("font_color", UiTheme.NAVY)
	_dim = get_node_or_null("Dim") as ColorRect
	if _dim:
		_dim_alpha = _dim.color.a


func open() -> void:
	show()
	if _tween:
		_tween.kill()
	modulate.a = 1.0
	if _dim:
		_dim.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.55, 0.55)
	await get_tree().process_frame
	_panel.pivot_offset = _panel.size / 2.0
	_tween = create_tween().set_parallel(true)
	if _dim:
		_tween.tween_property(_dim, "modulate:a", 1.0, 0.22)
	_tween.tween_property(_panel, "modulate:a", 1.0, 0.14)
	_tween.tween_property(_panel, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func close() -> void:
	if not visible:
		return
	Sfx.play("tap", 0.9)
	if _tween:
		_tween.kill()
	_panel.pivot_offset = _panel.size / 2.0
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_panel, "scale", Vector2(0.82, 0.82), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween.tween_property(_panel, "modulate:a", 0.0, 0.16)
	if _dim:
		_tween.tween_property(_dim, "modulate:a", 0.0, 0.2)
	await _tween.finished
	hide()
	closed.emit()
