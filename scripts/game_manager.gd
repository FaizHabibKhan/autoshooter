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

var state: State = State.PLAYING
var mode: Mode = Mode.ENDLESS
var level: int = 1

var score: int = 0
var wave: int = 1
var ally_count: int = 0
var waves_survived: int = 0
var pending_ally: Node = null   # ally awaiting a weapon choice

func _ready() -> void:
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.ally_collected.connect(_on_ally_collected)
	EventBus.player_died.connect(_on_player_died)

# --- run lifecycle -----------------------------------------------------------
# Called by Main._ready() every time the game scene loads.
func reset_run() -> void:
	state = State.PLAYING
	pending_ally = null
	score = 0
	wave = 1
	ally_count = 0
	waves_survived = 0
	EventBus.score_changed.emit(score)
	EventBus.wave_changed.emit(wave)

func start_endless() -> void:
	mode = Mode.ENDLESS
	level = 1
	_change(GAME_SCENE)

func start_level(n: int) -> void:
	mode = Mode.LEVELS
	level = clampi(n, 1, Config.level_count())
	_change(GAME_SCENE)

func retry() -> void:
	_change(GAME_SCENE)

func next_level() -> void:
	if mode == Mode.LEVELS and level < Config.level_count():
		level += 1
	_change(GAME_SCENE)

func go_to_menu() -> void:
	_change(MENU_SCENE)

func _change(path: String) -> void:
	EventBus.game_restarted.emit()
	get_tree().change_scene_to_file(path)

# --- scoring / wave ----------------------------------------------------------
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

func can_retry() -> bool:
	return state == State.GAME_OVER or state == State.LEVEL_CLEARED or state == State.WON

func is_choosing() -> bool:
	return state == State.CHOOSING

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
	if level >= Config.level_count():
		state = State.WON
		EventBus.game_won.emit(score)
	else:
		state = State.LEVEL_CLEARED
		EventBus.level_completed.emit(level, score)

# --- signal handlers ---------------------------------------------------------
func _on_enemy_killed(_pos: Vector2, score_value: int) -> void:
	add_score(score_value)

func _on_ally_collected(total: int) -> void:
	ally_count = total

func _on_player_died() -> void:
	if state != State.PLAYING:
		return
	state = State.GAME_OVER
	waves_survived = max(waves_survived, wave)
	EventBus.game_over.emit(score, waves_survived)
