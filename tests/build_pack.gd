extends SceneTree
## Генерує рівні для пакета (res://levels/pack.json) — запускається вручну, не в CI:
##   godot --headless --script res://tests/build_pack.gd -- <від> <до> <файл.jsonl>
## Кожен рядок — рівень у форматі LevelPack.encode. Якщо генератор не вклався й
## поставив менше механік, ніж задумано, пробуються інші сіди (до 8). Потім файли
## частин зливаються в pack.json (див. levels/README.md).

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var from := int(args[0])
	var to := int(args[1])
	var out := FileAccess.open(args[2], FileAccess.WRITE)
	for level in range(from, to + 1):
		var want := Mechanics.for_level(level)
		var t0 := Time.get_ticks_msec()
		var best: Dictionary = {}
		for k in 8:
			var seed_value := LevelGenerator.seed_for_level(level) + k * 7777
			var g := LevelGenerator.generate(level, seed_value)
			if g.is_empty():
				continue
			if best.is_empty() or (g.params.mech as Dictionary).size() > (best.params.mech as Dictionary).size():
				best = g
			if g.params.mech == want:
				break
		var board := ScrewBoard.from_dict(best.board)
		var sol: PackedInt32Array = best.stats.get("solution", PackedInt32Array())
		if sol.is_empty() or not Solver.replay(board, sol):
			sol = Solver.new().solve(board, 60000).moves
		var line := JSON.stringify(LevelPack.encode(best.board, best.params.mech, sol))
		out.store_line(line)
		out.flush()
		print("level %d mech %s (want %s) %d ms" % [level, best.params.mech, want, Time.get_ticks_msec() - t0])
	out.close()
	quit()
