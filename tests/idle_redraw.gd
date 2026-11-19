extends SceneTree
## Регресійний тест енергоспоживання (з «Кульок у колбах»): коли на екрані нічого
## не відбувається, гра нічого не оновлює покадрово, і кадри не малюються.
## Запуск: godot --headless --script res://tests/idle_redraw.gd
##
## Перевіряє в меню і на ігровому екрані:
##  - увімкнено low processor mode, FPS обмежено до 60;
##  - у спокої немає жодного вузла з увімкненим `_process` і жодного активного твіна;
##  - з реальним рендером (не headless) — майже 0 намальованих кадрів за 3 с;
##  - після ходу (відкручування, падіння пластини, заміна коробки) усе знову зупиняється.

const MAX_IDLE_FPS := 3.0

var main
var failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(OS.low_processor_usage_mode, "low processor mode увімкнено")
	_check(Engine.max_fps == 60, "FPS обмежено до 60")
	var gs = root.get_node("GameState")
	gs.tutorials_done = ["tap", "buffer"]
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	# Після показу меню: «вкручування» ілюстрації й пульсація кнопки скінчаться.
	await create_timer(6.0).timeout
	await _idle("меню")
	main._start(3)
	var game = main.get_node("Game")
	while game.loading:
		await process_frame
	await create_timer(2.0).timeout
	await _idle("гра")
	# Кілька ходів розв'язку: анімації вмикаються, а потім усе знову стоїть.
	var res := Solver.new().solve(game.board, 20000)
	for i in mini(6, res.moves.size()):
		while game.is_input_locked():
			await process_frame
		game._on_screw_pressed(res.moves[i])
		await create_timer(0.05).timeout
	await create_timer(0.1).timeout
	_check(get_processed_tweens().size() > 0, "під час ходу анімації працюють")
	await create_timer(4.0).timeout
	await _idle("гра після ходів")
	# Хитка пластина: маятник працює покадрово, а потім зупиняється.
	main._start(Mechanics.unlock_level(Mechanics.SWING))
	while game.loading:
		await process_frame
	await create_timer(1.0).timeout
	game._tutorial.dismiss()
	var swung := false
	for s in LevelPack.level(game.level).solution:
		while game.is_input_locked():
			await process_frame
		var events: Array = game.board.clone().tap(s)
		game._on_screw_pressed(s)
		await create_timer(0.3).timeout
		if events.any(func(e) -> bool: return e.t == "swing"):
			swung = true
			var busy := []
			_collect_processing(root, busy)
			_check(not busy.is_empty(), "маятник хиткої пластини працює")
			break
	_check(swung, "хитка пластина повернулась")
	await create_timer(4.0).timeout
	await _idle("гра після маятника")
	print("IDLE REDRAW FAILED" if failed else "IDLE REDRAW OK")
	quit(1 if failed else 0)


func _idle(label: String) -> void:
	var busy := []
	_collect_processing(root, busy)
	_check(busy.is_empty(), "%s: у спокої немає вузлів з _process %s" % [label, busy])
	var tweens := get_processed_tweens().size()
	_check(tweens == 0, "%s: у спокої немає активних твінів (%d)" % [label, tweens])
	if DisplayServer.get_name() == "headless":
		return
	var f0 := Engine.get_frames_drawn()
	var t0 := Time.get_ticks_msec()
	await create_timer(3.0).timeout
	var fps := (Engine.get_frames_drawn() - f0) / ((Time.get_ticks_msec() - t0) / 1000.0)
	_check(fps <= MAX_IDLE_FPS, "%s: у спокої %.1f кадрів/с" % [label, fps])


func _collect_processing(node: Node, out: Array) -> void:
	if node.is_processing() or node.is_physics_processing():
		out.append(str(node.get_path()).replace("/root/", ""))
	for child in node.get_children():
		_collect_processing(child, out)


func _check(cond: bool, what: String) -> void:
	failed = failed or not cond
	print("  %s: %s" % ["ok" if cond else "FAIL", what])
