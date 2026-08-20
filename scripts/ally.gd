# =============================================================================
#  ally.gd  —  a support unit. Waits on the map until the player walks near,
#  then joins the orbiting ring and auto-shoots alongside the player.
#  Extends Unit (shared auto-shoot).
# =============================================================================
extends Unit

enum AllyState { WAITING, FOLLOWING }

var state: AllyState = AllyState.WAITING
var _order: int = 0          # collection order — used for a stable ring slot
var _pulse: float = 0.0      # animation clock for the waiting marker

const RING_SPIN := 0.6       # radians/sec the whole formation rotates

func _ready() -> void:
	body_radius = Config.ALLY_RADIUS
	body_color = Config.COL_ALLY_UNCOLLECTED
	collision_layer = 0
	collision_mask = 0
	add_to_group("pickups")

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = body_radius
	shape.shape = circle
	add_child(shape)

func _physics_process(delta: float) -> void:
	if not GameManager.is_playing():
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	match state:
		AllyState.WAITING:
			_pulse += delta
			if global_position.distance_to(player.global_position) <= Config.ALLY_COLLECT_RADIUS + Config.PLAYER_RADIUS:
				_collect()
		AllyState.FOLLOWING:
			_follow(player, delta)
			process_shooting(delta)

	queue_redraw()

func _collect() -> void:
	# Safety net for the ally cap (spawner also stops spawning at the cap).
	if get_tree().get_nodes_in_group("allies").size() >= Config.ALLY_MAX:
		return
	state = AllyState.FOLLOWING
	body_color = Config.COL_ALLY
	remove_from_group("pickups")
	add_to_group("allies")
	# Stable slot = how many allies exist right now.
	var total := get_tree().get_nodes_in_group("allies").size()
	_order = total
	EventBus.ally_collected.emit(total)
	EventBus.request_hit_flash.emit(global_position, Config.COL_ALLY)

func _follow(player: Node2D, delta: float) -> void:
	var allies := get_tree().get_nodes_in_group("allies")
	var total: int = max(1, allies.size())
	# Index within a stable, order-sorted list so slots don't jump around.
	allies.sort_custom(func(a, b): return a._order < b._order)
	var index := allies.find(self)
	if index < 0:
		index = 0

	var spin := Time.get_ticks_msec() / 1000.0 * RING_SPIN
	var angle := TAU * float(index) / float(total) + spin
	var radius := Config.ALLY_FOLLOW_DISTANCE + float(max(0, total - 6)) * 3.0
	var target := player.global_position + Vector2.from_angle(angle) * radius

	# Frame-rate independent smoothing toward the slot.
	var t := 1.0 - exp(-Config.ALLY_FOLLOW_STIFFNESS * delta)
	global_position = global_position.lerp(target, t)

func _draw() -> void:
	if state == AllyState.WAITING:
		# Pulsing beacon so the player can spot uncollected allies easily.
		var p := 0.5 + 0.5 * sin(_pulse * 4.0)
		draw_circle(Vector2.ZERO, Config.ALLY_COLLECT_RADIUS, Color(Config.COL_ALLY_UNCOLLECTED, 0.06 + 0.06 * p))
		draw_arc(Vector2.ZERO, Config.ALLY_COLLECT_RADIUS, 0.0, TAU, 40, Color(Config.COL_ALLY_UNCOLLECTED, 0.25 + 0.2 * p), 2.0, true)
		draw_circle(Vector2.ZERO, body_radius, Config.COL_ALLY_UNCOLLECTED)
		draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 24, Color.WHITE, 1.5, true)
		# A small "+" to read as "pick me up".
		draw_line(Vector2(-4, 0), Vector2(4, 0), Config.COL_BG, 2.0)
		draw_line(Vector2(0, -4), Vector2(0, 4), Config.COL_BG, 2.0)
	else:
		draw_circle(Vector2.ZERO, body_radius + 4.0, Color(Config.COL_ALLY, 0.14))
		draw_circle(Vector2.ZERO, body_radius, Config.COL_ALLY)
		draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 24, Color.WHITE, 1.5, true)
