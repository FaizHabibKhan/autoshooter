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
var _anim: AnimatedSprite2D

func _ready() -> void:
	add_to_group("player")
	body_radius = Config.PLAYER_RADIUS
	body_color = Config.COL_PLAYER
	z_index = 2   # draw the hero above enemies/allies

	# On the player layer; masks nothing so enemies never block movement.
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(Config.LAYER_PLAYER, true)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = body_radius
	shape.shape = circle
	add_child(shape)

	_anim = AnimatedSprite2D.new()
	_anim.sprite_frames = SpriteLib.get_frames("player")
	_anim.scale = Vector2.ONE * Config.PLAYER_SPRITE_SCALE
	_anim.play("walk")
	add_child(_anim)

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

	_update_sprite(delta)

func _update_sprite(delta: float) -> void:
	# Face the nearest enemy if there is one, otherwise face movement.
	var target := _find_nearest_enemy()
	if target != null:
		_aim_dir = (target.global_position - global_position).normalized()
	elif velocity.length() > 10.0:
		_aim_dir = velocity.normalized()
	_anim.rotation = _aim_dir.angle()
	# Walk faster the faster we move; nearly still when idle.
	_anim.speed_scale = clampf(velocity.length() / Config.PLAYER_SPEED, 0.15, 1.4)
	# Hit flash: briefly brighten the sprite.
	if _hit_flash > 0.0:
		_hit_flash = max(0.0, _hit_flash - delta * 4.0)
	var f := _hit_flash * 0.9
	_anim.modulate = Color(1.0 + f, 1.0 + f, 1.0 + f, 1.0)
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
	if _anim != null:
		_anim.speed_scale = 1.0
		_anim.play("death")
	EventBus.request_screen_shake.emit(18.0)
	EventBus.player_died.emit()

func _draw() -> void:
	# Team-colored glow + drop shadow so the hero always pops off the floor.
	draw_circle(Vector2.ZERO, body_radius + 10.0, Color(Config.COL_PLAYER, 0.20))
	draw_circle(Vector2(0, body_radius * 0.5), body_radius * 0.9, Color(0, 0, 0, 0.22))
