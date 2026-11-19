class_name Mechanics
extends RefCounted
## Поступове введення механік (підхід з «Кульок у колбах»). Кожна механіка
## відкривається на своєму рівні; на ньому показується коротке знайомство
## (підсвітка + одне речення), id механіки записується в `GameState.tutorials_done`.
## Якщо гравець пропустив знайомство (debug-перехід, старша версія), воно з'явиться
## на першому рівні, де механіка трапиться.
##
## Після відкриття — 8 рівнів «передиху»: рівень легший, нова механіка в малій кількості.
## На рівні знайомства інших механік немає; старі повертаються поступово.
## Після передиху за останньою механікою (з 103-го рівня) механіки поєднуються.

const LOCK := "lock"
const GLASS := "glass"
const HIDDEN := "hidden"
const CHAIN := "chain"

## У порядку відкриття. `text` — ключ перекладу (одне речення знайомства).
const LIST := [
	{"id": LOCK, "from": 20, "text": "MECH_LOCK"},
	{"id": GLASS, "from": 45, "text": "MECH_GLASS"},
	{"id": HIDDEN, "from": 70, "text": "MECH_HIDDEN"},
	{"id": CHAIN, "from": 95, "text": "MECH_CHAIN"},
]

const RELIEF_LEVELS := 8

## Кількість на рівні знайомства / зростання (рівнів на +1) / межа до поєднань / межа в поєднаннях.
const AMOUNTS := {
	LOCK: {"intro": 1, "every": 10, "max": 3, "combo_max": 4},
	GLASS: {"intro": 1, "every": 12, "max": 2, "combo_max": 3},
	HIDDEN: {"intro": 2, "every": 6, "max": 6, "combo_max": 8},
	CHAIN: {"intro": 1, "every": 20, "max": 2, "combo_max": 2},
}


static func find(id: String) -> Dictionary:
	for m in LIST:
		if m.id == id:
			return m
	return {}


static func unlock_level(id: String) -> int:
	return int(find(id).get("from", 1 << 30))


static func combo_from() -> int:
	return unlock_level(CHAIN) + RELIEF_LEVELS


## Наймолодша вже відкрита механіка і скільки рівнів минуло з її відкриття (-1 — жодної).
static func latest_intro(level: int) -> Dictionary:
	var out := {"id": "", "since": -1}
	for m in LIST:
		if level >= int(m.from):
			out = {"id": m.id, "since": level - int(m.from)}
	return out


## Рівень знайомства з будь-якою механікою.
static func is_intro_level(level: int) -> bool:
	return latest_intro(level).since == 0


## 0…1: наскільки рівень полегшено як «передих» (1 — рівень знайомства, 0 — звичайний).
static func relief(level: int) -> float:
	var li := latest_intro(level)
	if li.since < 0 or li.since > RELIEF_LEVELS:
		return 0.0
	return 1.0 - float(li.since) / float(RELIEF_LEVELS + 1)


## Скільки елементів механіки `id` на рівні (0 — механіки немає).
static func amount(id: String, level: int) -> int:
	var from := unlock_level(id)
	if level < from:
		return 0
	var a: Dictionary = AMOUNTS[id]
	var since := level - from
	if since == 0:
		return int(a.intro)
	var combo := level >= combo_from()
	var n := mini(int(a.intro) + since / int(a.every), int(a.max))
	if combo:
		n = mini(int(a.combo_max), n + (level - combo_from()) / 40)
	var li := latest_intro(level)
	if li.id != id:
		# Інша механіка щойно відкрилась: на її рівні знайомства цієї немає,
		# далі вона повертається по 1 за 2 рівні.
		if li.since >= 0 and li.since <= RELIEF_LEVELS:
			n = mini(n, li.since / 2)
		# До поєднань старі механіки трапляються приблизно на половині рівнів.
		elif not combo and _roll(id, level) < 0.5:
			n = 0
		elif combo and _roll(id, level) < 0.25:
			n = 0
	return n


## Детермінований «кидок» 0…1 для механіки на рівні.
static func _roll(id: String, level: int) -> float:
	# hash() схожих рядків дає близькі молодші біти — перемішуємо через ГВЧ.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d" % [id, level])
	return rng.randf()


## Усі механіки рівня: {id: кількість} (лише ненульові).
static func for_level(level: int) -> Dictionary:
	var out := {}
	for m in LIST:
		var n := amount(m.id, level)
		if n > 0:
			out[m.id] = n
	return out
