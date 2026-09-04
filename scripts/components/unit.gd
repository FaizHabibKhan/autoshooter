# =============================================================================
#  unit.gd  —  base class for anything on the player's team that auto-shoots.
#  Player and Ally both `extend` this. Owns a weapon (see Config.WEAPONS) and
#  dispatches firing by weapon kind: bullet / railgun / rocket / sniper / flame.
#  All targeting/geometry lives here so behaviour is defined in one place.
# =============================================================================
class_name Unit
extends CharacterBody2D

const BulletScene := preload("res://scenes/Bullet.tscn")
const RocketScene := preload("res://scenes/Rocket.tscn")
const BeamFX := preload("res://scripts/beam_fx.gd")
const FlameFX := preload("res://scripts/flame_fx.gd")

var weapon_id: String = "rifle"
var weapon_color: Color = Config.COL_BULLET
var shoot_range: float = Config.SHOOT_RANGE
var shoot_cooldown: float = Config.SHOOT_COOLDOWN
var _wstats: Dictionary = {}
var _wkind: String = "bullet"

var body_radius: float = 16.0
var body_color: Color = Color.WHITE

var _cooldown_left: float = 0.0
var can_shoot: bool = true

func set_weapon(id: String) -> void:
	weapon_id = id
	_wstats = Config.WEAPONS.get(id, Config.WEAPONS["rifle"])
	_wkind = _wstats["kind"]
	weapon_color = _wstats["color"]
	shoot_range = _wstats["range"]
	shoot_cooldown = _wstats["cooldown"]

# Call every frame from the subclass's _physics_process.
func process_shooting(delta: float) -> void:
	if not can_shoot or not GameManager.is_playing():
		return
	if _wstats.is_empty():
		set_weapon(weapon_id)
	_cooldown_left -= delta
	if _cooldown_left > 0.0:
		return
	var target := _find_nearest_enemy()
	if target == null:
		return
	var dir := (target.global_position - global_position)
	if dir.length_squared() < 0.001:
		return
	_fire(dir.normalized(), target)
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

func _muzzle(dir: Vector2) -> Vector2:
	return global_position + dir * (body_radius + 4.0)

func _container() -> Node:
	var c := get_tree().get_first_node_in_group("projectiles")
	return c if c != null else get_tree().current_scene

# --- dispatch ----------------------------------------------------------------
func _fire(dir: Vector2, target: Node2D) -> void:
	var damage_mult := GameManager.get_player_damage_multiplier() if is_in_group("player") else 1.0
	match _wkind:
		"railgun": _fire_railgun(dir, damage_mult)
		"rocket":  _fire_rocket(dir, damage_mult)
		"sniper":  _fire_sniper(target, damage_mult)
		"flame":   _fire_flame(dir, damage_mult)
		_:         _fire_bullet(dir, damage_mult)

func _fire_bullet(dir: Vector2, damage_mult: float = 1.0) -> void:
	var bullet := BulletScene.instantiate()
	_container().add_child(bullet)
	bullet.global_position = _muzzle(dir)
	bullet.setup(dir, _wstats.get("damage", Config.BULLET_DAMAGE) * damage_mult)
	EventBus.shot_fired.emit(global_position)

func _fire_railgun(dir: Vector2, damage_mult: float = 1.0) -> void:
	var muzzle := _muzzle(dir)
	var rng: float = shoot_range
	var width: float = _wstats.get("width", 22.0)
	var dmg: float = _wstats.get("damage", 50.0) * damage_mult
	# Damage every enemy within a thin rectangle along the aim ray (piercing).
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var rel: Vector2 = e.global_position - muzzle
		var proj := rel.dot(dir)
		if proj < 0.0 or proj > rng:
			continue
		var perp := (rel - dir * proj).length()
		if perp <= width and e.has_method("take_damage"):
			e.take_damage(dmg)
	_spawn_beam(muzzle, muzzle + dir * rng, 6.0, 0.16)
	EventBus.weapon_fired.emit("railgun", global_position)

func _fire_sniper(target: Node2D, damage_mult: float = 1.0) -> void:
	if not is_instance_valid(target):
		return
	if target.has_method("take_damage"):
		target.take_damage(_wstats.get("damage", 150.0) * damage_mult)
	var dir := (target.global_position - global_position).normalized()
	_spawn_beam(_muzzle(dir), target.global_position, 3.0, 0.12)
	EventBus.weapon_fired.emit("sniper", global_position)

func _fire_rocket(dir: Vector2, damage_mult: float = 1.0) -> void:
	var r := RocketScene.instantiate()
	_container().add_child(r)
	r.global_position = _muzzle(dir)
	r.setup(dir, _wstats.get("speed", 340.0), shoot_range,
			_wstats.get("blast_radius", 95.0), _wstats.get("blast_damage", 60.0) * damage_mult, weapon_color)
	EventBus.weapon_fired.emit("rocket", global_position)

func _fire_flame(dir: Vector2, damage_mult: float = 1.0) -> void:
	var cone := deg_to_rad(_wstats.get("cone_deg", 42.0))
	var rng: float = shoot_range
	var dmg: float = _wstats.get("damage", 7.0) * damage_mult
	# Damage everything inside the cone in front of the unit.
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var rel: Vector2 = e.global_position - global_position
		if rel.length() <= rng and absf(rel.angle_to(dir)) <= cone * 0.5 and e.has_method("take_damage"):
			e.take_damage(dmg)
	var fl := FlameFX.new()
	_container().add_child(fl)
	fl.setup(_muzzle(dir), dir, rng, cone, weapon_color)
	EventBus.weapon_fired.emit("flame", global_position)

func _spawn_beam(from: Vector2, to: Vector2, thick: float, dur: float) -> void:
	var beam := BeamFX.new()
	_container().add_child(beam)
	beam.setup(from, to, weapon_color, thick, dur)
