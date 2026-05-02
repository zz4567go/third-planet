class_name PlanetPreview
extends Panel


func apply_color(c: Color) -> void:
	if not is_inside_tree():
		return
	var sb := StyleBoxFlat.new()
	var side := minf(size.x, size.y)
	var r := int(side * 0.5) if side > 0.0 else 18
	sb.corner_radius_top_left = r
	sb.corner_radius_top_right = r
	sb.corner_radius_bottom_right = r
	sb.corner_radius_bottom_left = r
	sb.bg_color = c
	sb.border_color = Color(1, 1, 1, 0.22)
	sb.set_border_width_all(2)
	add_theme_stylebox_override(&"panel", sb)


func _ready() -> void:
	resized.connect(_on_resized)
	apply_color(Color(0.35, 0.55, 0.95))


func _on_resized() -> void:
	if not is_inside_tree():
		return
	var sb := get_theme_stylebox(&"panel") as StyleBoxFlat
	if sb == null:
		return
	var side := minf(size.x, size.y)
	var r := int(side * 0.5)
	sb.corner_radius_top_left = r
	sb.corner_radius_top_right = r
	sb.corner_radius_bottom_right = r
	sb.corner_radius_bottom_left = r
