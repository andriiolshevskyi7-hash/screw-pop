class_name LevelGenerator
extends RefCounted
## Генератор розв'язних рівнів зі зростанням складності.
##
## 1. Пластини кладуться шар за шаром у випадкових місцях і під «гарними» кутами;
##    гвинти не перекриваються між собою, а край вищої пластини або чітко накриває
##    головку гвинта, або чітко її оминає (без двозначних «ледь зачепила»).
## 2. Знаходиться випадковий допустимий порядок відкручування; гвинти по порядку
##    діляться на трійки — кожна трійка отримує колір коробки, черга коробок = порядок трійок.
##    Так рівень завжди розв'язний без буфера. Потім кольори частини гвинтів
##    міняються місцями між близькими трійками («перемішування») — з'являється потреба в буфері.
## 3. Розв'язувач перевіряє, що рівень проходиться з буфером, меншим за справжній
##    (запас для гравця), а симуляція «звичайного гравця» — що складність у потрібних межах.
## Рівні детерміновані: той самий номер дає той самий розклад.

const BOARD_W := 600.0
const BOARD_H := 640.0
const R := ScrewBoard.SCREW_R
## Мінімальна відстань між центрами гвинтів.
const MIN_SCREW_DIST := R * 2.2
const BAR_W := 64.0
## Кількість кольорів пластин (декоративні відтінки, див. ScrewPainter.PLATE_TINTS).
const PLATE_TINTS := 6
const ATTEMPTS := 30
const CASUAL_RUNS := 24


static func seed_for_level(level: int) -> int:
	return hash("screw-pop:%d" % level) & 0x7fffffff


## Параметри складності рівня.
##  screws — скільки гвинтів (кратно 3), colors — кольорів, mix — частка перемішаних гвинтів,
##  cap — з яким буфером рівень мусить розв'язуватись, rate — межі успіху «звичайного гравця»,
##  cover — наскільки охоче пластини накривають гвинти нижчих шарів.
static func params_for_level(level: int) -> Dictionary:
	var p := {}
	if level <= 1:
		p = {"screws": 6, "colors": 2, "mix": 0.0, "cap": 1, "rate": [0.95, 1.0], "cover": 0.3, "max_cover": 2}
	elif level <= 10:
		# Дуже легкі: мало гвинтів, буфер майже не потрібен.
		var k := float(level - 2) / 8.0
		p = {
			"screws": 9 + 3 * int(k * 3.0 + 0.5),
			"colors": 3 if level < 6 else 4,
			"mix": lerpf(0.1, 0.35, k),
			"cap": 2 if level < 6 else 3,
			"rate": [0.85, 1.0],
			"cover": lerpf(0.5, 0.75, k),
			"max_cover": 3,
		}
	else:
		# Плавне зростання; кожен 5-й рівень трохи складніший, наступний — легший.
		var t := float(level - 11)
		var wave := 0.0
		match level % 5:
			0:
				wave = 1.0
			1:
				wave = -0.6
		var lo := 0.75 - t * 0.015 - wave * 0.12
		p = {
			"screws": mini(18 + 3 * int(t / 4.0) + (3 if wave > 0.0 else 0), 36),
			"colors": mini(4 + int(t / 7.0), 8),
			"mix": clampf(0.45 + t * 0.02 + wave * 0.1, 0.3, 1.2),
			"cap": 4,
			"rate": [clampf(lo, 0.15, 0.9), clampf(lo + 0.25, 0.4, 0.97)],
			"cover": clampf(0.8 + t * 0.008, 0.8, 0.95),
			"max_cover": mini(4 + int(t / 10.0), 6),
		}
	p["level"] = level
	return p


## Повертає {"board": Dictionary (ScrewBoard.to_dict), "params", "stats"}.
static func generate(level: int, seed_value: int) -> Dictionary:
	var params := params_for_level(level)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var best: Dictionary = {}
	var best_err := INF
	for attempt in ATTEMPTS:
		var board := _build(rng, params)
		if board == null:
			continue
		var res := Solver.new().solve(_with_cap(board, int(params.cap)), 8000)
		if not res.ok:
			continue
		var rate := Solver.casual_success_rate(board, CASUAL_RUNS, seed_value + attempt)
		var lo: float = params.rate[0]
		var hi: float = params.rate[1]
		var err := maxf(0.0, lo - rate) + maxf(0.0, rate - hi)
		if err < best_err:
			best_err = err
			best = {"board": board.to_dict(), "params": params, "stats": {"rate": rate, "attempt": attempt, "solution": res.moves}}
		if err == 0.0:
			break
	if best.is_empty():
		best = _fallback(rng, params)
	return best


static func _with_cap(board: ScrewBoard, cap: int) -> ScrewBoard:
	var b := board.clone()
	b.reset(cap)
	return b


## Рівень без перемішування (розв'язний без буфера) — на випадок, якщо спроби вичерпано.
static func _fallback(rng: RandomNumberGenerator, params: Dictionary) -> Dictionary:
	var easy := params.duplicate()
	easy.mix = 0.0
	for i in 50:
		var board := _build(rng, easy)
		if board != null and Solver.new().solve(board, 8000).ok:
			return {"board": board.to_dict(), "params": params, "stats": {"rate": 1.0, "attempt": -1}}
	push_error("LevelGenerator: не вдалося згенерувати рівень %d" % params.level)
	return {}


# --- Розклад пластин ------------------------------------------------------------

## Шаблони пластин: розмір і дірки (у локальних координатах).
static func _template(rng: RandomNumberGenerator, big_ok: bool) -> Dictionary:
	var roll := rng.randi() % (7 if big_ok else 6)
	match roll:
		0, 1:
			var l := float(rng.randi_range(9, 15) * 20)
			var hx := l / 2.0 - BAR_W / 2.0
			return {"shape": "bar", "size": Vector2(l, BAR_W), "holes": [Vector2(-hx, 0), Vector2(hx, 0)]}
		2:
			var l := float(rng.randi_range(15, 20) * 20)
			var hx := l / 2.0 - BAR_W / 2.0
			return {"shape": "bar", "size": Vector2(l, BAR_W), "holes": [Vector2(-hx, 0), Vector2(0, 0), Vector2(hx, 0)]}
		3:
			var s := 150.0
			var h := s / 2.0 - 38.0
			return {"shape": "bar", "size": Vector2(s, s), "holes": [Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]}
		4:
			var hx := 230.0 / 2.0 - 38.0
			var hy := 150.0 / 2.0 - 38.0
			return {"shape": "bar", "size": Vector2(230, 150), "holes": [Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)]}
		5:
			var d := 160.0
			var holes := []
			var n := 3
			for i in n:
				holes.append(Vector2.from_angle(TAU * i / n - PI / 2.0) * 44.0)
			return {"shape": "disc", "size": Vector2(d, d), "holes": holes}
		_:
			var hx := 340.0 / 2.0 - 40.0
			var hy := 180.0 / 2.0 - 40.0
			return {"shape": "bar", "size": Vector2(340, 180), "holes": [Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)]}


const ANGLES_BAR := [0.0, 90.0, 30.0, -30.0, 45.0, -45.0, 60.0, -60.0, 0.0, 90.0]
const ANGLES_BOX := [0.0, 0.0, 15.0, -15.0, 45.0, 90.0]


## Половина габариту повернутої пластини.
static func _half_extent(shape: String, size: Vector2, rot: float) -> Vector2:
	if shape == "disc":
		return size * 0.5
	var c := absf(cos(rot))
	var s := absf(sin(rot))
	var h := size * 0.5
	return Vector2(c * h.x + s * h.y, s * h.x + c * h.y)


## Будує поле без кольорів (кольори — у _colorize). null — не вдалося.
static func _build(rng: RandomNumberGenerator, params: Dictionary) -> ScrewBoard:
	var target: int = params.screws
	var plates: Array = []
	var screws: Array = []
	var tries := 0
	# Компактна область: чим менше гвинтів, тим менша, щоб пластини лягали одна на одну.
	var k := clampf(sqrt(float(target) / 42.0), 0.62, 1.0)
	var region := Rect2(Vector2(BOARD_W, BOARD_H) * (1.0 - k) * 0.5, Vector2(BOARD_W, BOARD_H) * k)
	while screws.size() < target and tries < 900:
		tries += 1
		var tpl := _template(rng, plates.size() < 2 and target >= 15)
		var rot := 0.0
		if tpl.shape == "disc":
			rot = deg_to_rad(rng.randf_range(0.0, 120.0))
		elif tpl.size.y == BAR_W:
			rot = deg_to_rad(ANGLES_BAR[rng.randi() % ANGLES_BAR.size()])
		else:
			rot = deg_to_rad(ANGLES_BOX[rng.randi() % ANGLES_BOX.size()])
		var he := _half_extent(tpl.shape, tpl.size, rot)
		if he.x * 2.0 > BOARD_W - 8.0 or he.y * 2.0 > BOARD_H - 8.0:
			continue
		var pos := Vector2(rng.randf_range(region.position.x, region.end.x), rng.randf_range(region.position.y, region.end.y))
		# Частіше кладемо пластину на вже покладений гвинт — так з'являються шари.
		if not screws.is_empty() and rng.randf() < float(params.cover):
			var under: Vector2 = screws[rng.randi() % screws.size()].pos
			pos = under + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(10.0, minf(he.x, he.y) + 30.0)
		pos.x = snappedf(clampf(pos.x, he.x + 4.0, BOARD_W - he.x - 4.0), 10.0)
		pos.y = snappedf(clampf(pos.y, he.y + 4.0, BOARD_H - he.y - 4.0), 10.0)
		var plate := {"pos": pos, "size": tpl.size, "rot": rot, "shape": tpl.shape, "tint": rng.randi() % PLATE_TINTS}
		var holes := []
		for h in tpl.holes:
			holes.append(pos + (h as Vector2).rotated(rot))
		if not _fits(plate, holes, plates, screws):
			continue
		# Скільки вже покладених гвинтів накриває нова пластина: з шаром складність росте,
		# але перші пластини кладуться вільно.
		var covered := 0
		for s in screws:
			if ScrewBoard.shape_distance(plate, s.pos) < R:
				covered += 1
		if plates.size() >= 2 and covered == 0 and rng.randf() < float(params.cover):
			continue
		if covered > int(params.get("max_cover", 3)):
			continue
		var idx := plates.size()
		plates.append(plate)
		for h in holes:
			screws.append({"plate": idx, "pos": h, "color": 0})
	# Замало місця — пробуємо інший розклад (рівень не має бути меншим за задуманий).
	if screws.size() < maxi(6, target - 2):
		return null
	# Кількість гвинтів — кратна 3 і не більша за ціль: зайві знімаємо спершу з пластин,
	# де їх ≥ 3 (планка з одним гвинтом на краю виглядає дивно), в крайньому разі — де 2.
	var guard := 0
	while (screws.size() % 3 != 0 or screws.size() > target) and guard < 160:
		guard += 1
		var i := rng.randi() % screws.size()
		var p: int = screws[i].plate
		var on_plate := 0
		for s in screws:
			if s.plate == p:
				on_plate += 1
		if on_plate >= (3 if guard < 100 else 2):
			screws.remove_at(i)
	if screws.size() % 3 != 0:
		return null
	var board := ScrewBoard.new()
	board.plates = plates
	board.screws = screws
	board.box_queue = PackedInt32Array()
	board.setup()
	if not _colorize(rng, board, params):
		return null
	return board


## Перевіряє, що гвинти не налазять один на одного, а край нової пластини не «ледь
## зачіпає» головки гвинтів нижчих шарів.
static func _fits(plate: Dictionary, holes: Array, plates: Array, screws: Array) -> bool:
	for h in holes:
		for s in screws:
			if (h as Vector2).distance_to(s.pos) < MIN_SCREW_DIST:
				return false
	for s in screws:
		var d := ScrewBoard.shape_distance(plate, s.pos)
		if d > R - 12.0 and d < R + 8.0:
			return false
	return true


## Розфарбовує гвинти й будує чергу коробок (див. опис класу).
static func _colorize(rng: RandomNumberGenerator, board: ScrewBoard, params: Dictionary) -> bool:
	var n := board.screw_count()
	var boxes := n / 3
	# Випадковий допустимий порядок відкручування (без урахування кольорів).
	var order := PackedInt32Array()
	var gone := PackedByteArray()
	gone.resize(board.plates.size())
	var left := PackedInt32Array()
	for p in board.plates.size():
		left.append(board.plate_screws[p].size())
	var removed := PackedByteArray()
	removed.resize(n)
	while order.size() < n:
		var free := []
		for s in n:
			if removed[s]:
				continue
			var ok := true
			for q in board.covers[s]:
				if not gone[q]:
					ok = false
					break
			if ok:
				free.append(s)
		if free.is_empty():
			return false
		var s: int = free[rng.randi() % free.size()]
		removed[s] = 1
		order.append(s)
		var p: int = board.screws[s].plate
		left[p] -= 1
		if left[p] == 0:
			gone[p] = 1
	# Кольори коробок: усі кольори по черзі, без двох однакових поспіль.
	var ncolors := mini(int(params.colors), boxes)
	var palette := range(ScrewPainter.COLORS.size())
	_shuffle(rng, palette)
	palette = palette.slice(0, ncolors)
	var queue := PackedInt32Array()
	var bag := []
	for i in boxes:
		if bag.is_empty():
			bag = palette.duplicate()
			_shuffle(rng, bag)
			if not queue.is_empty() and bag[0] == queue[queue.size() - 1] and bag.size() > 1:
				bag.append(bag.pop_front())
		queue.append(bag.pop_front())
	var colors := PackedInt32Array()
	colors.resize(n)
	for i in n:
		colors[order[i]] = queue[i / 3]
	# Перемішування: обмін кольорами гвинтів із близьких трійок.
	var swaps := int(round(float(params.mix) * n))
	var window := 2 + int(float(params.mix) * 6.0)
	for k in swaps:
		var a := rng.randi() % n
		var b := clampi(a + rng.randi_range(-window * 3, window * 3), 0, n - 1)
		var t := colors[order[a]]
		colors[order[a]] = colors[order[b]]
		colors[order[b]] = t
	for s in n:
		board.screws[s].color = colors[s]
	board.box_queue = queue
	board.reset()
	return true


static func _shuffle(rng: RandomNumberGenerator, arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t
