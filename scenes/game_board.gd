extends Control

const COLS := 8
const ROWS := 16
const CELL_COUNT := COLS * ROWS

const BOARD_STATE_SCRIPT := preload("res://scripts/board_state.gd")
const CELL_SCENE := preload("res://scenes/board/cell_view.tscn")

const MOVE_STEP_SEC := 0.095
const AI_THINK_PAUSE_SEC := 0.28

var _rng := RandomNumberGenerator.new()
var _board = BOARD_STATE_SCRIPT.new()

## Очередь видов шаров (индексы палитры) для ближайшей тройной выкладки; в HUD всегда показываем первые три после пополнения.
var _placement_queue: Array[int] = []

var _palette: PackedColorArray = PackedColorArray()
var _score_human: int = 0
var _score_ai: int = 0

var _human_turn: bool = true
## Блокирует ввод во время хода ИИ и стартовой расстановки.
var _busy: bool = false
## Защита от повторного входа в корутину передачи хода ИИ (дубль ввода / события).
var _segment_handoff_running: bool = false
var _game_ended: bool = false

var _selected_idx: int = -1

@onready var _aspect: AspectRatioContainer = $VBox/BoardMargin/AspectBoard
@onready var _grid: GridContainer = $VBox/BoardMargin/AspectBoard/CenterWrap/GridContainer
@onready var _label_score_human: Label = $VBox/HUD/HUDMargin/HUDRow/PlayerBox/ScoreHuman
@onready var _label_score_ai: Label = $VBox/HUD/HUDMargin/HUDRow/AIBox/ScoreAI
@onready var _peek1: PlanetPreview = $VBox/HUD/HUDMargin/HUDRow/PeekCenter/PeekRow/Peek1
@onready var _peek2: PlanetPreview = $VBox/HUD/HUDMargin/HUDRow/PeekCenter/PeekRow/Peek2
@onready var _peek3: PlanetPreview = $VBox/HUD/HUDMargin/HUDRow/PeekCenter/PeekRow/Peek3


func _ready() -> void:
	_rng.randomize()
	_palette = _planet_colors()
	$VBox/MenuBar/BackButton.pressed.connect(_on_back_pressed)
	_aspect.resized.connect(_on_aspect_resized)
	_build_cells()
	await get_tree().process_frame
	_reflow_cells()
	_ensure_queue_len(3)
	_update_peek_ui()
	_refresh_scores_ui()
	_start_human_turn()


func _on_aspect_resized() -> void:
	if not is_inside_tree():
		return
	if _aspect == null or _grid == null:
		return
	_reflow_cells()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _build_cells() -> void:
	if _grid == null:
		return
	for i in ROWS * COLS:
		var cell := CELL_SCENE.instantiate() as CellView
		cell.grid_index = i
		cell.cell_clicked.connect(_on_cell_clicked)
		_grid.add_child(cell)


func _reflow_cells() -> void:
	if _aspect == null or _grid == null:
		return
	var aw := _aspect.size.x
	var ah := _aspect.size.y
	if aw < 16.0 or ah < 16.0:
		return
	const HSEP := 4
	const VSEP := 4
	var hsep := HSEP
	var vsep := VSEP
	var cell_w := int((aw - hsep * (COLS - 1)) / COLS)
	var cell_h := int((ah - vsep * (ROWS - 1)) / ROWS)
	var side: int = mini(cell_w, cell_h)
	side = maxi(side, 20)
	for c in _grid.get_children():
		if c is Control:
			(c as Control).custom_minimum_size = Vector2(side, side)


func _planet_colors() -> PackedColorArray:
	return PackedColorArray([
		Color(0.72, 0.71, 0.67),
		Color(0.94, 0.76, 0.42),
		Color(0.28, 0.52, 0.92),
		Color(0.86, 0.36, 0.22),
		Color(0.78, 0.62, 0.38),
		Color(0.74, 0.82, 0.92),
		Color(0.35, 0.78, 0.82),
		Color(0.22, 0.38, 0.88),
	])


func _palette_size() -> int:
	return _palette.size()


func _ensure_queue_len(n: int) -> void:
	while _placement_queue.size() < n:
		_placement_queue.append(_rng.randi() % _palette_size())


func _pop_three_for_placement() -> Array[int]:
	_ensure_queue_len(3)
	var batch: Array[int] = []
	batch.append(_placement_queue.pop_front())
	batch.append(_placement_queue.pop_front())
	batch.append(_placement_queue.pop_front())
	_ensure_queue_len(3)
	return batch


func _place_kinds_on_board(kinds: Array[int]) -> void:
	var empties: Array[int] = []
	for i in CELL_COUNT:
		if _board.cells[i] < 0:
			empties.append(i)
	empties.shuffle()
	var n_place: int = mini(kinds.size(), empties.size())
	for j in n_place:
		_board.cells[empties[j]] = kinds[j]


func _cell_center_global(grid_idx: int) -> Vector2:
	if grid_idx < 0 or grid_idx >= _grid.get_child_count():
		return Vector2.ZERO
	var ctl := _grid.get_child(grid_idx) as Control
	if ctl == null:
		return Vector2.ZERO
	return ctl.get_global_rect().get_center()


func _ball_visual_side(grid_idx: int) -> float:
	if grid_idx < 0 or grid_idx >= _grid.get_child_count():
		return 24.0
	var ctl := _grid.get_child(grid_idx) as Control
	if ctl == null:
		return 24.0
	var side := minf(ctl.size.x, ctl.size.y) * 0.72
	return maxf(side, 12.0)


## Перелёт шара по пути по пустым клеткам; затем `apply_move` и `_sync_cells`. Общее для игрока и ИИ.
func _animate_move_then_apply(from_idx: int, to_idx: int) -> void:
	var kind: int = _board.cells[from_idx]
	var pal_idx := mini(kind, _palette.size() - 1)
	var path: Array[int] = _board.find_path_for_move(from_idx, to_idx)

	var from_cell := _grid.get_child(from_idx) as CellView
	if from_cell == null:
		_board.apply_move(from_idx, to_idx)
		_sync_cells()
		return

	if path.size() < 2:
		_board.apply_move(from_idx, to_idx)
		_sync_cells()
		return

	from_cell.clear_ball()

	var ball_side := _ball_visual_side(from_idx)
	var ghost := Panel.new()
	ghost.mouse_filter = MOUSE_FILTER_IGNORE
	ghost.z_index = 24
	CellView.apply_ball_style(ghost, _palette[pal_idx], ball_side)
	add_child(ghost)
	ghost.size = Vector2(ball_side, ball_side)
	var start_center := _cell_center_global(path[0])
	ghost.global_position = start_center - ghost.size * 0.5

	var tween := create_tween()
	tween.set_parallel(false)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	for i in range(path.size() - 1):
		var target_center := _cell_center_global(path[i + 1])
		var target_pos := target_center - ghost.size * 0.5
		tween.tween_property(ghost, "global_position", target_pos, MOVE_STEP_SEC)

	await tween.finished
	if is_instance_valid(ghost):
		ghost.queue_free()

	_board.apply_move(from_idx, to_idx)
	_sync_cells()


func _sync_cells() -> void:
	for i in CELL_COUNT:
		var cell := _grid.get_child(i) as CellView
		if cell == null:
			continue
		var kind: int = _board.cells[i]
		if kind < 0:
			cell.clear_ball()
		else:
			var k := mini(kind, _palette.size() - 1)
			cell.show_ball(_palette[k])


func _update_peek_ui() -> void:
	_ensure_queue_len(3)
	if _peek1:
		_peek1.apply_color(_palette[_placement_queue[0]])
	if _peek2:
		_peek2.apply_color(_palette[_placement_queue[1]])
	if _peek3:
		_peek3.apply_color(_palette[_placement_queue[2]])


func _refresh_scores_ui() -> void:
	if _label_score_human:
		_label_score_human.text = str(_score_human)
	if _label_score_ai:
		_label_score_ai.text = str(_score_ai)


func _clear_selection() -> void:
	if _selected_idx >= 0 and _selected_idx < _grid.get_child_count():
		var prev := _grid.get_child(_selected_idx) as CellView
		if prev:
			prev.set_selected(false)
	_selected_idx = -1


func _start_human_turn() -> void:
	if _game_ended:
		return
	_human_turn = true
	_busy = true
	_clear_selection()
	var batch := _pop_three_for_placement()
	_place_kinds_on_board(batch)
	_sync_cells()
	_update_peek_ui()
	_busy = false
	if not _board.any_legal_move():
		_offer_game_over()
		return


func _start_ai_turn() -> void:
	if _game_ended:
		return
	_human_turn = false
	_busy = true
	_clear_selection()
	var batch := _pop_three_for_placement()
	_place_kinds_on_board(batch)
	_sync_cells()
	_update_peek_ui()
	if not _board.any_legal_move():
		_busy = false
		_offer_game_over()
		return
	await _ai_play_sequence()
	_busy = false
	if _game_ended:
		return
	if not _board.any_legal_move():
		_offer_game_over()
		return
	_start_human_turn()


func _ai_play_sequence() -> void:
	while true:
		await get_tree().create_timer(AI_THINK_PAUSE_SEC).timeout
		if not _board.any_legal_move():
			return
		var moves: Array[Vector2i] = _board.list_legal_moves()
		if moves.is_empty():
			return
		var pick: Vector2i = _board.pick_greedy_move(moves, _rng)
		await _animate_move_then_apply(pick.x, pick.y)
		var data: Dictionary = _board.collect_matches()
		var matched: Dictionary = data[&"to_remove"]
		if matched.is_empty():
			return
		_score_ai += int(data[&"score"])
		_refresh_scores_ui()
		_board.clear_cells(matched)
		_sync_cells()


func _on_cell_clicked(which: int) -> void:
	if _busy or not _human_turn:
		return
	if which < 0 or which >= CELL_COUNT:
		return

	var cell := _grid.get_child(which) as CellView
	if cell == null:
		return

	var occ: int = _board.cells[which]

	if _selected_idx < 0:
		if occ < 0:
			return
		_selected_idx = which
		cell.set_selected(true)
		return

	if which == _selected_idx:
		_clear_selection()
		return

	if occ >= 0:
		_clear_selection()
		if occ >= 0:
			_selected_idx = which
			cell.set_selected(true)
		return

	var from_idx := _selected_idx
	if not _board.has_path(from_idx, which):
		return

	_busy = true
	_clear_selection()
	_run_human_move_after_pick(from_idx, which)


func _run_human_move_after_pick(from_idx: int, to_idx: int) -> void:
	await _animate_move_then_apply(from_idx, to_idx)
	if _game_ended:
		return

	var data: Dictionary = _board.collect_matches()
	var matched: Dictionary = data[&"to_remove"]
	if matched.is_empty():
		_busy = false
		_end_human_segment_pass_to_ai()
		return

	_score_human += int(data[&"score"])
	_refresh_scores_ui()
	_board.clear_cells(matched)
	_sync_cells()
	_busy = false
	if not _board.any_legal_move():
		_offer_game_over()


func _end_human_segment_pass_to_ai() -> void:
	if _segment_handoff_running:
		return
	_segment_handoff_running = true
	_busy = true
	await get_tree().create_timer(0.05).timeout
	await _start_ai_turn()
	_segment_handoff_running = false


func _offer_game_over() -> void:
	if _game_ended:
		return
	_game_ended = true
	_busy = true
	var msg: String
	if _score_human > _score_ai:
		msg = "Игра окончена.\nУ вас больше очков — победа!"
	elif _score_ai > _score_human:
		msg = "Игра окончена.\nКомпьютер набрал больше очков."
	else:
		msg = "Игра окончена.\nНичья по очкам."
	var dlg := AcceptDialog.new()
	dlg.dialog_text = msg
	dlg.confirmed.connect(func() -> void:
		dlg.queue_free()
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	)
	add_child(dlg)
	dlg.popup_centered()
