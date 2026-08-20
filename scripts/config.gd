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

# --- View & World ------------------------------------------------------------
const ARENA_SIZE := Vector2(1152, 648)   # the visible view / viewport size
const WORLD_SIZE := Vector2(3600, 2400)  # the full explorable map (bigger than view)
const ARENA_MARGIN := 24.0               # keeps the player off the world edges
const SPAWN_RING_PADDING := 90.0         # how far outside the view enemies spawn

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

# --- Weapons -----------------------------------------------------------------
# The player uses "rifle"; each ally rolls one of ALLY_WEAPONS when collected.
# kind drives the firing behaviour in unit.gd. Tune freely.
#   bullet : straight single-target projectile (the default rifle)
#   railgun: instant piercing beam — hits everything in a line
#   rocket : slow projectile that explodes for radial damage on impact
#   sniper : instant single shot, huge damage, very long range
#   flame  : rapid short-range cone, low damage per tick (burns a group)
var WEAPONS := {
	"rifle":   {"kind": "bullet",  "color": Color("fff5b0"), "cooldown": 0.32, "damage": 25.0,  "range": 360.0, "speed": 720.0},
	"railgun": {"kind": "railgun", "color": Color("b98bff"), "cooldown": 1.00, "damage": 55.0,  "range": 600.0, "width": 22.0},
	"rocket":  {"kind": "rocket",  "color": Color("ff9f45"), "cooldown": 1.40, "damage": 30.0,  "range": 460.0, "speed": 340.0, "blast_radius": 95.0, "blast_damage": 60.0},
	"sniper":  {"kind": "sniper",  "color": Color("7fe3ff"), "cooldown": 1.50, "damage": 160.0, "range": 760.0},
	"flame":   {"kind": "flame",   "color": Color("ff6a2b"), "cooldown": 0.10, "damage": 7.0,   "range": 190.0, "cone_deg": 42.0},
}
var ALLY_WEAPONS := ["railgun", "rocket", "sniper", "flame"]

# --- Allies ------------------------------------------------------------------
const ALLY_RADIUS := 12.0
const ALLY_COLLECT_RADIUS := 40.0
const ALLY_FOLLOW_DISTANCE := 46.0      # radius of the ring formation
const ALLY_FOLLOW_SPEED := 380.0
const ALLY_FOLLOW_STIFFNESS := 9.0      # how eagerly allies snap to formation
const ALLY_MAX := 10                    # hard cap on collected allies (perf + balance)

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
const ENEMY_MAX_ALIVE := 60             # hard cap on concurrent enemies (keeps big
                                        # stages smooth; bump to 75 for denser swarms)

# --- Waves / spawning --------------------------------------------------------
const WAVE_DURATION := 18.0             # seconds per wave
const SPAWN_INTERVAL_START := 1.3
const SPAWN_INTERVAL_MIN := 0.28
const SPAWN_INTERVAL_DECAY := 0.06      # subtracted per wave
const ENEMIES_PER_SPAWN_START := 1
const PICKUP_INTERVAL := 20.0           # allies are rare — long gap between spawns
const PICKUP_MAX_ON_FIELD := 2         # few on the map at once, scattered far away
const PICKUP_FIRST_DELAY := 6.0        # first ally appears fairly soon
const PICKUP_MIN_DIST_FROM_PLAYER := 500.0  # spawn far so you must go find them

# --- Health kits -------------------------------------------------------------
const HEALTH_KIT_INTERVAL := 24.0       # seconds between health-kit spawns
const HEALTH_KIT_FIRST_DELAY := 16.0
const HEALTH_KIT_MAX := 2               # max on the field at once
const HEALTH_KIT_HEAL := 35.0           # HP restored per kit
const HEALTH_KIT_RADIUS := 34.0         # pickup radius
const COL_HEALTH := Color("6bff9e")

# --- Sprites -----------------------------------------------------------------
# On-screen scale for the 128px character frames. Tune to taste.
const PLAYER_SPRITE_SCALE := 0.95
const ALLY_SPRITE_SCALE := 0.80
const ENEMY_SPRITE_SCALE := 0.90

# --- Off-screen indicators ---------------------------------------------------
const INDICATOR_MARGIN := 46.0         # inset from the screen edge for arrows
const INDICATOR_SIZE := 15.0           # arrow triangle size
const INDICATOR_MAX_ENEMIES := 12      # cap enemy arrows to avoid clutter

# --- Derived helpers ---------------------------------------------------------
func enemy_health(wave: int) -> float:
	return ENEMY_BASE_HP + ENEMY_HP_PER_WAVE * float(wave - 1)

func enemy_speed(wave: int) -> float:
	return ENEMY_BASE_SPEED + ENEMY_SPEED_PER_WAVE * float(wave - 1)

func spawn_interval(wave: int) -> float:
	return max(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_START - SPAWN_INTERVAL_DECAY * float(wave - 1))

func enemies_per_spawn(wave: int) -> int:
	return ENEMIES_PER_SPAWN_START + int(float(wave - 1) / 3.0)

# --- Level mode --------------------------------------------------------------
# 10 hand-tuned levels. Each is a "survive N seconds" objective with rising
# difficulty. Multipliers scale the base enemy stats/spawn rate. Add more
# dictionaries here to add levels — everything else adapts automatically.
#   survive : seconds to survive to clear the level
#   hp/spd  : enemy health / speed multiplier
#   rate    : spawn-frequency multiplier (higher = enemies appear faster)
#   burst   : extra enemies added to each spawn
const LEVELS := [
	{"survive": 25.0, "hp": 0.9,  "spd": 0.95, "rate": 1.0, "burst": 0},
	{"survive": 30.0, "hp": 1.0,  "spd": 1.0,  "rate": 1.1, "burst": 0},
	{"survive": 35.0, "hp": 1.15, "spd": 1.05, "rate": 1.25, "burst": 1},
	{"survive": 40.0, "hp": 1.3,  "spd": 1.1,  "rate": 1.4, "burst": 1},
	{"survive": 45.0, "hp": 1.5,  "spd": 1.15, "rate": 1.6, "burst": 1},
	{"survive": 50.0, "hp": 1.7,  "spd": 1.2,  "rate": 1.8, "burst": 2},
	{"survive": 55.0, "hp": 1.95, "spd": 1.28, "rate": 2.0, "burst": 2},
	{"survive": 60.0, "hp": 2.2,  "spd": 1.35, "rate": 2.25, "burst": 3},
	{"survive": 70.0, "hp": 2.6,  "spd": 1.45, "rate": 2.5, "burst": 3},
	{"survive": 80.0, "hp": 3.0,  "spd": 1.55, "rate": 2.8, "burst": 4},
]

func level_count() -> int:
	return LEVELS.size()

func level_data(level: int) -> Dictionary:
	return LEVELS[clampi(level - 1, 0, LEVELS.size() - 1)]

func level_enemy_health(level: int) -> float:
	return ENEMY_BASE_HP * float(level_data(level)["hp"])

func level_enemy_speed(level: int) -> float:
	return ENEMY_BASE_SPEED * float(level_data(level)["spd"])

func level_spawn_interval(level: int) -> float:
	return maxf(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_START / float(level_data(level)["rate"]))

func level_enemies_per_spawn(level: int) -> int:
	return ENEMIES_PER_SPAWN_START + int(level_data(level)["burst"])

func level_survive_time(level: int) -> float:
	return float(level_data(level)["survive"])

# --- Palette (kept central so re-skinning is one edit) -----------------------
const COL_PLAYER := Color("4dd2ff")
const COL_ALLY := Color("7CFF6B")
const COL_ALLY_UNCOLLECTED := Color("ffd166")
const COL_ENEMY := Color("ff5d73")
const COL_BULLET := Color("fff5b0")
const COL_BG := Color("11141c")
const COL_GRID := Color("1b2130")
