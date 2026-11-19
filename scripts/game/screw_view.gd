class_name ScrewView
extends Node2D
## Гвинт на пластині (дочірній вузол PlateView, локальні координати пластини).
## Сам гвинт не повертається разом з пластиною — шліц завжди «рівний» на екрані.
## Анімації (трясіння, «підстрибування», відкручування, перемикання хамелеона,
## пульс бомби) — твіни або `_process` лише на свій час.

## Лічильник бомби змінився чи пульсує — шар лічильників над пластинами перемальовується.
signal bomb_changed

var index := -1
var color_index := 0
var radius := ScrewBoard.SCREW_R
## Поворот шліца (відкручування крутить його).
var spin := 0.0
var lift := 0.0
## Хамелеон: другий колір (-1 — звичайний гвинт), що з'явиться після ходу.
var other_color := -1
## Колір, до якого вже йде (чи прийшла) анімація перемикання.
var target_color := -1
## Бомба: ходів до вибуху (0 — не бомба).
var bomb := 0
var _bomb_pulse := 0.0
var _flip := 1.0
var _shake_t := -1.0
var _shake_dir := Vector2.RIGHT
var _tween: Tween
var _fx_tween: Tween


## Godot вмикає `_process` при вході в дерево, якщо він визначений, — вимикаємо,
## анімації вмикають його самі лише на свій час.
func _ready() -> void:
	set_process(false)


func setup(p_index: int, p_color: int, p_radius: float) -> void:
	index = p_index
	color_index = p_color
	radius = p_radius
	set_process(false)
	queue_redraw()


func _draw() -> void:
	# Компенсуємо поворот пластини: головка й тінь завжди орієнтовані за екраном.
	var offset := Vector2.ZERO
	if _shake_t >= 0.0:
		offset = _shake_dir * sin(_shake_t * 60.0) * 6.0 * (1.0 - _shake_t / 0.32)
	draw_set_transform(offset, -get_parent().rotation, Vector2(absf(_flip), 1.0))
	if other_color >= 0:
		ScrewPainter.draw_chameleon(self, Vector2.ZERO, radius, color_index, other_color, spin, lift)
	else:
		ScrewPainter.draw_screw(self, Vector2.ZERO, radius, color_index, spin, lift)
	if bomb > 0:
		ScrewPainter.draw_bomb_ring(self, Vector2.ZERO, radius)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Пульс лічильника бомби (0…1) для шару лічильників.
func bomb_pulse() -> float:
	return _bomb_pulse


## Хамелеон після ходу: монетка перевертається, кольори міняються місцями.
func flip_to(current: int, next: int) -> void:
	target_color = current
	if _fx_tween:
		_fx_tween.kill()
	_fx_tween = create_tween()
	_fx_tween.tween_method(func(v: float) -> void:
		_flip = v
		queue_redraw(), 1.0, 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_fx_tween.tween_callback(func() -> void:
		color_index = current
		other_color = next)
	_fx_tween.tween_method(func(v: float) -> void:
		_flip = v
		queue_redraw(), 0.0, 1.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Новий лічильник бомби; на 3 і менше — помітний пульс (двічі, не постійно).
func set_bomb(left: int, animate: bool = true) -> void:
	var changed := left != bomb
	bomb = left
	queue_redraw()
	bomb_changed.emit()
	if not changed or not animate or left > 3:
		return
	if _fx_tween:
		_fx_tween.kill()
	_fx_tween = create_tween()
	for k in 2:
		_fx_tween.tween_method(_set_pulse, 0.0, 1.0, 0.16).set_trans(Tween.TRANS_SINE)
		_fx_tween.tween_method(_set_pulse, 1.0, 0.0, 0.22).set_trans(Tween.TRANS_SINE)


func _set_pulse(v: float) -> void:
	_bomb_pulse = v
	bomb_changed.emit()


## Легке трясіння: гвинт накритий пластиною, відкрутити не можна.
func shake() -> void:
	_shake_t = 0.0
	_shake_dir = Vector2.RIGHT
	set_process(true)


func _process(delta: float) -> void:
	_shake_t += delta
	if _shake_t > 0.32:
		_shake_t = -1.0
		set_process(false)
	queue_redraw()


## Гвинт щойно став вільним — коротко «підстрибує».
func pop() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE * 1.16, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Відкручування на місці: шліц обертається, гвинт піднімається й більшає.
func unscrew(duration: float) -> Tween:
	if _tween:
		_tween.kill()
	bomb = 0
	bomb_changed.emit()
	_tween = create_tween().set_parallel(true)
	_tween.tween_method(func(v: float) -> void:
		spin = v
		lift = clampf(absf(v) / (TAU * 2.0), 0.0, 1.0)
		queue_redraw(), 0.0, -TAU * 2.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "scale", Vector2.ONE * 1.22, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return _tween
