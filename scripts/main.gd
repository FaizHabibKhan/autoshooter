# =============================================================================
#  main.gd  —  root of the game scene. Builds the whole world tree in code
#  (containers, player, spawner, FX, camera, HUD) so there's no brittle scene
#  wiring, owns camera screen-shake, draws the background grid, and handles the
#  restart key. Everything else talks through the EventBus.
# =============================================================================
extends Node2D

const PlayerScene := preload("res://scenes/Player.tscn")
const SpawnerScript := preload("res://scripts/spawner.gd")
const FXScript := preload("res://scripts/fx.gd")
const HUDScript := preload("res://scripts/hud.gd")

var _camera: Camera2D
var _trauma: float = 0.0

func _ready() -> void:
	GameManager.reset_run()

	# --- entity containers (found by group elsewhere) ---
	_add_container("Projectiles", "projectiles")
	_add_container("Enemies", "enemy_container")
	_add_container("Pickups", "pickup_container")

	# --- FX layer ---
	var fx := FXScript.new()
	fx.name = "FX"
	add_child(fx)

	# --- player at arena center ---
	var player := PlayerScene.instantiate()
	player.position = Config.ARENA_SIZE * 0.5
	add_child(player)

	# --- spawner ---
	var spawner := SpawnerScript.new()
	spawner.name = "Spawner"
	add_child(spawner)

	# --- camera (fixed, centered; only used for screen shake) ---
	_camera = Camera2D.new()
	_camera.position = Config.ARENA_SIZE * 0.5
	add_child(_camera)
	_camera.make_current()

	# --- HUD ---
	add_child(HUDScript.new())

	EventBus.request_screen_shake.connect(_add_trauma)
	queue_redraw()

func _add_container(node_name: String, group: String) -> void:
	var n := Node2D.new()
	n.name = node_name
	n.add_to_group(group)
	add_child(n)

func _add_trauma(strength: float) -> void:
	_trauma = minf(1.0, _trauma + strength / 20.0)

func _process(delta: float) -> void:
	# Screen shake: trauma^2 feels better than linear.
	if _trauma > 0.0:
		_trauma = maxf(0.0, _trauma - delta * 1.5)
		var amt := _trauma * _trauma
		_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 14.0 * amt
	else:
		_camera.offset = Vector2.ZERO

	if not GameManager.is_playing() and Input.is_action_just_pressed("restart"):
		GameManager.restart()

func _draw() -> void:
	# Background: fill, subtle grid, border. Drawn behind all children.
	var size := Config.ARENA_SIZE
	draw_rect(Rect2(Vector2.ZERO, size), Config.COL_BG, true)
	var step := 48.0
	var x := 0.0
	while x <= size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), Config.COL_GRID, 1.0)
		x += step
	var y := 0.0
	while y <= size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), Config.COL_GRID, 1.0)
		y += step
	draw_rect(Rect2(Vector2.ZERO, size), Config.COL_GRID, false, 2.0)
