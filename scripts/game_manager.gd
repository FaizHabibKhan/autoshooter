# =============================================================================
#  GameManager.gd  (Autoload singleton)
#  Holds run state: score, wave, ally count, alive/dead. Owns start/restart.
#  Keeps no node references beyond what it needs — Main wires the scene.
# =============================================================================
extends Node

enum State { PLAYING, GAME_OVER }

var state: State = State.PLAYING
var score: int = 0
var wave: int = 1
var ally_count: int = 0
var waves_survived: int = 0

func _ready() -> void:
	# React to gameplay events and keep the canonical state.
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.ally_collected.connect(_on_ally_collected)
	EventBus.player_died.connect(_on_player_died)

func reset_run() -> void:
	state = State.PLAYING
	score = 0
	wave = 1
	ally_count = 0
	waves_survived = 0
	EventBus.score_changed.emit(score)
	EventBus.wave_changed.emit(wave)

func add_score(amount: int) -> void:
	score += amount
	EventBus.score_changed.emit(score)

func set_wave(new_wave: int) -> void:
	if new_wave == wave:
		return
	wave = new_wave
	waves_survived = max(waves_survived, wave - 1)
	EventBus.wave_changed.emit(wave)

func is_playing() -> bool:
	return state == State.PLAYING

# --- Signal handlers ---------------------------------------------------------
func _on_enemy_killed(_pos: Vector2, score_value: int) -> void:
	add_score(score_value)

func _on_ally_collected(total: int) -> void:
	ally_count = total

func _on_player_died() -> void:
	if state == State.GAME_OVER:
		return
	state = State.GAME_OVER
	waves_survived = max(waves_survived, wave)
	EventBus.game_over.emit(score, waves_survived)

func restart() -> void:
	reset_run()
	EventBus.game_restarted.emit()
	get_tree().reload_current_scene()
