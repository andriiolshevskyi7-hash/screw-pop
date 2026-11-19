extends SceneTree
## Генерує рівні й перевіряє, що кожен розв'язний (розв'язувач з урахуванням буфера).
## Запуск: godot --headless --script res://tests/generator_test.gd [-- from to]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var from := 1
	var to := 30
	if args.size() >= 2:
		from = int(args[0])
		to = int(args[1])
	var failed := false
	var t_total := 0
	for level in range(from, to + 1):
		var t0 := Time.get_ticks_msec()
		var g := LevelGenerator.generate(level, LevelGenerator.seed_for_level(level))
		var ms := Time.get_ticks_msec() - t0
		t_total += ms
		if g.is_empty():
			print("level %d: FAILED to generate" % level)
			failed = true
			continue
		var board := ScrewBoard.from_dict(g.board)
		var res := Solver.new().solve(board, 30000)
		var cap := Solver.min_buffer(board)
		var colors := {}
		for s in board.screws:
			colors[s.color] = true
		print("level %3d: plates %2d screws %2d colors %d boxes %2d  min buffer %d  casual %.2f (want %.2f-%.2f) attempt %d  %d ms" % [
			level, board.plates.size(), board.screw_count(), colors.size(), board.box_queue.size(),
			cap, g.stats.rate, g.params.rate[0], g.params.rate[1], g.stats.attempt, ms])
		if not res.ok:
			print("   NOT SOLVABLE")
			failed = true
		# Кожного кольору — кратно 3, коробок рівно стільки, скільки трійок.
		var per := {}
		for s in board.screws:
			per[s.color] = int(per.get(s.color, 0)) + 1
		var qper := {}
		for c in board.box_queue:
			qper[c] = int(qper.get(c, 0)) + 3
		if per != qper:
			print("   COLOR COUNTS MISMATCH ", per, qper)
			failed = true
		# Механіки: стільки, скільки задано, не раніше свого рівня; на рівні знайомства — лише нова.
		var found := {}
		for pl in board.plates:
			if pl.get("swing", false):
				found["swing"] = int(found.get("swing", 0)) + 1
		for sc in board.screws:
			if (sc.get("colors", []) as Array).size() == 2:
				found["chameleon"] = int(found.get("chameleon", 0)) + 1
			if int(sc.get("bomb", 0)) > 0:
				found["bomb"] = int(found.get("bomb", 0)) + 1
		if not board.safe.is_empty():
			found["safe"] = 1
		if found != g.params.mech:
			print("   MECHANICS MISMATCH want %s got %s" % [g.params.mech, found])
			failed = true
		# Механіку не можна проігнорувати: розв'язки моделі без неї не проходять рівень.
		if not found.is_empty():
			var rng := RandomNumberGenerator.new()
			rng.seed = level * 7 + 3
			if not LevelGenerator.mechanics_matter(board, found.keys(), rng):
				print("   MECHANIC CAN BE IGNORED ", found)
				failed = true
		for m in Mechanics.LIST:
			if found.has(m.id) and level < int(m.from):
				print("   MECHANIC %s BEFORE LEVEL %d" % [m.id, m.from])
				failed = true
		if Mechanics.is_intro_level(level) and found.size() != 1:
			print("   INTRO LEVEL WITH OTHER MECHANICS ", found)
			failed = true
		if not found.is_empty():
			print("   mech ", found)
		# Детермінованість.
		if level <= from + 2:
			var g2 := LevelGenerator.generate(level, LevelGenerator.seed_for_level(level))
			if str(g2.board) != str(g.board):
				print("   NOT DETERMINISTIC")
				failed = true
	print("total %d ms" % t_total)
	print("GENERATOR FAILED" if failed else "GENERATOR OK")
	quit(1 if failed else 0)
