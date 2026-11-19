extends Node
## Менеджер реклами (автозавантаження `AdManager`).
##
## На Android працює через нативний плагін Poing Studios godot-admob-android
## (Java-синглтони PoingGodotAdMob*), який додається в збірку експорт-плагіном
## addons/admob_export. Усі ID — у scripts/core/ad_config.gd.
##
## Порядок запуску: згода GDPR через UMP → MobileAds.initialize() →
## завантаження interstitial і rewarded. Якщо реклама не завантажилась або
## немає інтернету, гра продовжує працювати: винагорода не видається,
## а сигнал `message` показує коротке повідомлення.
##
## На ПК/у редакторі (плагіна немає) працює заглушка: rewarded одразу
## «переглянуто», interstitial одразу «закрито».

## Коротке повідомлення для гравця (ключ перекладу).
signal message(text_key: String)
signal interstitial_closed
## Внутрішній сигнал завершення rewarded (для request_rewarded).
signal _rewarded_done(earned: bool)

const PLACEMENT_SLOT := "extra_slot"
const PLACEMENT_UNDO := "undo"
const PLACEMENT_HAMMER := "hammer"
## Продовження після програшу: +1 місце в буфері.
const PLACEMENT_CONTINUE := "continue_slot"
const PLACEMENT_COINS := "coins"
const PLACEMENT_MULTIPLY_REWARD := "multiply_reward"
const PLACEMENT_DAILY_BONUS := "daily_bonus"
const PLACEMENT_WHEEL := "wheel_spin"
## ×2 вмісту скрині.
const PLACEMENT_CHEST := "chest_double"

## Interstitial: після кожного 3-го пройденого рівня, не частіше раз на 60 с.
const INTERSTITIAL_EVERY_LEVELS := 2
const INTERSTITIAL_MIN_INTERVAL_MS := 60_000
## Скільки перших рівнів проходяться без interstitial.
const INTERSTITIAL_SKIP_FIRST_LEVELS := 5

## Затримки повторного завантаження після помилки (секунди).
const RETRY_DELAYS := [5.0, 15.0, 30.0, 60.0, 120.0]

## Максимальний рейтинг реклами для аудиторії 13+ (G, PG, T, MA).
const MAX_AD_CONTENT_RATING := "T"

## Стан згоди UMP (ConsentInformation.ConsentStatus).
const CONSENT_REQUIRED := 2

## Заглушка на ПК: чи «вдається» реклама (тести вимикають, щоб перевірити помилки).
var stub_fill := true
const STUB_DELAY := 0.25

var _plugin := false
var _initialized := false
var _showing := false
var _last_interstitial_ms := -INTERSTITIAL_MIN_INTERVAL_MS

var _mobile_ads: Object
var _interstitial_api: Object
var _rewarded_api: Object
var _consent_info: Object
var _ump: Object

var _interstitial_uid := -1
var _interstitial_ready := false
var _interstitial_retry := 0
var _rewarded_uid := -1
var _rewarded_ready := false
var _rewarded_retry := 0
var _rewarded_earned := false
var _rewarded_callback := Callable()
var _consent_form_uid := -1
var _privacy_request := false


func _ready() -> void:
	_plugin = OS.get_name() == "Android" and Engine.has_singleton("PoingGodotAdMob")
	if not _plugin:
		if OS.get_name() == "Android":
			push_warning("AdManager: плагін AdMob не знайдено в збірці")
		return
	_mobile_ads = Engine.get_singleton("PoingGodotAdMob")
	_interstitial_api = Engine.get_singleton("PoingGodotAdMobInterstitialAd")
	_rewarded_api = Engine.get_singleton("PoingGodotAdMobRewardedAd")
	_consent_info = Engine.get_singleton("PoingGodotAdMobConsentInformation")
	_ump = Engine.get_singleton("PoingGodotAdMobUserMessagingPlatform")
	_mobile_ads.connect("on_initialization_complete", _on_initialized)
	_interstitial_api.connect("on_interstitial_ad_loaded", _on_interstitial_loaded)
	_interstitial_api.connect("on_interstitial_ad_failed_to_load", _on_interstitial_failed_to_load)
	_interstitial_api.connect("on_interstitial_ad_dismissed_full_screen_content", _on_interstitial_closed)
	_interstitial_api.connect("on_interstitial_ad_failed_to_show_full_screen_content", _on_interstitial_failed_to_show)
	_rewarded_api.connect("on_rewarded_ad_loaded", _on_rewarded_loaded)
	_rewarded_api.connect("on_rewarded_ad_failed_to_load", _on_rewarded_failed_to_load)
	_rewarded_api.connect("on_rewarded_ad_user_earned_reward", _on_rewarded_earned)
	_rewarded_api.connect("on_rewarded_ad_dismissed_full_screen_content", _on_rewarded_closed)
	_rewarded_api.connect("on_rewarded_ad_failed_to_show_full_screen_content", _on_rewarded_failed_to_show)
	_consent_info.connect("on_consent_info_updated_success", _on_consent_info_updated)
	_consent_info.connect("on_consent_info_updated_failure", _on_consent_info_failed)
	_ump.connect("on_consent_form_load_success_listener", _on_consent_form_loaded)
	_ump.connect("on_consent_form_load_failure_listener", _on_consent_form_failed)
	_ump.connect("on_consent_form_dismissed", _on_consent_form_dismissed)
	# Спершу згода GDPR, і лише потім ініціалізація реклами.
	_request_consent()


func is_plugin_active() -> bool:
	return _plugin


func is_showing() -> bool:
	return _showing


# --- Публічний API ----------------------------------------------------------

## Показує rewarded-рекламу. `callback(earned: bool)` викликається рівно один
## раз: earned = true лише після події «reward earned» від AdMob.
func show_rewarded(callback: Callable, placement: String = "") -> void:
	if _showing:
		_finish_rewarded(callback, false)
		return
	if not _plugin:
		_stub_rewarded(callback, placement)
		return
	if not _rewarded_ready:
		message.emit("TOAST_AD_FAILED")
		_load_rewarded()
		_finish_rewarded(callback, false)
		return
	_showing = true
	_rewarded_ready = false
	_rewarded_earned = false
	_rewarded_callback = callback
	_rewarded_api.show(_rewarded_uid)


## Корутина-обгортка: `if await AdManager.request_rewarded(placement): ...`
func request_rewarded(placement: String) -> bool:
	var result := [false]
	var done := [false]
	show_rewarded(func(earned: bool) -> void:
		result[0] = earned
		done[0] = true, placement)
	while not done[0]:
		await _rewarded_done
	return result[0]


## Показує interstitial, якщо він завантажений. Завершується сигналом
## interstitial_closed (одразу, якщо показувати нічого).
func show_interstitial() -> void:
	if GameState.no_ads or _showing:
		interstitial_closed.emit.call_deferred()
		return
	if not _plugin:
		print("[AdManager] show_interstitial() — заглушка")
		_showing = true
		await get_tree().create_timer(STUB_DELAY).timeout
		_showing = false
		_last_interstitial_ms = Time.get_ticks_msec()
		interstitial_closed.emit()
		return
	if not _interstitial_ready:
		_load_interstitial()
		interstitial_closed.emit.call_deferred()
		return
	_showing = true
	_interstitial_ready = false
	_interstitial_api.show(_interstitial_uid)


## Викликається між рівнями (кнопка «Далі»), тож ніколи не посеред рівня.
## Показує interstitial після кожного 3-го рівня, не частіше раз на 60 с.
func on_level_completed() -> void:
	GameState.levels_since_interstitial += 1
	GameState.save_game()
	if not should_show_interstitial():
		return
	GameState.levels_since_interstitial = 0
	GameState.save_game()
	show_interstitial()
	await interstitial_closed


func should_show_interstitial() -> bool:
	if GameState.no_ads:
		return false
	# Перші 5 рівнів — без міжсторінкової реклами.
	if GameState.completed_levels() < INTERSTITIAL_SKIP_FIRST_LEVELS:
		return false
	if GameState.levels_since_interstitial < INTERSTITIAL_EVERY_LEVELS:
		return false
	return Time.get_ticks_msec() - _last_interstitial_ms >= INTERSTITIAL_MIN_INTERVAL_MS


## Кнопка «Налаштування конфіденційності»: повторно показує форму згоди UMP.
## Повертає false, якщо форма в цьому регіоні не потрібна/недоступна.
func show_privacy_options() -> void:
	if not _plugin:
		message.emit("PRIVACY_NOT_REQUIRED")
		return
	# Плагін (v4.1.0) не має окремого privacy options form, тому скидаємо
	# збережений вибір і показуємо форму згоди наново.
	_privacy_request = true
	_consent_info.reset()
	_request_consent()


# --- Згода (UMP) ------------------------------------------------------------

func _request_consent() -> void:
	_consent_info.update({"tag_for_under_age_of_consent": false})


func _on_consent_info_updated() -> void:
	var required: bool = _consent_info.get_consent_status() == CONSENT_REQUIRED
	if required and _consent_info.get_is_consent_form_available():
		_ump.load_consent_form()
	else:
		if _privacy_request:
			message.emit("PRIVACY_NOT_REQUIRED")
		_privacy_request = false
		_initialize_ads()


func _on_consent_info_failed(_error: Dictionary) -> void:
	# Немає інтернету тощо: SDK використає раніше збережений вибір.
	_privacy_request = false
	_initialize_ads()


func _on_consent_form_loaded(uid: int) -> void:
	_consent_form_uid = uid
	_ump.show(uid)


func _on_consent_form_failed(_error: Dictionary) -> void:
	_privacy_request = false
	_initialize_ads()


func _on_consent_form_dismissed(_uid: int, _error: Dictionary) -> void:
	_privacy_request = false
	_initialize_ads()


# --- Ініціалізація та завантаження -----------------------------------------

func _initialize_ads() -> void:
	if _initialized:
		return
	_initialized = true
	# Аудиторія 13+: реклама не вище рейтингу «T» (Teen); дитячі прапорці не задані.
	_mobile_ads.set_request_configuration({
		"max_ad_content_rating": MAX_AD_CONTENT_RATING,
		"tag_for_child_directed_treatment": -1,
		"tag_for_under_age_of_consent": -1,
	}, PackedStringArray())
	_mobile_ads.initialize()


func _on_initialized(_status: Dictionary) -> void:
	_load_interstitial()
	_load_rewarded()


func _ad_request() -> Dictionary:
	# Плагін очікує обидва словники, навіть порожні.
	return {"google_request_agent": "", "mediation_extras": {}, "extras": {}}


func _load_interstitial() -> void:
	if not _initialized or _interstitial_ready or GameState.no_ads:
		return
	if _interstitial_uid != -1:
		_interstitial_api.destroy(_interstitial_uid)
	_interstitial_uid = _interstitial_api.create()
	_interstitial_api.load(AdConfig.interstitial_id(), _ad_request(), PackedStringArray(), _interstitial_uid)


func _load_rewarded() -> void:
	if not _initialized or _rewarded_ready:
		return
	if _rewarded_uid != -1:
		_rewarded_api.destroy(_rewarded_uid)
	_rewarded_uid = _rewarded_api.create()
	_rewarded_api.load(AdConfig.rewarded_id(), _ad_request(), PackedStringArray(), _rewarded_uid)


func _retry(kind: String) -> void:
	var attempt := _interstitial_retry if kind == "interstitial" else _rewarded_retry
	var delay: float = RETRY_DELAYS[mini(attempt, RETRY_DELAYS.size() - 1)]
	if kind == "interstitial":
		_interstitial_retry += 1
	else:
		_rewarded_retry += 1
	await get_tree().create_timer(delay).timeout
	if kind == "interstitial":
		_load_interstitial()
	else:
		_load_rewarded()


# --- Колбеки interstitial --------------------------------------------------

func _on_interstitial_loaded(uid: int) -> void:
	if uid == _interstitial_uid:
		_interstitial_ready = true
		_interstitial_retry = 0


func _on_interstitial_failed_to_load(uid: int, _error: Dictionary) -> void:
	if uid == _interstitial_uid:
		_retry("interstitial")


func _on_interstitial_closed(uid: int) -> void:
	if uid != _interstitial_uid:
		return
	_showing = false
	_last_interstitial_ms = Time.get_ticks_msec()
	interstitial_closed.emit()
	_load_interstitial()


func _on_interstitial_failed_to_show(uid: int, _error: Dictionary) -> void:
	if uid != _interstitial_uid:
		return
	_showing = false
	interstitial_closed.emit()
	_load_interstitial()


# --- Колбеки rewarded ------------------------------------------------------

func _on_rewarded_loaded(uid: int) -> void:
	if uid == _rewarded_uid:
		_rewarded_ready = true
		_rewarded_retry = 0


func _on_rewarded_failed_to_load(uid: int, _error: Dictionary) -> void:
	if uid == _rewarded_uid:
		_retry("rewarded")


func _on_rewarded_earned(uid: int, _reward: Dictionary) -> void:
	if uid == _rewarded_uid:
		_rewarded_earned = true


func _on_rewarded_closed(uid: int) -> void:
	if uid != _rewarded_uid:
		return
	_showing = false
	if not _rewarded_earned:
		message.emit("AD_NOT_COMPLETED")
	var cb := _rewarded_callback
	_rewarded_callback = Callable()
	_finish_rewarded(cb, _rewarded_earned)
	_load_rewarded()


func _on_rewarded_failed_to_show(uid: int, _error: Dictionary) -> void:
	if uid != _rewarded_uid:
		return
	_showing = false
	message.emit("TOAST_AD_FAILED")
	var cb := _rewarded_callback
	_rewarded_callback = Callable()
	_finish_rewarded(cb, false)
	_load_rewarded()


func _finish_rewarded(callback: Callable, earned: bool) -> void:
	if callback.is_valid():
		callback.call(earned)
	_rewarded_done.emit.call_deferred(earned)


# --- Заглушка для ПК --------------------------------------------------------

func _stub_rewarded(callback: Callable, placement: String) -> void:
	print("[AdManager] show_rewarded(%s) — заглушка" % placement)
	_showing = true
	await get_tree().create_timer(STUB_DELAY).timeout
	_showing = false
	if not stub_fill:
		message.emit("TOAST_AD_FAILED")
	_finish_rewarded(callback, stub_fill)
