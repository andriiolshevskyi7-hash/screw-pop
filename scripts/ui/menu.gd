extends Control
## Головне меню: кольоровий логотип, ілюстрація з пластинами й гвинтами,
## рівень, велика кнопка «Грати», серія перемог.
## (Плитки магазину, щоденного бонусу й скрині з'являться на етапі 3.)

signal play_pressed
signal settings_pressed

## Літери логотипа — палітра Alderwood (як плитки Arrows Away).
const LOGO_COLORS := ["ffc233", "ff6b6b", "ff79c6", "a66bff", "3d8bff", "2ecc80"]

@onready var logo: RichTextLabel = %Logo
@onready var art: Control = %Art
@onready var level_label: Label = %LevelLabel
@onready var level_badge: PanelContainer = %LevelBadge
@onready var play_button: Button = %PlayButton
@onready var info_label: Label = %InfoLabel
@onready var settings_button: Button = %SettingsButton
@onready var coin_counter: CoinCounter = %CoinCounter

var _pulse_tween: Tween
## Поки відкрите вікно поверх меню, анімації меню не запускаються.
var paused := false


func _ready() -> void:
	play_button.pressed.connect(func() -> void:
		Sfx.play("select")
		play_pressed.emit())
	settings_button.pressed.connect(func() -> void:
		Sfx.play("tap")
		settings_pressed.emit())
	UiTheme.top_button(settings_button, "settings")
	UiTheme.paint_button(play_button, UiTheme.GREEN)
	play_button.icon = UiTheme.icon("play_arrow")
	play_button.expand_icon = true
	play_button.add_theme_constant_override("icon_max_width", 80)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.PILL
	sb.set_corner_radius_all(30)
	sb.content_margin_left = 36
	sb.content_margin_right = 36
	sb.content_margin_top = 2
	sb.content_margin_bottom = 6
	level_badge.add_theme_stylebox_override("panel", sb)
	GameState.language_changed.connect(refresh)
	GameState.coins_changed.connect(func(_c: int) -> void: refresh())
	visibility_changed.connect(_on_visibility_changed)
	refresh()


func refresh() -> void:
	_set_logo(tr("APP_TITLE").replace("\\n", "\n"))
	level_label.text = tr("LEVEL_N") % GameState.level
	# Текст уже перекладено й переведено у верхній регістр: інакше Godot
	# сприйняв би англійське «PLAY» як ключ і переклав назад.
	play_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	play_button.text = tr("PLAY").to_upper()
	var lines := PackedStringArray()
	if GameState.win_streak > 1:
		lines.append(tr("STREAK_N") % GameState.win_streak)
	if GameState.best_streak > 1:
		lines.append(tr("BEST_N") % GameState.best_streak)
	info_label.text = "   ·   ".join(lines)


func _set_logo(text: String) -> void:
	var bb := "[center]"
	var k := 0
	for ch in text:
		if ch == " " or ch == "\n":
			bb += ch
			continue
		bb += "[color=#%s]%s[/color]" % [LOGO_COLORS[k % LOGO_COLORS.size()], ch]
		k += 1
	logo.text = bb + "[/center]"


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		if _pulse_tween:
			_pulse_tween.kill()
		play_button.scale = Vector2.ONE
		return
	refresh()
	art.play_intro()
	_start_pulse()


## Кнопка «Грати» пульсує кілька разів після показу меню й зупиняється.
func _start_pulse() -> void:
	await get_tree().process_frame
	if _pulse_tween:
		_pulse_tween.kill()
	play_button.scale = Vector2.ONE
	play_button.pivot_offset = play_button.size / 2.0
	_pulse_tween = create_tween().set_loops(3)
	var tw := _pulse_tween
	tw.tween_property(play_button, "scale", Vector2(1.05, 1.05), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(play_button, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
