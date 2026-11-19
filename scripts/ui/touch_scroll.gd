class_name TouchScroll
extends ScrollContainer
## Прокрутка пальцем з «мертвою зоною» та інерцією.
##
## Стандартний ScrollContainer на телефоні віддає натискання кнопкам усередині,
## тож замість прокрутки спрацьовувала кнопка. Тут ми самі відстежуємо рух
## пальця: якщо він зрушив більше ніж на DEADZONE, це прокрутка, і кнопки
## мають ігнорувати натискання (див. `consume_tap()`).

const DEADZONE := 14.0
const FRICTION := 5.0

var _pressing := false
var _dragging := false
var _drag_happened := false
var _start_pos := Vector2.ZERO
var _start_scroll := 0
var _velocity := 0.0
var _last_y := 0.0
var _last_time := 0


func _ready() -> void:
	# Вимикаємо вбудовану прокрутку дотиком, щоб вона не конфліктувала з нашою.
	scroll_deadzone = 100000
	set_process(false)
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED


## Викликається з обробника натискання кнопки всередині: повертає true,
## якщо це було не натискання, а прокрутка (тоді кнопка нічого не робить).
func consume_tap() -> bool:
	return _drag_happened


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if get_global_rect().has_point(event.position):
				_pressing = true
				_dragging = false
				_drag_happened = false
				_start_pos = event.position
				_start_scroll = scroll_vertical
				_velocity = 0.0
				_last_y = event.position.y
				_last_time = Time.get_ticks_msec()
		elif _pressing:
			_pressing = false
			_dragging = false
			set_process(absf(_velocity) >= 5.0)
	elif event is InputEventMouseMotion and _pressing:
		var dy: float = event.position.y - _start_pos.y
		if not _dragging and absf(dy) > DEADZONE:
			_dragging = true
			_drag_happened = true
			# Знімаємо «натиснутий» вигляд з кнопки під пальцем.
			get_viewport().gui_release_focus()
		if _dragging:
			scroll_vertical = int(_start_scroll - dy)
			var now := Time.get_ticks_msec()
			var dt := maxf(1.0, float(now - _last_time)) / 1000.0
			var v: float = (_last_y - event.position.y) / dt
			_velocity = lerpf(_velocity, v, 0.5)
			_last_y = event.position.y
			_last_time = now


## Інерція прокрутки: `_process` працює лише поки список ще котиться.
func _process(delta: float) -> void:
	if _pressing or absf(_velocity) < 5.0:
		set_process(false)
		return
	scroll_vertical += int(_velocity * delta)
	_velocity = lerpf(_velocity, 0.0, clampf(FRICTION * delta, 0.0, 1.0))
	var max_scroll := get_v_scroll_bar().max_value - get_v_scroll_bar().page
	if scroll_vertical <= 0 or scroll_vertical >= max_scroll:
		_velocity = 0.0
