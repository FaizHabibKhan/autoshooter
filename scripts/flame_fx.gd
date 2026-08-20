# =============================================================================
#  flame_fx.gd  —  a short-lived flame cone for the flamethrower. Draws a
#  translucent cone plus flickering embers that shoot forward, then fades.
#  Spawned each fire tick, so the rapid cadence reads as a continuous jet.
# =============================================================================
extends Node2D

var _origin: Vector2 = Vector2.ZERO
var _dir: Vector2 = Vector2.RIGHT
var _range: float = 190.0
var _cone: float = 0.7
var _color: Color = Color("ff6a2b")
var _dur: float = 0.18
var _t: float = 0.0
var _parts: Array = []

func setup(origin: Vector2, dir: Vector2, rng: float, cone: float, color: Color) -> void:
	_origin = origin
	_dir = dir
	_range = rng
	_cone = cone
	_color = color
	for i in 12:
		var a := dir.angle() + randf_range(-cone * 0.5, cone * 0.5)
		var spd := randf_range(0.6, 1.1) * rng / _dur * 0.5
		_parts.append({"pos": origin, "vel": Vector2.from_angle(a) * spd, "r": randf_range(3.0, 7.0)})

func _process(delta: float) -> void:
	_t += delta
	for p in _parts:
		p.pos += p.vel * delta
		p.vel *= 0.88
	queue_redraw()
	if _t >= _dur:
		queue_free()

func _draw() -> void:
	var f := clampf(1.0 - _t / _dur, 0.0, 1.0)
	# Translucent cone footprint.
	var a0 := _dir.angle() - _cone * 0.5
	var a1 := _dir.angle() + _cone * 0.5
	var poly := PackedVector2Array([
		_origin,
		_origin + Vector2.from_angle(a0) * _range,
		_origin + Vector2.from_angle(a1) * _range,
	])
	draw_colored_polygon(poly, Color(_color, 0.10 * f))
	# Embers (hot white core → weapon color).
	for p in _parts:
		draw_circle(p.pos, p.r * f + 1.0, Color(_color, 0.65 * f))
		draw_circle(p.pos, (p.r * f) * 0.5, Color(1, 1, 0.8, 0.5 * f))
