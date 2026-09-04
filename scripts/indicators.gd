# =============================================================================
#  indicators.gd  —  edge-of-screen arrows that point toward off-screen allies
#  (green) and the nearest off-screen enemies (red). Lives on a CanvasLayer so
#  it draws in screen space, unaffected by the world camera.
# =============================================================================
extends Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not GameManager.is_playing():
		return
	var cam: Camera2D = get_tree().get_first_node_in_group("camera")
	if cam == null:
		return

	var view := get_viewport_rect().size
	var center := view * 0.5
	var cam_center: Vector2 = cam.get_screen_center_position()
	var halfw := view.x * 0.5 - Config.INDICATOR_MARGIN
	var halfh := view.y * 0.5 - Config.INDICATOR_MARGIN

	# --- Health kits (green): every off-screen kit ---
	for h in get_tree().get_nodes_in_group("health_kits"):
		if not is_instance_valid(h):
			continue
		var hrel: Vector2 = h.global_position - cam_center
		if _is_offscreen(hrel, halfw, halfh):
			_draw_arrow(hrel, center, halfw, halfh, Config.COL_HEALTH)

	# --- Enemies (red): only the nearest few off-screen, to avoid clutter ---
	var offscreen: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var rel: Vector2 = e.global_position - cam_center
		if _is_offscreen(rel, halfw, halfh):
			offscreen.append(rel)
	offscreen.sort_custom(func(x, y): return x.length_squared() < y.length_squared())
	var count: int = min(offscreen.size(), Config.INDICATOR_MAX_ENEMIES)
	for i in count:
		_draw_arrow(offscreen[i], center, halfw, halfh, Config.COL_ENEMY)

func _is_offscreen(rel: Vector2, halfw: float, halfh: float) -> bool:
	return absf(rel.x) > halfw or absf(rel.y) > halfh

func _draw_arrow(rel: Vector2, center: Vector2, halfw: float, halfh: float, color: Color) -> void:
	if rel.length_squared() < 1.0:
		return
	# Project the direction onto the inset screen rectangle to find the edge point.
	var scale := minf(halfw / maxf(absf(rel.x), 0.001), halfh / maxf(absf(rel.y), 0.001))
	var edge := center + rel * scale
	var ang := rel.angle()

	# Closer targets read brighter.
	var dist := rel.length()
	var a := clampf(1.15 - dist / 2200.0, 0.4, 1.0)
	var col := Color(color, a)

	var s := Config.INDICATOR_SIZE
	var p1 := edge + Vector2(s, 0).rotated(ang)
	var p2 := edge + Vector2(-s * 0.6, s * 0.65).rotated(ang)
	var p3 := edge + Vector2(-s * 0.6, -s * 0.65).rotated(ang)
	draw_colored_polygon(PackedVector2Array([p1, p2, p3]), col)
	draw_polyline(PackedVector2Array([p1, p2, p3, p1]), Color(0, 0, 0, 0.4 * a), 1.5, true)
