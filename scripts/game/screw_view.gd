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
## Механіки: замок (пара — для кольору замка/ключа), ключ, прихований колір.
var locked := false
var lock_pair := -1
var key_pair := -1
var masked := false
var _open := 0.0
var _flip := 1.0
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
	var offset := Vector2.ZERO
	if _shake_t >= 0.0:
		offset = _shake_dir * sin(_shake_t * 60.0) * 6.0 * (1.0 - _shake_t / 0.32)
	draw_set_transform(offset, -get_parent().rotation, Vector2(absf(_flip), 1.0))
	if masked or _flip < 0.0:
		ScrewPainter.draw_hidden(self, Vector2.ZERO, radius, lift)
	else:
		ScrewPainter.draw_screw(self, Vector2.ZERO, radius, color_index, spin, lift)
		if key_pair >= 0:
			ScrewPainter.draw_key_badge(self, Vector2.ZERO, radius, ScrewPainter.lock_tint(key_pair))
	if lock_pair >= 0 and (locked or _open > 0.0):
		ScrewPainter.draw_padlock(self, Vector2.ZERO, radius, ScrewPainter.lock_tint(lock_pair), _open)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Замок відкрито: дужка піднімається, замок зникає.
func unlock() -> void:
	locked = false
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		_open = v
		queue_redraw(), 0.0, 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		_open = 0.0
		lock_pair = -1
		queue_redraw())
	pop()


## «?» перевертається й показує колір.
func reveal() -> void:
	masked = false
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		_flip = v
		queue_redraw(), -1.0, 1.0, 0.4).set_trans(Tween.TRANS_SINE)
	pop()


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
