# =============================================================================
#  bullet.gd  —  a player/ally projectile. Area2D that flies straight, damages
#  the first enemy it touches, then dies. Visual drawn in code (no textures).
# =============================================================================
extends Area2D

var _velocity: Vector2 = Vector2.ZERO
var _damage: float = Config.BULLET_DAMAGE
var _life: float = Config.BULLET_LIFETIME
var _radius: float = Config.BULLET_RADIUS

func _ready() -> void:
	# Collision: this is on the BULLET layer and only looks at ENEMY bodies.
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(Config.LAYER_BULLET, true)
	set_collision_mask_value(Config.LAYER_ENEMY, true)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _radius
	shape.shape = circle
	add_child(shape)

	body_entered.connect(_on_body_entered)

# Called by the firing unit right after instancing.
func setup(direction: Vector2, damage: float) -> void:
	_velocity = direction.normalized() * Config.BULLET_SPEED
	_damage = damage
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	global_position += _velocity * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(_damage)
		EventBus.request_hit_flash.emit(global_position, Config.COL_BULLET)
		queue_free()

func _draw() -> void:
	# Little glowing bolt: bright core + soft halo.
	draw_circle(Vector2.ZERO, _radius * 1.9, Color(Config.COL_BULLET, 0.18))
	draw_circle(Vector2.ZERO, _radius, Config.COL_BULLET)
