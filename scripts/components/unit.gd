# =============================================================================
#  unit.gd  —  base class for anything on the player's team that auto-shoots.
#  Player and Ally both `extend` this. Handles target acquisition + firing so
#  the shooting behaviour lives in exactly one place (scalable: tweak once).
# =============================================================================
class_name Unit
extends CharacterBody2D

const BulletScene := preload("res://scenes/Bullet.tscn")

# Per-unit shooting stats (defaults pulled from Config; overridable per unit).
var shoot_range: float = Config.SHOOT_RANGE
var shoot_cooldown: float = Config.SHOOT_COOLDOWN
var bullet_damage: float = Config.BULLET_DAMAGE
var body_radius: float = 16.0
var body_color: Color = Color.WHITE

var _cooldown_left: float = 0.0
var can_shoot: bool = true

# Call every frame from the subclass's _physics_process.
func process_shooting(delta: float) -> void:
	if not can_shoot or not GameManager.is_playing():
		return
	_cooldown_left -= delta
	if _cooldown_left > 0.0:
		return
	var target := _find_nearest_enemy()
	if target == null:
		return
	_fire_at(target.global_position)
	_cooldown_left = shoot_cooldown

func _find_nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := shoot_range * shoot_range
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var d := global_position.distance_squared_to(e.global_position)
		if d <= best_d:
			best_d = d
			best = e
	return best

func _fire_at(target_pos: Vector2) -> void:
	var dir := (target_pos - global_position)
	if dir.length_squared() < 0.001:
		return
	dir = dir.normalized()
	var bullet := BulletScene.instantiate()
	var container := get_tree().get_first_node_in_group("projectiles")
	if container == null:
		container = get_tree().current_scene
	container.add_child(bullet)
	bullet.global_position = global_position + dir * (body_radius + 4.0)
	bullet.setup(dir, bullet_damage)
