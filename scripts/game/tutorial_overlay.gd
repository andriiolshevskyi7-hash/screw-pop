class_name TutorialOverlay
extends Control
## Туторіал: анімована рука, що «натискає» на ціль, і бульбашка з підказкою.
## У режимі `blocking` перехоплює дотик: будь-яке натискання ховає підказку.
## `spotlight()` — знайомство з механікою: екран затемнюється, а цілі
## (кульки чи колби) лишаються в світлих «вікнах» з пульсуючим обідком.

signal dismissed

var _hand: TextureRect
var _shadow: TextureRect
var _bubble: PanelContainer
var _label: Label
var _tween: Tween
var _blocking := false
var _dim: ColorRect
## Підсвічені області: Rect2 у локальних координатах (еліпс, вписаний у прямокутник).
var _spots: Array = []
var _time := 0.0

const MAX_SPOTS := 8
const DIM_SHADER := """
shader_type canvas_item;
uniform vec4 spots[8];
uniform int count = 0;
uniform vec2 rect_size = vec2(720.0, 1280.0);
uniform float dim = 0.62;
void fragment() {
	vec2 p = UV * rect_size;
	float a = dim;
	for (int i = 0; i < 8; i++) {
		if (i >= count) { break; }
		vec2 d = (p - spots[i].xy) / max(spots[i].zw, vec2(1.0));
		a *= smoothstep(1.0, 1.18, length(d));
	}
	COLOR = vec4(0.02, 0.0, 0.08, a);
}
"""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = DIM_SHADER
	_dim.material = mat
	_dim.hide()
	_dim.show_behind_parent = true  # обідки (_draw) — поверх затемнення
	add_child(_dim)
	_shadow = _make_hand(Color(0, 0, 0, 0.35))
	_hand = _make_hand(Color.WHITE)
	_bubble = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	# Біла бульбашка Alderwood з темно-синім текстом і бузковою «підкладкою».
	sb.bg_color = Color.WHITE
	sb.set_corner_radius_all(28)
	sb.border_width_bottom = 8
	sb.border_color = UiTheme.CARD_SHADOW
	sb.shadow_color = Color(0.02, 0.1, 0.25, 0.3)
	sb.shadow_size = 16
	sb.set_content_margin_all(20)
	_bubble.add_theme_stylebox_override("panel", sb)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.custom_minimum_size = Vector2(440, 0)
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_color", UiTheme.NAVY)
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	_bubble.add_child(_label)
	add_child(_bubble)
	hide()


func _make_hand(col: Color) -> TextureRect:
	var t := TextureRect.new()
	t.texture = UiTheme.icon("touch_app")
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.size = Vector2(110, 110)
	t.pivot_offset = Vector2(40, 10)
	t.modulate = col
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(t)
	return t


## Показує руку на глобальній точці `target` з текстом. `blocking` — чекати дотику.
func point_at(target: Vector2, text: String, blocking: bool = false) -> void:
	show()
	_blocking = blocking
	mouse_filter = Control.MOUSE_FILTER_STOP if blocking else Control.MOUSE_FILTER_IGNORE
	var local := get_global_transform().affine_inverse() * target
	# Кінчик пальця іконки — приблизно (40, 10) від її лівого верхнього кута.
	var pos := local - Vector2(40, 10)
	_hand.position = pos
	_shadow.position = pos + Vector2(6, 8)
	_label.text = text
	_bubble.reset_size()
	await get_tree().process_frame
	var bsize := _bubble.get_combined_minimum_size()
	var by := local.y + 120 if local.y < size.y * 0.55 else local.y - bsize.y - 40
	_bubble.position = Vector2(clampf(local.x - bsize.x / 2.0, 16, size.x - bsize.x - 16), by)
	if _tween:
		_tween.kill()
	_tween = create_tween().set_loops()
	for h in [_hand, _shadow]:
		h.scale = Vector2.ONE
	_tween.tween_property(_hand, "scale", Vector2(0.82, 0.82), 0.35).set_trans(Tween.TRANS_QUAD)
	_tween.parallel().tween_property(_shadow, "scale", Vector2(0.82, 0.82), 0.35).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(_hand, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_QUAD)
	_tween.parallel().tween_property(_shadow, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_QUAD)
	_tween.tween_interval(0.2)


## Знайомство з механікою: затемнення з підсвіченими `targets` (глобальні
## Rect2) і одне речення тексту. Без руки; торкання будь-де закриває.
func spotlight(targets: Array, text: String) -> void:
	show()
	_blocking = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_hand.hide()
	_shadow.hide()
	var inv := get_global_transform().affine_inverse()
	_spots.clear()
	for r in targets.slice(0, MAX_SPOTS):
		var rect: Rect2 = r
		_spots.append(Rect2(inv * rect.position, rect.size * inv.get_scale()))
	var packed := []
	for sp in _spots:
		packed.append(Vector4(sp.get_center().x, sp.get_center().y, sp.size.x * 0.5 * 1.15, sp.size.y * 0.5 * 1.15))
	while packed.size() < MAX_SPOTS:
		packed.append(Vector4.ZERO)
	var mat: ShaderMaterial = _dim.material
	mat.set_shader_parameter("spots", packed)
	mat.set_shader_parameter("count", _spots.size())
	mat.set_shader_parameter("rect_size", size)
	_dim.show()
	_dim.modulate.a = 0.0
	set_process(true)
	_label.text = text
	_bubble.reset_size()
	await get_tree().process_frame
	# Бульбашка — під найнижчою ціллю або над найвищою, щоб не закривати їх.
	var bsize := _bubble.get_combined_minimum_size()
	var top := INF
	var bottom := -INF
	var cx := 0.0
	for sp in _spots:
		top = minf(top, sp.position.y)
		bottom = maxf(bottom, sp.end.y)
		cx += sp.get_center().x / _spots.size()
	var by := bottom + 40.0 if bottom + 40.0 + bsize.y < size.y - 200.0 else top - bsize.y - 40.0
	_bubble.position = Vector2(clampf(cx - bsize.x / 2.0, 16, size.x - bsize.x - 16), clampf(by, 16, size.y - bsize.y - 16))
	_bubble.modulate.a = 0.0
	_bubble.scale = Vector2(0.8, 0.8)
	_bubble.pivot_offset = bsize / 2.0
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_dim, "modulate:a", 1.0, 0.3)
	_tween.tween_property(_bubble, "modulate:a", 1.0, 0.25).set_delay(0.15)
	_tween.tween_property(_bubble, "scale", Vector2.ONE, 0.35).set_delay(0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _spots.is_empty() or not visible:
		set_process(false)
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	# Пульсуючий золотий обідок навколо кожної підсвіченої цілі.
	var k := 0.5 + 0.5 * sin(_time * 5.0)
	for sp in _spots:
		var c: Vector2 = sp.get_center()
		var rx: float = sp.size.x * 0.5 * (1.18 + 0.06 * k)
		var ry: float = sp.size.y * 0.5 * (1.18 + 0.06 * k)
		var pts := PackedVector2Array()
		for i in 49:
			var a := TAU * i / 48.0
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		draw_polyline(pts, Color(UiTheme.GOLD, 0.35 + 0.5 * k), 4.0 + 2.0 * k, true)


func dismiss() -> void:
	if _tween:
		_tween.kill()
	_spots.clear()
	_dim.hide()
	_hand.show()
	_shadow.show()
	_bubble.modulate.a = 1.0
	_bubble.scale = Vector2.ONE
	queue_redraw()
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _blocking:
		_blocking = false
		dismissed.emit()


func _gui_input(event: InputEvent) -> void:
	if _blocking and event is InputEventMouseButton and event.pressed:
		accept_event()
		dismiss()
