extends SceneTree
## Перевіряє пакет рівнів (res://levels/pack.json):
##  - кожен рівень проходиться збереженим розв'язком за справжніми правилами;
##  - механіки — ті, що задумані для рівня (Mechanics.for_level), не раніше свого рівня,
##    на рівні знайомства — лише нова; кожного кольору гвинтів — під коробки;
##  - для кожного 5-го рівня з механіками (і всіх рівнів знайомства) — що механіку не
##    можна проігнорувати (LevelGenerator.mechanics_matter);
##  - рівні після кінця пакета (по колу, з іншими кольорами) теж проходяться.
## Запуск: godot --headless --script res://tests/pack_test.gd

const MIN_LEVELS := 150


func _initialize() -> void:
	var failed := false
	var n := LevelPack.size()
	print("pack: %d levels" % n)
	if n < MIN_LEVELS:
		print("PACK TOO SMALL")
		failed = true
	var t0 := Time.get_ticks_msec()
	for level in range(1, n + 31):
		var e := LevelPack.level(level)
		var board := ScrewBoard.from_dict(e.board)
		if not Solver.replay(board, e.solution):
			print("level %d: stored solution does not win" % level)
			failed = true
		var found := _count(board)
		if level <= n:
			if found != Mechanics.for_level(level) or found != e.mech:
				print("level %d: mechanics %s, want %s" % [level, found, Mechanics.for_level(level)])
				failed = true
			if Mechanics.is_intro_level(level) and found.size() != 1:
				print("level %d: intro level with other mechanics %s" % [level, found])
				failed = true
		var per := {}
		for i in board.screw_count():
			var c: int = board.screws[i].color
			per[c] = int(per.get(c, 0)) + 1
		if not found.has("chameleon"):
			for c in per:
				if per[c] % 3 != 0:
					print("level %d: colour %d count %d" % [level, c, per[c]])
					failed = true
		if not found.is_empty() and (level % 5 == 0 or Mechanics.is_intro_level(level)) and level <= n:
			if not LevelGenerator.mechanics_matter(board, found.keys()):
				print("level %d: a mechanic can be ignored %s" % [level, found])
				failed = true
	print("checked in %d ms" % (Time.get_ticks_msec() - t0))
	print("PACK FAILED" if failed else "PACK OK")
	quit(1 if failed else 0)


func _count(board: ScrewBoard) -> Dictionary:
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
	return found
