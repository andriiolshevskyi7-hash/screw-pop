class_name BoxView
extends Control
## Одна активна коробка вгорі (3 гнізда). Показує лише гвинти, що вже долетіли.
## Повна коробка закривається кришкою і відлітає вгору; нова приїжджає збоку.

signal landed

const BOX_SIZE := Vector2(250, 104)

var color_index := -1
## Скільки гвинтів уже лежить (видно).
var shown := 0
## Скільки гвинтів летить у цю коробку.
var pending := 0
var lid := 0.0
var screw_r := 24.0
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = BOX_SIZE
	size = BOX_SIZE
	pivot_offset = BOX_SIZE / 2.0


func set_box(p_color: int) -> void:
	color_index = p_color
	shown = 0
	pending = 0
	lid = 0.0
	position.y = 0.0
	modulate.a = 1.0
	scale = Vector2.ONE
	queue_redraw()


func _box_rect() -> Rect2:
	return Rect2(Vector2.ZERO, BOX_SIZE)


func _draw() -> void:
	var rect := _box_rect()
	if color_index < 0:
		# Коробок більше немає: напівпрозоре місце.
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.08)
		sb.set_corner_radius_all(26)
		sb.set_border_width_all(3)
		sb.border_color = Color(1, 1, 1, 0.25)
		draw_style_box(sb, rect)
		return
	ScrewPainter.draw_box(self, rect, color_index)
	for i in 3:
		var c := ScrewPainter.box_slot_center(rect, i)
		ScrewPainter.draw_hole(self, c, screw_r * 1.05)
		if i < shown:
			ScrewPainter.draw_screw(self, c, screw_r, color_index)
	if lid > 0.0:
		ScrewPainter.draw_box(self, Rect2(rect.position, Vector2(rect.size.x, rect.size.y)), color_index, lid)


func slot_global(slot: int) -> Vector2:
	return get_global_transform() * ScrewPainter.box_slot_center(_box_rect(), slot)


## Гвинт долетів: з'являється в гнізді, коробка «підстрибує».
func land() -> void:
	shown = mini(shown + 1, 3)
	pending = maxi(0, pending - 1)
	queue_redraw()
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2(1.08, 0.92), 0.07)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	landed.emit()


## Кришка закривається, коробка підстрибує й відлітає вгору.
func close_and_leave() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(func(v: float) -> void:
		lid = v
		queue_redraw(), 0.0, 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.1)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.12)
	_tween.tween_interval(0.06)
	_tween.set_parallel(true)
	_tween.tween_property(self, "position:y", -260.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "modulate:a", 0.0, 0.28)
	await _tween.finished


## Нова коробка приїжджає збоку (з того боку, де вона стоїть).
func arrive(p_color: int, from_right: bool) -> void:
	set_box(p_color)
	var home := position.x
	position.x = home + (520.0 if from_right else -520.0)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position:x", home, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _tween.finished
