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

# --- Boss ---------------------------------------------------------------------
const BOSS_EVERY := 10                  # every Nth endless wave is a boss wave
const BOSS_BASE_HP := 1400.0
const BOSS_HP_PER_TIER := 0.35          # +35% per boss tier (wave 10, 20, 30…)
const BOSS_SPEED := 46.0
const BOSS_CONTACT_DAMAGE := 30.0
const BOSS_SCALE := 2.4                 # sprite/ body multiplier
const BOSS_SCORE := 500
const BOSS_MINIONS := 6                 # minions that trickle in during a boss wave

func is_boss_wave(w: int) -> bool:
	return w % BOSS_EVERY == 0

func boss_health(w: int) -> float:
	var tier := int(w / BOSS_EVERY)      # 1,2,3… for waves 10,20,30
	return BOSS_BASE_HP * (1.0 + BOSS_HP_PER_TIER * float(tier - 1))

# --- ENDLESS: wave-based (dynamic formulas) ----------------------------------
# Wave 1 = 10 enemies, +5 each wave; enemies get healthier/faster; spawns are
# trickled over time (see spawner). Waves rise forever.
func wave_enemy_count(w: int) -> int:
	return 10 + 5 * (w - 1)

func wave_enemy_health(w: int) -> float:
	return ENEMY_BASE_HP * (1.0 + 0.15 * float(w - 1))

func wave_enemy_speed(w: int) -> float:
	return minf(ENEMY_BASE_SPEED * 2.2, ENEMY_BASE_SPEED * (1.0 + 0.04 * float(w - 1)))

func wave_spawn_interval(w: int) -> float:
	return maxf(0.25, 0.85 - 0.03 * float(w - 1))     # spawn a little faster each wave

func wave_per_spawn(w: int) -> int:
	return 1 + int(float(w - 1) / 4.0)                # trickle grows slowly

# --- LEVELS: dynamic / unbounded ---------------------------------------------
# Levels are no longer a fixed list — difficulty is a function of the level
# number, so they rise forever. Each level is a "survive N seconds" objective.
func level_enemy_health(l: int) -> float:
	return ENEMY_BASE_HP * (1.0 + 0.18 * float(l - 1))

func level_enemy_speed(l: int) -> float:
	return minf(ENEMY_BASE_SPEED * 2.3, ENEMY_BASE_SPEED * (1.0 + 0.05 * float(l - 1)))

func level_spawn_interval(l: int) -> float:
	return maxf(0.30, 1.10 - 0.05 * float(l - 1))

func level_enemies_per_spawn(l: int) -> int:
	return 1 + int(float(l - 1) / 3.0)

func level_survive_time(l: int) -> float:
	return minf(120.0, 25.0 + 5.0 * float(l - 1))

# --- Palette (kept central so re-skinning is one edit) -----------------------
const COL_PLAYER := Color("4dd2ff")
const COL_ALLY := Color("7CFF6B")
const COL_ALLY_UNCOLLECTED := Color("ffd166")
const COL_ENEMY := Color("ff5d73")
const COL_BULLET := Color("fff5b0")
const COL_BG := Color("11141c")
const COL_GRID := Color("1b2130")
