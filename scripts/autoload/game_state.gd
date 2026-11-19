extends Node
## Прогрес гравця, монети, серія перемог і налаштування.
## Зберігається локально у user://save.json.
## (Перенесено з «Кульок у колбах»; магазин, щоденний бонус і скриня — на етапі 3.)

signal changed
signal coins_changed(coins: int)
signal cosmetics_changed
signal language_changed
signal boosters_changed
signal effects_changed

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

## Підтримувані мови: код → назва мовою оригіналу.
const LANGUAGES := {
	"en": "English",
	"uk": "Українська",
	"de": "Deutsch",
	"fr": "Français",
	"es": "Español",
	"pt": "Português",
	"it": "Italiano",
	"pl": "Polski",
	"cs": "Čeština",
	"tr": "Türkçe",
	"ru": "Русский",
	"id": "Bahasa Indonesia",
	"ja": "日本語",
	"ko": "한국어",
	"zh": "中文",
	"ar": "العربية",
	"hi": "हिन्दी",
}
const FALLBACK_LANGUAGE := "en"

var level := 1
var win_streak := 0
var best_streak := 0
var total_wins := 0
var sound_on := true
var vibration_on := true
var music_on := true
## Режим для дальтоніків: символи на гвинтах.
var colorblind := false
## Покупка «Без реклами» (поки без справжньої оплати): прибирає interstitial.
var no_ads := false
var levels_since_interstitial := 0
## "" — мова як у системі.
var language := ""
var coins := Economy.START_COINS
## Найкраща кількість зірок для кожного пройденого рівня.
var level_stars := {}
## Бустери в запасі: {"slot": n, "undo": n, "hammer": n}.
var boosters := {}
## Пройдені навчання: "tap", далі — механіки.
var tutorials_done: Array = []
## Візуальні ефекти (конфеті, частинки). Вимкнення — для слабких телефонів.
var effects_on := true


func _ready() -> void:
	for id in Economy.BOOSTERS:
		boosters[id] = 0
	load_game()
	ScrewPainter.show_symbols = colorblind
	apply_language()


# --- Збереження -------------------------------------------------------------

func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"level": level,
		"win_streak": win_streak,
		"best_streak": best_streak,
		"total_wins": total_wins,
		"sound_on": sound_on,
		"vibration_on": vibration_on,
		"music_on": music_on,
		"colorblind": colorblind,
		"no_ads": no_ads,
		"levels_since_interstitial": levels_since_interstitial,
		"language": language,
		"coins": coins,
		"level_stars": level_stars,
		"boosters": boosters,
		"tutorials_done": tutorials_done,
		"effects_on": effects_on,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Не вдалося зберегти прогрес: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(data))
	file.close()
	changed.emit()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Пошкоджений файл збереження, починаємо спочатку")
		return
	level = maxi(1, int(data.get("level", 1)))
	win_streak = int(data.get("win_streak", 0))
	best_streak = int(data.get("best_streak", 0))
	total_wins = int(data.get("total_wins", 0))
	sound_on = bool(data.get("sound_on", true))
	vibration_on = bool(data.get("vibration_on", true))
	music_on = bool(data.get("music_on", true))
	colorblind = bool(data.get("colorblind", false))
	no_ads = bool(data.get("no_ads", false))
	levels_since_interstitial = int(data.get("levels_since_interstitial", 0))
	language = str(data.get("language", ""))
	coins = maxi(0, int(data.get("coins", Economy.START_COINS)))
	var saved_boosters = data.get("boosters", {})
	if typeof(saved_boosters) == TYPE_DICTIONARY:
		for id in Economy.BOOSTERS:
			boosters[id] = maxi(0, int(saved_boosters.get(id, 0)))
	var saved_tut = data.get("tutorials_done", [])
	if typeof(saved_tut) == TYPE_ARRAY:
		tutorials_done = saved_tut.duplicate()
	effects_on = bool(data.get("effects_on", true))
	var saved_stars = data.get("level_stars", {})
	if typeof(saved_stars) == TYPE_DICTIONARY:
		level_stars = saved_stars


# --- Монети -----------------------------------------------------------------

func add_coins(amount: int) -> void:
	coins += amount
	save_game()
	coins_changed.emit(coins)


func can_afford(price: int) -> bool:
	return coins >= price


func spend_coins(price: int) -> bool:
	if coins < price:
		return false
	coins -= price
	save_game()
	coins_changed.emit(coins)
	return true


## Скільки рівнів пройдено (основна лінійка).
func completed_levels() -> int:
	return level - 1


# --- Бустери в запасі ------------------------------------------------------

func booster_count(id: String) -> int:
	return int(boosters.get(id, 0))


func add_booster(id: String, amount: int) -> void:
	boosters[id] = booster_count(id) + amount
	save_game()
	boosters_changed.emit()


func use_booster(id: String) -> bool:
	if booster_count(id) <= 0:
		return false
	boosters[id] = booster_count(id) - 1
	save_game()
	boosters_changed.emit()
	return true


# --- Навчання та ефекти -----------------------------------------------------

func is_tutorial_done(id: String) -> bool:
	return tutorials_done.has(id)


func mark_tutorial_done(id: String) -> void:
	if not tutorials_done.has(id):
		tutorials_done.append(id)
		save_game()


func set_effects(on: bool) -> void:
	effects_on = on
	save_game()
	effects_changed.emit()


# --- Мова -------------------------------------------------------------------

func set_language(code: String) -> void:
	language = code
	save_game()
	apply_language()


## Код мови, що реально використовується (з урахуванням «як у системі»).
func resolved_language() -> String:
	if LANGUAGES.has(language):
		return language
	var system := OS.get_locale_language()
	return system if LANGUAGES.has(system) else FALLBACK_LANGUAGE


func apply_language() -> void:
	TranslationServer.set_locale(resolved_language())
	language_changed.emit()


# --- Рівні та серії ---------------------------------------------------------

## Записує перемогу і нараховує монети. Повертає підсумок для екрана перемоги.
func register_win(stars: int = 1) -> Dictionary:
	var finished_level := level
	total_wins += 1
	win_streak += 1
	best_streak = maxi(best_streak, win_streak)
	level += 1
	var reward := Economy.level_reward(win_streak, false, stars)
	coins += reward
	var key := str(finished_level)
	level_stars[key] = maxi(int(level_stars.get(key, 0)), stars)
	save_game()
	coins_changed.emit(coins)
	return {
		"level": finished_level,
		"win_streak": win_streak,
		"best_streak": best_streak,
		"reward": reward,
		# Доплата за rewarded-рекламу (не зменшена): нагорода до знижки.
		"ad_bonus": Economy.level_ad_bonus(win_streak, false, stars),
		"stars": stars,
	}


## Серія переривається, якщо гравець програє, перезапускає або кидає розпочатий рівень.
func break_streak() -> void:
	if win_streak == 0:
		return
	win_streak = 0
	save_game()


func set_sound(on: bool) -> void:
	sound_on = on
	save_game()


func set_colorblind(on: bool) -> void:
	colorblind = on
	ScrewPainter.show_symbols = on
	save_game()
	cosmetics_changed.emit()


func set_no_ads(on: bool) -> void:
	no_ads = on
	save_game()


func set_music(on: bool) -> void:
	music_on = on
	save_game()
	Sfx.update_music()


func set_vibration(on: bool) -> void:
	vibration_on = on
	save_game()


func today_string() -> String:
	return _local_date_string(0)


func yesterday_string() -> String:
	return _local_date_string(-1)


func _local_date_string(day_offset: int) -> String:
	var bias_minutes: int = Time.get_time_zone_from_system().get("bias", 0)
	var local_unix := int(Time.get_unix_time_from_system()) + bias_minutes * 60 + day_offset * 86400
	return Time.get_date_string_from_unix_time(local_unix)
