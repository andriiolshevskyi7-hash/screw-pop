class_name ScrewBoard
extends RefCounted
## Чиста логіка поля «відкрути гвинти» (без вузлів сцени): нею користуються і гра,
## і розв'язувач, і генератор, тож усі правила живуть лише тут.
##
## Поле: пластини (шари, вищий шар накриває нижчі), на кожній — гвинти.
## Гвинт можна відкрутити, лише якщо його не накриває жодна пластина вищого шару.
## Відкручений гвинт летить у активну коробку свого кольору (2 коробки по 3 місця),
## інакше — у буфер (5 місць). Пластина без гвинтів падає. Повна коробка
## закривається і відлітає, на її місце приїжджає наступна з черги й забирає
## з буфера гвинти свого кольору. Перемога — коли впали всі пластини.
## Програш — буфер повний і жоден вільний гвинт не підходить до коробок, або вибухнула бомба.
##
## Механіки (вводяться поступово, див. Mechanics) — кожна змінює порядок відкручування
## або тиск на буфер і коробки:
##  - хитка пластина (`swing`): коли на ній лишається один гвинт, вона провертається
##    на ньому й звисає вертикально вниз — нове положення накриває/відкриває інші гвинти;
##  - гвинт-хамелеон (`colors` = [a, b]): після кожного ходу перемикає колір
##    (на парному ході — a, на непарному — b); летить у коробку свого поточного кольору;
##  - бомба (`bomb` = N): якщо гвинт не відкрутити за N ходів — програш;
##  - сейф (`safe` = {"slot", "color"}): одне з двох місць коробок закрите, доки не
##    заповнено коробку кольору сейфа.
##
## `blind` (лише для генератора): механіки з цього списку вважаються відсутніми —
## так перевіряється, що механіку не можна проігнорувати.

const BUFFER_SIZE := 5
const BOX_CAPACITY := 3
const ACTIVE_BOXES := 2
## Радіус головки гвинта в одиницях поля.
const SCREW_R := 26.0
## Колір місця, закритого сейфом.
const SAFE := -2
## Скільки ходів додає продовження після вибуху бомби.
const BOMB_CONTINUE_MOVES := 5

## Пластини: {"pos": Vector2, "size": Vector2, "rot": float, "shape": "bar"|"disc", "tint": int,
##            "swing": bool (необов'язково)}. Індекс пластини = її шар (вищий індекс лежить вище).
var plates: Array = []
## Гвинти: {"plate": int, "pos": Vector2, "color": int,
##          "colors": [a, b] (хамелеон, необов'язково), "bomb": int (необов'язково)}.
var screws: Array = []
## Черга кольорів коробок (усі коробки рівня по порядку).
var box_queue: PackedInt32Array = PackedInt32Array()
## Сейф: {} або {"slot": int, "color": int}.
var safe: Dictionary = {}
## Механіки, яких «не існує» (перевірка генератора): "swing", "chameleon", "bomb", "safe".
var blind: Dictionary = {}

## covers[s] — пластини вищих шарів, що накривають гвинт s у початковому положенні.
var covers: Array = []
## plate_screws[p] — гвинти пластини p.
var plate_screws: Array = []
## Хиткі пластини і їхні положення: swing_cover[q][k] — множина гвинтів (нижчих шарів),
## які накриває пластина q, коли висить на гвинті k ({} — не повертається на ньому).
var swing_plates := PackedInt32Array()
var swing_cover := {}
var swing := PackedByteArray()
## Хамелеони: cham_a/cham_b (-1 — звичайний гвинт); бомби: bomb_n (0 — не бомба).
var cham_a := PackedInt32Array()
var cham_b := PackedInt32Array()
var bomb_n := PackedInt32Array()

# --- Динамічний стан ---------------------------------------------------------
var removed := PackedByteArray()
var plate_gone := PackedByteArray()
## Скільки гвинтів ще тримає пластину.
var plate_left := PackedInt32Array()
## Положення хиткої пластини: -1 — початкове, інакше — гвинт, на якому вона висить.
var plate_pose := PackedInt32Array()
## Слоти буфера: колір або -1.
var buffer := PackedInt32Array()
## Активні коробки: колір (-1 — черга скінчилась, SAFE — сейф) і заповненість.
var box_color := PackedInt32Array()
var box_count := PackedInt32Array()
var next_box := 0
var plates_left := 0
## Скільки ходів зроблено (хамелеони й бомби).
var moves := 0
## Додаткові ходи бомбам (продовження за рекламу).
var bomb_extra := 0
var exploded := false
var _screws_left := 0
## Хамелеонів і бомб ще на полі (поки є — порядок ходів важливий для розв'язувача).
var _dyn_left := 0


## Обчислює накриття і скидає динамічний стан до початкового.
func setup() -> void:
	plate_screws = []
	for p in plates.size():
		plate_screws.append(PackedInt32Array())
	for s in screws.size():
		plate_screws[int(screws[s].plate)].append(s)
	covers = []
	for s in screws.size():
		var c := PackedInt32Array()
		var own: int = screws[s].plate
		for q in range(own + 1, plates.size()):
			if covers_point(plates[q], screws[s].pos):
				c.append(q)
		covers.append(c)
	swing = PackedByteArray()
	swing_plates = PackedInt32Array()
	swing_cover = {}
	for p in plates.size():
		var on := bool(plates[p].get("swing", false))
		swing.append(1 if on else 0)
		if on:
			swing_plates.append(p)
			var poses := {}
			for k in plate_screws[p]:
				var pose := swing_pose(plates[p], screws[k].pos)
				if pose.is_empty():
					continue
				var hung: Dictionary = plates[p].duplicate()
				hung.pos = pose.pos
				hung.rot = pose.rot
				var set := {}
				for s in screws.size():
					if int(screws[s].plate) < p and covers_point(hung, screws[s].pos):
						set[s] = true
				poses[k] = set
			swing_cover[p] = poses
	cham_a = PackedInt32Array()
	cham_b = PackedInt32Array()
	bomb_n = PackedInt32Array()
	for s in screws.size():
		var cols: Array = screws[s].get("colors", [])
		cham_a.append(int(cols[0]) if cols.size() == 2 else -1)
		cham_b.append(int(cols[1]) if cols.size() == 2 else -1)
		bomb_n.append(int(screws[s].get("bomb", 0)))
	reset()


func reset(buffer_size: int = BUFFER_SIZE) -> void:
	removed = PackedByteArray()
	removed.resize(screws.size())
	plate_gone = PackedByteArray()
	plate_gone.resize(plates.size())
	plate_left = PackedInt32Array()
	plate_pose = PackedInt32Array()
	plates_left = 0
	_screws_left = screws.size()
	_dyn_left = 0
	for s in screws.size():
		if is_chameleon(s) or is_bomb(s):
			_dyn_left += 1
	for p in plates.size():
		plate_left.append(plate_screws[p].size())
		plate_pose.append(-1)
		if plate_screws[p].is_empty():
			plate_gone[p] = 1
		else:
			plates_left += 1
	buffer = PackedInt32Array()
	buffer.resize(buffer_size)
	buffer.fill(-1)
	moves = 0
	bomb_extra = 0
	exploded = false
	box_color = PackedInt32Array()
	box_count = PackedInt32Array()
	next_box = 0
	for b in ACTIVE_BOXES:
		box_color.append(-1)
		box_count.append(0)
	for b in ACTIVE_BOXES:
		box_color[b] = SAFE if has_safe() and b == int(safe.slot) else _take_next_box()


func clone() -> ScrewBoard:
	var c := ScrewBoard.new()
	# Статичні дані спільні (не змінюються під час гри).
	c.plates = plates
	c.screws = screws
	c.box_queue = box_queue
	c.safe = safe
	c.blind = blind
	c.covers = covers
	c.plate_screws = plate_screws
	c.swing_plates = swing_plates
	c.swing_cover = swing_cover
	c.swing = swing
	c.cham_a = cham_a
	c.cham_b = cham_b
	c.bomb_n = bomb_n
	c.removed = removed.duplicate()
	c.plate_gone = plate_gone.duplicate()
	c.plate_left = plate_left.duplicate()
	c.plate_pose = plate_pose.duplicate()
	c.buffer = buffer.duplicate()
	c.box_color = box_color.duplicate()
	c.box_count = box_count.duplicate()
	c.next_box = next_box
	c.plates_left = plates_left
	c.moves = moves
	c.bomb_extra = bomb_extra
	c.exploded = exploded
	c._screws_left = _screws_left
	c._dyn_left = _dyn_left
	return c


func _take_next_box() -> int:
	if next_box >= box_queue.size():
		return -1
	next_box += 1
	return box_queue[next_box - 1]


# --- Запити -----------------------------------------------------------------

func screw_count() -> int:
	return screws.size()


func has_safe() -> bool:
	return not safe.is_empty() and not blind.has("safe")


func is_chameleon(s: int) -> bool:
	return cham_a[s] >= 0 and not blind.has("chameleon")


func is_bomb(s: int) -> bool:
	return bomb_n[s] > 0 and not blind.has("bomb")


## Поточний колір гвинта (хамелеон: a на парному ході, b — на непарному).
func color_of(s: int) -> int:
	if is_chameleon(s):
		return cham_a[s] if moves % 2 == 0 else cham_b[s]
	if cham_a[s] >= 0:
		return cham_a[s]  # «сліпа» модель: хамелеон завжди першого кольору
	return screws[s].color


## Колір хамелеона на наступному ході (для показу другої половини).
func other_color_of(s: int) -> int:
	return cham_b[s] if moves % 2 == 0 else cham_a[s]


## Скільки ходів лишилось до вибуху бомби (поки вона на полі).
func bomb_left(s: int) -> int:
	return bomb_n[s] + bomb_extra - moves


func is_free(s: int) -> bool:
	return not removed[s] and not is_covered(s)


## Гвинт накритий пластиною вищого шару (з урахуванням повернутих хитких пластин).
func is_covered(s: int) -> bool:
	for q in covers[s]:
		if not plate_gone[q] and plate_pose[q] == -1:
			return true
	for q in swing_plates:
		var k := plate_pose[q]
		if k >= 0 and not plate_gone[q] and swing_cover[q][k].has(s):
			return true
	return false


## Коробка, у яку полетить гвинт кольору `color` (або -1).
func box_for(color: int) -> int:
	for b in ACTIVE_BOXES:
		if box_color[b] == color and box_count[b] < BOX_CAPACITY:
			return b
	return -1


func buffer_free() -> int:
	var n := 0
	for c in buffer:
		if c == -1:
			n += 1
	return n


func buffer_used() -> int:
	return buffer.size() - buffer_free()


## Гвинт можна відкрутити: він вільний і йому є куди летіти.
func can_tap(s: int) -> bool:
	return not exploded and is_free(s) and (box_for(color_of(s)) != -1 or buffer_free() > 0)


func free_screws() -> PackedInt32Array:
	var out := PackedInt32Array()
	for s in screws.size():
		if is_free(s):
			out.append(s)
	return out


func is_won() -> bool:
	return plates_left == 0 and _screws_left == 0 and not exploded


## Програш через буфер: немає жодного ходу.
func is_stuck() -> bool:
	if is_won() or exploded:
		return false
	for s in screws.size():
		if can_tap(s):
			return false
	return true


func is_lost() -> bool:
	return exploded or is_stuck()


func screws_left() -> int:
	return _screws_left


## Хід без «пам'яті»: не повертає пластину й на полі немає хамелеонів і бомб.
## Лише для таких ходів розв'язувач може класти гвинт у коробку без розгалуження.
func is_quiet(s: int) -> bool:
	if _dyn_left > 0:
		return false
	var p: int = screws[s].plate
	return not (swing[p] and plate_left[p] == 2 and not blind.has("swing"))


# --- Хід -------------------------------------------------------------------

## Відкручує гвинт `s`. Повертає список подій для анімації (по порядку):
##   {"t": "box", "s", "box", "slot", "color"} — гвинт летить у коробку;
##   {"t": "buf", "s", "slot", "color"}        — гвинт летить у буфер;
##   {"t": "swing", "plate", "pivot"}           — хитка пластина повисла на гвинті pivot;
##   {"t": "fall", "plate"}                     — пластина без гвинтів падає;
##   {"t": "close", "box", "color"}             — повна коробка закривається й відлітає;
##   {"t": "safe", "box"}                       — сейф відкрито;
##   {"t": "arrive", "box", "color"}            — приїжджає нова коробка (color -1 — більше немає);
##   {"t": "pull", "from", "box", "slot", "color"} — гвинт з буфера летить у коробку;
##   {"t": "boom", "s"}                         — бомба вибухнула (програш).
func tap(s: int) -> Array:
	var ev: Array = []
	if not can_tap(s):
		return ev
	var color := color_of(s)
	var b := box_for(color)
	if b != -1:
		box_count[b] += 1
		ev.append({"t": "box", "s": s, "box": b, "slot": box_count[b] - 1, "color": color})
	else:
		var slot := buffer.find(-1)
		buffer[slot] = color
		ev.append({"t": "buf", "s": s, "slot": slot, "color": color})
	remove_structural(s, ev)
	_resolve_boxes(ev)
	moves += 1
	for k in screws.size():
		if not removed[k] and is_bomb(k) and bomb_left(k) <= 0:
			exploded = true
			ev.append({"t": "boom", "s": k})
			break
	return ev


## Структурна частина ходу (без коробок і буфера): гвинт знято, хитка пластина
## повертається, порожня — падає. Генератор нею ж шукає допустимий порядок відкручування.
func remove_structural(s: int, ev: Array) -> void:
	removed[s] = 1
	_screws_left -= 1
	if is_chameleon(s) or is_bomb(s):
		_dyn_left -= 1
	var p: int = screws[s].plate
	plate_left[p] -= 1
	if plate_left[p] == 0:
		plate_gone[p] = 1
		plates_left -= 1
		ev.append({"t": "fall", "plate": p})
	elif plate_left[p] == 1 and swing[p] and not blind.has("swing"):
		for k in plate_screws[p]:
			if not removed[k] and swing_cover[p].has(k):
				plate_pose[p] = k
				ev.append({"t": "swing", "plate": p, "pivot": k})


## Додає слот у буфер (реклама/бустер). Повертає індекс нового слота.
func add_buffer_slot() -> int:
	buffer.append(-1)
	return buffer.size() - 1


## Продовження після вибуху: бомбам +5 ходів.
func add_bomb_moves(n: int = BOMB_CONTINUE_MOVES) -> void:
	bomb_extra += n
	exploded = false


## Повні коробки відлітають, нові приїжджають і забирають гвинти з буфера;
## повна коробка кольору сейфа відкриває сейф.
func _resolve_boxes(ev: Array) -> void:
	var again := true
	while again:
		again = false
		for b in ACTIVE_BOXES:
			if box_color[b] < 0 or box_count[b] < BOX_CAPACITY:
				continue
			var closed := box_color[b]
			ev.append({"t": "close", "box": b, "color": closed})
			_fill_slot(b, ev)
			if has_safe() and box_color[int(safe.slot)] == SAFE and closed == int(safe.color):
				ev.append({"t": "safe", "box": int(safe.slot)})
				_fill_slot(int(safe.slot), ev)
			again = true


func _fill_slot(b: int, ev: Array) -> void:
	box_color[b] = _take_next_box()
	box_count[b] = 0
	ev.append({"t": "arrive", "box": b, "color": box_color[b]})
	if box_color[b] < 0:
		return
	for slot in buffer.size():
		if buffer[slot] == box_color[b] and box_count[b] < BOX_CAPACITY:
			buffer[slot] = -1
			box_count[b] += 1
			ev.append({"t": "pull", "from": slot, "box": b, "slot": box_count[b] - 1, "color": box_color[b]})


## Ключ стану для розв'язувача (порядок слотів буфера не важливий).
func state_key() -> String:
	var buf := Array(buffer)
	buf.sort()
	var key := removed.hex_encode() + "|" + str(buf) + "|" + str(box_color) + str(box_count) + str(next_box)
	if _dyn_left > 0:
		key += "|%d" % moves
	return key


# --- Геометрія --------------------------------------------------------------

## Знакова відстань від точки до пластини (від'ємна — всередині).
static func shape_distance(plate: Dictionary, point: Vector2) -> float:
	var center: Vector2 = plate.pos
	var size: Vector2 = plate.size
	var local: Vector2 = (point - center).rotated(-float(plate.rot))
	if plate.shape == "disc":
		return local.length() - size.x * 0.5
	var half: Vector2 = size * 0.5
	var r := minf(half.x, half.y)  # «пігулка»/закруглений прямокутник
	r = minf(r, 44.0)
	var q: Vector2 = local.abs() - half + Vector2(r, r)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r


static func covers_point(plate: Dictionary, point: Vector2) -> bool:
	return shape_distance(plate, point) < SCREW_R - 2.0


## Положення хиткої пластини, що висить на гвинті в точці `pivot`: центр пластини
## точно під гвинтом. {} — центр збігається з гвинтом (повертатися нікуди).
static func swing_pose(plate: Dictionary, pivot: Vector2) -> Dictionary:
	var v: Vector2 = Vector2(plate.pos) - pivot
	if v.length() < 12.0:
		return {}
	var delta := wrapf(PI / 2.0 - v.angle(), -PI, PI)
	return {"pos": pivot + v.rotated(delta), "rot": float(plate.rot) + delta, "delta": delta}


## Для збереження/передачі між потоками.
func to_dict() -> Dictionary:
	return {"plates": plates, "screws": screws, "queue": Array(box_queue), "safe": safe}


static func from_dict(d: Dictionary) -> ScrewBoard:
	var b := ScrewBoard.new()
	b.plates = d.plates
	b.screws = d.screws
	b.box_queue = PackedInt32Array(d.queue)
	b.safe = d.get("safe", {})
	b.setup()
	return b
