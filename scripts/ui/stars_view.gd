class_name StarsView
extends Control
## Три зірки рейтингу рівня. Зароблені по черзі «влітають» з обертом і
## пружинкою, вибухають променями та іскрами, а потім м'яко мерехтять
## (по зірках пробігає відблиск).

const GOLD := Color("ffc233")
const GOLD_LIGHT := Color("ffe680")
const GOLD_DARK := Color("c77800")
## Порожня зірка на білому вікні — бузкова.
const EMPTY := Color("e4dff5")
const OFFSETS := [Vector2(-110, 14), Vector2(0, -6), Vector2(110, 14)]
const RADII := [44.0, 56.0, 44.0]

var stars := 0
var _scales := [0.0, 0.0, 0.0]
var _spins := [0.0, 0.0, 0.0]
## Спалах променів після появи зірки: 1 → 0.
var _bursts := [0.0, 0.0, 0.0]
var _sparks: Array = []
var _time := 0.0
var _shine_from := INF


func _ready() -> void:
	custom_minimum_size = Vector2(0, 120)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func play(count: int) -> void:
	set_process(true)
	stars = count
	_scales = [0.0, 0.0, 0.0]
	_spins = [0.0, 0.0, 0.0]
	_bursts = [0.0, 0.0, 0.0]
	_sparks.clear()
	_shine_from = INF
	queue_redraw()
	for i in 3:
		if i >= count:
			_scales[i] = 1.0
			continue
		await get_tree().create_timer(0.22 if i > 0 else 0.3).timeout
		if not is_inside_tree():
			return
		_pop_star(i)
	await get_tree().create_timer(0.5).timeout
	_shine_from = _time


func _pop_star(i: int) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_method(func(v: float) -> void: _scales[i] = v, 0.0, 1.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: _spins[i] = v, -1.4, 0.0, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: _bursts[i] = v, 1.0, 0.0, 0.6).set_delay(0.12)
	Sfx.play("star", 1.0 + i * 0.12)
	Sfx.vibrate(18 + i * 8)
	if GameState.effects_on:
		var c := _center(i)
		for k in 14:
			var a := randf() * TAU
			_sparks.append({"pos": c, "vel": Vector2(cos(a), sin(a)) * randf_range(160, 380), "life": randf_range(0.45, 0.8), "t": 0.0, "r": randf_range(3.0, 6.5)})


func _center(i: int) -> Vector2:
	return size / 2.0 + OFFSETS[i]


## Покадрово — лише поки зірки з'являються, летять іскри і кілька проходів
## відблиску; потім зірки статичні, `_process` вимкнено.
const SHINE_SECONDS := 6.0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		set_process(false)
		return
	_time += delta
	if _shine_from < INF and _time - _shine_from > SHINE_SECONDS and _sparks.is_empty():
		_shine_from = INF
		queue_redraw()
		set_process(false)
		return
	for p in _sparks:
		p.t += delta
		p.vel *= 1.0 - 2.5 * delta
		p.vel.y += 380.0 * delta
		p.pos += p.vel * delta
	_sparks = _sparks.filter(func(p: Dictionary) -> bool: return p.t < p.life)
	queue_redraw()


func _draw() -> void:
	for i in 3:
		var c := _center(i)
		var r: float = RADII[i]
		_star(c, r, 0.0, EMPTY, Color("d3cbee"))
		if i >= stars or _scales[i] <= 0.0:
			continue
		# Промені-спалах за зіркою.
		var b: float = _bursts[i]
		if b > 0.0:
			draw_circle(c, r * (1.0 + (1.0 - b) * 0.9), Color(GOLD_LIGHT, 0.35 * b))
			for k in 8:
				var a := TAU * k / 8.0 + 0.2
				var dir := Vector2(cos(a), sin(a))
				draw_line(c + dir * r * (0.9 + (1.0 - b) * 0.5), c + dir * r * (1.25 + (1.0 - b) * 0.9), Color(GOLD_LIGHT, b), 5.0 * b + 1.0, true)
		var sr: float = r * _scales[i]
		var rot: float = _spins[i]
		# Легке «дихання» вже показаних зірок.
		if _shine_from < INF:
			sr *= 1.0 + 0.04 * sin((_time - _shine_from) * 3.0 + i * 0.9)
		_star(c + Vector2(0, 5), sr, rot, GOLD_DARK, GOLD_DARK)
		_star(c, sr, rot, GOLD, Color("fff1b8"))
		_star(c + Vector2(0, -sr * 0.06), sr * 0.6, rot, Color(GOLD_LIGHT, 0.55), Color(0, 0, 0, 0))
		draw_circle(c + Vector2(-sr * 0.25, -sr * 0.3).rotated(rot), sr * 0.12, Color(1, 1, 1, 0.75))
		# Відблиск, що пробігає по зірках по черзі.
		if _shine_from < INF:
			var phase := fmod(_time - _shine_from, 2.6) - i * 0.18
			if phase > 0.0 and phase < 0.35:
				var k := phase / 0.35
				var tw := sin(k * PI)
				var p := c + Vector2(lerpf(-sr * 0.5, sr * 0.5, k), lerpf(-sr * 0.4, sr * 0.2, k))
				_sparkle(p, sr * 0.32 * tw, Color(1, 1, 1, 0.9 * tw))
	for p in _sparks:
		var a: float = 1.0 - p.t / p.life
		_sparkle(p.pos, p.r * (0.6 + a), Color(GOLD_LIGHT.lightened(0.3), a))


## Чотирипроменева іскорка.
func _sparkle(c: Vector2, r: float, col: Color) -> void:
	if r <= 0.5:
		return
	var pts := PackedVector2Array()
	for k in 8:
		var a := k * PI / 4.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.28))
	draw_colored_polygon(pts, col)


func _star(c: Vector2, r: float, rot: float, fill: Color, edge: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2.0 + k * PI / 5.0 + rot
		var rr := r if k % 2 == 0 else r * 0.48
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, fill)
	if edge.a > 0.0:
		pts.append(pts[0])
		draw_polyline(pts, edge, maxf(2.0, r * 0.07), true)
