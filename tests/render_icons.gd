extends SceneTree
## Рендерить PNG-іконки для Android з SVG:
##   godot --headless --script res://tests/render_icons.gd
## Результат: assets/icon/icon_192.png, adaptive_fg_432.png, adaptive_bg_432.png

func _init() -> void:
	_render("res://icon.svg", "res://assets/icon/icon_192.png", 192)
	_render("res://assets/icon/foreground.svg", "res://assets/icon/adaptive_fg_432.png", 432)
	_render("res://assets/icon/background.svg", "res://assets/icon/adaptive_bg_432.png", 432)
	_render("res://icon.svg", "res://assets/icon/preview_512.png", 512)
	quit(0)


func _render(src: String, dst: String, px: int) -> void:
	var img := Image.new()
	var err := img.load_svg_from_string(FileAccess.get_file_as_string(src), px / 256.0)
	if err != OK:
		push_error("SVG error %s" % src)
		quit(1)
		return
	img.save_png(ProjectSettings.globalize_path(dst))
	print("saved ", dst)
