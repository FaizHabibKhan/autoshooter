# =============================================================================
#  spawner.gd  —  drives waves. Spawns enemies from a ring outside the screen
#  ("from all directions") and periodically drops collectible allies inside.
#  Difficulty scales with the wave number via Config helpers.
# =============================================================================
extends Node

const EnemyScene := preload("res://scenes/Enemy.tscn")
const AllyScene := preload("res://scenes/Ally.tscn")

var _spawn_t: float = 0.6
var _wave_t: float = 0.0
var _pickup_t: float = Config.PICKUP_FIRST_DELAY

func _physics_process(delta: float) -> void:
	if not GameManager.is_playing():
		return

	_wave_t += delta
	if _wave_t >= Config.WAVE_DURATION:
		_wave_t = 0.0
		GameManager.set_wave(GameManager.wave + 1)

	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_enemies()
		_spawn_t = Config.spawn_interval(GameManager.wave)

	_pickup_t -= delta
	if _pickup_t <= 0.0:
		_try_spawn_pickup()
		_pickup_t = Config.PICKUP_INTERVAL

func _spawn_enemies() -> void:
	var container := get_tree().get_first_node_in_group("enemy_container")
	if container == null:
		return
	var count := Config.enemies_per_spawn(GameManager.wave)
	for i in count:
		var e := EnemyScene.instantiate()
		e.wave = GameManager.wave
		e.position = _ring_point()
		container.add_child(e)

func _try_spawn_pickup() -> void:
	var container := get_tree().get_first_node_in_group("pickup_container")
	if container == null:
		return
	if get_tree().get_nodes_in_group("pickups").size() >= Config.PICKUP_MAX_ON_FIELD:
		return
	var a := AllyScene.instantiate()
	a.position = _random_inside()
	container.add_child(a)

func _ring_point() -> Vector2:
	# Spawn just off-screen around the PLAYER, so enemies always close in from
	# every direction no matter where the player has wandered in the world.
	var player: Node2D = get_tree().get_first_node_in_group("player")
	var center: Vector2 = player.global_position if player != null else Config.WORLD_SIZE * 0.5
	var ang := randf() * TAU
	var r := Config.ARENA_SIZE.length() * 0.5 + Config.SPAWN_RING_PADDING
	return center + Vector2.from_angle(ang) * r

func _random_inside() -> Vector2:
	# Allies drop somewhere in the world, far from the player, so you have to
	# explore to reach them.
	var player: Node2D = get_tree().get_first_node_in_group("player")
	var m := 120.0
	var pos := Vector2.ZERO
	for attempt in 12:
		pos = Vector2(
			randf_range(m, Config.WORLD_SIZE.x - m),
			randf_range(m, Config.WORLD_SIZE.y - m)
		)
		if player == null or pos.distance_to(player.global_position) >= Config.PICKUP_MIN_DIST_FROM_PLAYER:
			break
	return pos
