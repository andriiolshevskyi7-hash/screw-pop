class_name ScrewView
extends Node2D
## Гвинт на пластині (дочірній вузол PlateView, локальні координати пластини).
## Сам гвинт не повертається разом з пластиною — шліц завжди «рівний» на екрані.
## Анімації (трясіння, «підстрибування», відкручування) вмикають `_process`
## лише на свій час.

var index := -1
var color_index := 0
var radius := ScrewBoard.SCREW_R
## Поворот шліца (відкручування крутить його).
var spin := 0.0
var lift := 0.0
var _shake_t := -1.0
var _shake_dir := Vector2.RIGHT
var _tween: Tween


func setup(p_index: int, p_color: int, p_radius: float) -> void:
	index = p_index
	color_index = p_color
	radius = p_radius
	set_process(false)
	queue_redraw()


func _draw() -> void:
	# Компенсуємо поворот пластини: головка й тінь завжди орієнтовані за екраном.
	draw_set_transform(Vector2.ZERO, -get_parent().rotation, Vector2.ONE)
	var offset := Vector2.ZERO
	if _shake_t >= 0.0:
		offset = _shake_dir * sin(_shake_t * 60.0) * 6.0 * (1.0 - _shake_t / 0.32)
	ScrewPainter.draw_screw(self, offset, radius, color_index, spin, lift)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
	_tween = create_tween().set_parallel(true)
	_tween.tween_method(func(v: float) -> void:
		spin = v
		lift = clampf(absf(v) / (TAU * 2.0), 0.0, 1.0)
		queue_redraw(), 0.0, -TAU * 2.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "scale", Vector2.ONE * 1.22, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return _tween
