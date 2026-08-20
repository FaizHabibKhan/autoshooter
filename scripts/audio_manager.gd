# =============================================================================
#  AudioManager.gd  (Autoload singleton)
#  Plays SFX in response to EventBus signals. Uses a pool of players so many
#  sounds can overlap, throttles the very frequent ones (shooting / hits), and
#  adds slight pitch variation so repeats don't feel robotic.
# =============================================================================
extends Node

const POOL_SIZE := 14

# Loaded at runtime (not preloaded) so script parsing never depends on the
# .wav importer having run yet — robust on a cold first open of the project.
var _sfx: Dictionary = {}

var _pool: Array = []
var _next: int = 0

# Throttles (seconds) for high-frequency sounds.
const SHOOT_GAP := 0.045
const HIT_GAP := 0.03
var _last_shoot: float = -999.0
var _last_hit: float = -999.0
var _last_hp: float = Config.PLAYER_MAX_HP

func _ready() -> void:
	_sfx = {
		"shoot":   load("res://audio/shoot.wav"),
		"hit":     load("res://audio/enemy_hit.wav"),
		"death":   load("res://audio/enemy_death.wav"),
		"collect": load("res://audio/ally_collect.wav"),
		"hurt":    load("res://audio/player_hurt.wav"),
		"wave":    load("res://audio/wave.wav"),
		"over":    load("res://audio/game_over.wav"),
		"railgun": load("res://audio/railgun.wav"),
		"rocket":  load("res://audio/rocket_fire.wav"),
		"explosion": load("res://audio/explosion.wav"),
		"sniper":  load("res://audio/sniper.wav"),
		"flame":   load("res://audio/flame.wav"),
		"heal":    load("res://audio/heal.wav"),
	}
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)

	EventBus.shot_fired.connect(_on_shot)
	EventBus.enemy_hit.connect(_on_enemy_hit)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.ally_collected.connect(_on_ally_collected)
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.wave_changed.connect(_on_wave_changed)
	EventBus.game_over.connect(_on_game_over)
	EventBus.weapon_fired.connect(_on_weapon_fired)
	EventBus.explosion.connect(_on_explosion)
	EventBus.health_pickup.connect(func(_pos): _play("heal", -3.0, 1.0, 1.0))
	EventBus.game_restarted.connect(func(): _last_hp = Config.PLAYER_MAX_HP)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _play(key: String, volume_db: float = 0.0, pitch_min: float = 1.0, pitch_max: float = 1.0) -> void:
	var stream: AudioStream = _sfx.get(key)
	if stream == null:
		return
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = randf_range(pitch_min, pitch_max)
	p.play()

# --- handlers ----------------------------------------------------------------
func _on_shot(_pos: Vector2) -> void:
	var t := _now()
	if t - _last_shoot < SHOOT_GAP:
		return
	_last_shoot = t
	_play("shoot", -12.0, 0.92, 1.08)

func _on_enemy_hit(_pos: Vector2) -> void:
	var t := _now()
	if t - _last_hit < HIT_GAP:
		return
	_last_hit = t
	_play("hit", -15.0, 0.95, 1.12)

func _on_enemy_killed(_pos: Vector2, _score: int) -> void:
	_play("death", -7.0, 0.9, 1.12)

func _on_ally_collected(_total: int) -> void:
	_play("collect", -3.0, 1.0, 1.0)

func _on_player_damaged(hp: float, _max_hp: float) -> void:
	if hp < _last_hp:
		_play("hurt", -4.0, 0.95, 1.05)
	_last_hp = hp

func _on_wave_changed(w: int) -> void:
	if w > 1:
		_play("wave", -7.0, 1.0, 1.0)

func _on_game_over(_score: int, _waves: int) -> void:
	_play("over", -3.0, 1.0, 1.0)

var _last_flame: float = -999.0

func _on_weapon_fired(kind: String, _pos: Vector2) -> void:
	match kind:
		"railgun": _play("railgun", -9.0, 0.96, 1.06)
		"rocket":  _play("rocket", -8.0, 0.95, 1.05)
		"sniper":  _play("sniper", -7.0, 0.97, 1.05)
		"flame":
			# Rapid weapon — throttle so it reads as a steady jet, not a buzz.
			var t := _now()
			if t - _last_flame < 0.09:
				return
			_last_flame = t
			_play("flame", -13.0, 0.95, 1.1)

func _on_explosion(_pos: Vector2) -> void:
	_play("explosion", -5.0, 0.92, 1.08)
