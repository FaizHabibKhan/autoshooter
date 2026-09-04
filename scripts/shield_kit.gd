extends Node2D

var _pulse: float = 0.0

func _ready() -> void:
	add_to_group("shield_kits")
	add_to_group("pickups")

func _physics_process(delta: float) -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if global_position.distance_to(player.global_position) <= Config.SHIELD_KIT_RADIUS + Config.PLAYER_RADIUS:
		GameManager.activate_shield(GameManager.get_shield_duration())
		EventBus.request_hit_flash.emit(global_position, Color("8df0ff"))
		queue_free()
	_pulse += delta
	queue_redraw()

func _draw() -> void:
	var p: float = 0.5 + 0.5 * sin(_pulse * 4.0)
	var radius: float = Config.SHIELD_KIT_RADIUS
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, Color("8df0ff", 0.35 + 0.25 * p), 3.0, true)
	draw_circle(Vector2.ZERO, radius * 0.55, Color("8df0ff", 0.16 + 0.15 * p))
	draw_line(Vector2(-7, 0), Vector2(7, 0), Color("e8ffff"), 3.0)
	draw_line(Vector2(0, -7), Vector2(0, 7), Color("e8ffff"), 3.0)
