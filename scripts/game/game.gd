extends Control
## Ігровий екран: коробки, буфер, поле з пластинами. Натискання по гвинту
## змінює стан одразу (ScrewBoard.tap), а події ходу програються анімаціями:
## відкручування → політ у коробку/буфер → падіння пластини → повна коробка
## закривається й відлітає → нова приїжджає й забирає гвинти з буфера.
## Поки йде заміна коробки, нові натискання не приймаються (коротко, ~1 с).

signal level_won(summary: Dictionary)
signal exit_requested
signal settings_requested
## Рівень згенеровано й показано.
signal level_ready
## Фонова генерація завершила рівень з ключем `key`.
signal generation_done(key: String)
## Усі анімації ходів завершилися.
signal settled

const UNSCREW_TIME := 0.16
const FLY_TIME := 0.34
const PULL_TIME := 0.3
## Радіус гвинта в коробках і буфері (пікселі екрана).
const UI_SCREW_R := 23.0

@onready var level_label: Label = %LevelLabel
@onready var info_label: Label = %InfoLabel
@onready var board_view: BoardView = %Board
@onready var buffer_view: BufferView = %Buffer
@onready var boxes_root: Control = %Boxes
@onready var fly_layer: Node2D = %FlyLayer
@onready var home_button: Button = %HomeButton
@onready var settings_button: Button = %SettingsButton
@onready var restart_button: Button = %RestartButton
@onready var coin_counter: CoinCounter = %CoinCounter
@onready var lose_popup = %LosePopup

var boxes: Array[BoxView] = []
var board: ScrewBoard
var initial: Dictionary = {}
var level := 1
## Рівень запущено з debug-меню (лише debug-збірка): прогрес не зберігається.
var debug_play := false
var moves_made := 0
## Продовження за рекламу (+1 місце в буфері) на цьому рівні.
var continues := 0
var loading := false
var _load_id := 0
var _won := false
var _lost := false
## Скільки ходів ще анімуються і скільки з них міняють коробки (блокують ввід).
var _active := 0
var _box_lock := 0
## Покоління анімацій: рестарт/вихід збільшує його, і старі корутини ходів зупиняються.
var _gen := 0
var _tutorial: TutorialOverlay
var _hand: TextureRect
var _hand_tween: Tween
var _hand_screw := -1


func _ready() -> void:
	boxes = [%BoxA, %BoxB]
	for b in boxes:
		b.screw_r = UI_SCREW_R
	buffer_view.screw_r = UI_SCREW_R
	boxes_root.resized.connect(_layout_boxes)
	UiTheme.top_button(home_button, "home")
	UiTheme.top_button(settings_button, "settings")
	UiTheme.icon_button(restart_button, "restart_alt", UiTheme.PRIMARY, 104.0)
	home_button.pressed.connect(request_exit)
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	restart_button.pressed.connect(restart)
	board_view.screw_pressed.connect(_on_screw_pressed)
	GameState.language_changed.connect(_update_texts)
	GameState.cosmetics_changed.connect(_redraw_all)
	_build_hand()
	_tutorial = TutorialOverlay.new()
	add_child(_tutorial)
	move_child(_tutorial, lose_popup.get_index())
	_layout_boxes()


## Режим для дальтоніків змінює вигляд гвинтів — перемальовуємо все.
func _redraw_all() -> void:
	board_view.queue_redraw_all()
	buffer_view.queue_redraw()
	for b in boxes:
		b.queue_redraw()


func _layout_boxes() -> void:
	var w := boxes_root.size.x
	var gap := 26.0
	var total := BoxView.BOX_SIZE.x * 2.0 + gap
	for i in 2:
		boxes[i].position = Vector2((w - total) / 2.0 + i * (BoxView.BOX_SIZE.x + gap), 0.0)


# --- Запуск рівня -----------------------------------------------------------

## Рівень генерується у фоновому потоці (розв'язувач на телефоні може працювати
## сотні мілісекунд); поки триває генерація, `loading` = true і ходи не приймаються.
func start_level(p_level: int, p_debug: bool = false) -> void:
	level = p_level
	debug_play = p_debug and OS.is_debug_build()
	_load_id += 1
	var my_load := _load_id
	loading = true
	_clear()
	_update_texts()
	var generated: Dictionary = await _generate_async(level, LevelGenerator.seed_for_level(level))
	if my_load != _load_id:
		return  # поки генерувалося, запустили інший рівень або вийшли
	loading = false
	initial = generated.board
	_reset()
	level_ready.emit()
	_start_tutorial()
	if not debug_play:
		prefetch(level + 1)


func restart() -> void:
	if loading or initial.is_empty():
		return
	Sfx.play("tap")
	if moves_made > 0 and not debug_play and not _won:
		GameState.break_streak()
	_load_id += 1
	_reset()


func _clear() -> void:
	_gen += 1
	if _tutorial:
		_tutorial.dismiss()
	board = null
	_won = false
	_lost = false
	_active = 0
	_box_lock = 0
	moves_made = 0
	continues = 0
	_hide_hand()
	for child in fly_layer.get_children():
		child.queue_free()
	board_view.clear()
	for b in boxes:
		b.set_box(-1)
	buffer_view.setup(0)


func _reset() -> void:
	_clear()
	board = ScrewBoard.from_dict(initial)
	board_view.build(board)
	for i in boxes.size():
		if board.box_color[i] == ScrewBoard.SAFE:
			boxes[i].set_safe(int(board.safe.color))
		else:
			boxes[i].set_box(board.box_color[i])
	buffer_view.setup(board.buffer.size())
	_update_texts()
	_play_intro()


## Поява поля: пластини по черзі «прилітають» згори з пружинкою.
func _play_intro() -> void:
	var i := 0
	for p in board_view.plate_views:
		var v: PlateView = board_view.plate_views[p]
		var home := v.position
		v.position = home + Vector2(0, -60)
		v.modulate.a = 0.0
		var tw := v.create_tween().set_parallel(true)
		tw.tween_property(v, "position", home, 0.35).set_delay(i * 0.035).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(v, "modulate:a", 1.0, 0.2).set_delay(i * 0.035)
		i += 1
	for k in boxes.size():
		boxes[k].scale = Vector2(0.6, 0.6)
		boxes[k].create_tween().tween_property(boxes[k], "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_texts() -> void:
	level_label.uppercase = true
	level_label.text = tr("LEVEL_N") % level
	if debug_play:
		level_label.text += " · debug"
	info_label.text = ""


# --- Генерація у фоновому потоці --------------------------------------------

## Готові рівні: "рівень:сід" -> результат LevelGenerator.generate.
var _generated := {}
## Задачі WorkerThreadPool, що ще генерують: ключ -> id задачі.
var _gen_tasks := {}


func _gen_key(p_level: int, seed_value: int) -> String:
	return "%d:%d" % [p_level, seed_value]


## Почати генерацію рівня заздалегідь (у фоні).
func prefetch(p_level: int) -> void:
	_request_generation(p_level, LevelGenerator.seed_for_level(p_level))


func _request_generation(p_level: int, seed_value: int) -> void:
	var key := _gen_key(p_level, seed_value)
	if _generated.has(key) or _gen_tasks.has(key):
		return
	_gen_tasks[key] = WorkerThreadPool.add_task(_generate_job.bind(key, p_level, seed_value), false, "level %d" % p_level)


## Працює у фоновому потоці: лише чиста логіка, без вузлів сцени. Рівні беруться з
## заздалегідь згенерованого пакета (LevelPack); генератор — лише якщо пакета немає.
func _generate_job(key: String, p_level: int, seed_value: int) -> void:
	var packed := LevelPack.level(p_level)
	var g := {"board": packed.board, "params": {"mech": packed.mech}} if not packed.is_empty() else LevelGenerator.generate(p_level, seed_value)
	_deliver_generated.call_deferred(key, g)


func _deliver_generated(key: String, g: Dictionary) -> void:
	if _gen_tasks.has(key):
		WorkerThreadPool.wait_for_task_completion(_gen_tasks[key])
		_gen_tasks.erase(key)
	if _generated.size() > 4:
		_generated.erase(_generated.keys()[0])
	_generated[key] = g
	generation_done.emit(key)


func _generate_async(p_level: int, seed_value: int) -> Dictionary:
	var key := _gen_key(p_level, seed_value)
	_request_generation(p_level, seed_value)
	while not _generated.has(key):
		await generation_done
	var g: Dictionary = _generated[key]
	_generated.erase(key)
	return g


func _exit_tree() -> void:
	for task in _gen_tasks.values():
		WorkerThreadPool.wait_for_task_completion(task)
	_gen_tasks.clear()


# --- Хід -------------------------------------------------------------------

func is_input_locked() -> bool:
	return loading or board == null or _won or _lost or _box_lock > 0


func _on_screw_pressed(s: int) -> void:
	if is_input_locked():
		return
	var sv: ScrewView = board_view.screw_views.get(s)
	if sv == null:
		return
	if not board.is_free(s):
		# Накритий пластиною: легке трясіння.
		sv.shake()
		Sfx.play("blocked")
		Sfx.vibrate(18)
		return
	if not board.can_tap(s):
		sv.shake()
		buffer_view.warn()
		Sfx.play("error")
		return
	var events := board.tap(s)
	moves_made += 1
	_on_moved(s, events)
	_play(events)


func _play(ev: Array) -> void:
	var gen := _gen
	_active += 1
	var changes_boxes := false
	for e in ev:
		if e.t == "close":
			changes_boxes = true
	if changes_boxes:
		_box_lock += 1
	var first: Dictionary = ev[0]
	var s: int = first.s
	# Колір, з яким гвинт відкрутили (хамелеон уже перемкнувся на наступний хід).
	var color: int = first.color
	var p: int = board.screws[s].plate
	var sv: ScrewView = board_view.screw_views[s]
	var pv: PlateView = board_view.plate_views[p]
	board_view.screw_views.erase(s)
	pv.screw_views.erase(s)
	var target_box: BoxView = boxes[first.box] if first.t == "box" else null
	if target_box:
		target_box.pending += 1
	Sfx.play("unscrew", randf_range(0.95, 1.08))
	Sfx.vibrate(12)
	await sv.unscrew(UNSCREW_TIME).finished
	if gen != _gen:
		return
	var from := fly_layer.get_global_transform().affine_inverse() * sv.global_position
	var r_from := ScrewBoard.SCREW_R * board_view.board_scale * 1.22
	sv.queue_free()
	Sfx.play("pop", randf_range(0.95, 1.1))
	# Пластина: падає; хитка на останньому гвинті повертається й звисає;
	# звичайна з одним гвинтом — коротко гойдається на ньому.
	var structural := false
	for e in ev:
		match e.t:
			"fall":
				structural = true
				_drop_plate(pv)
			"swing":
				structural = true
				_swing_plate(pv, int(e.pivot))
	if not structural and pv.screw_views.size() == 1:
		var last: ScrewView = pv.screw_views.values()[0]
		pv.wobble(last.position)
	_refresh_mechanics()
	# Політ.
	var to: Vector2
	if first.t == "box":
		to = _to_fly(target_box.slot_global(first.slot))
	else:
		to = _to_fly(buffer_view.slot_global(first.slot))
	await _fly(color, from, to, r_from, UI_SCREW_R, FLY_TIME)
	if gen != _gen:
		return
	if target_box:
		target_box.land()
		Sfx.play_land(first.slot)
	else:
		buffer_view.set_slot(first.slot, color)
		Sfx.play("tray")
		_on_buffered()
	Sfx.vibrate(8)
	# Заміна коробок і гвинти з буфера.
	for i in range(1, ev.size()):
		var e: Dictionary = ev[i]
		match e.t:
			"close":
				var bx: BoxView = boxes[e.box]
				while bx.pending > 0:
					await bx.landed
				if gen != _gen:
					return
				_box_fx(bx, int(e.color))
				await bx.close_and_leave()
			"safe":
				Sfx.play("safe")
				Sfx.vibrate(25)
				await boxes[e.box].open_safe()
			"arrive":
				await boxes[e.box].arrive(e.color, e.box == 1)
				if e.color >= 0:
					Sfx.play("arrive")
			"pull":
				_pull(e)
				await get_tree().create_timer(0.08).timeout
		if gen != _gen:
			return
	# Дочекатися гвинтів з буфера, що ще летять.
	for b in boxes:
		while b.pending > 0:
			await b.landed
	if gen != _gen:
		return
	if changes_boxes:
		_box_lock -= 1
	_active -= 1
	_after_move()


## Повна коробка: конфеті, звук і вібрація, коли кришка закривається.
func _box_fx(bx: BoxView, color: int) -> void:
	await get_tree().create_timer(0.18).timeout
	BurstFx.spawn(fly_layer, _to_fly(bx.get_global_rect().get_center()), ScrewPainter.color_of(color))
	Sfx.play("box")
	Sfx.vibrate(30)


## Гвинт з буфера летить у нову коробку.
func _pull(e: Dictionary) -> void:
	var bx: BoxView = boxes[e.box]
	bx.pending += 1
	var gen := _gen
	var from := _to_fly(buffer_view.slot_global(e.from))
	buffer_view.clear_slot(e.from)
	var to := _to_fly(bx.slot_global(e.slot))
	await _fly(int(e.color), from, to, UI_SCREW_R, UI_SCREW_R, PULL_TIME)
	if gen != _gen:
		return
	bx.land()
	Sfx.play_land(e.slot)


func _to_fly(global: Vector2) -> Vector2:
	return fly_layer.get_global_transform().affine_inverse() * global


func _fly(color: int, from: Vector2, to: Vector2, r_from: float, r_to: float, duration: float) -> void:
	var f := FlyScrew.new()
	f.color_index = color
	fly_layer.add_child(f)
	await f.fly(from, to, r_from, r_to, duration).finished
	f.queue_free()


## Після ходу: хамелеони перемикаються, лічильники бомб зменшуються (на ≤ 3 — «тік»).
func _refresh_mechanics() -> void:
	var r := board_view.refresh_states()
	if r.flipped > 0:
		Sfx.play("flip")
	if r.hot <= 3:
		Sfx.play("tick")


## Хитка пластина повертається на гвинті `pivot` і звисає вниз (маятник), потім
## звільнені гвинти «підстрибують».
func _swing_plate(pv: PlateView, pivot: int) -> void:
	var piv: ScrewView = pv.screw_views.get(pivot)
	if piv == null:
		return
	var pose := ScrewBoard.swing_pose(board.plates[pv.index], board.screws[pivot].pos)
	if pose.is_empty():
		return
	pv.swing_to(piv.position, float(pose.delta))
	Sfx.play("swing")
	Sfx.vibrate(15)
	await get_tree().create_timer(PlateView.SWING_TIME * 0.5).timeout
	if board == null:
		return
	for s in board_view.screw_views:
		# Гвинти, які пластина накривала до повороту і які тепер вільні.
		if board.is_free(s) and board.covers[s].has(pv.index):
			board_view.screw_views[s].pop()


func _drop_plate(pv: PlateView) -> void:
	board_view.plate_views.erase(pv.index)
	pv.bounced.connect(func() -> void:
		Sfx.play("thud", randf_range(0.9, 1.1))
		Sfx.vibrate(15))
	pv.fall(board_view.floor_y())
	Sfx.play("drop")
	# Гвинти, що звільнилися, коротко «підстрибують».
	await get_tree().create_timer(0.12).timeout
	if board == null:
		return
	for s in board_view.screw_views:
		if board.is_free(s) and board.covers[s].has(pv.index):
			board_view.screw_views[s].pop()
	_refresh_mechanics()


## Перевірка кінця рівня, коли всі анімації скінчились.
func _after_move() -> void:
	if _active > 0 or board == null:
		return
	settled.emit()
	if board.is_won() and not _won:
		_won = true
		_win()
	elif board.exploded and not _lost:
		_lost = true
		_explode()
	elif board.is_stuck() and not _lost:
		_lost = true
		_lose()


func _win() -> void:
	_hide_hand()
	await get_tree().create_timer(0.55).timeout
	Sfx.play("win")
	var stars := 3 if continues == 0 else (2 if continues == 1 else 1)
	var summary := {}
	if debug_play:
		summary = {"level": level, "win_streak": GameState.win_streak, "best_streak": GameState.best_streak, "reward": 0, "stars": stars}
	else:
		summary = GameState.register_win(stars)
	summary["debug"] = debug_play
	level_won.emit(summary)


## Бомба вибухнула: спалах, трясіння поля, вікно «+5 ходів» за рекламу.
func _explode() -> void:
	Sfx.play("boom")
	Sfx.vibrate(120)
	for s in board_view.screw_views:
		if board.is_bomb(s) and board.bomb_left(s) <= 0:
			BurstFx.spawn(fly_layer, _to_fly(board_view.screw_global(s)), Color("ff7a1a"), 40)
	var tw := create_tween()
	var home := board_view.position
	for k in 6:
		tw.tween_property(board_view, "position", home + Vector2(randf_range(-14, 14), randf_range(-10, 10)), 0.04)
	tw.tween_property(board_view, "position", home, 0.05)
	await get_tree().create_timer(0.7).timeout
	if board == null or not _lost:
		return
	var choice: String = await lose_popup.ask(continues < Economy.MAX_CONTINUES, "bomb")
	if choice == "continue":
		continues += 1
		board.add_bomb_moves()
		board_view.refresh_states()
		_lost = false
		Sfx.play("arrive")
	else:
		if not debug_play:
			GameState.break_streak()
		_reset()


func _lose() -> void:
	Sfx.play("error")
	Sfx.vibrate(60)
	buffer_view.warn()
	await get_tree().create_timer(0.6).timeout
	if board == null or not _lost:
		return
	var choice: String = await lose_popup.ask(continues < Economy.MAX_CONTINUES)
	if choice == "continue":
		continues += 1
		board.add_buffer_slot()
		buffer_view.add_slot()
		_lost = false
		Sfx.play("arrive")
	else:
		if not debug_play:
			GameState.break_streak()
		_reset()


func request_exit() -> void:
	Sfx.play("tap")
	if moves_made > 0 and not _won and not debug_play:
		GameState.break_streak()
	_load_id += 1
	loading = false
	_clear()
	exit_requested.emit()


# --- Навчання першого рівня ---------------------------------------------------

func _build_hand() -> void:
	_hand = TextureRect.new()
	_hand.texture = UiTheme.icon("touch_app")
	_hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hand.size = Vector2(96, 96)
	_hand.pivot_offset = Vector2(30, 6)
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand.modulate = Color(1, 1, 1, 0.0)
	add_child(_hand)


func _start_tutorial() -> void:
	var my_load := _load_id
	await get_tree().create_timer(0.6).timeout
	if my_load != _load_id or board == null:
		return
	var first_tap := not GameState.is_tutorial_done("tap") if not debug_play else level == 1
	if not first_tap:
		_show_mechanic_intro()
		return
	# Вільний гвинт, що одразу ляже в коробку.
	for s in board.screw_count():
		if board.is_free(s) and board.box_for(board.color_of(s)) != -1:
			_show_hand(s, tr("TUT_TAP"))
			return


## Знайомство з механікою на рівні, де вона вперше трапилась: затемнення,
## підсвічені цілі й одне речення. Один раз (id механіки → tutorials_done).
func _show_mechanic_intro() -> void:
	for m in Mechanics.LIST:
		var id: String = m.id
		if GameState.is_tutorial_done(id) and not (debug_play and Mechanics.unlock_level(id) == level):
			continue
		var targets := _mechanic_targets(id)
		if targets.is_empty():
			continue
		var gen := _gen
		_tutorial.spotlight(targets, tr(m.text))
		Sfx.play("select")
		await _tutorial.dismissed
		# Закрите виходом чи рестартом (а не торканням) знайомство не зараховується.
		if gen == _gen and not debug_play:
			GameState.mark_tutorial_done(id)
		return


## Глобальні прямокутники, які підсвічує знайомство з механікою.
func _mechanic_targets(id: String) -> Array:
	var out := []
	if board == null:
		return out
	var k := board_view.board_scale
	var side := ScrewBoard.SCREW_R * 2.8 * k
	match id:
		Mechanics.CHAMELEON, Mechanics.BOMB:
			for s in board_view.screw_views:
				var hit := board.is_chameleon(s) if id == Mechanics.CHAMELEON else board.is_bomb(s)
				if hit:
					var c := board_view.screw_global(s)
					if id == Mechanics.BOMB:
						# Разом з лічильником над гвинтом.
						out.append(Rect2(c - Vector2(side, side * 1.6) / 2.0 - Vector2(0, side * 0.3), Vector2(side, side * 1.6)))
					else:
						out.append(Rect2(c - Vector2(side, side) / 2.0, Vector2(side, side)))
		Mechanics.SWING:
			for p in board_view.plate_views:
				if board.swing[p] and not board.plate_gone[p]:
					var pl: Dictionary = board.plates[p]
					var he := LevelGenerator._half_extent(pl.shape, pl.size, pl.rot) * k
					var c: Vector2 = board_view.plates_root.get_global_transform() * Vector2(pl.pos)
					out.append(Rect2(c - he, he * 2.0))
		Mechanics.SAFE:
			for b in boxes:
				if b.is_safe():
					out.append(b.get_global_rect())
	return out


func _show_hand(s: int, text: String) -> void:
	_hand_screw = s
	var at := board_view.screw_global(s) - global_position
	_hand.position = at + Vector2(-18, 8)
	info_label.text = text
	if _hand_tween:
		_hand_tween.kill()
	_hand.modulate.a = 1.0
	_hand_tween = create_tween()
	# Кілька «натискань» пальцем, потім рука просто стоїть (без нескінченної анімації).
	for k in 6:
		_hand_tween.tween_property(_hand, "scale", Vector2(0.86, 0.86), 0.28).set_trans(Tween.TRANS_SINE)
		_hand_tween.tween_property(_hand, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_SINE)


func _hide_hand() -> void:
	if _hand_tween:
		_hand_tween.kill()
		_hand_tween = null
	if _hand:
		_hand.modulate.a = 0.0
	_hand_screw = -1


func _on_moved(_s: int, _events: Array) -> void:
	if _hand_screw != -1:
		_hide_hand()
		info_label.text = ""
		if not debug_play:
			GameState.mark_tutorial_done("tap")


## Перший гвинт у буфері: одноразове пояснення лотка.
func _on_buffered() -> void:
	if buffer_view.used() >= buffer_view.slots.size() - 1:
		buffer_view.warn()
	if not GameState.is_tutorial_done("buffer"):
		info_label.text = tr("TUT_BUFFER")
		if not debug_play:
			GameState.mark_tutorial_done("buffer")
	elif info_label.text == tr("TUT_BUFFER"):
		info_label.text = ""
