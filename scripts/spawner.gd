# =============================================================================
#  spawner.gd  —  drives both modes.
#   ENDLESS: true wave-based. Wave N spawns wave_enemy_count(N) enemies, trickled
#            over time; the wave clears (→ next) only when all are dead. Every
#            10th wave is a BOSS wave (a big enemy + a few minions).
#   LEVELS : survive-the-timer, difficulty a function of the (unbounded) level.
#  Enemy/ally caps and health-at-full are all respected.
# =============================================================================
extends Node

const EnemyScene := preload("res://scenes/Enemy.tscn")
const AllyScene := preload("res://scenes/Ally.tscn")
const HealthKitScene := preload("res://scenes/HealthKit.tscn")
const ShieldKitScript := preload("res://scripts/shield_kit.gd")

var _spawn_t: float = 0.4
var _pickup_t: float = Config.PICKUP_FIRST_DELAY
var _health_t: float = Config.HEALTH_KIT_FIRST_DELAY
var _shield_t: float = Config.SHIELD_KIT_FIRST_DELAY

# endless wave state
var _wave_active: bool = false
var _wave_to_spawn: int = 0
var _between: float = 0.0

# level state
var _level_time_left: float = 0.0
var _last_shown_sec: int = -1

func _ready() -> void:
	if GameManager.mode == GameManager.Mode.LEVELS:
		_level_time_left = Config.level_survive_time(GameManager.level)
		_emit_objective()
	else:
		_start_wave(1)

func _physics_process(delta: float) -> void:
	if not GameManager.is_playing():
		return

	if GameManager.mode == GameManager.Mode.LEVELS:
		_tick_level(delta)
	else:
		_tick_endless(delta)

	_pickup_t -= delta
	if _pickup_t <= 0.0:
		_try_spawn_pickup()
		_pickup_t = Config.PICKUP_INTERVAL

	_health_t -= delta
	if _health_t <= 0.0:
		_try_spawn_health()
		_health_t = Config.HEALTH_KIT_INTERVAL

	_shield_t -= delta
	if _shield_t <= 0.0:
		_try_spawn_shield()
		_shield_t = Config.SHIELD_KIT_INTERVAL

# --- ENDLESS -----------------------------------------------------------------
func _start_wave(w: int) -> void:
	GameManager.set_wave(w)
	_wave_active = true
	_spawn_t = 0.4
	if Config.is_boss_wave(w):
		_spawn_boss(w)
		_wave_to_spawn = Config.BOSS_MINIONS
		EventBus.boss_wave.emit(w)
	else:
		_wave_to_spawn = Config.wave_enemy_count(w)

func _tick_endless(delta: float) -> void:
	if not _wave_active:
		_between -= delta
		if _between <= 0.0:
			_start_wave(GameManager.wave + 1)
		return

	if _wave_to_spawn > 0:
		_spawn_t -= delta
		if _spawn_t <= 0.0:
			var w := GameManager.wave
			var n: int = min(_wave_to_spawn, Config.wave_per_spawn(w))
			var got := _spawn_batch(n, Config.wave_enemy_health(w), Config.wave_enemy_speed(w))
			_wave_to_spawn -= got   # any blocked by the cap retry next tick
			_spawn_t = Config.wave_spawn_interval(w)
	elif get_tree().get_nodes_in_group("enemies").is_empty():
		# whole wave down → short breather, then next wave
		_wave_active = false
		_between = 2.5
		GameManager.on_wave_cleared(GameManager.wave)

func _spawn_boss(w: int) -> void:
	var container := get_tree().get_first_node_in_group("enemy_container")
	if container == null:
		return
	var e := EnemyScene.instantiate()
	e.is_boss = true
	e.hp = Config.boss_health(w)
	e._max_hp = e.hp
	e.speed = Config.BOSS_SPEED
	e.contact_damage = Config.BOSS_CONTACT_DAMAGE
	e.score_value = Config.BOSS_SCORE
	e.coin_value = int(max(20.0, e.hp * 0.14 * Config.BOSS_COIN_BONUS))
	e.position = _ring_point()
	container.add_child(e)

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
# Returns how many were actually spawned (limited by the alive cap).
func _spawn_batch(count: int, hp: float, speed: float) -> int:
	var container := get_tree().get_first_node_in_group("enemy_container")
	if container == null:
		return 0
	var alive: int = get_tree().get_nodes_in_group("enemies").size()
	var allowed: int = Config.ENEMY_MAX_ALIVE - alive
	count = min(count, allowed)
	if count <= 0:
		return 0
	for i in count:
		var e := EnemyScene.instantiate()
		var rand := RandomNumberGenerator.new()
		rand.randomize()
		var variant := "walker"
		if GameManager.wave >= Config.SPITTER_SPAWN_MIN_WAVE and rand.randf() < Config.ENEMY_VARIANT_CHANCE_SPITTER:
			variant = "spitter"
		elif GameManager.wave >= Config.EXPLODER_SPAWN_MIN_WAVE and rand.randf() < Config.ENEMY_VARIANT_CHANCE_EXPLODER:
			variant = "exploder"
		e.variant = variant
		e.hp = hp * (1.0 + (0.18 if variant == "exploder" else 0.0) + (0.12 if variant == "spitter" else 0.0))
		e._max_hp = e.hp
		e.speed = speed * (1.0 + (0.12 if variant == "spitter" else 0.0))
		e.score_value = Config.ENEMY_TOUCH_SCORE + (10 if variant == "exploder" else 0) + (8 if variant == "spitter" else 0)
		e.contact_damage = Config.ENEMY_CONTACT_DAMAGE * (1.0 + (0.35 if variant == "exploder" else 0.0) + (0.2 if variant == "spitter" else 0.0))
		e.coin_value = int(max(4, ceil(hp * 0.15 + e.score_value * 0.8)))
		e.position = _ring_point()
		container.add_child(e)
	return count

func _try_spawn_pickup() -> void:
	var container := get_tree().get_first_node_in_group("pickup_container")
	if container == null:
		return
	# Never spawn allies past the cap, and keep only a few pickups on the field.
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
	# Don't drop kits when the player is already full, or when the field is full.
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null and "hp" in player and "max_hp" in player and player.hp >= player.max_hp - 0.5:
		return
	if get_tree().get_nodes_in_group("health_kits").size() >= Config.HEALTH_KIT_MAX:
		return
	var kit := HealthKitScene.instantiate()
	kit.position = _random_inside()
	container.add_child(kit)

func _try_spawn_shield() -> void:
	var container := get_tree().get_first_node_in_group("pickup_container")
	if container == null:
		return
	if get_tree().get_nodes_in_group("shield_kits").size() >= Config.SHIELD_KIT_MAX:
		return
	var kit := ShieldKitScript.new()
	kit.position = _random_inside()
	container.add_child(kit)

func _ring_point() -> Vector2:
	var player: Node2D = get_tree().get_first_node_in_group("player")
	var center: Vector2 = player.global_position if player != null else Config.WORLD_SIZE * 0.5
	var ang: float = randf() * TAU
	var r: float = Config.ARENA_SIZE.length() * 0.5 + Config.SPAWN_RING_PADDING
	return center + Vector2.from_angle(ang) * r

func _random_inside() -> Vector2:
	var player: Node2D = get_tree().get_first_node_in_group("player")
	var m := 120.0
	var pos := Vector2.ZERO
	for attempt in 12:
		pos = Vector2(
			randf_range(m, Config.WORLD_SIZE.x - m),
			randf_range(m, Config.WORLD_SIZE.y - m))
		if player == null or pos.distance_to(player.global_position) >= Config.PICKUP_MIN_DIST_FROM_PLAYER:
			break
	return pos
