extends Control
## Простий ефект конфеті для екрана перемоги.

const COUNT := 140
const DURATION := 4.5

var _parts: Array = []
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func burst() -> void:
	_parts.clear()
	for i in COUNT:
		_parts.append({
			"pos": Vector2(randf() * size.x, -randf() * size.y * 0.6 - 20.0),
			"vel": Vector2(randf_range(-70, 70), randf_range(240, 460)),
			"rot": randf() * TAU,
			"spin": randf_range(-7, 7),
			"sway": randf() * TAU,
			"size": Vector2(randf_range(12, 22), randf_range(7, 11)),
			"color": ScrewPainter.color_of(i),
		})
	_time = 0.0
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	for p in _parts:
		p["pos"] += p["vel"] * delta + Vector2(sin(_time * 4.0 + p["sway"]) * 60.0 * delta, 0)
		p["rot"] += p["spin"] * delta
	if _time > DURATION:
		_parts.clear()
		set_process(false)
	queue_redraw()


func _draw() -> void:
	for p in _parts:
		draw_set_transform(p["pos"], p["rot"], Vector2.ONE)
		var sz: Vector2 = p["size"]
		draw_rect(Rect2(-sz / 2.0, sz), p["color"])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
