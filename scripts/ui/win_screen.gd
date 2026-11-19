extends Control
## Екран перемоги: нагорода монетами, «×2 ▶» за рекламу поруч із «Далі»,
## салют, конфеті, монети летять у лічильник.

signal next_pressed

@onready var panel: PanelContainer = %Panel
@onready var ribbon_label: Label = %Ribbon
@onready var title_label: Label = %Title
@onready var reward_label: Label = %RewardLabel
@onready var reward_icon: TextureRect = %RewardIcon
@onready var reward_row: Control = %RewardRow
@onready var streak_label: Label = %Streak
@onready var extra_label: Label = %Extra
@onready var next_button: Button = %NextButton
@onready var multiply_button: Button = %MultiplyButton
@onready var confetti: Control = %Confetti
@onready var coin_counter: CoinCounter = %CoinCounter
@onready var fly_layer: Control = %FlyLayer
@onready var stars_view: StarsView = %Stars
@onready var chest_label: Label = %Chest
@onready var fireworks: Fireworks = %Fireworks

var _summary := {}


func _ready() -> void:
	next_button.pressed.connect(_on_next)
	multiply_button.pressed.connect(_on_multiply)
	UiTheme.paint_button(next_button, UiTheme.GREEN)
	UiTheme.paint_button(multiply_button, UiTheme.ORANGE)
	multiply_button.icon = UiTheme.icon("ad")
	multiply_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	multiply_button.expand_icon = true
	multiply_button.add_theme_constant_override("icon_max_width", 56)
	reward_icon.texture = UiTheme.icon("coin")
	streak_label.add_theme_color_override("font_color", UiTheme.GOLD_TEXT)
	panel.theme = UiTheme.panel_theme()
	title_label.uppercase = true
	ribbon_label.uppercase = true
	ribbon_label.add_theme_color_override("font_color", Color.WHITE)
	var ribbon := StyleBoxFlat.new()
	ribbon.bg_color = UiTheme.PRIMARY
	ribbon.set_corner_radius_all(28)
	ribbon.border_width_bottom = 6
	ribbon.border_color = UiTheme.PRIMARY.darkened(0.22)
	ribbon.content_margin_left = 40
	ribbon.content_margin_right = 40
	ribbon.content_margin_top = 6
	ribbon.content_margin_bottom = 10
	%RibbonPanel.add_theme_stylebox_override("panel", ribbon)
	hide()


func show_win(summary: Dictionary) -> void:
	_summary = summary
	var is_daily: bool = summary.get("is_daily", false)
	ribbon_label.text = tr("DAILY_LEVEL") if is_daily else tr("LEVEL_N") % summary.get("level", 1)
	var stars: int = summary.get("stars", 1)
	match stars:
		3:
			title_label.text = tr("WIN_5")
		2:
			title_label.text = tr("WIN_%d" % (randi() % 4 + 1))
		_:
			title_label.text = tr("WIN_DONE")
	# Скриня заповнилась — відкривається в меню.
	var chest: bool = summary.get("chest_opened", false)
	chest_label.visible = chest
	chest_label.text = tr("CHEST_READY")
	var reward: int = summary.get("reward", 0)
	reward_row.visible = reward > 0
	reward_label.text = "+%d" % reward
	multiply_button.visible = reward > 0
	multiply_button.disabled = false
	# За рекламу — доплата, що дорівнює нагороді до знижки (не зменшена).
	multiply_button.text = "+%d" % (reward + _ad_bonus())
	streak_label.text = tr("STREAK_N") % summary.get("win_streak", 0)
	var extra := ""
	var streak: int = summary.get("win_streak", 0)
	if is_daily:
		extra = tr("WIN_DAYS") % summary.get("daily_streak", 0)
	elif streak > 1 and streak == summary.get("best_streak", 0):
		extra = tr("WIN_NEW_RECORD")
	extra_label.text = extra
	extra_label.visible = extra != ""
	# Текст уже перекладено й переведено у верхній регістр: інакше Godot
	# сприйняв би англійське «NEXT»/«PLAY»/«CLAIM» як ключ і переклав назад.
	next_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	next_button.text = tr("NEXT").to_upper()
	next_button.disabled = false
	show()
	modulate.a = 0.0
	panel.scale = Vector2(0.6, 0.6)
	await get_tree().process_frame
	panel.pivot_offset = panel.size / 2.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if GameState.effects_on:
		confetti.burst()
		fireworks.launch(5)
	stars_view.play(stars)
	if reward > 0:
		await get_tree().create_timer(0.5).timeout
		_fly_coins(8)


func _ad_bonus() -> int:
	return int(_summary.get("ad_bonus", Economy.ad_bonus(int(_summary.get("reward", 0)))))


func _on_multiply() -> void:
	multiply_button.disabled = true
	var ok: bool = await AdManager.request_rewarded(AdManager.PLACEMENT_MULTIPLY_REWARD)
	if not ok:
		multiply_button.disabled = false
		return
	var reward: int = _summary.get("reward", 0)
	var bonus := _ad_bonus()
	reward_label.text = "+%d" % (reward + bonus)
	multiply_button.disabled = true
	Sfx.play("complete")
	_fly_coins(14, bonus)


## Монетки летять від нагороди до лічильника; баланс оновлюється по прильоту.
func _fly_coins(count: int, add_amount: int = 0) -> void:
	var from := reward_icon.get_global_rect().get_center() - fly_layer.global_position
	var to := coin_counter.icon_global_center() - fly_layer.global_position
	for i in count:
		var coin := TextureRect.new()
		coin.texture = UiTheme.icon("coin")
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.size = Vector2(54, 54)
		coin.pivot_offset = coin.size / 2.0
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin.position = from - coin.size / 2.0
		fly_layer.add_child(coin)
		var mid := from.lerp(to, 0.5) + Vector2(randf_range(-160, 160), randf_range(-60, 140))
		var tw := coin.create_tween()
		tw.tween_interval(i * 0.05)
		tw.tween_method(func(t: float) -> void:
			coin.position = from.lerp(mid, t).lerp(mid.lerp(to, t), t) - coin.size / 2.0
			coin.scale = Vector2.ONE * lerpf(1.1, 0.7, t),
			0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		var last := i == count - 1
		tw.tween_callback(func() -> void:
			coin.queue_free()
			coin_counter.pulse()
			Sfx.play("tap", 1.4 + randf() * 0.3)
			if last and add_amount > 0:
				GameState.add_coins(add_amount))


func _on_next() -> void:
	if next_button.disabled:
		return
	next_button.disabled = true
	multiply_button.disabled = true
	Sfx.play("select")
	next_pressed.emit()
