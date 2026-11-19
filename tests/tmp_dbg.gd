extends SceneTree
func _initialize():
	for level in [20, 30, 48, 61, 73, 95, 110]:
		var params := LevelGenerator.params_for_level(level)
		var rng := RandomNumberGenerator.new()
		rng.seed = LevelGenerator.seed_for_level(level)
		var stats := {"null": 0, "unsolved": 0, "aborted": 0, "bomb": 0, "ignorable": {}, "ok": 0}
		var t0 := Time.get_ticks_msec()
		for a in 40:
			var board := LevelGenerator._build(rng, params)
			if board == null:
				stats["null"] += 1
				continue
			var res := Solver.new().solve(LevelGenerator._with_cap(board, int(params.cap)), 8000)
			if not res.ok:
				stats["aborted" if res.aborted else "unsolved"] += 1
				continue
			if params.mech.has("bomb"):
				res = LevelGenerator._place_bombs(rng, board, int(params.mech["bomb"]), int(params.cap), res.moves)
				if not res.ok:
					stats["bomb"] += 1
					continue
			var bad := ""
			for id in params.mech.keys():
				if not LevelGenerator.mechanics_matter(board, [id], rng):
					bad = id
					break
			if bad != "":
				stats.ignorable[bad] = int(stats.ignorable.get(bad, 0)) + 1
				continue
			stats["ok"] += 1
		print(level, " ", params.mech, " cap ", params.cap, " ", stats, " ", Time.get_ticks_msec() - t0, " ms")
	quit()
