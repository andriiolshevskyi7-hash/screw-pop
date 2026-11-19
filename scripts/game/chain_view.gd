class_name ChainView
extends Node2D
## Ланцюг між двома пластинами (поверх усіх пластин; генератор стежить, щоб він
## не проходив над гвинтами). Коли пластина без гвинтів чекає на пару — ланцюг
## смикається; коли обидві падають — ланцюг падає й тане разом з ними.

var plate_a := -1
var plate_b := -1
var from := Vector2.ZERO
var to := Vector2.ZERO
var _jiggle := 0.0
var _alpha := 1.0
var _vel := Vector2.ZERO
var _falling := false
var _t := 0.0
var _tween: Tween


## Godot вмикає `_process` при вході в дерево, якщо він визначений, — вимикаємо,
## анімації вмикають його самі лише на свій час.
func _ready() -> void:
	set_process(false)


func setup(a: int, b: int, seg: Array) -> void:
	plate_a = a
	plate_b = b
	from = seg[0]
	to = seg[1]
	set_process(false)
	queue_redraw()


func _draw() -> void:
	ScrewPainter.draw_chain(self, from, to, _alpha, _jiggle)


## Пластина без гвинтів повисла на ланцюгу: ланцюг коротко гойдається.
func rattle() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	for k in 3:
		_tween.tween_method(_set_jiggle, 0.0, 14.0 - k * 4.0, 0.08)
		_tween.tween_method(_set_jiggle, 14.0 - k * 4.0, -(10.0 - k * 3.0), 0.12)
	_tween.tween_method(_set_jiggle, -1.0, 0.0, 0.08)


func _set_jiggle(v: float) -> void:
	_jiggle = v
	queue_redraw()


func fall() -> void:
	if _falling:
		return
	_falling = true
	_vel = Vector2(randf_range(-60.0, 60.0), -180.0)
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	_vel.y += 3000.0 * delta
	position += _vel * delta
	_alpha = maxf(0.0, 1.0 - _t / 0.7)
	queue_redraw()
	if _alpha <= 0.0:
		queue_free()
