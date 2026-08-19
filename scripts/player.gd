# =============================================================================
#  player.gd  —  the hero circle. WASD/arrows to move, shooting is automatic.
#  Extends Unit (shared auto-shoot). Passes through enemies (contact = damage),
#  so movement always feels free.
# =============================================================================
extends Unit

var max_hp: float = Config.PLAYER_MAX_HP
var hp: float = Config.PLAYER_MAX_HP

var _hit_flash: float = 0.0
var _aim_dir: Vector2 = Vector2.RIGHT

func _ready() -> void:
	add_to_group("player")
	body_radius = Config.PLAYER_RADIUS
	body_color = Config.COL_PLAYER

	# On the player layer; masks nothing so enemies never block movement.
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(Config.LAYER_PLAYER, true)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = body_radius
	shape.shape = circle
	add_child(shape)

	EventBus.player_damaged.emit(hp, max_hp)

func _physics_process(delta: float) -> void:
	if not GameManager.is_playing():
		velocity = Vector2.ZERO
		return

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var desired := input * Config.PLAYER_SPEED
	if input != Vector2.ZERO:
		velocity = velocity.move_toward(desired, Config.PLAYER_ACCEL * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, Config.PLAYER_FRICTION * delta)

	move_and_slide()
	_clamp_to_arena()
	process_shooting(delta)

	if _hit_flash > 0.0:
		_hit_flash = max(0.0, _hit_flash - delta * 4.0)
	queue_redraw()

func _clamp_to_arena() -> void:
	var m := Config.ARENA_MARGIN + body_radius
	global_position.x = clampf(global_position.x, m, Config.WORLD_SIZE.x - m)
	global_position.y = clampf(global_position.y, m, Config.WORLD_SIZE.y - m)

# Called by enemies on contact.
func take_damage(amount: float) -> void:
	if not GameManager.is_playing():
		return
	hp = max(0.0, hp - amount)
	_hit_flash = 1.0
	EventBus.player_damaged.emit(hp, max_hp)
	EventBus.request_screen_shake.emit(6.0)
	if hp <= 0.0:
		_die()

func _die() -> void:
	EventBus.request_screen_shake.emit(18.0)
	EventBus.player_died.emit()

func _draw() -> void:
	# Aim indicator (points at the nearest enemy if there is one).
	var target := _find_nearest_enemy()
	if target != null:
		_aim_dir = (target.global_position - global_position).normalized()
	draw_line(Vector2.ZERO, _aim_dir * (body_radius + 10.0), Color(Config.COL_PLAYER, 0.5), 3.0)

	# Body: soft aura, fill, outline. Flash white briefly when hit.
	var col := Config.COL_PLAYER.lerp(Color.WHITE, _hit_flash)
	draw_circle(Vector2.ZERO, body_radius + 6.0, Color(Config.COL_PLAYER, 0.12))
	draw_circle(Vector2.ZERO, body_radius, col)
	draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 32, Color.WHITE, 2.0, true)
