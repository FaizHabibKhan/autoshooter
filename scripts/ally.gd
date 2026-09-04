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
var _anim: AnimatedSprite2D
var _declined: bool = false  # true after the player skips this ally's picker

const RING_SPIN := 0.6       # radians/sec the whole formation rotates

func _ready() -> void:
	body_radius = Config.ALLY_RADIUS
	body_color = Config.COL_ALLY_UNCOLLECTED
	collision_layer = 0
	collision_mask = 0
	z_index = 1
	add_to_group("pickups")

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = body_radius
	shape.shape = circle
	add_child(shape)

	_anim = AnimatedSprite2D.new()
	_anim.sprite_frames = SpriteLib.get_frames("ally")
	_anim.scale = Vector2.ONE * Config.ALLY_SPRITE_SCALE
	_anim.play("walk")
	_anim.speed_scale = 0.0   # stands still until collected
	add_child(_anim)
	# Weapon is chosen by the player at pickup time (see join_with).

func _physics_process(delta: float) -> void:
	if not GameManager.is_playing():
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	match state:
		AllyState.WAITING:
			_pulse += delta
			var d := global_position.distance_to(player.global_position)
			if d > Config.ALLY_COLLECT_RADIUS * 1.6:
				_declined = false   # reset once the player walks away
			# Open the weapon picker when the player steps close (unless already
			# skipped here, at the ally cap, or another picker is open).
			if not _declined \
					and GameManager.pending_ally == null \
					and get_tree().get_nodes_in_group("allies").size() < Config.ALLY_MAX \
					and d <= Config.ALLY_COLLECT_RADIUS + Config.PLAYER_RADIUS:
				GameManager.begin_selection(self)
		AllyState.FOLLOWING:
			_follow(player, delta)
			process_shooting(delta)
			_update_sprite()

	queue_redraw()

func _update_sprite() -> void:
	# Face the nearest enemy while shooting; otherwise face the player.
	var target := _find_nearest_enemy()
	var player := get_tree().get_first_node_in_group("player")
	if target != null:
		_anim.rotation = (target.global_position - global_position).angle()
	elif player != null:
		_anim.rotation = (player.global_position - global_position).angle()

# Called by GameManager.confirm_selection() with the player's chosen weapon.
func join_with(chosen_weapon: String) -> void:
	if get_tree().get_nodes_in_group("allies").size() >= Config.ALLY_MAX:
		return
	state = AllyState.FOLLOWING
	set_weapon(chosen_weapon)
	# Swap to the weapon-colored soldier sprite.
	var wf := SpriteLib.get_frames("ally_" + chosen_weapon)
	if wf != null:
		_anim.sprite_frames = wf
		_anim.play("walk")
	_anim.speed_scale = 1.0   # comes to life once collected
	remove_from_group("pickups")
	add_to_group("allies")
	# Stable slot = how many allies exist right now.
	var total := get_tree().get_nodes_in_group("allies").size()
	_order = total
	EventBus.ally_collected.emit(total)
	EventBus.request_hit_flash.emit(global_position, weapon_color)

# Called by GameManager.cancel_selection() when the player skips this ally.
func on_declined() -> void:
	_declined = true

func take_damage(amount: float) -> void:
	if GameManager.is_shield_active():
		return
	if not is_inside_tree():
		return
	# Allies can be hit by enemy contact/explosions; they simply lose their
	# current momentum and brief flash, but do not hard-crash the run.
	_anim.modulate = Color(1.0, 1.0, 1.0, 1.0)
	EventBus.request_hit_flash.emit(global_position, weapon_color)

func _follow(player: Node2D, delta: float) -> void:
	var allies := get_tree().get_nodes_in_group("allies")
	var total: int = max(1, allies.size())
	# Index within a stable, order-sorted list so slots don't jump around.
	allies.sort_custom(func(a, b): return a._order < b._order)
	var index: int = allies.find(self)
	if index < 0:
		index = 0

	var spin: float = Time.get_ticks_msec() / 1000.0 * RING_SPIN
	var angle: float = TAU * float(index) / float(total) + spin
	var radius: float = Config.ALLY_FOLLOW_DISTANCE + float(max(0, total - 6)) * 3.0
	var target: Vector2 = player.global_position + Vector2.from_angle(angle) * radius

	# Frame-rate independent smoothing toward the slot.
	var t := 1.0 - exp(-Config.ALLY_FOLLOW_STIFFNESS * delta)
	global_position = global_position.lerp(target, t)

func _draw() -> void:
	if state == AllyState.WAITING:
		# Pulsing beacon under the waiting soldier so the player can spot it.
		var p := 0.5 + 0.5 * sin(_pulse * 4.0)
		draw_circle(Vector2.ZERO, Config.ALLY_COLLECT_RADIUS, Color(Config.COL_ALLY_UNCOLLECTED, 0.06 + 0.06 * p))
		draw_arc(Vector2.ZERO, Config.ALLY_COLLECT_RADIUS, 0.0, TAU, 40, Color(Config.COL_ALLY_UNCOLLECTED, 0.30 + 0.2 * p), 2.0, true)
	else:
		# Weapon-colored glow + drop shadow while following, so you can read the
		# mix of gun types at a glance; a small pip reinforces the weapon color.
		draw_circle(Vector2.ZERO, body_radius + 8.0, Color(weapon_color, 0.22))
		draw_circle(Vector2(0, body_radius * 0.5), body_radius * 0.85, Color(0, 0, 0, 0.20))
		draw_circle(Vector2(0, -body_radius - 6.0), 3.0, weapon_color)
