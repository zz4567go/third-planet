class_name CellView
extends Panel

signal cell_clicked(cell_index: int)

var grid_index: int = -1

## При emulate_touch_from_mouse один физический тап может дать и ScreenTouch, и MouseButton в `_gui_input`.
const CLICK_DEBOUNCE_MS := 50

@onready var _ball: Panel = $Ball

var _last_click_emit_ms: int = -1000000


func _ready() -> void:
	if _ball == null:
		return
	_ball.visible = false


static func apply_ball_style(panel: Panel, color: Color, side: float) -> void:
	var sb := StyleBoxFlat.new()
	var r := maxi(int(side * 0.5), 4)
	sb.corner_radius_top_left = r
	sb.corner_radius_top_right = r
	sb.corner_radius_bottom_right = r
	sb.corner_radius_bottom_left = r
	sb.bg_color = color
	sb.border_color = Color(1, 1, 1, 0.28)
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override(&"panel", sb)


func show_ball(color: Color) -> void:
	if _ball == null:
		return
	var side := minf(_ball.size.x, _ball.size.y)
	if side <= 0.0:
		side = minf(size.x, size.y) * 0.72
	apply_ball_style(_ball, color, side)
	_ball.visible = true


func clear_ball() -> void:
	if _ball == null:
		return
	_ball.visible = false


func set_selected(on: bool) -> void:
	modulate = Color(1.22, 1.22, 1.08, 1.0) if on else Color.WHITE


func _gui_input(event: InputEvent) -> void:
	var activate := false
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		activate = st.pressed
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		activate = mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and not mb.is_echo()

	if not activate:
		return

	var now_ms := Time.get_ticks_msec()
	if now_ms - _last_click_emit_ms < CLICK_DEBOUNCE_MS:
		accept_event()
		return

	_last_click_emit_ms = now_ms
	accept_event()
	cell_clicked.emit(grid_index)


func _notification(what: int) -> void:
	if what != NOTIFICATION_RESIZED:
		return
	if _ball == null:
		return
	var side := minf(size.x, size.y)
	var inset := side * 0.14
	_ball.offset_left = inset
	_ball.offset_top = inset
	_ball.offset_right = -inset
	_ball.offset_bottom = -inset
