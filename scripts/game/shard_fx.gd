class_name ShardFx
extends Node2D
## Уламки скляної пластини: віяло трикутників від центру, що розлітаються,
## крутяться, падають і тануть (~1 с), потім вузол видаляється.

const LIFE := 1.1

var _shards: Array = []
var _t := 0.0


func setup(outline: PackedVector2Array) -> void:
	var step := maxi(1, outline.size() / 10)
	var i := 0
	while i < outline.size():
		var a := outline[i]
		var b := outline[(i + step) % outline.size()]
		var c := (a + b) / 3.0
		var tri := PackedVector2Array([Vector2.ZERO - c, a - c, b - c])
		var dir := c.normalized() if c.length() > 1.0 else Vector2.UP
		_shards.append({
			"pts": tri,
			"pos": c,
			"vel": dir.rotated(rotation) * randf_range(120.0, 360.0) + Vector2(0, -200.0),
			"rot": 0.0,
			"spin": randf_range(-6.0, 6.0),
		})
		i += step


func _process(delta: float) -> void:
	_t += delta
	for sh in _shards:
		sh.vel.y += 2400.0 * delta
		# Швидкість у координатах екрана, а вузол повернутий — переводимо.
		sh.pos += (sh.vel as Vector2).rotated(-rotation) * delta
		sh.rot += sh.spin * delta
	queue_redraw()
	if _t >= LIFE:
		queue_free()


func _draw() -> void:
	var a := clampf((LIFE - _t) / 0.4, 0.0, 1.0)
	for sh in _shards:
		draw_set_transform(sh.pos, sh.rot, Vector2.ONE)
		draw_colored_polygon(sh.pts, Color(0.85, 0.96, 1.0, 0.6 * a))
		var loop: PackedVector2Array = (sh.pts as PackedVector2Array).duplicate()
		loop.append(sh.pts[0])
		draw_polyline(loop, Color(1, 1, 1, 0.9 * a), 2.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
