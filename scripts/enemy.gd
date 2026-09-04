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
var coin_value: int = 0
var variant: String = "walker"

var _attack_cd: float = 0.0
var _hit_flash: float = 0.0
var _bar_flash: float = 0.0
var _dying: bool = false
var is_boss: bool = false            # set by spawner before add_child
var _max_hp: float = 1.0             # for the boss health bar
var body_radius: float = Config.ENEMY_RADIUS
var _anim: AnimatedSprite2D
var _spit_cd: float = 0.0
var _visual_tint := Color.WHITE

func _ready() -> void:
	add_to_group("enemies")
	if is_boss:
		body_radius = Config.ENEMY_RADIUS * Config.BOSS_SCALE
		z_index = 1
	if variant == "spitter":
		_spit_cd = randf_range(0.5, 1.4)

	_anim = AnimatedSprite2D.new()
	_anim.sprite_frames = SpriteLib.get_frames("zombie")
	_anim.scale = Vector2.ONE * Config.ENEMY_SPRITE_SCALE * (Config.BOSS_SCALE if is_boss else 1.0)
	_visual_tint = Color("9be8b5") if variant == "spitter" else Color.WHITE
	_anim.modulate = _visual_tint
	_anim.play("walk")
	add_child(_anim)

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
	if _dying or not GameManager.is_playing():
		return
	var target: Node2D = _get_target()
	if target == null:
		return

	var to_target: Vector2 = target.global_position - global_position
	var dist: float = to_target.length()
	var dir: Vector2 = to_target / dist if dist > 0.001 else Vector2.ZERO

	if variant == "spitter":
		_spit_cd = maxf(0.0, _spit_cd - delta)
		if dist <= Config.SPITTER_RANGE and _spit_cd <= 0.0:
			_fire_spit(target)
			_spit_cd = Config.SPITTER_COOLDOWN * randf_range(0.8, 1.6)

	velocity = dir * speed + _separation()
	move_and_slide()

	if velocity.length() > 5.0:
		_anim.rotation = velocity.angle()
	elif dir != Vector2.ZERO:
		_anim.rotation = dir.angle()

	_attack_cd = max(0.0, _attack_cd - delta)
	if dist <= body_radius + Config.PLAYER_RADIUS and _attack_cd <= 0.0:
		if target.has_method("take_damage"):
			target.take_damage(contact_damage)
		_attack_cd = Config.ENEMY_ATTACK_COOLDOWN
		if variant == "exploder":
			_explode_on_contact()

	if _hit_flash > 0.0:
		_hit_flash = max(0.0, _hit_flash - delta * 6.0)
	var f := _hit_flash
	_anim.modulate = Color(
		minf(_visual_tint.r + f, 1.0),
		minf(_visual_tint.g + f, 1.0),
		minf(_visual_tint.b + f, 1.0), 1.0)

	if _bar_flash > 0.0:
		_bar_flash = max(0.0, _bar_flash - delta * 3.0)
		queue_redraw()

func _get_target() -> Node2D:
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	if variant == "spitter":
		return player
	return player

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

func _fire_spit(target: Node2D) -> void:
	if target == null or not is_instance_valid(target):
		return
	var dir := (target.global_position - global_position).normalized()
	var spit_script := preload("res://scripts/enemy_spit.gd")
	var spit := spit_script.new()
	get_parent().add_child(spit)
	spit.setup(global_position + dir * (body_radius + 10.0), dir, 220.0, contact_damage * 0.8, Color("ff8e5a"))
	EventBus.request_hit_flash.emit(global_position, Color("ff8e5a"))

func _explode_on_contact() -> void:
	if _dying:
		return
	if hp <= 0.0:
		_die()
		return
	var damage: float = Config.EXPLODER_DAMAGE
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e != self and e.global_position.distance_to(global_position) <= Config.EXPLODER_RADIUS and e.has_method("take_damage"):
			e.take_damage(damage * 0.55)
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player != null and player.global_position.distance_to(global_position) <= Config.EXPLODER_RADIUS and player.has_method("take_damage"):
		player.take_damage(damage)
	for a in get_tree().get_nodes_in_group("allies"):
		if is_instance_valid(a) and a.global_position.distance_to(global_position) <= Config.EXPLODER_RADIUS and a.has_method("take_damage"):
			a.take_damage(damage)
	EventBus.request_screen_shake.emit(9.0)
	EventBus.explosion.emit(global_position)
	hp = 0.0
	_die()

func take_damage(amount: float) -> void:
	if _dying:
		return
	hp -= amount
	_hit_flash = 1.0
	_bar_flash = 1.0
	queue_redraw()
	if hp <= 0.0:
		if variant == "exploder":
			_explode_on_contact()
		else:
			_die()
	else:
		EventBus.enemy_hit.emit(global_position)

func _die() -> void:
	if _dying:
		return
	_dying = true
	remove_from_group("enemies")
	set_collision_layer_value(Config.LAYER_ENEMY, false)
	velocity = Vector2.ZERO
	EventBus.enemy_killed.emit(global_position, score_value, coin_value, is_boss)
	EventBus.request_screen_shake.emit(8.0 if is_boss else 3.0)
	if _anim != null:
		_anim.play("death")
	queue_redraw()
	get_tree().create_timer(0.7 if is_boss else 0.55).timeout.connect(queue_free)

func _draw() -> void:
	draw_circle(Vector2.ZERO, body_radius + 7.0, Color(Config.COL_ENEMY, 0.16))
	draw_circle(Vector2(0, body_radius * 0.5), body_radius * 0.85, Color(0, 0, 0, 0.22))
	if variant == "spitter":
		draw_arc(Vector2.ZERO, body_radius + 5.0, 0.0, TAU, 32, Color("65e6b3", 0.9), 2.5, true)
	if not _dying and (is_boss or hp < _max_hp):
		var bw := body_radius * 2.2
		var bh := 6.0 if is_boss else 5.0
		var by := -body_radius - (18.0 if is_boss else 12.0)
		var cells := HealthBar.cells_for(_max_hp)
		HealthBar.draw_cells(self, Vector2(-bw * 0.5, by), Vector2(bw, bh),
			hp / _max_hp, cells, _bar_flash, Config.COL_ENEMY)
