# =============================================================================
#  health_kit.gd  —  a medkit that restores the player's HP on pickup. Drawn in
#  code (pulsing green cross). Auto-collects on contact; no selection.
# =============================================================================
extends Node2D

var _pulse: float = 0.0

func _ready() -> void:
	add_to_group("health_kits")

func _physics_process(delta: float) -> void:
	if not GameManager.is_playing():
		return
	_pulse += delta
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player != null and global_position.distance_to(player.global_position) <= Config.HEALTH_KIT_RADIUS + Config.PLAYER_RADIUS:
		if player.has_method("heal"):
			player.heal(Config.HEALTH_KIT_HEAL)
		EventBus.health_pickup.emit(global_position)
		EventBus.request_hit_flash.emit(global_position, Config.COL_HEALTH)
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var p := 0.5 + 0.5 * sin(_pulse * 4.0)
	# Pulsing aura + white-outlined green medkit with a cross.
	draw_circle(Vector2.ZERO, Config.HEALTH_KIT_RADIUS, Color(Config.COL_HEALTH, 0.06 + 0.06 * p))
	draw_arc(Vector2.ZERO, Config.HEALTH_KIT_RADIUS, 0.0, TAU, 40, Color(Config.COL_HEALTH, 0.28 + 0.2 * p), 2.0, true)
	var r := 11.0
	draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), Color(Config.COL_HEALTH), true)
	draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), Color.WHITE, false, 2.0)
	# Cross
	draw_rect(Rect2(-2.5, -7, 5, 14), Color(0.06, 0.09, 0.09), true)
	draw_rect(Rect2(-7, -2.5, 14, 5), Color(0.06, 0.09, 0.09), true)
