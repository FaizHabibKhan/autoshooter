extends Node2D

var value: int = 1
var _spin: float = 0.0
var _bob: float = 0.0
var _life: float = 20.0

func _ready() -> void:
	add_to_group("coins")
	add_to_group("pickups")
	set_process(true)
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var d := global_position.distance_to(player.global_position)
	var magnet := GameManager.get_magnet_radius()
	if magnet > 0.0 and d < magnet:
		var dir := (player.global_position - global_position).normalized()
		global_position += dir * minf(240.0 * delta, d)
	if d <= Config.PLAYER_RADIUS + 16.0:
		GameManager.add_coins(value)
		EventBus.request_hit_flash.emit(global_position, Color("ffd166"))
		queue_free()

func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	_spin += delta * 2.8
	_bob += delta * 4.0
	var screen_pos := get_viewport().get_canvas_transform() * global_position
	visible = Rect2(Vector2.ZERO, get_viewport_rect().size).grow(24.0).has_point(screen_pos)
	queue_redraw()

func _draw() -> void:
	var pulse := 0.55 + 0.45 * sin(_bob)
	var coin_color := Color("ffd166")
	var rim := Color("fff2ad")
	var radius := 8.0 + pulse * 1.5
	draw_circle(Vector2.ZERO, radius + 4.0, Color(coin_color, 0.18))
	draw_circle(Vector2.ZERO, radius, coin_color)
	draw_arc(Vector2.ZERO, radius * 0.7, 0.0, TAU, 20, rim, 2.0, true)
	draw_line(Vector2(-3, 0), Vector2(3, 0), Color(0.28, 0.19, 0.03, 0.78), 2.0)
	draw_line(Vector2(0, -3), Vector2(0, 3), Color(0.28, 0.19, 0.03, 0.78), 2.0)

