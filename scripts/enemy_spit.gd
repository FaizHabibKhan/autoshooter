extends Area2D

var _vel: Vector2 = Vector2.ZERO
var _life: float = 2.0
var _damage: float = 10.0
var _radius: float = 8.0
var _color: Color = Color("ff7d5c")

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(Config.LAYER_BULLET, true)
	set_collision_mask_value(Config.LAYER_PLAYER, true)
	set_collision_mask_value(Config.LAYER_ALLY, true)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _radius
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)

func setup(from: Vector2, dir: Vector2, speed: float, damage: float, color: Color) -> void:
	global_position = from
	_vel = dir.normalized() * speed
	_life = 2.5
	_damage = damage
	_color = color
	rotation = dir.angle()

func _physics_process(delta: float) -> void:
	global_position += _vel * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(_damage)
		queue_free()
	elif body.is_in_group("allies") and body.has_method("take_damage"):
		body.take_damage(_damage)
		queue_free()
	elif body.is_in_group("enemies"):
		queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, _radius + 2.0, Color(_color, 0.18))
	draw_circle(Vector2.ZERO, _radius, _color)
	draw_circle(Vector2.ZERO, _radius * 0.35, Color(1, 1, 1, 0.8))
