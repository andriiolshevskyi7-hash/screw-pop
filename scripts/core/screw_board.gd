class_name ScrewBoard
extends RefCounted
## Чиста логіка поля «відкрути гвинти» (без вузлів сцени): нею користуються і гра,
## і розв'язувач, тож усі правила живуть лише тут.
##
## Поле: пластини (шари, вищий шар накриває нижчі), на кожній — гвинти.
## Гвинт можна відкрутити, лише якщо його не накриває жодна пластина вищого шару.
## Відкручений гвинт летить у активну коробку свого кольору (2 коробки по 3 місця),
## інакше — у буфер (5 місць). Пластина без гвинтів падає. Повна коробка
## закривається і відлітає, на її місце приїжджає наступна з черги й забирає
## з буфера гвинти свого кольору. Перемога — коли впали всі пластини.
## Програш — буфер повний і жоден вільний гвинт не підходить до коробок.

const BUFFER_SIZE := 5
const BOX_CAPACITY := 3
const ACTIVE_BOXES := 2
## Радіус головки гвинта в одиницях поля.
const SCREW_R := 26.0

## Пластини: {"pos": Vector2, "size": Vector2, "rot": float, "shape": "bar"|"disc", "tint": int}.
## Індекс пластини = її шар (вищий індекс лежить вище).
var plates: Array = []
## Гвинти: {"plate": int, "pos": Vector2, "color": int}.
var screws: Array = []
## Черга кольорів коробок (усі коробки рівня по порядку).
var box_queue: PackedInt32Array = PackedInt32Array()
## covers[s] — пластини вищих шарів, що накривають гвинт s.
var covers: Array = []
## plate_screws[p] — гвинти пластини p.
var plate_screws: Array = []

# --- Динамічний стан ---------------------------------------------------------
var removed := PackedByteArray()
var plate_gone := PackedByteArray()
## Скільки гвинтів ще тримає пластину.
var plate_left := PackedInt32Array()
## Слоти буфера: колір або -1.
var buffer := PackedInt32Array()
## Активні коробки: колір (-1 — місце порожнє, черга скінчилась) і заповненість.
var box_color := PackedInt32Array()
var box_count := PackedInt32Array()
var next_box := 0
var plates_left := 0


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
			if shape_distance(plates[q], screws[s].pos) < SCREW_R - 2.0:
				c.append(q)
		covers.append(c)
	reset()


func reset(buffer_size: int = BUFFER_SIZE) -> void:
	removed = PackedByteArray()
	removed.resize(screws.size())
	plate_gone = PackedByteArray()
	plate_gone.resize(plates.size())
	plate_left = PackedInt32Array()
	plates_left = 0
	for p in plates.size():
		plate_left.append(plate_screws[p].size())
		# Пластина без гвинтів (не буває в згенерованих рівнях) одразу вважається впалою.
		if plate_screws[p].is_empty():
			plate_gone[p] = 1
		else:
			plates_left += 1
	buffer = PackedInt32Array()
	buffer.resize(buffer_size)
	buffer.fill(-1)
	box_color = PackedInt32Array()
	box_count = PackedInt32Array()
	next_box = 0
	for b in ACTIVE_BOXES:
		box_color.append(_take_next_box())
		box_count.append(0)


func clone() -> ScrewBoard:
	var c := ScrewBoard.new()
	# Статичні дані спільні (не змінюються під час гри).
	c.plates = plates
	c.screws = screws
	c.box_queue = box_queue
	c.covers = covers
	c.plate_screws = plate_screws
	c.removed = removed.duplicate()
	c.plate_gone = plate_gone.duplicate()
	c.plate_left = plate_left.duplicate()
	c.buffer = buffer.duplicate()
	c.box_color = box_color.duplicate()
	c.box_count = box_count.duplicate()
	c.next_box = next_box
	c.plates_left = plates_left
	return c


func _take_next_box() -> int:
	if next_box >= box_queue.size():
		return -1
	next_box += 1
	return box_queue[next_box - 1]


# --- Запити -----------------------------------------------------------------

func screw_count() -> int:
	return screws.size()


func color_of(s: int) -> int:
	return screws[s].color


func is_free(s: int) -> bool:
	if removed[s]:
		return false
	for q in covers[s]:
		if not plate_gone[q]:
			return false
	return true


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
	return is_free(s) and (box_for(color_of(s)) != -1 or buffer_free() > 0)


func free_screws() -> PackedInt32Array:
	var out := PackedInt32Array()
	for s in screws.size():
		if is_free(s):
			out.append(s)
	return out


func is_won() -> bool:
	return plates_left == 0


## Програш: немає жодного ходу (буфер повний, і вільні гвинти не підходять до коробок).
func is_stuck() -> bool:
	if is_won():
		return false
	for s in screws.size():
		if can_tap(s):
			return false
	return true


func screws_left() -> int:
	var n := 0
	for r in removed:
		if not r:
			n += 1
	return n


# --- Хід ------------------------------------------------------------------

## Відкручує гвинт `s`. Повертає список подій для анімації (по порядку):
##   {"t": "box", "s", "box", "slot"}      — гвинт летить у коробку;
##   {"t": "buf", "s", "slot"}             — гвинт летить у буфер;
##   {"t": "fall", "plate"}                — пластина без гвинтів падає;
##   {"t": "close", "box", "color"}        — повна коробка закривається й відлітає;
##   {"t": "arrive", "box", "color"}       — приїжджає нова коробка (color -1 — більше немає);
##   {"t": "pull", "from", "box", "slot", "color"} — гвинт з буфера летить у нову коробку.
func tap(s: int) -> Array:
	var ev: Array = []
	if not can_tap(s):
		return ev
	var color := color_of(s)
	removed[s] = 1
	var b := box_for(color)
	if b != -1:
		box_count[b] += 1
		ev.append({"t": "box", "s": s, "box": b, "slot": box_count[b] - 1})
	else:
		var slot := buffer.find(-1)
		buffer[slot] = color
		ev.append({"t": "buf", "s": s, "slot": slot})
	var p: int = screws[s].plate
	plate_left[p] -= 1
	if plate_left[p] == 0 and not plate_gone[p]:
		plate_gone[p] = 1
		plates_left -= 1
		ev.append({"t": "fall", "plate": p})
	_resolve_boxes(ev)
	return ev


## Додає слот у буфер (реклама/бустер). Повертає індекс нового слота.
func add_buffer_slot() -> int:
	buffer.append(-1)
	return buffer.size() - 1


## Повні коробки відлітають, нові приїжджають і забирають гвинти з буфера.
func _resolve_boxes(ev: Array) -> void:
	var again := true
	while again:
		again = false
		for b in ACTIVE_BOXES:
			if box_color[b] == -1 or box_count[b] < BOX_CAPACITY:
				continue
			ev.append({"t": "close", "box": b, "color": box_color[b]})
			box_color[b] = _take_next_box()
			box_count[b] = 0
			ev.append({"t": "arrive", "box": b, "color": box_color[b]})
			if box_color[b] == -1:
				continue
			for slot in buffer.size():
				if buffer[slot] == box_color[b] and box_count[b] < BOX_CAPACITY:
					buffer[slot] = -1
					box_count[b] += 1
					ev.append({"t": "pull", "from": slot, "box": b, "slot": box_count[b] - 1, "color": box_color[b]})
			again = true


## Ключ стану для розв'язувача (порядок слотів буфера не важливий).
func state_key() -> String:
	var buf := Array(buffer)
	buf.sort()
	return removed.hex_encode() + "|" + str(buf) + "|" + str(box_color) + str(box_count) + str(next_box)


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


## Для збереження/передачі між потоками.
func to_dict() -> Dictionary:
	return {"plates": plates, "screws": screws, "queue": Array(box_queue)}


static func from_dict(d: Dictionary) -> ScrewBoard:
	var b := ScrewBoard.new()
	b.plates = d.plates
	b.screws = d.screws
	b.box_queue = PackedInt32Array(d.queue)
	b.setup()
	return b
