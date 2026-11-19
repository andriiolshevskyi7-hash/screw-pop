extends Control
## Ілюстрація в меню: три пластини, прикручені кольоровими гвинтами.
## Після показу меню гвинти по черзі «вкручуються» (короткий твін) — і все стоїть.

const PLATES := [
	{"pos": Vector2(-120, 30), "size": Vector2(300, 74), "rot": -0.5, "tint": 3, "screws": [[-113, 0, 1], [113, 0, 0]]},
	{"pos": Vector2(110, 10), "size": Vector2(300, 74), "rot": 0.55, "tint": 0, "screws": [[-113, 0, 2], [113, 0, 3]]},
	{"pos": Vector2(0, 70), "size": Vector2(180, 180), "rot": 0.2, "tint": 1, "screws": [[-52, -52, 4], [52, -52, 5], [52, 52, 0], [-52, 52, 2]]},
]

var _k := 1.0
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func play_intro() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(func(v: float) -> void:
		_k = v
		queue_redraw(), 0.0, 1.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var scale_k := minf(size.x / 640.0, size.y / 340.0)
	if scale_k <= 0.0:
		return
	var center := size / 2.0
	draw_set_transform(center, 0.0, Vector2.ONE * scale_k)
	var r := 30.0
	var n := 0
	var total := 8.0
	for p in PLATES:
		var rot: float = p.rot
		var holes := []
		for s in p.screws:
			holes.append(Vector2(s[0], s[1]))
		draw_set_transform(center + (p.pos as Vector2) * scale_k, rot, Vector2.ONE * scale_k)
		ScrewPainter.draw_plate(self, "bar", p.size, ScrewPainter.tint_of(p.tint), holes, r, rot)
		for s in p.screws:
			var local := Vector2(s[0], s[1])
			var world := (p.pos as Vector2) + local.rotated(rot)
			# Гвинти «вкручуються» по черзі: з'являються збільшеними й крутяться.
			var t := clampf(_k * (total + 2.0) / 3.0 - n / 3.0, 0.0, 1.0)
			n += 1
			if t <= 0.0:
				continue
			draw_set_transform(center + world * scale_k, 0.0, Vector2.ONE * scale_k * lerpf(1.4, 1.0, t))
			ScrewPainter.draw_screw(self, Vector2.ZERO, r, int(s[2]), (1.0 - t) * TAU, 1.0 - t)
		draw_set_transform(center, 0.0, Vector2.ONE * scale_k)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
