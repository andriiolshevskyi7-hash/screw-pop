class_name BufferView
extends Control
## Буфер (лоток) під коробками: ряд гнізд, у які падають гвинти без своєї коробки.
## Коли місць лишається мало — лоток коротко блимає червоним (кілька разів, не постійно).

const SLOT_STEP := 74.0
const PAD := Vector2(22, 14)

## Кольори в гніздах (-1 — порожнє), як їх видно гравцю.
var slots: Array = []
var screw_r := 24.0
var _warn := 0.0
var _tween: Tween
var _new_slot := -1
var _new_k := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func setup(count: int) -> void:
	slots = []
	for i in count:
		slots.append(-1)
	_new_slot = -1
	_warn = 0.0
	queue_redraw()


func _tray_rect() -> Rect2:
	var w := slots.size() * SLOT_STEP + PAD.x * 2.0 - (SLOT_STEP - screw_r * 2.4)
	var h := screw_r * 2.4 + PAD.y * 2.0
	return Rect2(Vector2((size.x - w) / 2.0, (size.y - h) / 2.0), Vector2(w, h))


func slot_center(i: int) -> Vector2:
	var r := _tray_rect()
	return Vector2(r.position.x + PAD.x + screw_r * 1.2 + i * SLOT_STEP, r.position.y + r.size.y / 2.0)


func slot_global(i: int) -> Vector2:
	return get_global_transform() * slot_center(i)


func _draw() -> void:
	if slots.is_empty():
		return
	var rect := _tray_rect()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UiTheme.PILL, 0.32).lerp(Color(0.9, 0.15, 0.25, 0.55), _warn)
	sb.set_corner_radius_all(int(rect.size.y / 2.0))
	sb.corner_detail = 12
	draw_style_box(sb, rect)
	for i in slots.size():
		var c := slot_center(i)
		var k := _new_k if i == _new_slot else 1.0
		ScrewPainter.draw_hole(self, c, screw_r * 1.1 * k)
		if slots[i] >= 0:
			ScrewPainter.draw_screw(self, c, screw_r, slots[i])


func set_slot(i: int, color: int) -> void:
	slots[i] = color
	queue_redraw()


func clear_slot(i: int) -> void:
	slots[i] = -1
	queue_redraw()


func used() -> int:
	var n := 0
	for c in slots:
		if c >= 0:
			n += 1
	return n


## Нове гніздо (реклама / бустер): лоток розширюється, гніздо «розкривається».
func add_slot() -> void:
	slots.append(-1)
	_new_slot = slots.size() - 1
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(func(v: float) -> void:
		_new_k = v
		queue_redraw(), 0.0, 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Попередження: лоток тричі блимає червоним.
func warn() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	for k in 3:
		_tween.tween_method(_set_warn, 0.0, 1.0, 0.14)
		_tween.tween_method(_set_warn, 1.0, 0.0, 0.2)


func _set_warn(v: float) -> void:
	_warn = v
	queue_redraw()
