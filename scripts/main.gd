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
const IndicatorsScript := preload("res://scripts/indicators.gd")
const MinimapScript := preload("res://scripts/minimap.gd")

var _camera: Camera2D
var _player: Node2D
var _trauma: float = 0.0
var _ground: Texture2D
var _road: Texture2D

func _ready() -> void:
	GameManager.reset_run()
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED   # lets the ground tile
	_ground = load("res://art/ground_tile.png")
	_road = load("res://art/road_tile.png")
	_build_decals()

	# --- entity containers (found by group elsewhere) ---
	_add_container("Projectiles", "projectiles")
	_add_container("Enemies", "enemy_container")
	_add_container("Pickups", "pickup_container")

	# --- FX layer ---
	var fx := FXScript.new()
	fx.name = "FX"
	add_child(fx)

	# --- player at world center ---
	var player := PlayerScene.instantiate()
	player.position = Config.WORLD_SIZE * 0.5
	add_child(player)
	_player = player

	# --- spawner ---
	var spawner := SpawnerScript.new()
	spawner.name = "Spawner"
	add_child(spawner)

	# --- camera: follows the player, clamped to the world edges ---
	_camera = Camera2D.new()
	_camera.position = _player.global_position
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 8.0
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(Config.WORLD_SIZE.x)
	_camera.limit_bottom = int(Config.WORLD_SIZE.y)
	_camera.add_to_group("camera")
	add_child(_camera)
	_camera.make_current()

	# --- HUD + off-screen indicators ---
	add_child(HUDScript.new())
	var ind_layer := CanvasLayer.new()
	ind_layer.layer = 9   # just under the HUD (layer 10)
	add_child(ind_layer)
	ind_layer.add_child(IndicatorsScript.new())
	ind_layer.add_child(MinimapScript.new())

	# --- vignette overlay (mood) ---
	var vig_layer := CanvasLayer.new()
	vig_layer.layer = 8
	var vig := TextureRect.new()
	vig.texture = load("res://art/vignette.png")
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vig_layer.add_child(vig)
	add_child(vig_layer)

	EventBus.request_screen_shake.connect(_add_trauma)
	queue_redraw()

func _build_decals() -> void:
	# Scatter static rubble/rock/crater sprites across the world, behind entities.
	var decals := Node2D.new()
	decals.name = "Decals"
	add_child(decals)   # added first → renders under the entity containers
	var texs := [
		load("res://art/decal_rock.png"),
		load("res://art/decal_rubble.png"),
		load("res://art/decal_crater.png"),
		load("res://art/decal_rock.png"),
		load("res://art/decal_rubble.png"),
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	for i in 90:
		var sp := Sprite2D.new()
		sp.texture = texs[rng.randi() % texs.size()]
		sp.position = Vector2(
			rng.randf_range(80.0, Config.WORLD_SIZE.x - 80.0),
			rng.randf_range(80.0, Config.WORLD_SIZE.y - 80.0))
		sp.rotation = rng.randf_range(0.0, TAU)
		sp.scale = Vector2.ONE * rng.randf_range(0.7, 1.3)
		sp.modulate = Color(1, 1, 1, rng.randf_range(0.85, 1.0))
		decals.add_child(sp)

func _add_container(node_name: String, group: String) -> void:
	var n := Node2D.new()
	n.name = node_name
	n.add_to_group(group)
	add_child(n)

func _add_trauma(strength: float) -> void:
	_trauma = minf(1.0, _trauma + strength / 20.0)

func _process(delta: float) -> void:
	# Camera follows the player (smoothing set on the camera does the easing).
	if is_instance_valid(_player):
		_camera.position = _player.global_position

	# Screen shake: trauma^2 feels better than linear.
	if _trauma > 0.0:
		_trauma = maxf(0.0, _trauma - delta * 1.5)
		var amt := _trauma * _trauma
		_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 14.0 * amt
	else:
		_camera.offset = Vector2.ZERO

	if GameManager.can_retry() and Input.is_action_just_pressed("restart"):
		GameManager.retry()

func _draw() -> void:
	# Wasteland battleground: tiled dirt, a cracked road cross, lane dashes,
	# and a world border. (Rocks/rubble/craters are decal sprites; see above.)
	var world: Vector2 = Config.WORLD_SIZE
	if _ground != null:
		draw_texture_rect(_ground, Rect2(Vector2.ZERO, world), true)
	else:
		draw_rect(Rect2(Vector2.ZERO, world), Config.COL_BG, true)

	var cx: float = world.x * 0.5
	var cy: float = world.y * 0.5
	var hw: float = 150.0
	if _road != null:
		draw_texture_rect(_road, Rect2(0.0, cy - hw, world.x, hw * 2.0), true)
		draw_texture_rect(_road, Rect2(cx - hw, 0.0, hw * 2.0, world.y), true)

	# Faded lane dashes down the middle of each road.
	var dash := Color(0.83, 0.76, 0.45, 0.45)
	var x := 0.0
	while x < world.x:
		draw_rect(Rect2(x, cy - 4.0, 42.0, 8.0), dash, true)
		x += 92.0
	var y := 0.0
	while y < world.y:
		draw_rect(Rect2(cx - 4.0, y, 8.0, 42.0), dash, true)
		y += 92.0

	draw_rect(Rect2(Vector2.ZERO, world), Color(0, 0, 0, 0.55), false, 6.0)
