# =============================================================================
#  rocket.gd  —  a rocket-launcher projectile. Flies toward the aim, explodes on
#  the first enemy it touches (or at the end of its range) and deals radial
#  damage to everything in the blast. Visual drawn in code.
# =============================================================================
extends Area2D

const EffectScript := preload("res://scripts/effect.gd")

var _vel: Vector2 = Vector2.ZERO
var _life: float = 1.2
var _blast_radius: float = 95.0
var _blast_damage: float = 60.0
var _color: Color = Color("ff9f45")
var _exploded: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(Config.LAYER_BULLET, true)
	set_collision_mask_value(Config.LAYER_ENEMY, true)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)

func setup(dir: Vector2, speed: float, rng: float, blast_radius: float, blast_damage: float, color: Color) -> void:
	_vel = dir.normalized() * speed
	_life = rng / maxf(speed, 1.0)
	_blast_radius = blast_radius
	_blast_damage = blast_damage
	_color = color
	rotation = dir.angle()

func _physics_process(delta: float) -> void:
	if _exploded:
		return
	global_position += _vel * delta
	_life -= delta
	if _life <= 0.0:
		_explode()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemies"):
		_explode()

func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.global_position.distance_to(global_position) <= _blast_radius and e.has_method("take_damage"):
			e.take_damage(_blast_damage)
	var fx := EffectScript.new()
	get_parent().add_child(fx)
	fx.global_position = global_position
	fx.explosion(_color, _blast_radius)
	EventBus.explosion.emit(global_position)
	EventBus.request_screen_shake.emit(5.0)
	queue_free()

func _draw() -> void:
	# Exhaust trail + warhead, oriented along travel (+x).
	draw_line(Vector2(-12, 0), Vector2(4, 0), Color(_color, 0.5), 5.0)
	draw_circle(Vector2(5, 0), 4.5, _color)
	draw_circle(Vector2(5, 0), 2.0, Color.WHITE)
