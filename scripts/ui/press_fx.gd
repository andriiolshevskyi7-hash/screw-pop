class_name PressFx
extends RefCounted
## Анімація натискання для всіх кнопок гри: при дотику кнопка «втискається»
## (зменшується), а після відпускання пружно повертається з легким перескоком.
## Підключається один раз до дерева сцени (`PressFx.install`) — нові кнопки,
## зокрема створені з коду, отримують ефект автоматично.

const PRESSED_SCALE := 0.9
const META := "_press_fx"


static func install(tree: SceneTree) -> void:
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)
	_walk(tree.root)


static func _walk(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_walk(child)


static func _on_node_added(node: Node) -> void:
	if not node is BaseButton or node.has_meta(META):
		return
	var b: BaseButton = node
	b.set_meta(META, true)
	b.button_down.connect(_down.bind(b))
	b.button_up.connect(_up.bind(b))
	b.visibility_changed.connect(func() -> void:
		if not b.is_visible_in_tree():
			_kill(b)
			b.scale = Vector2.ONE)


static func _kill(b: BaseButton) -> void:
	var old: Tween = b.get_meta("_press_tween") if b.has_meta("_press_tween") else null
	if old and old.is_valid():
		old.kill()


static func _tween(b: BaseButton) -> Tween:
	_kill(b)
	var tw := b.create_tween()
	b.set_meta("_press_tween", tw)
	return tw


static func _down(b: BaseButton) -> void:
	if b.disabled:
		return
	b.pivot_offset = b.size / 2.0
	_tween(b).tween_property(b, "scale", Vector2.ONE * PRESSED_SCALE, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func _up(b: BaseButton) -> void:
	b.pivot_offset = b.size / 2.0
	var tw := _tween(b)
	tw.tween_property(b, "scale", Vector2.ONE * 1.06, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
