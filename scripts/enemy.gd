# =============================================================================
#  enemy.gd  —  swarmer that hunts the player from any direction, deals contact
#  damage, and dies to bullets. Light separation keeps the swarm from stacking
#  into a single dot, which reads much better on screen.
# =============================================================================
extends CharacterBody2D

var wave: int = 1                     # set by the spawner before add_child
var hp: float = Config.ENEMY_BASE_HP
var speed: float = Config.ENEMY_BASE_SPEED
var contact_damage: float = Config.ENEMY_CONTACT_DAMAGE
var score_value: int = 10

var _attack_cd: float = 0.0
var _hit_flash: float = 0.0
var body_radius: float = Config.ENEMY_RADIUS

func _ready() -> void:
	add_to_group("enemies")
	hp = Config.enemy_health(wave)
	speed = Config.enemy_speed(wave)

	# On the ENEMY layer (so bullets can find it); masks nothing so it never
	# gets physically blocked — the swarm feel comes from manual separation.
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(Config.LAYER_ENEMY, true)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = body_radius
	shape.shape = circle
	add_child(shape)

	EventBus.enemy_spawned.emit(self)

func _physics_process(delta: float) -> void:
	if not GameManager.is_playing():
		return
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player == null:
		return

	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()
	var dir: Vector2 = to_player / dist if dist > 0.001 else Vector2.ZERO

	velocity = dir * speed + _separation()
	move_and_slide()

	# Contact damage on a cooldown while overlapping the player.
	_attack_cd = max(0.0, _attack_cd - delta)
	if dist <= body_radius + Config.PLAYER_RADIUS and _attack_cd <= 0.0:
		if player.has_method("take_damage"):
			player.take_damage(contact_damage)
		_attack_cd = Config.ENEMY_ATTACK_COOLDOWN

	if _hit_flash > 0.0:
		_hit_flash = max(0.0, _hit_flash - delta * 6.0)
		queue_redraw()

# Push away from nearby enemies so they spread into a readable swarm.
func _separation() -> Vector2:
	var push := Vector2.ZERO
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or not is_instance_valid(e):
			continue
		var away: Vector2 = global_position - e.global_position
		var d: float = away.length()
		if d < Config.ENEMY_SEPARATION and d > 0.001:
			push += (away / d) * (Config.ENEMY_SEPARATION - d)
	return push * 4.0

func take_damage(amount: float) -> void:
	hp -= amount
	_hit_flash = 1.0
	queue_redraw()
	if hp <= 0.0:
		_die()
	else:
		EventBus.enemy_hit.emit(global_position)

func _die() -> void:
	EventBus.enemy_killed.emit(global_position, score_value)
	EventBus.request_screen_shake.emit(3.0)
	queue_free()

func _draw() -> void:
	var col := Config.COL_ENEMY.lerp(Color.WHITE, _hit_flash)
	draw_circle(Vector2.ZERO, body_radius + 3.0, Color(Config.COL_ENEMY, 0.12))
	draw_circle(Vector2.ZERO, body_radius, col)
	draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 24, Color(Color.BLACK, 0.35), 2.0, true)
