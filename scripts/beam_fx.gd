# =============================================================================
#  beam_fx.gd  —  a one-shot beam/tracer that fades out. Used by the railgun
#  (thick piercing beam) and the sniper (thin tracer). Drawn in world space.
# =============================================================================
extends Node2D

var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _color: Color = Color.WHITE
var _thick: float = 5.0
var _dur: float = 0.14
var _t: float = 0.0

func setup(from: Vector2, to: Vector2, color: Color, thick: float, dur: float) -> void:
	_from = from
	_to = to
	_color = color
	_thick = thick
	_dur = dur

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= _dur:
		queue_free()

func _draw() -> void:
	var f := clampf(1.0 - _t / _dur, 0.0, 1.0)
	draw_line(_from, _to, Color(_color, 0.22 * f), _thick * 2.6)   # outer glow
	draw_line(_from, _to, Color(_color, 0.9 * f), _thick)          # core
	draw_line(_from, _to, Color(1, 1, 1, 0.7 * f), _thick * 0.4)   # hot center
