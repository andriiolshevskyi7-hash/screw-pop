class_name Solver
extends RefCounted
## Розв'язувач (пошук у глибину з пам'яттю станів). Працює лише через правила
## ScrewBoard (can_tap / tap), тож враховує буфер, сейф, хиткі пластини (нове
## накриття після повороту), хамелеонів (колір залежить від ходу) і бомби (термін).
##
## Скорочення перебору: якщо вільний гвинт підходить до активної коробки і хід
## «спокійний» (ScrewBoard.is_quiet: не повертає пластину, на полі немає хамелеонів
## і бомб), його відкручування ніколи не шкодить — такі ходи робляться без розгалуження.
## Інакше перебираються всі ходи, спершу — у коробки.

var max_nodes := 20000
var nodes := 0
var aborted := false
## Якщо задано — рівні за оцінкою ходи перебираються у випадковому порядку
## (генератор шукає кілька різних розв'язків «сліпої» моделі).
var rng: RandomNumberGenerator
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


## Чи існує послідовність ходів, що виграє одночасно на двох полях (`a` — «сліпа»
## модель без механіки, `b` — справжні правила). Ходи однакові для обох, стан — пара.
## Так генератор перевіряє, що механіку не можна проігнорувати: гравець, який грає так,
## ніби механіки немає, не може виграти жодним способом.
## Повертає {"ok": bool, "aborted": bool, "moves": PackedInt32Array}.
func solve_both(a: ScrewBoard, b: ScrewBoard, budget: int) -> Dictionary:
	max_nodes = budget
	nodes = 0
	aborted = false
	_seen = {}
	_moves = PackedInt32Array()
	var ok := _dfs_both(a.clone(), b.clone())
	return {"ok": ok, "aborted": aborted, "moves": _moves.duplicate() if ok else PackedInt32Array()}


func _dfs_both(a: ScrewBoard, b: ScrewBoard) -> bool:
	if a.is_won() and b.is_won():
		return true
	if a.exploded or b.exploded:
		return false
	var key := a.state_key() + "#" + b.state_key()
	if _seen.has(key):
		return false
	_seen[key] = true
	nodes += 1
	if nodes > max_nodes:
		aborted = true
		return false
	for s in _ordered_candidates(a):
		if not b.can_tap(s):
			continue
		var ca := a.clone()
		var cb := b.clone()
		ca.tap(s)
		cb.tap(s)
		_moves.append(s)
		if _dfs_both(ca, cb):
			return true
		_moves.resize(_moves.size() - 1)
		if aborted:
			break
	return false


## Програє ходи за правилами поля: чи привели вони до перемоги.
static func replay(board: ScrewBoard, moves: PackedInt32Array) -> bool:
	var b := board.clone()
	for s in moves:
		if not b.can_tap(s):
			return false
		b.tap(s)
		if b.exploded:
			return false
	return b.is_won()


func _dfs(b: ScrewBoard) -> bool:
	var mark := _moves.size()
	_play_forced(b)
	if b.is_won():
		return true
	if b.exploded:
		_moves.resize(mark)
		return false
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


## Відкручує всі вільні «спокійні» гвинти, що підходять до коробок (повторно, поки є).
func _play_forced(b: ScrewBoard) -> void:
	var again := true
	while again:
		again = false
		for s in b.screw_count():
			if b.is_free(s) and b.is_quiet(s) and b.box_for(b.color_of(s)) != -1:
				b.tap(s)
				_moves.append(s)
				again = true


## Кандидати: спершу ходи в коробки, потім у буфер — ті, що відкривають поле,
## скоро знадобляться або рятують бомбу.
func _ordered_candidates(b: ScrewBoard) -> Array:
	var scored := []
	var seen_dup := {}
	var dyn := b._dyn_left > 0
	for s in b.screw_count():
		if not b.can_tap(s):
			continue
		var color := b.color_of(s)
		var p: int = b.screws[s].plate
		# Однакові за кольором звичайні гвинти однієї пластини взаємозамінні — лишаємо один.
		if not dyn and not b.swing[p]:
			var dup := "%d:%d" % [p, color]
			if seen_dup.has(dup):
				continue
			seen_dup[dup] = true
		var score := 0.0
		if b.box_for(color) != -1:
			score += 20.0
		if b.plate_left[p] == 1:
			score += 6.0  # пластина впаде й щось відкриє
		score -= float(b.plate_left[p])
		if b.is_bomb(s):
			score += 30.0 / maxf(1.0, float(b.bomb_left(s)))
		var dist := 99
		for i in range(b.next_box, b.box_queue.size()):
			if b.box_queue[i] == color:
				dist = i - b.next_box
				break
		score -= dist * 1.5
		if b.buffer.has(color):
			score += 2.0
		if rng:
			score += rng.randf() * 3.0
		scored.append([score, s])
	scored.sort_custom(func(a, c) -> bool: return a[0] > c[0])
	var out := []
	for e in scored:
		out.append(e[1])
	return out


## Частка успіхів «звичайного гравця»: рятує бомбу, коли лишилось ≤ 3 ходи,
## кладе гвинт у коробку, якщо може, інакше відкручує випадковий вільний гвинт.
## Міра легкості рівня.
static func casual_success_rate(board: ScrewBoard, runs: int, seed_value: int) -> float:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	var wins := 0
	for run in runs:
		var b := board.clone()
		while not b.is_won() and not b.exploded:
			var urgent := -1
			var to_box := PackedInt32Array()
			var any := PackedInt32Array()
			for s in b.screw_count():
				if not b.can_tap(s):
					continue
				if b.is_bomb(s) and b.bomb_left(s) <= 3:
					urgent = s
				if b.box_for(b.color_of(s)) != -1:
					to_box.append(s)
				else:
					any.append(s)
			if urgent != -1:
				b.tap(urgent)
			elif not to_box.is_empty():
				b.tap(to_box[r.randi() % to_box.size()])
			elif not any.is_empty():
				b.tap(any[r.randi() % any.size()])
			else:
				break
		if b.is_won():
			wins += 1
	return float(wins) / runs
