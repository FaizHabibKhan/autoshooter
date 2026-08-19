# =============================================================================
#  Config.gd  (Autoload singleton)
#  One place for every tunable number in the game. Change balance here.
#  Access anywhere as: Config.PLAYER_SPEED, Config.enemy_health(wave), etc.
# =============================================================================
extends Node

# Register input actions in code so the build never depends on the editor's
# InputMap serialization. Runs once at startup (Config is the first autoload).
func _ready() -> void:
	_bind("move_up",    [KEY_W, KEY_UP])
	_bind("move_down",  [KEY_S, KEY_DOWN])
	_bind("move_left",  [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("restart",    [KEY_R, KEY_SPACE, KEY_ENTER])

func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)

# --- Arena -------------------------------------------------------------------
const ARENA_SIZE := Vector2(1152, 648)   # matches the viewport
const ARENA_MARGIN := 24.0               # keeps the player off the edges
const SPAWN_RING_PADDING := 80.0         # how far outside the screen enemies spawn

# --- Collision layers (bit indices, 1-based like the Godot editor) -----------
const LAYER_PLAYER := 1
const LAYER_ALLY := 2
const LAYER_ENEMY := 3
const LAYER_BULLET := 4
const LAYER_PICKUP := 5

# --- Player ------------------------------------------------------------------
const PLAYER_SPEED := 320.0
const PLAYER_RADIUS := 16.0
const PLAYER_MAX_HP := 100.0
const PLAYER_ACCEL := 2200.0            # higher = snappier movement
const PLAYER_FRICTION := 2600.0

# --- Shooting (shared by player + allies) ------------------------------------
const SHOOT_RANGE := 360.0
const SHOOT_COOLDOWN := 0.32            # seconds between shots
const BULLET_SPEED := 720.0
const BULLET_DAMAGE := 25.0
const BULLET_RADIUS := 5.0
const BULLET_LIFETIME := 1.4

# --- Allies ------------------------------------------------------------------
const ALLY_RADIUS := 12.0
const ALLY_COLLECT_RADIUS := 40.0
const ALLY_FOLLOW_DISTANCE := 46.0      # radius of the ring formation
const ALLY_FOLLOW_SPEED := 380.0
const ALLY_FOLLOW_STIFFNESS := 9.0      # how eagerly allies snap to formation
const ALLY_MAX := 12                    # formation slots before it just stacks

# --- Enemies -----------------------------------------------------------------
const ENEMY_RADIUS := 14.0
const ENEMY_BASE_SPEED := 70.0
const ENEMY_SPEED_PER_WAVE := 4.0
const ENEMY_BASE_HP := 40.0
const ENEMY_HP_PER_WAVE := 12.0
const ENEMY_CONTACT_DAMAGE := 12.0
const ENEMY_ATTACK_COOLDOWN := 0.6
const ENEMY_SEPARATION := 26.0          # personal space to avoid perfect stacking
const ENEMY_TOUCH_SCORE := 10

# --- Waves / spawning --------------------------------------------------------
const WAVE_DURATION := 18.0             # seconds per wave
const SPAWN_INTERVAL_START := 1.3
const SPAWN_INTERVAL_MIN := 0.28
const SPAWN_INTERVAL_DECAY := 0.06      # subtracted per wave
const ENEMIES_PER_SPAWN_START := 1
const PICKUP_INTERVAL := 9.0            # seconds between ally pickups appearing
const PICKUP_MAX_ON_FIELD := 4

# --- Derived helpers ---------------------------------------------------------
func enemy_health(wave: int) -> float:
	return ENEMY_BASE_HP + ENEMY_HP_PER_WAVE * float(wave - 1)

func enemy_speed(wave: int) -> float:
	return ENEMY_BASE_SPEED + ENEMY_SPEED_PER_WAVE * float(wave - 1)

func spawn_interval(wave: int) -> float:
	return max(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_START - SPAWN_INTERVAL_DECAY * float(wave - 1))

func enemies_per_spawn(wave: int) -> int:
	return ENEMIES_PER_SPAWN_START + int(float(wave - 1) / 3.0)

# --- Palette (kept central so re-skinning is one edit) -----------------------
const COL_PLAYER := Color("4dd2ff")
const COL_ALLY := Color("7CFF6B")
const COL_ALLY_UNCOLLECTED := Color("ffd166")
const COL_ENEMY := Color("ff5d73")
const COL_BULLET := Color("fff5b0")
const COL_BG := Color("11141c")
const COL_GRID := Color("1b2130")
