extends PopupBase
## Програш: «+1 місце в буфері» (лоток повний) або «+5 ходів» (вибухнула бомба)
## за рекламу, чи «Спробувати ще».
## Використання: `var choice := await lose_popup.ask(can_continue, kind)` → "continue" або "retry".

signal chosen(option: String)

@onready var title_label: Label = %Title
@onready var close_button: Button = %CloseButton
@onready var message_label: Label = %Message
@onready var vbox: VBoxContainer = %VBox

var _continue_button: Button
var _retry_button: Button
var _answered := true


func _ready() -> void:
	super._ready()
	close_button.hide()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_continue_button = _make_button(UiTheme.ORANGE, "ad")
	_continue_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_continue_button.pressed.connect(_answer.bind("continue"))
	_retry_button = _make_button(UiTheme.PRIMARY, "restart_alt")
	_retry_button.pressed.connect(_answer.bind("retry"))


func _make_button(color: Color, icon_name: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 110)
	b.add_theme_font_size_override("font_size", 36)
	b.icon = UiTheme.icon(icon_name)
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 60)
	UiTheme.paint_button(b, color)
	vbox.add_child(b)
	return b


## `kind`: "buffer" — лоток повний (+1 місце), "bomb" — вибухнула бомба (+5 ходів).
func ask(can_continue: bool, kind: String = "buffer") -> String:
	var bomb := kind == "bomb"
	title_label.text = tr("BOOM") if bomb else tr("OUT_OF_SPACE")
	message_label.text = tr("BOOM_TEXT") if bomb else tr("OUT_OF_SPACE_TEXT")
	_continue_button.text = tr("CONTINUE_MOVES") if bomb else tr("CONTINUE_SLOT")
	_continue_button.visible = can_continue
	_continue_button.disabled = false
	_retry_button.text = tr("TRY_AGAIN")
	_answered = false
	open()
	var option: String = await chosen
	return option


func _answer(option: String) -> void:
	if _answered:
		return
	if option == "continue":
		# Нагорода лише після перегляду реклами до кінця.
		_continue_button.disabled = true
		var ok: bool = await AdManager.request_rewarded(AdManager.PLACEMENT_CONTINUE)
		if not ok:
			_continue_button.disabled = false
			return
	_answered = true
	close()
	chosen.emit(option)
