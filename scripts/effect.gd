# =============================================================================
#  effect.gd  —  a one-shot particle burst drawn in code. Expands, fades, frees
#  itself. Used for enemy deaths (burst), bullet impacts and pickups (spark).
# =============================================================================
extends Node2D

var _t: float = 0.0
var _dur: float = 0.45
var _color: Color = Color.WHITE
var _kind: String = "burst"
var _particles: Array = []

func burst(color: Color) -> void:
	_kind = "burst"
	_color = color
	_dur = 0.45
	for i in 10:
		var ang := randf() * TAU
		var spd := randf_range(80.0, 220.0)
		_particles.append({"pos": Vector2.ZERO, "vel": Vector2.from_angle(ang) * spd})

func spark(color: Color) -> void:
	_kind = "spark"
	_color = color
	_dur = 0.22
	for i in 5:
		var ang := randf() * TAU
		var spd := randf_range(40.0, 130.0)
		_particles.append({"pos": Vector2.ZERO, "vel": Vector2.from_angle(ang) * spd})

func _process(delta: float) -> void:
	_t += delta
	for p in _particles:
		p.pos += p.vel * delta
		p.vel *= 0.90
	queue_redraw()
	if _t >= _dur:
		queue_free()

func _draw() -> void:
	var f := clampf(1.0 - _t / _dur, 0.0, 1.0)
	if _kind == "burst":
		var rad := lerpf(4.0, 46.0, _t / _dur)
		draw_arc(Vector2.ZERO, rad, 0.0, TAU, 32, Color(_color, 0.5 * f), 3.0, true)
	for p in _particles:
		draw_circle(p.pos, 3.0 * f + 1.0, Color(_color, f))
