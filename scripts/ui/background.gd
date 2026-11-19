extends Control
## Фон гри «Лагуна» (як Arrows Away і Кульки в колбах): бірюза → синій,
## м'яке світло за полем і напівпрозорі заокруглені квадрати. Статичний:
## малюється один раз (і знову — лише при зміні розміру). Скіни фонів — етап 3.

const TOP := Color("23c9c8")
const MID := Color("1fa0bf")
const BOTTOM := Color("1863ae")

var _items: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for i in 12:
		_items.append({"k": rng.randf(), "phase": rng.randf() * TAU})


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var s := size
	var mid_y := s.y * 0.48
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), Vector2(s.x, mid_y), Vector2(0, mid_y)]), PackedColorArray([TOP, TOP, MID, MID]))
	draw_polygon(PackedVector2Array([Vector2(0, mid_y), Vector2(s.x, mid_y), s, Vector2(0, s.y)]), PackedColorArray([MID, MID, BOTTOM, BOTTOM]))
	var gc := Vector2(s.x * 0.5, s.y * 0.55)
	for k in 6:
		draw_circle(gc, s.x * (0.95 - k * 0.13), Color(1, 1, 1, 0.022))
	_draw_squares(s, minf(s.x, s.y * 0.6), 0.08)


## Напівпрозорі заокруглені квадрати, що «пливуть» по фону (як в Arrows Away). Статично.
func _draw_squares(s: Vector2, unit: float, alpha: float) -> void:
	var spots := [Vector2(0.62, 0.06), Vector2(0.12, 0.3), Vector2(0.86, 0.36), Vector2(0.48, 0.52),
		Vector2(0.06, 0.74), Vector2(0.78, 0.7), Vector2(0.34, 0.86), Vector2(0.95, 0.93)]
	for i in spots.size():
		var b: Dictionary = _items[i]
		var c: Vector2 = spots[i] * s
		var side: float = unit * (0.16 + b.k * 0.16)
		var rot: float = (b.phase - PI) * 0.2
		var pts := PackedVector2Array()
		var r: float = side * 0.22
		var half: float = side / 2.0 - r
		for corner in 4:
			var cc := Vector2(half if corner == 0 or corner == 3 else -half, half if corner < 2 else -half)
			for k in 6:
				var a := PI / 2.0 * corner + PI / 2.0 * k / 5.0
				pts.append(c + (cc + Vector2(cos(a), sin(a)) * r).rotated(rot))
		draw_colored_polygon(pts, Color(1, 1, 1, alpha * (0.6 + b.k * 0.6)))
