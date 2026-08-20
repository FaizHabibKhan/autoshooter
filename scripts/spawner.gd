# =============================================================================
#  spawner.gd  —  drives both modes.
#   ENDLESS: waves scale forever with GameManager.wave.
#   LEVELS : a per-level survive timer + difficulty from Config.LEVELS.
#  Enforces the enemy and ally caps so large stages stay smooth.
# =============================================================================
extends Node

const EnemyScene := preload("res://scenes/Enemy.tscn")
const AllyScene := preload("res://scenes/Ally.tscn")
const HealthKitScene := preload("res://scenes/HealthKit.tscn")

var _spawn_t: float = 0.6
var _wave_t: float = 0.0
var _pickup_t: float = Config.PICKUP_FIRST_DELAY
var _health_t: float = Config.HEALTH_KIT_FIRST_DELAY
var _level_time_left: float = 0.0
var _last_shown_sec: int = -1

func _ready() -> void:
	if GameManager.mode == GameManager.Mode.LEVELS:
		_level_time_left = Config.level_survive_time(GameManager.level)
		_emit_objective()

func _physics_process(delta: float) -> void:
	if not GameManager.is_playing():
		return

	if GameManager.mode == GameManager.Mode.LEVELS:
		_tick_level(delta)
	else:
		_tick_endless(delta)

	# Ally pickups behave the same in both modes.
	_pickup_t -= delta
	if _pickup_t <= 0.0:
		_try_spawn_pickup()
		_pickup_t = Config.PICKUP_INTERVAL

	# Health kits appear occasionally.
	_health_t -= delta
	if _health_t <= 0.0:
		_try_spawn_health()
		_health_t = Config.HEALTH_KIT_INTERVAL

# --- ENDLESS -----------------------------------------------------------------
func _tick_endless(delta: float) -> void:
	_wave_t += delta
	if _wave_t >= Config.WAVE_DURATION:
		_wave_t = 0.0
		GameManager.set_wave(GameManager.wave + 1)

	_spawn_t -= delta
	if _spawn_t <= 0.0:
		var w := GameManager.wave
		_spawn_batch(Config.enemies_per_spawn(w), Config.enemy_health(w), Config.enemy_speed(w))
		_spawn_t = Config.spawn_interval(w)

# --- LEVELS ------------------------------------------------------------------
func _tick_level(delta: float) -> void:
	_level_time_left -= delta
	if int(ceil(maxf(_level_time_left, 0.0))) != _last_shown_sec:
		_emit_objective()
	if _level_time_left <= 0.0:
		GameManager.complete_level()
		return

	_spawn_t -= delta
	if _spawn_t <= 0.0:
		var lv := GameManager.level
		_spawn_batch(Config.level_enemies_per_spawn(lv), Config.level_enemy_health(lv), Config.level_enemy_speed(lv))
		_spawn_t = Config.level_spawn_interval(lv)

func _emit_objective() -> void:
	_last_shown_sec = int(ceil(maxf(_level_time_left, 0.0)))
	EventBus.objective_changed.emit("Survive:  %d s" % _last_shown_sec)

# --- shared spawning ---------------------------------------------------------
func _spawn_batch(count: int, hp: float, speed: float) -> void:
	var container := get_tree().get_first_node_in_group("enemy_container")
	if container == null:
		return
	# Enforce the hard cap on concurrent enemies.
	var alive := get_tree().get_nodes_in_group("enemies").size()
	var allowed := Config.ENEMY_MAX_ALIVE - alive
	count = min(count, allowed)
	if count <= 0:
		return
	for i in count:
		var e := EnemyScene.instantiate()
		e.hp = hp
		e.speed = speed
		e.score_value = Config.ENEMY_TOUCH_SCORE
		e.position = _ring_point()
		container.add_child(e)

func _try_spawn_pickup() -> void:
	var container := get_tree().get_first_node_in_group("pickup_container")
	if container == null:
		return
	# Never exceed the ally cap, and keep only a few on the field at once.
	if get_tree().get_nodes_in_group("allies").size() >= Config.ALLY_MAX:
		return
	if get_tree().get_nodes_in_group("pickups").size() >= Config.PICKUP_MAX_ON_FIELD:
		return
	var a := AllyScene.instantiate()
	a.position = _random_inside()
	container.add_child(a)

func _try_spawn_health() -> void:
	var container := get_tree().get_first_node_in_group("pickup_container")
	if container == null:
		return
	if get_tree().get_nodes_in_group("health_kits").size() >= Config.HEALTH_KIT_MAX:
		return
	var kit := HealthKitScene.instantiate()
	kit.position = _random_inside()
	container.add_child(kit)

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
