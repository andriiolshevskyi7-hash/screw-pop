class_name AdConfig
extends RefCounted
## Усі ідентифікатори реклами AdMob в одному місці.
##
## Тестові чи справжні ID обираються АВТОМАТИЧНО під час експорту
## (addons/admob_export/export_plugin.gd):
##   - пресет «Android» (APK для телефона, мітка test_ads) і будь-яка
##     debug-збірка → офіційні тестові ID Google;
##   - пресет «Android AAB» (реліз для Google Play) → справжні ID нижче.
## Рішення записується і в AndroidManifest (App ID), і у файл
## res://ad_mode.txt усередині збірки, звідки гра бере ID рекламних блоків.
## У редакторі та на ПК (файлу немає) завжди тестові ID.

## ЄДИНИЙ ПЕРЕМИКАЧ РЕКЛАМИ ДЛЯ ПРОДАКШН-РЕЛІЗУ.
## true  — тестові ID в усіх збірках, зокрема в AAB для Google Play (закритий тест).
## false — AAB для Google Play отримує справжні ID (REAL_* нижче); debug-APK і
##         редактор лишаються з тестовими. Експорт-плагін і CI читають саме цей рядок.
const FORCE_TEST_ADS := true

## Мітка пресета, що вмикає тестову рекламу (export_presets.cfg → custom_features).
const TEST_FEATURE := "test_ads"
## Файл, який експорт-плагін додає в збірку: вміст "test" або "real".
const MODE_FILE := "res://ad_mode.txt"

# Офіційні тестові ID Google: https://developers.google.com/admob/android/test-ads
const TEST_APP_ID := "ca-app-pub-3940256099942544~3347511713"
const TEST_INTERSTITIAL_ID := "ca-app-pub-3940256099942544/1033173712"
const TEST_REWARDED_ID := "ca-app-pub-3940256099942544/5224354917"

# Справжні ID з AdMob для Screw Pop — ще не створені (застосунок треба додати в AdMob).
# Поки порожні, усі збірки (навіть з FORCE_TEST_ADS = false) лишаються з тестовими ID.
const REAL_APP_ID := ""
const REAL_INTERSTITIAL_ID := ""
const REAL_REWARDED_ID := ""

static var _runtime_real := -1


static func real_ids_filled() -> bool:
	return REAL_APP_ID != "" and REAL_INTERSTITIAL_ID != "" and REAL_REWARDED_ID != ""


## Рішення для експорту: чи збирати з тестовими ID.
static func export_uses_test_ads(preset_features: PackedStringArray, debug: bool) -> bool:
	return FORCE_TEST_ADS or debug or preset_features.has(TEST_FEATURE) or not real_ids_filled()


## Рішення в грі: справжні ID лише якщо збірку експортовано в режимі "real".
static func use_real_ads() -> bool:
	if _runtime_real == -1:
		var mode := ""
		if FileAccess.file_exists(MODE_FILE):
			mode = FileAccess.get_file_as_string(MODE_FILE).strip_edges()
		_runtime_real = 1 if mode == "real" and not FORCE_TEST_ADS and real_ids_filled() else 0
	return _runtime_real == 1


static func app_id(test: bool) -> String:
	return TEST_APP_ID if test else REAL_APP_ID


static func interstitial_id() -> String:
	return REAL_INTERSTITIAL_ID if use_real_ads() else TEST_INTERSTITIAL_ID


static func rewarded_id() -> String:
	return REAL_REWARDED_ID if use_real_ads() else TEST_REWARDED_ID
