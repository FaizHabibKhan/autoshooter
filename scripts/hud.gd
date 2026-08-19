# =============================================================================
#  hud.gd  —  all on-screen UI, built in code (no fragile .tscn wiring).
#  Reads purely from EventBus so it stays decoupled from gameplay nodes.
# =============================================================================
extends CanvasLayer

var _score_label: Label
var _wave_label: Label
var _ally_label: Label
var _hp_fill: ColorRect
var _gameover: Control

const BAR_W := 320.0
const BAR_H := 16.0

func _ready() -> void:
	layer = 10
	var w := Config.ARENA_SIZE.x

	_score_label = _make_label(Vector2(20, 14), w, HORIZONTAL_ALIGNMENT_LEFT, 26)
	_score_label.text = "Score: 0"

	_wave_label = _make_label(Vector2(0, 14), w, HORIZONTAL_ALIGNMENT_CENTER, 26)
	_wave_label.text = "Wave 1"

	_ally_label = _make_label(Vector2(-20, 14), w, HORIZONTAL_ALIGNMENT_RIGHT, 26)
	_ally_label.text = "Allies: 0"

	# Health bar (bottom-center)
	var bar_x := (w - BAR_W) * 0.5
	var bar_y := Config.ARENA_SIZE.y - 40.0
	_hp_fill = _make_rect(Vector2(bar_x, bar_y), Vector2(BAR_W, BAR_H), Config.COL_ALLY)
	var hp_bg := _make_rect(Vector2(bar_x, bar_y), Vector2(BAR_W, BAR_H), Color(0, 0, 0, 0.45))
	# Draw bg behind fill: add bg first, then move fill in front.
	move_child(hp_bg, 0)

	var hint := _make_label(Vector2(0, Config.ARENA_SIZE.y - 20.0), w, HORIZONTAL_ALIGNMENT_CENTER, 15)
	hint.text = "Move: WASD / Arrows   ·   Fire: automatic   ·   Collect glowing allies   ·   R: restart"
	hint.modulate = Color(1, 1, 1, 0.55)

	_build_gameover()

	# Wire up to the event bus.
	EventBus.score_changed.connect(func(s): _score_label.text = "Score: %d" % s)
	EventBus.wave_changed.connect(func(v): _wave_label.text = "Wave %d" % v)
	EventBus.ally_collected.connect(func(t): _ally_label.text = "Allies: %d" % t)
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.game_over.connect(_on_game_over)

func _on_player_damaged(hp: float, max_hp: float) -> void:
	var frac := clampf(hp / max_hp, 0.0, 1.0)
	_hp_fill.size = Vector2(BAR_W * frac, BAR_H)
	_hp_fill.color = Config.COL_ENEMY.lerp(Config.COL_ALLY, frac)

func _on_game_over(final_score: int, waves: int) -> void:
	var label := _gameover.get_node("Label") as Label
	label.text = "GAME OVER\n\nScore: %d\nWaves survived: %d\n\nPress R to play again" % [final_score, waves]
	_gameover.visible = true

# --- builders ----------------------------------------------------------------
func _make_label(pos: Vector2, width: float, align: int, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(width - 40.0, 40.0)
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font_size)
	add_child(l)
	return l

func _make_rect(pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = size
	r.color = color
	add_child(r)
	return r

func _build_gameover() -> void:
	_gameover = Control.new()
	_gameover.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gameover.visible = false
	add_child(_gameover)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	_gameover.add_child(dim)

	var label := Label.new()
	label.name = "Label"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 40)
	label.text = "GAME OVER"
	_gameover.add_child(label)
