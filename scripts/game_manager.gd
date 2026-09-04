# =============================================================================
#  GameManager.gd  (Autoload singleton)
#  Owns run state (score, wave/level, ally count) and the two game modes:
#  ENDLESS (infinite scaling) and LEVELS (10 survive-the-timer stages).
#  Also owns scene transitions between the menu and the game.
# =============================================================================
extends Node

enum State { PLAYING, GAME_OVER, LEVEL_CLEARED, WON, CHOOSING }
enum Mode { ENDLESS, LEVELS }

const GAME_SCENE := "res://scenes/Main.tscn"
const MENU_SCENE := "res://scenes/Menu.tscn"
const SAVE_PATH := "user://save.cfg"

var state: State = State.PLAYING
var mode: Mode = Mode.ENDLESS
var level: int = 1

var score: int = 0
var wave: int = 1
var ally_count: int = 0
var waves_survived: int = 0
var pending_ally: Node = null   # ally awaiting a weapon choice
var coins: int = 0
var menu_page: String = "main"
var upgrade_levels: Dictionary = {
	"damage": 0,
	"health": 0,
	"magnet": 0,
	"shield": 0,
	"speed": 0,
}
var _shield_timer: float = 0.0

# Persistent progress
var campaign_level: int = 1     # highest unlocked level (levels rise forever)
var endless_best: int = 0       # best endless wave reached

func _ready() -> void:
	_load_progress()
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.ally_collected.connect(_on_ally_collected)
	EventBus.player_died.connect(_on_player_died)
	EventBus.coins_changed.emit(coins)

func _process(delta: float) -> void:
	if _shield_timer > 0.0:
		_shield_timer = maxf(0.0, _shield_timer - delta)

func _load_progress() -> void:
	var defaults: Dictionary = {"damage": 0, "health": 0, "magnet": 0, "shield": 0, "speed": 0}
	upgrade_levels = defaults.duplicate()
	var c := ConfigFile.new()
	if c.load(SAVE_PATH) == OK:
		campaign_level = int(c.get_value("progress", "campaign_level", 1))
		endless_best = int(c.get_value("progress", "endless_best", 0))
		var loaded_upgrades: Variant = c.get_value("progress", "upgrades", defaults)
		if loaded_upgrades is Dictionary:
			var saved: Dictionary = loaded_upgrades
			for key in defaults.keys():
				upgrade_levels[key] = clampi(int(saved.get(key, 0)), 0, Config.UPGRADE_CAPS.get(key, Config.UPGRADE_LEVELS))
	EventBus.upgrade_changed.emit("damage", upgrade_levels["damage"])
	EventBus.upgrade_changed.emit("health", upgrade_levels["health"])
	EventBus.upgrade_changed.emit("magnet", upgrade_levels["magnet"])
	EventBus.upgrade_changed.emit("shield", upgrade_levels["shield"])
	EventBus.upgrade_changed.emit("speed", upgrade_levels["speed"])

func _save_progress() -> void:
	var c := ConfigFile.new()
	c.set_value("progress", "campaign_level", campaign_level)
	c.set_value("progress", "endless_best", endless_best)
	c.set_value("progress", "upgrades", upgrade_levels)
	c.save(SAVE_PATH)

# --- run lifecycle -----------------------------------------------------------
# Called by Main._ready() every time the game scene loads.
func reset_run() -> void:
	state = State.PLAYING
	pending_ally = null
	score = 0
	wave = 1
	ally_count = 0
	waves_survived = 0
	coins = 0
	_shield_timer = 0.0
	EventBus.score_changed.emit(score)
	EventBus.wave_changed.emit(wave)
	EventBus.coins_changed.emit(coins)
	EventBus.upgrade_changed.emit("damage", upgrade_levels["damage"])
	EventBus.upgrade_changed.emit("health", upgrade_levels["health"])
	EventBus.upgrade_changed.emit("magnet", upgrade_levels["magnet"])
	EventBus.upgrade_changed.emit("shield", upgrade_levels["shield"])
	EventBus.upgrade_changed.emit("speed", upgrade_levels["speed"])

func start_endless() -> void:
	mode = Mode.ENDLESS
	level = 1
	_change(GAME_SCENE)

func start_level(n: int) -> void:
	mode = Mode.LEVELS
	level = maxi(1, n)   # levels are unbounded
	_change(GAME_SCENE)

func retry() -> void:
	_change(GAME_SCENE)

func next_level() -> void:
	if mode == Mode.LEVELS:
		level += 1
	_change(GAME_SCENE)

func go_to_menu(page: String = "main") -> void:
	menu_page = page
	_change(MENU_SCENE)

func go_to_upgrades() -> void:
	go_to_menu("upgrades")

func _change(path: String) -> void:
	EventBus.game_restarted.emit()
	get_tree().change_scene_to_file(path)

# --- scoring / wave ----------------------------------------------------------
func add_score(amount: int) -> void:
	score += amount
	EventBus.score_changed.emit(score)

func add_coins(amount: int) -> void:
	coins += max(0, amount)
	EventBus.coins_changed.emit(coins)

func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	EventBus.coins_changed.emit(coins)
	return true

func set_wave(new_wave: int) -> void:
	if new_wave == wave:
		return
	wave = new_wave
	waves_survived = max(waves_survived, wave - 1)
	EventBus.wave_changed.emit(wave)

func is_playing() -> bool:
	return state == State.PLAYING

func can_retry() -> bool:
	return state == State.GAME_OVER or state == State.LEVEL_CLEARED or state == State.WON

func is_choosing() -> bool:
	return state == State.CHOOSING

func is_ally_invincible() -> bool:
	return _shield_timer > 0.0

func is_shield_active() -> bool:
	return _shield_timer > 0.0

func get_shield_time_remaining() -> float:
	return _shield_timer

func get_upgrade_level(id: String) -> int:
	return int(upgrade_levels.get(id, 0))

func get_upgrade_cost(id: String) -> int:
	var lvl := get_upgrade_level(id)
	return Config.get_upgrade_cost_for_level(id, lvl)

func get_player_damage_multiplier() -> float:
	var lvl := get_upgrade_level("damage")
	return 1.0 + float(lvl) * Config.PLAYER_DAMAGE_UPGRADE

func get_player_health_multiplier() -> float:
	var lvl := get_upgrade_level("health")
	return 1.0 + float(lvl) * Config.PLAYER_HEALTH_UPGRADE

func get_player_speed_multiplier() -> float:
	var lvl := get_upgrade_level("speed")
	return 1.0 + float(lvl) * Config.PLAYER_SPEED_UPGRADE

func get_magnet_radius() -> float:
	return float(get_upgrade_level("magnet")) * Config.MAGNET_RADIUS_PER_LEVEL

func get_shield_duration() -> float:
	return Config.SHIELD_DURATION_BASE + float(get_upgrade_level("shield")) * Config.SHIELD_DURATION_PER_LEVEL

func get_player_max_hp() -> float:
	return Config.PLAYER_MAX_HP * get_player_health_multiplier()

func apply_player_upgrades() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var next_max: float = get_player_max_hp()
	if "max_hp" in player and "hp" in player:
		var old: float = player.max_hp
		player.max_hp = next_max
		player.hp = min(player.max_hp, player.hp + (next_max - old))
		EventBus.player_damaged.emit(player.hp, player.max_hp)

func buy_upgrade(id: String) -> bool:
	if not Config.UPGRADE_COSTS.has(id):
		return false
	var lvl := get_upgrade_level(id)
	if lvl >= Config.UPGRADE_CAPS.get(id, Config.UPGRADE_LEVELS):
		return false
	var cost := get_upgrade_cost(id)
	if not spend_coins(cost):
		return false
	upgrade_levels[id] = lvl + 1
	_save_progress()
	EventBus.upgrade_changed.emit(id, upgrade_levels[id])
	if id == "health":
		apply_player_upgrades()
	if id == "speed":
		var player: Node = get_tree().get_first_node_in_group("player")
		if player != null and player.has_method("_update_sprite"):
			player._update_sprite(0.0)
	return true

func activate_shield(duration: float) -> void:
	if duration <= 0.0:
		return
	_shield_timer = maxf(_shield_timer, duration)
	EventBus.shield_started.emit(_shield_timer)

func drop_coins(pos: Vector2, amount: int) -> void:
	if amount <= 0:
		return
	var container := get_tree().get_first_node_in_group("pickup_container")
	if container == null:
		container = get_tree().current_scene
	var coin_script := preload("res://scripts/coin.gd")
	for i in range(max(1, int(round(float(amount) / 2.0)))):
		var coin := coin_script.new()
		coin.global_position = pos + Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
		coin.value = int(max(1, amount / max(1, i + 1)))
		container.add_child(coin)
	if max(1, int(round(float(amount) / 2.0))) <= 0:
		var coin := coin_script.new()
		coin.global_position = pos
		coin.value = amount
		container.add_child(coin)

# --- ally weapon selection (pick-on-collect) ---------------------------------
func begin_selection(ally: Node) -> void:
	if state != State.PLAYING:
		return
	pending_ally = ally
	state = State.CHOOSING
	EventBus.selection_started.emit()

func confirm_selection(weapon_id: String) -> void:
	if state != State.CHOOSING:
		return
	var a := pending_ally
	pending_ally = null
	state = State.PLAYING
	if is_instance_valid(a) and a.has_method("join_with"):
		a.join_with(weapon_id)
	EventBus.selection_ended.emit()

func cancel_selection() -> void:
	if state != State.CHOOSING:
		return
	var a := pending_ally
	pending_ally = null
	state = State.PLAYING
	if is_instance_valid(a) and a.has_method("on_declined"):
		a.on_declined()
	EventBus.selection_ended.emit()

# --- outcomes ----------------------------------------------------------------
# Called by the spawner when a level's survive-timer runs out.
func complete_level() -> void:
	if state != State.PLAYING:
		return
	campaign_level = maxi(campaign_level, level + 1)   # unlock the next level
	_save_progress()
	state = State.LEVEL_CLEARED
	EventBus.level_completed.emit(level, score)

# Called by the spawner in endless mode when a whole wave is cleared.
func on_wave_cleared(cleared_wave: int) -> void:
	endless_best = maxi(endless_best, cleared_wave)
	_save_progress()
	EventBus.wave_cleared.emit(cleared_wave)

# --- signal handlers ---------------------------------------------------------
func _on_enemy_killed(pos: Vector2, score_value: int, coin_value: int, _is_boss: bool) -> void:
	add_score(score_value)
	if coin_value > 0:
		drop_coins(pos, coin_value)

func _on_ally_collected(total: int) -> void:
	ally_count = total

func _on_player_died() -> void:
	if state != State.PLAYING:
		return
	state = State.GAME_OVER
	waves_survived = max(waves_survived, wave)
	EventBus.game_over.emit(score, waves_survived)
