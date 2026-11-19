class_name BurstFx
extends Node2D
## Короткий вибух конфеті (повна коробка) — живе ~1 с і видаляється.

const LIFE := 1.0

var _parts: Array = []
var _t := 0.0


static func spawn(parent: Node, at: Vector2, color: Color, count: int = 26) -> void:
	if not GameState.effects_on:
		return
	var fx := BurstFx.new()
	fx.position = at
	parent.add_child(fx)
	for i in count:
		var a := randf() * TAU
		var speed := randf_range(260.0, 620.0)
		var c := color if i % 3 != 0 else (Color.WHITE if i % 2 == 0 else UiTheme.GOLD)
		fx._parts.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(a), sin(a) * 0.8 - 0.6) * speed,
			"rot": randf() * TAU,
			"spin": randf_range(-10.0, 10.0),
			"size": Vector2(randf_range(10, 18), randf_range(6, 10)),
			"color": c,
		})


func _process(delta: float) -> void:
	_t += delta
	for p in _parts:
		p.vel.y += 1300.0 * delta
		p.vel *= 0.985
		p.pos += p.vel * delta
		p.rot += p.spin * delta
	queue_redraw()
	if _t >= LIFE:
		queue_free()


func _draw() -> void:
	var a := clampf((LIFE - _t) / 0.35, 0.0, 1.0)
	for p in _parts:
		draw_set_transform(p.pos, p.rot, Vector2.ONE)
		var sz: Vector2 = p.size
		draw_rect(Rect2(-sz / 2.0, sz), Color(p.color, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
