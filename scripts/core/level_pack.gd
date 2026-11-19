class_name LevelPack
extends RefCounted
## Заздалегідь згенеровані рівні (res://levels/pack.json).
##
## Генератор з перевіркою механік (розв'язувач + «сліпі» розв'язувачі) для рівнів з
## механіками працює десятки секунд — на телефоні це неприйнятно. Тому рівні 1…N
## генеруються заздалегідь (tests/build_pack.gd) і постачаються з грою разом з
## розв'язком; tests/pack_test.gd у CI перевіряє кожен.
## Рівні після N беруться по колу з останніх CYCLE_FROM…N з переставленими
## кольорами (механікам кольори байдужі, тож рівень лишається перевіреним).

const PATH := "res://levels/pack.json"
## З якого рівня беруться рівні «по колу» (поєднання механік).
const CYCLE_FROM := 103

static var _levels: Array = []
static var _loaded := false
static var _mutex := Mutex.new()


static func size() -> int:
	_load()
	return _levels.size()


## Рівень з пакета: {"board": словник для ScrewBoard.from_dict, "mech": {...},
## "solution": PackedInt32Array, "source": номер рівня в пакеті} або {} (пакета немає).
static func level(n: int) -> Dictionary:
	_load()
	if _levels.is_empty() or n < 1:
		return {}
	var count := _levels.size()
	if n <= count:
		return _decode(_levels[n - 1], -1)
	var from := mini(CYCLE_FROM, count)
	var span := count - from + 1
	var source := from + (n - count - 1) % span
	return _decode(_levels[source - 1], n)


static func _load() -> void:
	_mutex.lock()
	if not _loaded:
		_loaded = true
		if FileAccess.file_exists(PATH):
			var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
			if typeof(data) == TYPE_ARRAY:
				_levels = data
			else:
				push_warning("LevelPack: пошкоджений %s" % PATH)
	_mutex.unlock()


# --- Кодування (JSON не зберігає Vector2) --------------------------------------------

static func encode(board_dict: Dictionary, mech: Dictionary, solution: PackedInt32Array) -> Dictionary:
	var plates := []
	for p in board_dict.plates:
		var e := {"pos": [p.pos.x, p.pos.y], "size": [p.size.x, p.size.y], "rot": snappedf(p.rot, 0.00001), "shape": p.shape, "tint": p.tint}
		if p.get("swing", false):
			e["swing"] = true
		plates.append(e)
	var screws := []
	for s in board_dict.screws:
		var e := {"plate": s.plate, "pos": [s.pos.x, s.pos.y], "color": s.color}
		if s.has("colors"):
			e["colors"] = s.colors
		if s.has("bomb"):
			e["bomb"] = s.bomb
		screws.append(e)
	return {"plates": plates, "screws": screws, "queue": board_dict.queue, "safe": board_dict.get("safe", {}), "mech": mech, "solution": Array(solution)}


## `recolor` > 0 — номер рівня, для якого переставити кольори (рівні «по колу»).
static func _decode(e: Dictionary, recolor: int) -> Dictionary:
	var perm := range(ScrewPainter.COLORS.size())
	if recolor > 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("screw-pop-recolor:%d" % recolor)
		for i in range(perm.size() - 1, 0, -1):
			var j := rng.randi() % (i + 1)
			var t = perm[i]
			perm[i] = perm[j]
			perm[j] = t
	var plates := []
	for p in e.plates:
		var d := {"pos": Vector2(p.pos[0], p.pos[1]), "size": Vector2(p.size[0], p.size[1]), "rot": float(p.rot), "shape": str(p.shape), "tint": int(p.tint)}
		if p.get("swing", false):
			d["swing"] = true
		plates.append(d)
	var screws := []
	for s in e.screws:
		var d := {"plate": int(s.plate), "pos": Vector2(s.pos[0], s.pos[1]), "color": perm[int(s.color)]}
		if s.has("colors"):
			d["colors"] = [perm[int(s.colors[0])], perm[int(s.colors[1])]]
		if s.has("bomb"):
			d["bomb"] = int(s.bomb)
		screws.append(d)
	var queue := []
	for c in e.queue:
		queue.append(perm[int(c)])
	var safe := {}
	if not (e.safe as Dictionary).is_empty():
		safe = {"slot": int(e.safe.slot), "color": perm[int(e.safe.color)]}
	var mech := {}
	for k in e.mech:
		mech[k] = int(e.mech[k])
	return {
		"board": {"plates": plates, "screws": screws, "queue": queue, "safe": safe},
		"mech": mech,
		"solution": PackedInt32Array(e.solution),
	}
