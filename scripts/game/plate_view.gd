class_name PlateView
extends Node2D
## Пластина на полі (координати поля). Гвинти — дочірні ScrewView.
## Падіння — проста фізика (гравітація, обертання, один відскок від «підлоги»
## під полем), потім пластина зникає. `_process` працює лише під час падіння
## чи погойдування.

signal bounced
signal fell

const GRAVITY := 3000.0

var index := -1
var shape := "bar"
var plate_size := Vector2.ONE
var tint := Color.WHITE
var holes: Array = []
var screw_views := {}
var is_glass := false
## Скло розбилось: лишились лише гвинти в дошці.
var broken := false
var base_pos := Vector2.ZERO
var base_rot := 0.0

var _falling := false
var _vel := Vector2.ZERO
var _ang_vel := 0.0
var _floor_y := 0.0
var _bounced := false
var _t := 0.0
var _alpha := 1.0
## Погойдування навколо гвинта, що лишився.
var _wobble_t := -1.0
var _wobble_pivot := Vector2.ZERO
var _wobble_amp := 0.0


## Godot вмикає `_process` при вході в дерево, якщо він визначений, — вимикаємо,
## анімації вмикають його самі лише на свій час.
func _ready() -> void:
	set_process(false)


func setup(p_index: int, plate: Dictionary, p_holes: Array, screw_radius: float) -> void:
	index = p_index
	shape = plate.shape
	plate_size = plate.size
	tint = ScrewPainter.tint_of(int(plate.tint))
	is_glass = plate.get("glass", false)
	base_pos = plate.pos
	base_rot = plate.rot
	position = base_pos
	rotation = base_rot
	holes = p_holes
	_screw_r = screw_radius
	set_process(false)
	queue_redraw()


var _screw_r := ScrewBoard.SCREW_R


func add_screw(view: ScrewView, local_pos: Vector2) -> void:
	view.position = local_pos
	add_child(view)
	screw_views[view.index] = view


func _draw() -> void:
	if broken:
		# Гвинти, що лишились, тримаються в дошці: темне гніздо під кожним.
		for v in screw_views.values():
			draw_circle(v.position, _screw_r * 1.12, Color(0.03, 0.08, 0.2, 0.35))
		return
	if is_glass:
		ScrewPainter.draw_glass_plate(self, shape, plate_size, holes, _screw_r, rotation, _alpha)
	else:
		ScrewPainter.draw_plate(self, shape, plate_size, tint, holes, _screw_r, rotation, _alpha)


## Скло розбивається на уламки, що розлітаються й падають.
func shatter() -> void:
	broken = true
	_wobble_t = -1.0
	position = base_pos
	rotation = base_rot
	queue_redraw()
	var fx := ShardFx.new()
	fx.position = position
	fx.rotation = rotation
	get_parent().add_child(fx)
	fx.setup(ScrewPainter.plate_outline(shape, plate_size))


## Пластина тримається на одному гвинті — коротко гойдається навколо нього.
func wobble(pivot_local: Vector2) -> void:
	if _falling or broken:
		return
	_wobble_pivot = base_pos + pivot_local.rotated(base_rot)
	_wobble_t = 0.0
	_wobble_amp = 0.09 * (1.0 if randf() < 0.5 else -1.0)
	set_process(true)


## Падіння: невеликий поштовх убік і обертання; `floor_y` — де відскок.
func fall(floor_y: float) -> void:
	_falling = true
	_wobble_t = -1.0
	_floor_y = floor_y
	_vel = Vector2(randf_range(-120.0, 120.0), -260.0)
	_ang_vel = randf_range(1.6, 3.2) * (1.0 if randf() < 0.5 else -1.0)
	_t = 0.0
	set_process(true)


func is_falling() -> bool:
	return _falling


func _process(delta: float) -> void:
	if not _falling:
		_wobble_t += delta
		var k := _wobble_t / 0.9
		if k >= 1.0:
			_wobble_t = -1.0
			position = base_pos
			rotation = base_rot
			set_process(false)
			queue_redraw()
			return
		var a := _wobble_amp * sin(k * TAU * 2.0) * (1.0 - k)
		rotation = base_rot + a
		position = _wobble_pivot + (base_pos - _wobble_pivot).rotated(a)
		queue_redraw()
		return
	_t += delta
	_vel.y += GRAVITY * delta
	position += _vel * delta
	rotation += _ang_vel * delta
	var bottom := position.y + _half_height()
	if not _bounced and bottom > _floor_y and _vel.y > 0.0:
		_bounced = true
		position.y -= bottom - _floor_y
		_vel.y = -_vel.y * 0.38
		_vel.x *= 0.6
		_ang_vel *= -0.5
		bounced.emit()
	if _bounced:
		_alpha = maxf(0.0, _alpha - delta * 2.4)
	queue_redraw()
	if _alpha <= 0.0 or _t > 2.5:
		set_process(false)
		fell.emit()
		queue_free()


func _half_height() -> float:
	if shape == "disc":
		return plate_size.y * 0.5
	var c := absf(cos(rotation))
	var s := absf(sin(rotation))
	return s * plate_size.x * 0.5 + c * plate_size.y * 0.5
