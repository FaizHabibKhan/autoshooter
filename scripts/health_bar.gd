# =============================================================================
#  health_bar.gd  —  shared segmented ("cell") health bar renderer, used by both
#  the player HUD and every enemy so they look consistent. Pure static drawing:
#  pass in any CanvasItem to draw onto.
# =============================================================================
class_name HealthBar
extends RefCounted

# More HP → more cells (tougher enemies read as bigger bars).
static func cells_for(max_hp: float) -> int:
	return clampi(int(ceil(max_hp / 20.0)), 2, 12)

# Draws a segmented bar into `ci` at `pos`/`size`. `frac` 0..1, `cells` count,
# `flash` 0..1 brightens the filled cells + border to signal a hit.
static func draw_cells(ci: CanvasItem, pos: Vector2, size: Vector2, frac: float,
		cells: int, flash: float, fill: Color) -> void:
	frac = clampf(frac, 0.0, 1.0)
	cells = maxi(1, cells)
	ci.draw_rect(Rect2(pos, size), Color(0, 0, 0, 0.6), true)   # backing
	var gap := 2.0
	var cw := (size.x - gap * float(cells + 1)) / float(cells)
	if cw < 1.0:
		cw = maxf(1.0, size.x / float(cells))
	var ch := size.y - 2.0 * gap
	var filled := frac * float(cells)
	var col := fill.lerp(Color.WHITE, flash * 0.85)
	for i in cells:
		var f := clampf(filled - float(i), 0.0, 1.0)
		if f <= 0.0:
			continue
		var cx := pos.x + gap + float(i) * (cw + gap)
		ci.draw_rect(Rect2(Vector2(cx, pos.y + gap), Vector2(cw * f, ch)), col, true)
	# Border — glows on flash.
	ci.draw_rect(Rect2(pos, size), Color(1, 1, 1, 0.22 + 0.6 * flash), false, 1.0 + 2.0 * flash)
