class_name Fireworks
extends Control
## Салют: ракети злітають і розсипаються кольоровими іскрами зі шлейфами.

const COLORS := [Color("ffd54f"), Color("ff6f91"), Color("6ee7ff"), Color("b388ff"), Color("8cffb0"), Color("ffffff")]
const SPARKS := 34
const GRAVITY := 260.0

var _rockets: Array = []
var _sparks: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## Запускає `count` ракет з невеликими інтервалами.
func launch(count: int = 5) -> void:
	set_process(true)
	for i in count:
		var target := Vector2(randf_range(0.15, 0.85) * size.x, randf_range(0.12, 0.42) * size.y)
		_rockets.append({
			"pos": Vector2(target.x + randf_range(-60, 60), size.y + 20),
			"target": target,
			"delay": i * 0.32,
			"t": 0.0,
			"color": COLORS[randi() % COLORS.size()],
		})


func _process(delta: float) -> void:
	for r in _rockets.duplicate():
		if r.delay > 0.0:
			r.delay -= delta
			continue
		r.t += delta / 0.55
		if r.t >= 1.0:
			_explode(r.target, r.color)
			_rockets.erase(r)
	for s in _sparks.duplicate():
		s.prev = s.pos
		s.vel.y += GRAVITY * delta
		s.vel *= 0.985
		s.pos += s.vel * delta
		s.life -= delta
		if s.life <= 0.0:
			_sparks.erase(s)
	if _rockets.is_empty() and _sparks.is_empty():
		set_process(false)
	queue_redraw()


func _explode(at: Vector2, color: Color) -> void:
	Sfx.play("melt", randf_range(0.8, 1.1))
	for k in SPARKS:
		var a := TAU * k / SPARKS + randf_range(-0.08, 0.08)
		var speed := randf_range(180.0, 320.0)
		_sparks.append({
			"pos": at, "prev": at,
			"vel": Vector2(cos(a), sin(a)) * speed,
			"life": randf_range(0.9, 1.4),
			"color": color if k % 4 != 0 else Color.WHITE,
		})


func _draw() -> void:
	for r in _rockets:
		if r.delay > 0.0:
			continue
		var p: Vector2 = r.pos.lerp(r.target, ease(r.t, 0.6))
		draw_circle(p, 4.0, Color(r.color, 0.95))
		draw_line(p, p + Vector2(0, 26), Color(r.color, 0.35), 3.0, true)
	for s in _sparks:
		var a := clampf(s.life / 1.2, 0.0, 1.0)
		var c: Color = s.color
		draw_line(s.prev - (s.pos - s.prev) * 3.0, s.pos, Color(c, 0.35 * a), 2.5, true)
		draw_circle(s.pos, 2.6, Color(c, a))
