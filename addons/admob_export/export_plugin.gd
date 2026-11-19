@tool
extends EditorExportPlugin
## Під час Android-експорту (Gradle) додає:
##  - AAR-бібліотеки godot-admob-android v4.1.0 (Poing Studios, MIT) з bin/ads/libs;
##  - Maven-залежність Google Mobile Ads SDK;
##  - AdMob App ID у AndroidManifest (без нього SDK падає під час запуску);
##  - файл res://ad_mode.txt ("test"/"real") — з нього гра бере ID блоків.
## Тестові ID: пресет з міткою test_ads (APK для телефона) або debug-експорт.
## Справжні ID: релізний пресет без мітки (AAB для Google Play).
## Runtime-обгортка над плагіном — scripts/autoload/ad_manager.gd.

const LIBS := "res://addons/admob_export/bin/ads/libs"
const ADS_SDK := "com.google.android.gms:play-services-ads:24.9.0"
const AdConfigScript := preload("res://scripts/core/ad_config.gd")


func _get_name() -> String:
	return "SortPuzzleAdMob"


func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformAndroid


func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
	var variant := "debug" if debug else "release"
	return PackedStringArray([
		"%s/poing-godot-admob-ads-%s.aar" % [LIBS, variant],
		"%s/poing-godot-admob-core-%s.aar" % [LIBS, variant],
	])


func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
	return PackedStringArray([ADS_SDK])


## Режим поточного експорту. За замовчуванням — тестовий (безпечно).
## _export_begin викликається до запису маніфесту (ExportNotifier у Godot 4.3).
var _test_mode := true


func _export_begin(features: PackedStringArray, is_debug: bool, _path: String, _flags: int) -> void:
	_test_mode = AdConfigScript.export_uses_test_ads(features, is_debug)
	print("AdMob: export mode = %s (App ID %s)" % ["test" if _test_mode else "real", AdConfigScript.app_id(_test_mode)])
	add_file(AdConfigScript.MODE_FILE, ("test" if _test_mode else "real").to_utf8_buffer(), false)


func _export_end() -> void:
	_test_mode = true


func _get_android_manifest_application_element_contents(_platform: EditorExportPlatform, debug: bool) -> String:
	return """
		<meta-data
			android:name="com.google.android.gms.ads.APPLICATION_ID"
			android:value="%s"/>
	""" % AdConfigScript.app_id(_test_mode or debug)
