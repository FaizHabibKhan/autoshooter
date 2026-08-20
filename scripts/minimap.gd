# =============================================================================
#  minimap.gd  —  bottom-right minimap of the whole world: player, allies,
#  enemies, and the current camera view rectangle. Screen-space (CanvasLayer),
#  so it ignores the world camera.
# =============================================================================
extends Control

const PANEL := Vector2(210, 140)   # 3:2, matches WORLD_SIZE aspect
const MARGIN := 16.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var view := get_viewport_rect().size
	var origin := Vector2(view.x - PANEL.x - MARGIN, view.y - PANEL.y - MARGIN)
	var scale := PANEL / Config.WORLD_SIZE

	# Panel background + border.
	draw_rect(Rect2(origin, PANEL), Color(0, 0, 0, 0.5), true)
	draw_rect(Rect2(origin, PANEL), Color(1, 1, 1, 0.18), false, 1.5)

	# Current view rectangle.
	var cam: Camera2D = get_tree().get_first_node_in_group("camera")
	if cam != null:
		var cam_center: Vector2 = cam.get_screen_center_position()
		var tl := origin + (cam_center - view * 0.5) * scale
		draw_rect(Rect2(tl, view * scale), Color(1, 1, 1, 0.5), false, 1.0)

	# Enemies (red).
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			draw_circle(_to_mm(e.global_position, origin, scale), 2.0, Color(Config.COL_ENEMY, 0.9))

	# Uncollected allies (yellow) — the ones you want to go find.
	for a in get_tree().get_nodes_in_group("pickups"):
		if is_instance_valid(a):
			draw_circle(_to_mm(a.global_position, origin, scale), 3.0, Config.COL_ALLY_UNCOLLECTED)

	# Collected allies (colored by their weapon).
	for a in get_tree().get_nodes_in_group("allies"):
		if is_instance_valid(a):
			draw_circle(_to_mm(a.global_position, origin, scale), 2.0, a.weapon_color)

	# Health kits (green).
	for h in get_tree().get_nodes_in_group("health_kits"):
		if is_instance_valid(h):
			draw_circle(_to_mm(h.global_position, origin, scale), 3.0, Config.COL_HEALTH)

	# Player (blue), drawn last so it's always on top.
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player != null:
		var pp := _to_mm(player.global_position, origin, scale)
		draw_circle(pp, 3.5, Config.COL_PLAYER)
		draw_arc(pp, 5.0, 0.0, TAU, 16, Color(1, 1, 1, 0.7), 1.0, true)

func _to_mm(world_pos: Vector2, origin: Vector2, scale: Vector2) -> Vector2:
	var p := origin + world_pos * scale
	return Vector2(
		clampf(p.x, origin.x, origin.x + PANEL.x),
		clampf(p.y, origin.y, origin.y + PANEL.y)
	)
