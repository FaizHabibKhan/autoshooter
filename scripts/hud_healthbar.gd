# =============================================================================
#  hud_healthbar.gd  —  the player's segmented health bar (a Control the HUD
#  places at the bottom). Flashes when the player takes damage.
# =============================================================================
extends Control

var frac: float = 1.0
var flash: float = 0.0
var cells: int = 10

func set_hp(f: float, hit: bool) -> void:
	frac = f
	if hit:
		flash = 1.0
	queue_redraw()

func _process(delta: float) -> void:
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 3.0)
		queue_redraw()

func _draw() -> void:
	# Green when healthy → red when low; flashes white on a hit.
	var col := Config.COL_ENEMY.lerp(Config.COL_ALLY, frac)
	HealthBar.draw_cells(self, Vector2.ZERO, size, frac, cells, flash, col)
