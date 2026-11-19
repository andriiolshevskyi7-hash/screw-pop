class_name FlyScrew
extends Node2D
## Гвинт у польоті (від поля до коробки чи буфера, з буфера до коробки).
## Летить дугою, обертаючись; розмір плавно змінюється до розміру гнізда.

var color_index := 0
var radius := 24.0
var spin := 0.0
var lift := 0.8


func _draw() -> void:
	ScrewPainter.draw_screw(self, Vector2.ZERO, radius, color_index, spin, lift)


## Політ з `from` у `to` (координати батька). Повертає твін.
func fly(from: Vector2, to: Vector2, r_from: float, r_to: float, duration: float) -> Tween:
	position = from
	radius = r_from
	var height := clampf(from.distance_to(to) * 0.35, 60.0, 220.0)
	var ctrl := from.lerp(to, 0.5) + Vector2(0, -height)
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		position = from.lerp(ctrl, t).lerp(ctrl.lerp(to, t), t)
		radius = lerpf(r_from, r_to, t)
		spin = -t * TAU * 1.5
		lift = lerpf(0.8, 0.0, t * t)
		queue_redraw(), 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw
