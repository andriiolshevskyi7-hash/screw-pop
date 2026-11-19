class_name Rays
extends Control
## Промені, що повільно обертаються позаду нагороди (скриня, нова нагорода).

@export var color := Color(1.0, 0.85, 0.4)
@export var count := 14

var _angle := 0.0
var _power := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## Плавно вмикає промені.
## Після спалаху промені обертаються лише кілька секунд, потім застигають
## (щоб не перемальовувати екран безкінечно).
const SPIN_SECONDS := 3.0

var _spin_left := 0.0


func flare() -> void:
	_power = 0.0
	_spin_left = SPIN_SECONDS
	set_process(true)
	create_tween().tween_property(self, "_power", 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _power <= 0.0:
		set_process(false)
		return
	_angle += delta * 0.5
	_spin_left -= delta
	queue_redraw()
	if _spin_left <= 0.0:
		set_process(false)


func _draw() -> void:
	if _power <= 0.0:
		return
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.5 * _power
	for k in count:
		var a := _angle + TAU * k / count
		var w := TAU / count * 0.28
		draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a - w), sin(a - w)) * r, c + Vector2(cos(a + w), sin(a + w)) * r]), Color(color, 0.16 * _power))
	for k in 4:
		draw_circle(c, r * (0.18 + k * 0.08), Color(color, 0.06 * _power))
