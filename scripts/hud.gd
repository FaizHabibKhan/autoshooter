# =============================================================================
#  hud.gd  —  all on-screen UI, built in code. Adapts to the active mode
#  (Endless shows Wave; Levels shows Level + survive countdown) and shows a
#  result overlay with buttons on game over / level clear / win.
# =============================================================================
extends CanvasLayer

var _score_label: Label
var _status_label: Label      # "Wave N" (endless) or "Level N" (levels)
var _objective_label: Label   # level countdown; empty in endless
var _ally_label: Label
var _hp_fill: ColorRect

# Result overlay
var _overlay: Control
var _title: Label
var _subtitle: Label
var _btn_next: Button
var _btn_retry: Button
var _btn_menu: Button

const BAR_W := 320.0
const BAR_H := 16.0

func _ready() -> void:
	layer = 10
	var w := Config.ARENA_SIZE.x

	_score_label = _make_label(Vector2(20, 14), w, HORIZONTAL_ALIGNMENT_LEFT, 26)
	_score_label.text = "Score: 0"

	_status_label = _make_label(Vector2(0, 14), w, HORIZONTAL_ALIGNMENT_CENTER, 26)
	_objective_label = _make_label(Vector2(0, 46), w, HORIZONTAL_ALIGNMENT_CENTER, 20)
	_objective_label.modulate = Color(1, 1, 1, 0.85)

	_ally_label = _make_label(Vector2(-20, 14), w, HORIZONTAL_ALIGNMENT_RIGHT, 26)
	_ally_label.text = "Allies: 0"

	# Mode-specific initial text.
	if GameManager.mode == GameManager.Mode.LEVELS:
		_status_label.text = "Level %d / %d" % [GameManager.level, Config.level_count()]
	else:
		_status_label.text = "Wave 1"

	# Health bar (bottom-center).
	var bar_x := (w - BAR_W) * 0.5
	var bar_y := Config.ARENA_SIZE.y - 40.0
	_hp_fill = _make_rect(Vector2(bar_x, bar_y), Vector2(BAR_W, BAR_H), Config.COL_ALLY)
	var hp_bg := _make_rect(Vector2(bar_x, bar_y), Vector2(BAR_W, BAR_H), Color(0, 0, 0, 0.45))
	move_child(hp_bg, 0)

	var hint := _make_label(Vector2(0, Config.ARENA_SIZE.y - 20.0), w, HORIZONTAL_ALIGNMENT_CENTER, 15)
	hint.text = "Move: WASD / Arrows   ·   Fire: automatic   ·   Green arrows = allies   ·   Red arrows = enemies   ·   R: retry"
	hint.modulate = Color(1, 1, 1, 0.55)

	_build_overlay()

	EventBus.score_changed.connect(func(s): _score_label.text = "Score: %d" % s)
	EventBus.wave_changed.connect(_on_wave_changed)
	EventBus.objective_changed.connect(func(t): _objective_label.text = t)
	EventBus.ally_collected.connect(func(t): _ally_label.text = "Allies: %d / %d" % [t, Config.ALLY_MAX])
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.game_over.connect(_on_game_over)
	EventBus.level_completed.connect(_on_level_completed)
	EventBus.game_won.connect(_on_game_won)

func _on_wave_changed(v: int) -> void:
	# Only meaningful in endless mode.
	if GameManager.mode == GameManager.Mode.ENDLESS:
		_status_label.text = "Wave %d" % v

func _on_player_damaged(hp: float, max_hp: float) -> void:
	var frac := clampf(hp / max_hp, 0.0, 1.0)
	_hp_fill.size = Vector2(BAR_W * frac, BAR_H)
	_hp_fill.color = Config.COL_ENEMY.lerp(Config.COL_ALLY, frac)

# --- outcomes ----------------------------------------------------------------
func _on_game_over(final_score: int, waves: int) -> void:
	_title.text = "GAME OVER"
	if GameManager.mode == GameManager.Mode.LEVELS:
		_subtitle.text = "Level %d — Score %d" % [GameManager.level, final_score]
	else:
		_subtitle.text = "Score %d  ·  Waves survived %d" % [final_score, waves]
	_show_overlay(false, true, true)

func _on_level_completed(level: int, final_score: int) -> void:
	_title.text = "LEVEL %d COMPLETE" % level
	_subtitle.text = "Score %d  ·  Next: Level %d" % [final_score, level + 1]
	_show_overlay(true, true, true)

func _on_game_won(final_score: int) -> void:
	_title.text = "YOU WIN!"
	_subtitle.text = "All %d levels cleared  ·  Score %d" % [Config.level_count(), final_score]
	_show_overlay(false, true, true)

func _show_overlay(next: bool, retry: bool, menu: bool) -> void:
	_btn_next.visible = next
	_btn_retry.visible = retry
	_btn_menu.visible = menu
	_overlay.visible = true

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

func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.66)
	_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 46)
	vbox.add_child(_title)

	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 22)
	_subtitle.modulate = Color(1, 1, 1, 0.85)
	vbox.add_child(_subtitle)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	vbox.add_child(row)

	_btn_next = _make_button("Next ▶")
	_btn_next.pressed.connect(func(): GameManager.next_level())
	row.add_child(_btn_next)

	_btn_retry = _make_button("Retry (R)")
	_btn_retry.pressed.connect(func(): GameManager.retry())
	row.add_child(_btn_retry)

	_btn_menu = _make_button("Menu")
	_btn_menu.pressed.connect(func(): GameManager.go_to_menu())
	row.add_child(_btn_menu)

func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 48)
	b.add_theme_font_size_override("font_size", 20)
	return b
