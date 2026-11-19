extends SceneTree
## Проходить гру натисканнями: меню → рівень 1 (з навчанням) → перемога → «Далі» →
## рівень 2; потім програш (буфер заповнено), «+1 місце» за рекламу (заглушка) і «Спробувати ще».
## Запуск: godot --headless --script res://tests/smoke_test.gd
## З дисплеєм (xvfb-run) ще й зберігає знімки екрана в build/shots/.

var main
var game
var failed := false
var shots := DisplayServer.get_name() != "headless"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Знімкам потрібні кадри навіть «у спокої».
	if shots:
		OS.low_processor_usage_mode = false
	var gs = root.get_node("GameState")
	gs.level = 1
	gs.tutorials_done = []
	gs.coins = 200
	gs.win_streak = 0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	game = main.get_node("Game")
	await create_timer(1.2).timeout
	await _shot("01_menu")
	main.get_node("Menu").play_button.pressed.emit()
	await _wait_loaded()
	await create_timer(1.0).timeout
	_check(game._hand.modulate.a > 0.5, "рівень 1: показано руку-підказку")
	await _shot("02_level1_tutorial")
	await _solve_level()
	await create_timer(1.6).timeout
	var win = main.get_node("WinScreen")
	_check(win.visible, "після розв'язання — екран перемоги")
	_check(gs.level == 2, "рівень збільшився до 2")
	_check(gs.coins > 200, "нараховано монети (%d)" % gs.coins)
	_check(gs.is_tutorial_done("tap"), "навчання першого ходу пройдено")
	await _shot("03_win")
	win._on_next()
	await _wait_loaded()
	await create_timer(0.8).timeout
	_check(game.level == 2 and game.visible, "«Далі» відкриває рівень 2")
	# Рівні 3–30: генеруються, розв'язуються солвером через натискання.
	for lvl in [5, 12, 30]:
		game.start_level(lvl)
		await _wait_loaded()
		await create_timer(0.6).timeout
		if lvl == 30:
			await _shot("04_level30")
		await _solve_level(lvl == 12)
		await create_timer(1.6).timeout
		_check(win.visible, "рівень %d пройдено через натискання" % lvl)
		win.hide()
	# Механіки: на рівні відкриття — знайомство (підсвітка + речення), рівень проходиться.
	gs.tutorials_done = ["tap", "buffer"]
	for m in Mechanics.LIST:
		var lvl: int = m.from
		game.start_level(lvl)
		await _wait_loaded()
		await create_timer(1.4).timeout
		_check(game._tutorial.visible, "рівень %d: знайомство з механікою «%s»" % [lvl, m.id])
		await _shot("07_intro_%s" % m.id)
		game._tutorial.dismiss()
		_check(gs.is_tutorial_done(m.id), "знайомство «%s» записано" % m.id)
		if m.id == Mechanics.SAFE:
			_check(game.boxes[1].is_safe() and game.board.box_color[1] == ScrewBoard.SAFE, "рівень %d: одне місце закрите сейфом" % lvl)
		if m.id == Mechanics.SWING:
			_check(game.board.swing_plates.size() == 1, "рівень %d: одна хитка пластина" % lvl)
		await _solve_level(true)
		await create_timer(1.6).timeout
		_check(win.visible, "рівень %d з механікою «%s» пройдено" % [lvl, m.id])
		win.hide()
	# Бомба: граємо, не чіпаючи бомбу, — вибух, вікно «+5 ходів», продовження.
	game.start_level(Mechanics.unlock_level(Mechanics.BOMB))
	await _wait_loaded()
	await create_timer(1.0).timeout
	game._tutorial.dismiss()
	var guard_b := 0
	while not game.lose_popup.visible and guard_b < 120:
		guard_b += 1
		var pick := -1
		for s in game.board.screw_count():
			if game.board.can_tap(s) and not game.board.is_bomb(s):
				pick = s
				if game.board.box_for(game.board.color_of(s)) != -1:
					break
		if pick == -1 or game.is_input_locked():
			await create_timer(0.2).timeout
			continue
		game._on_screw_pressed(pick)
		await _settle()
	await create_timer(1.2).timeout
	_check(game.board.exploded and game.lose_popup.visible, "бомба вибухнула — вікно програшу")
	_check(game.lose_popup.title_label.text == tr("BOOM"), "вікно вибуху: «%s»" % game.lose_popup.title_label.text)
	await _shot("09_boom")
	game.lose_popup._answer("continue")
	await create_timer(1.0).timeout
	var bomb_ok := false
	for s in game.board.screw_count():
		if game.board.is_bomb(s) and not game.board.removed[s] and game.board.bomb_left(s) == ScrewBoard.BOMB_CONTINUE_MOVES:
			bomb_ok = true
	_check(bomb_ok and not game.board.exploded, "+5 ходів бомбі після реклами")
	# Поєднання механік.
	game.start_level(120)
	await _wait_loaded()
	await create_timer(1.0).timeout
	await _shot("08_combo")
	await _solve_level(true)
	await create_timer(1.6).timeout
	_check(win.visible, "рівень 120 (поєднання механік) пройдено")
	win.hide()
	# Програш: кладемо в буфер усе, що не йде в коробку.
	game.start_level(_losing_level())
	await _wait_loaded()
	await create_timer(0.6).timeout
	var guard := 0
	while not game.lose_popup.visible and guard < 200:
		guard += 1
		var s := _worst_move()
		if s == -1:
			await create_timer(0.3).timeout
			continue
		game._on_screw_pressed(s)
		await _settle()
	await create_timer(0.3).timeout
	print("  (програш: ходів %d, буфер %s, виграно %s, застряг %s)" % [guard, game.board.buffer, game._won, game.board.is_stuck()])
	_check(game.lose_popup.visible, "буфер заповнено — вікно програшу")
	await _shot("05_lose")
	var slots_before: int = game.board.buffer.size()
	game.lose_popup._answer("continue")
	await create_timer(1.0).timeout
	_check(game.board.buffer.size() == slots_before + 1, "+1 місце в буфері за рекламу")
	_check(game.buffer_view.slots.size() == slots_before + 1, "у лотку з'явилось нове гніздо")
	await _shot("06_continue")
	game.restart()
	await create_timer(0.5).timeout
	_check(game.board.buffer.size() == ScrewBoard.BUFFER_SIZE and game.board.screws_left() == game.board.screw_count(), "рестарт повертає початковий стан")
	# Накритий гвинт: трясеться, хід не робиться.
	for s in game.board.screw_count():
		if not game.board.is_free(s):
			var before: int = game.board.screws_left()
			game._on_screw_pressed(s)
			_check(game.board.screws_left() == before, "накритий гвинт не відкручується")
			break
	game.request_exit()
	await create_timer(0.5).timeout
	_check(main.get_node("Menu").visible, "вихід у меню")
	print("SMOKE FAILED" if failed else "SMOKE OK")
	quit(1 if failed else 0)


func _wait_loaded() -> void:
	while game.loading or game.board == null:
		await process_frame


func _settle() -> void:
	await process_frame
	var guard := 0
	while (game._active > 0 or game._box_lock > 0) and guard < 600:
		guard += 1
		await process_frame


## Грає розв'язок солвера натисканнями. `fast` — не чекати кінця анімацій між ходами
## (лише поки ввід не заблоковано), як гравець, що швидко тапає.
func _solve_level(fast: bool = false) -> void:
	var res := Solver.new().solve(game.board, 30000)
	_check(res.ok, "рівень %d розв'язний" % game.level)
	for s in res.moves:
		var guard := 0
		while game.is_input_locked() and guard < 600:
			guard += 1
			await process_frame
		game._on_screw_pressed(s)
		if fast:
			await create_timer(0.05).timeout
		else:
			await _settle()
	await _settle()


## Рівень, який «найгірша» гра (усе, що можна, — у буфер) програє: шукаємо, а не
## хардкодимо номер — інакше тест ламався б з кожною зміною генератора.
func _losing_level() -> int:
	for lvl in range(15, 120):
		var g := LevelGenerator.generate(lvl, LevelGenerator.seed_for_level(lvl))
		var b := ScrewBoard.from_dict(g.board)
		while not b.is_won() and not b.is_stuck():
			var pick := -1
			var any := -1
			for s in b.screw_count():
				if b.can_tap(s):
					if b.box_for(b.color_of(s)) == -1:
						pick = s
						break
					any = s
			b.tap(pick if pick != -1 else any)
		if b.is_stuck():
			print("  (програш перевіряється на рівні %d)" % lvl)
			return lvl
	return 26


## Найгірший хід: вільний гвинт, що не йде в коробку (інакше — будь-який вільний).
func _worst_move() -> int:
	if game.is_input_locked():
		return -1
	var b: ScrewBoard = game.board
	var any := -1
	for s in b.screw_count():
		if b.can_tap(s):
			if b.box_for(b.color_of(s)) == -1:
				return s
			any = s
	return any


func _shot(name: String) -> void:
	if not shots:
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/shots"))
	img.save_png(ProjectSettings.globalize_path("res://build/shots/%s.png" % name))


func _check(cond: bool, what: String) -> void:
	failed = failed or not cond
	print("  %s: %s" % ["ok" if cond else "FAIL", what])
