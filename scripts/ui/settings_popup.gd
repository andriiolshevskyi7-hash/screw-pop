extends PopupBase
## Налаштування: звук, музика, вібрація, режим для дальтоніків, мова
## (автоматично — як у системі) і конфіденційність (форма згоди UMP).
## Стан кожного перемикача видно одразу: увімкнено — зелена кнопка з «Увімк.»,
## вимкнено — сіра з «Вимк.» і перекресленою іконкою. Зберігається у user://.

@onready var title_label: Label = %Title
@onready var close_button: Button = %CloseButton
@onready var main_page: Control = %MainPage
@onready var lang_page: TouchScroll = %LangPage
@onready var lang_list: VBoxContainer = %LangList
@onready var sound_button: Button = %SoundButton
@onready var vibration_button: Button = %VibrationButton
@onready var music_button: Button = %MusicButton
@onready var language_button: Button = %LanguageButton
@onready var colorblind_button: Button = %ColorblindButton
@onready var effects_button: Button = %EffectsButton
@onready var privacy_button: Button = %PrivacyButton

const OFF_COLOR := Color("6b6490")
@onready var dim: ColorRect = %Dim


func _ready() -> void:
	super._ready()
	UiTheme.icon_button(close_button, "close", UiTheme.ACCENT, 80.0)
	close_button.pressed.connect(_on_close)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_on_close())
	sound_button.pressed.connect(func() -> void:
		GameState.set_sound(not GameState.sound_on)
		Sfx.play("select")
		_refresh())
	music_button.pressed.connect(func() -> void:
		GameState.set_music(not GameState.music_on)
		Sfx.play("tap")
		_refresh())
	vibration_button.pressed.connect(func() -> void:
		GameState.set_vibration(not GameState.vibration_on)
		Sfx.vibrate(60)
		Sfx.play("tap")
		_refresh())
	effects_button.pressed.connect(func() -> void:
		GameState.set_effects(not GameState.effects_on)
		Sfx.play("tap")
		_refresh())
	colorblind_button.pressed.connect(func() -> void:
		GameState.set_colorblind(not GameState.colorblind)
		Sfx.play("tap")
		_refresh())
	privacy_button.pressed.connect(func() -> void:
		Sfx.play("tap")
		close()
		AdManager.show_privacy_options())
	language_button.pressed.connect(func() -> void:
		Sfx.play("tap")
		_show_languages(true))
	for b in [sound_button, music_button, vibration_button, effects_button, colorblind_button, language_button, privacy_button]:
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 52)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 86)
	GameState.language_changed.connect(_refresh)
	_build_language_list()


func open() -> void:
	_show_languages(false)
	_refresh()
	await super.open()


func _on_close() -> void:
	if lang_page.visible:
		_show_languages(false)
		Sfx.play("tap", 0.9)
	else:
		close()


func _show_languages(on: bool) -> void:
	lang_page.visible = on
	main_page.visible = not on
	_refresh()


func _refresh() -> void:
	title_label.text = tr("LANGUAGE") if lang_page.visible else tr("SETTINGS")
	_toggle(sound_button, "SOUND", GameState.sound_on, "volume_up", "volume_off")
	_toggle(music_button, "MUSIC", GameState.music_on, "music_note", "music_off")
	_toggle(vibration_button, "VIBRATION", GameState.vibration_on, "vibration", "mobile_off")
	_toggle(effects_button, "EFFECTS", GameState.effects_on, "auto_awesome", "motion_photos_off")
	_toggle(colorblind_button, "COLORBLIND", GameState.colorblind, "visibility", "visibility_off")
	privacy_button.text = tr("PRIVACY")
	privacy_button.icon = UiTheme.icon("privacy_tip")
	UiTheme.paint_button(privacy_button, UiTheme.PRIMARY)
	var lang_name: String = tr("LANG_AUTO") if GameState.language == "" else GameState.LANGUAGES[GameState.language]
	language_button.text = "%s: %s" % [tr("LANGUAGE"), lang_name]
	language_button.icon = UiTheme.icon("language")
	UiTheme.paint_button(language_button, Color("3d8bfd"))
	for b in lang_list.get_children():
		var code: String = b.get_meta("code")
		var active: bool = code == GameState.language
		if code == "":
			b.text = "%s (%s)" % [tr("LANG_AUTO"), GameState.LANGUAGES[GameState.resolved_language()]]
		b.icon = UiTheme.icon("check") if active else null
		UiTheme.paint_button(b, UiTheme.GREEN if active else UiTheme.MUTED)


## Перемикач: зелений «Увімк.» або сірий «Вимк.» з перекресленою іконкою.
func _toggle(button: Button, key: String, on: bool, icon_on: String, icon_off: String) -> void:
	button.text = "%s: %s" % [tr(key), tr("ON") if on else tr("OFF")]
	button.icon = UiTheme.icon(icon_on if on else icon_off)
	UiTheme.paint_button(button, UiTheme.GREEN if on else OFF_COLOR)


func _build_language_list() -> void:
	var codes := [""]
	codes.append_array(GameState.LANGUAGES.keys())
	for code in codes:
		var b := Button.new()
		b.set_meta("code", code)
		b.text = GameState.LANGUAGES.get(code, "")
		b.custom_minimum_size = Vector2(0, 84)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 44)
		b.add_theme_font_size_override("font_size", 30)
		b.pressed.connect(func() -> void:
			if lang_page.consume_tap():
				return  # це була прокрутка, а не натискання
			Sfx.play("select")
			GameState.set_language(code)
			_refresh())
		lang_list.add_child(b)
