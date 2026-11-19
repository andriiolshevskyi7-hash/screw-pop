class_name BoardView
extends Control
## Поле з пластинами: масштабує координати поля під розмір вузла і визначає,
## по якому гвинту натиснули. Шари: пластини додаються від нижньої до верхньої.

## Натиснули по гвинту `s` (вільному чи накритому — вирішує гра).
signal screw_pressed(s: int)

const PlateScript := preload("res://scripts/game/plate_view.gd")
const ScrewScript := preload("res://scripts/game/screw_view.gd")
## Радіус «влучання» пальцем (у радіусах головки).
const TOUCH_K := 1.45

var board: ScrewBoard
var plates_root: Node2D
var plate_views := {}
var screw_views := {}
var board_scale := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	plates_root = Node2D.new()
	add_child(plates_root)
	resized.connect(_fit)


func build(p_board: ScrewBoard) -> void:
	clear()
	board = p_board
	var holes := {}
	for s in board.screw_count():
		var sc: Dictionary = board.screws[s]
		var p: int = sc.plate
		if not holes.has(p):
			holes[p] = []
		var plate: Dictionary = board.plates[p]
		holes[p].append((sc.pos - plate.pos).rotated(-float(plate.rot)))
	for p in board.plates.size():
		if board.plate_gone[p]:
			continue
		var v: PlateView = PlateScript.new()
		v.setup(p, board.plates[p], holes.get(p, []), ScrewBoard.SCREW_R)
		plates_root.add_child(v)
		plate_views[p] = v
	for s in board.screw_count():
		if board.removed[s]:
			continue
		var sc: Dictionary = board.screws[s]
		var plate: Dictionary = board.plates[int(sc.plate)]
		var sv: ScrewView = ScrewScript.new()
		sv.setup(s, int(sc.color), ScrewBoard.SCREW_R)
		plate_views[int(sc.plate)].add_screw(sv, (sc.pos - plate.pos).rotated(-float(plate.rot)))
		screw_views[s] = sv
	_fit()


func queue_redraw_all() -> void:
	for v in screw_views.values():
		v.queue_redraw()


func clear() -> void:
	for v in plates_root.get_children():
		v.queue_free()
	plate_views.clear()
	screw_views.clear()
	board = null


## Поле по центру вузла, з масштабом «вписати».
func _fit() -> void:
	if plates_root == null:
		return
	var w := LevelGenerator.BOARD_W
	var h := LevelGenerator.BOARD_H
	board_scale = minf(size.x / w, size.y / h)
	plates_root.scale = Vector2.ONE * board_scale
	plates_root.position = (size - Vector2(w, h) * board_scale) / 2.0


func to_board(local: Vector2) -> Vector2:
	return (local - plates_root.position) / board_scale


## Глобальна позиція гвинта на екрані (для польоту).
func screw_global(s: int) -> Vector2:
	var sv: ScrewView = screw_views.get(s)
	if sv:
		return sv.global_position
	return plates_root.get_global_transform() * Vector2(board.screws[s].pos)


## Підлога для відскоку пластин — трохи нижче поля (у координатах поля).
func floor_y() -> float:
	return (size.y - plates_root.position.y) / board_scale + 20.0


func _gui_input(event: InputEvent) -> void:
	if board == null:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var s := pick(to_board(event.position))
	if s != -1:
		accept_event()
		screw_pressed.emit(s)


## Гвинт під пальцем: найближчий вільний; якщо вільних поряд немає — найближчий
## накритий (щоб показати, що він заблокований).
func pick(p: Vector2) -> int:
	var best_free := -1
	var best_free_d := INF
	var best_any := -1
	var best_any_d := INF
	var reach := ScrewBoard.SCREW_R * TOUCH_K
	for s in board.screw_count():
		if board.removed[s]:
			continue
		var d := p.distance_to(board.screws[s].pos)
		if d > reach:
			continue
		if board.is_free(s):
			if d < best_free_d:
				best_free_d = d
				best_free = s
		elif d < ScrewBoard.SCREW_R * 1.1 and d < best_any_d:
			best_any_d = d
			best_any = s
	return best_free if best_free != -1 else best_any
