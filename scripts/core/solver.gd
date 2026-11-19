class_name Solver
extends RefCounted
## Розв'язувач (пошук у глибину з пам'яттю станів). Працює лише через правила
## ScrewBoard (can_tap / tap), тож враховує буфер і всі механіки поля.
##
## Скорочення перебору: якщо вільний гвинт підходить до активної коробки, його
## відкручування ніколи не шкодить (поле лише відкривається, буфер не займається),
## тож такі ходи робляться одразу без розгалуження. Розгалуження — лише на ходах
## у буфер.

var max_nodes := 20000
var nodes := 0
var aborted := false
var _seen := {}
var _moves := PackedInt32Array()


## Повертає {"ok": bool, "moves": PackedInt32Array, "nodes": int, "aborted": bool}.
func solve(board: ScrewBoard, budget: int = 20000) -> Dictionary:
	max_nodes = budget
	nodes = 0
	aborted = false
	_seen = {}
	_moves = PackedInt32Array()
	var ok := _dfs(board.clone())
	return {"ok": ok, "moves": _moves.duplicate() if ok else PackedInt32Array(), "nodes": nodes, "aborted": aborted}


## Найменший розмір буфера, з яким рівень розв'язний (1…max_cap), або -1.
static func min_buffer(board: ScrewBoard, max_cap: int = ScrewBoard.BUFFER_SIZE, budget: int = 6000) -> int:
	for cap in range(1, max_cap + 1):
		var b := board.clone()
		b.reset(cap)
		var res := Solver.new().solve(b, budget)
		if res.ok:
			return cap
	return -1


func _dfs(b: ScrewBoard) -> bool:
	var mark := _moves.size()
	_play_forced(b)
	if b.is_won():
		return true
	var key := b.state_key()
	if _seen.has(key):
		_moves.resize(mark)
		return false
	_seen[key] = true
	nodes += 1
	if nodes > max_nodes:
		aborted = true
		_moves.resize(mark)
		return false
	if b.buffer_free() == 0:
		_moves.resize(mark)
		return false
	for s in _ordered_candidates(b):
		var c := b.clone()
		c.tap(s)
		_moves.append(s)
		if _dfs(c):
			return true
		_moves.resize(_moves.size() - 1)
		if aborted:
			break
	_moves.resize(mark)
	return false


## Відкручує всі вільні гвинти, що підходять до коробок (повторно, поки є).
func _play_forced(b: ScrewBoard) -> void:
	var again := true
	while again:
		again = false
		for s in b.screw_count():
			if b.is_free(s) and b.box_for(b.color_of(s)) != -1:
				b.tap(s)
				_moves.append(s)
				again = true


## Кандидати в буфер — спершу ті, що відкривають поле або скоро знадобляться.
func _ordered_candidates(b: ScrewBoard) -> Array:
	var scored := []
	var seen_colors_plates := {}
	for s in b.screw_count():
		if not b.is_free(s):
			continue
		var color := b.color_of(s)
		var p: int = b.screws[s].plate
		# Однакові за кольором гвинти однієї пластини взаємозамінні — лишаємо один.
		var dup := "%d:%d" % [p, color]
		if seen_colors_plates.has(dup):
			continue
		seen_colors_plates[dup] = true
		var score := 0.0
		if b.plate_left[p] == 1:
			score += 6.0  # пластина впаде й щось відкриє
		score -= float(b.plate_left[p])
		# Наскільки скоро колір з'явиться в черзі коробок.
		var dist := 99
		for i in range(b.next_box, b.box_queue.size()):
			if b.box_queue[i] == color:
				dist = i - b.next_box
				break
		score -= dist * 1.5
		if b.buffer.has(color):
			score += 2.0
		scored.append([score, s])
	scored.sort_custom(func(a, c) -> bool: return a[0] > c[0])
	var out := []
	for e in scored:
		out.append(e[1])
	return out


## Частка успіхів «звичайного гравця»: він завжди кладе гвинт у коробку,
## якщо може, інакше відкручує випадковий вільний гвинт. Міра легкості рівня.
static func casual_success_rate(board: ScrewBoard, runs: int, seed_value: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var wins := 0
	for r in runs:
		var b := board.clone()
		while not b.is_won():
			var to_box := PackedInt32Array()
			var any := PackedInt32Array()
			for s in b.screw_count():
				if not b.is_free(s):
					continue
				if b.box_for(b.color_of(s)) != -1:
					to_box.append(s)
				elif b.buffer_free() > 0:
					any.append(s)
			if not to_box.is_empty():
				b.tap(to_box[rng.randi() % to_box.size()])
			elif not any.is_empty():
				b.tap(any[rng.randi() % any.size()])
			else:
				break
		if b.is_won():
			wins += 1
	return float(wins) / runs
