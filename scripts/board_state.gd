class_name BoardState
extends RefCounted

const COLS := 8
const ROWS := 16
const SIZE := COLS * ROWS

var cells: PackedInt32Array


func _init() -> void:
	cells.resize(SIZE)
	cells.fill(-1)


func clone() -> BoardState:
	var b := BoardState.new()
	b.cells = cells.duplicate()
	return b


@warning_ignore("integer_division")
static func idx_to_rc(i: int) -> Vector2i:
	return Vector2i(i % COLS, int(i / COLS))


static func rc_to_idx(c: Vector2i) -> int:
	return c.y * COLS + c.x


func in_bounds_rc(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < COLS and c.y >= 0 and c.y < ROWS


func has_path(from_idx: int, to_idx: int) -> bool:
	if from_idx < 0 or to_idx < 0 or from_idx >= SIZE or to_idx >= SIZE:
		return false
	if cells[to_idx] != -1:
		return false
	var moving := cells[from_idx]
	if moving < 0:
		return false

	var visited: Dictionary = {}
	var queue: Array[int] = []
	var from_rc := idx_to_rc(from_idx)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = from_rc + d
		if not in_bounds_rc(n):
			continue
		var ni := rc_to_idx(n)
		if cells[ni] != -1:
			continue
		visited[ni] = true
		queue.append(ni)

	var qpos := 0
	while qpos < queue.size():
		var u: int = queue[qpos]
		qpos += 1
		if u == to_idx:
			return true
		var urc: Vector2i = idx_to_rc(u)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = urc + d
			if not in_bounds_rc(n):
				continue
			var ni := rc_to_idx(n)
			if visited.has(ni):
				continue
			if cells[ni] != -1:
				continue
			visited[ni] = true
			queue.append(ni)
	return false


func apply_move(from_idx: int, to_idx: int) -> void:
	var kind := cells[from_idx]
	cells[from_idx] = -1
	cells[to_idx] = kind


func _process_index_list(index_list: Array[int], to_remove: Dictionary) -> int:
	var add_score := 0
	var i := 0
	while i < index_list.size():
		var ii: int = index_list[i]
		var color: int = cells[ii]
		if color < 0:
			i += 1
			continue
		var j := i
		while j < index_list.size() and cells[index_list[j]] == color:
			j += 1
		var run := j - i
		if run >= 3:
			add_score += 3 * (run - 2)
			for k in range(i, j):
				to_remove[index_list[k]] = true
		i = j
	return add_score


func collect_matches() -> Dictionary:
	var to_remove: Dictionary = {}
	var score := 0

	for row in ROWS:
		var line: Array[int] = []
		for col in COLS:
			line.append(row * COLS + col)
		score += _process_index_list(line, to_remove)

	for col in COLS:
		var line: Array[int] = []
		for row in ROWS:
			line.append(row * COLS + col)
		score += _process_index_list(line, to_remove)

	for s in range(COLS + ROWS - 1):
		var line: Array[int] = []
		for c in COLS:
			var r := s - c
			if r >= 0 and r < ROWS:
				line.append(r * COLS + c)
		score += _process_index_list(line, to_remove)

	for d in range(-(ROWS - 1), COLS):
		var line: Array[int] = []
		for r in ROWS:
			var c := r - d
			if c >= 0 and c < COLS:
				line.append(r * COLS + c)
		score += _process_index_list(line, to_remove)

	return {&"score": score, &"to_remove": to_remove}


func clear_cells(to_remove: Dictionary) -> void:
	for k in to_remove.keys():
		var idx: int = int(k)
		if idx >= 0 and idx < SIZE:
			cells[idx] = -1


func any_legal_move() -> bool:
	for from_idx in SIZE:
		if cells[from_idx] < 0:
			continue
		for to_idx in SIZE:
			if from_idx == to_idx or cells[to_idx] != -1:
				continue
			if has_path(from_idx, to_idx):
				return true
	return false


func list_legal_moves() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for from_idx in SIZE:
		if cells[from_idx] < 0:
			continue
		for to_idx in SIZE:
			if from_idx == to_idx or cells[to_idx] != -1:
				continue
			if has_path(from_idx, to_idx):
				out.append(Vector2i(from_idx, to_idx))
	return out
