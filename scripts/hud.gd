# =============================================================================
#  hud.gd  —  all on-screen UI, built in code. Adapts to the active mode
#  (Endless shows Wave; Levels shows Level + survive countdown) and shows a
#  result overlay with buttons on game over / level clear / win.
# =============================================================================
extends CanvasLayer

var _menu_button: Button
var _pause_panel: Control
var _quit_dialog: Control
var _shield_label: Label

var _score_label: Label
var _status_label: Label      # "Wave N" (endless) or "Level N" (levels)
var _objective_label: Label   # level countdown; empty in endless
var _ally_label: Label
var _coins_label: Label
var _hp_bar: Control
var _last_hp: float = Config.PLAYER_MAX_HP

const HpBar := preload("res://scripts/hud_healthbar.gd")

# Result overlay
var _overlay: Control
var _title: Label
var _subtitle: Label
var _btn_next: Button
var _btn_retry: Button
var _btn_menu: Button

# Weapon picker (pick-on-collect)
var _picker: Control

# Boss banner
var _boss_label: Label
var _boss_t: float = 0.0

const BAR_W := 320.0
const BAR_H := 16.0

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var w: float = Config.ARENA_SIZE.x

	_score_label = _make_label(Vector2(20, 14), w, HORIZONTAL_ALIGNMENT_LEFT, 26)
	_score_label.text = "Score: 0"

	_status_label = _make_label(Vector2(0, 14), w, HORIZONTAL_ALIGNMENT_CENTER, 26)
	_objective_label = _make_label(Vector2(0, 46), w, HORIZONTAL_ALIGNMENT_CENTER, 20)
	_objective_label.modulate = Color(1, 1, 1, 0.85)

	_ally_label = _make_label(Vector2(-20, 14), w, HORIZONTAL_ALIGNMENT_RIGHT, 26)
	_ally_label.text = "Allies: 0"

	_coins_label = _make_label(Vector2(20, 52), w, HORIZONTAL_ALIGNMENT_LEFT, 22)
	_coins_label.text = "Coins: 0"
	_shield_label = _make_label(Vector2(20, 78), w, HORIZONTAL_ALIGNMENT_LEFT, 19)
	_shield_label.modulate = Color("8df0ff")
	_shield_label.text = ""

	# Mode-specific initial text.
	if GameManager.mode == GameManager.Mode.LEVELS:
		_status_label.text = "Level %d" % GameManager.level
	else:
		_status_label.text = "Wave 1"

	# Health bar (bottom-center).
	var bar_x: float = (w - BAR_W) * 0.5
	var bar_y: float = Config.ARENA_SIZE.y - 44.0
	_hp_bar = HpBar.new()
	_hp_bar.position = Vector2(bar_x, bar_y)
	_hp_bar.size = Vector2(BAR_W, 20.0)
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hp_bar)

	var hint := _make_label(Vector2(0, Config.ARENA_SIZE.y - 20.0), w, HORIZONTAL_ALIGNMENT_CENTER, 15)
	hint.text = "Move: WASD / Arrows   ·   Fire: automatic   ·   Green arrows = allies   ·   Red arrows = enemies   ·   R: retry"
	hint.modulate = Color(1, 1, 1, 0.55)

	_build_overlay()
	_build_picker()
	_build_pause_menu()

	_boss_label = _make_label(Vector2(0, 92), w, HORIZONTAL_ALIGNMENT_CENTER, 40)
	_boss_label.add_theme_color_override("font_color", Config.COL_ENEMY)
	_boss_label.add_theme_constant_override("outline_size", 10)
	_boss_label.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.08))
	_boss_label.text = "⚠  BOSS WAVE  ⚠"
	_boss_label.visible = false

	EventBus.selection_started.connect(func(): _picker.visible = true)
	EventBus.selection_ended.connect(func(): _picker.visible = false)
	EventBus.score_changed.connect(func(s): _score_label.text = "Score: %d" % s)
	EventBus.coins_changed.connect(func(c): _coins_label.text = "Coins: %d" % c)
	EventBus.wave_changed.connect(_on_wave_changed)
	EventBus.objective_changed.connect(func(t): _objective_label.text = t)
	EventBus.ally_collected.connect(func(t): _ally_label.text = "Allies: %d / %d" % [t, Config.ALLY_MAX])
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.game_over.connect(_on_game_over)
	EventBus.level_completed.connect(_on_level_completed)
	EventBus.boss_wave.connect(_on_boss_wave)
	EventBus.shield_started.connect(func(_d): _update_shield_label())

func _on_boss_wave(_w: int) -> void:
	_boss_label.visible = true
	_boss_t = 2.5

func _process(delta: float) -> void:
	_update_shield_label()
	if _boss_t > 0.0:
		_boss_t -= delta
		if _boss_t <= 0.0:
			_boss_label.visible = false

func _update_shield_label() -> void:
	if GameManager.is_shield_active():
		_shield_label.text = "Shield -%ds" % ceili(GameManager.get_shield_time_remaining())
	else:
		_shield_label.text = ""

func _on_wave_changed(v: int) -> void:
	# Only meaningful in endless mode.
	if GameManager.mode == GameManager.Mode.ENDLESS:
		_status_label.text = "Wave %d" % v

func _on_player_damaged(hp: float, max_hp: float) -> void:
	var frac := clampf(hp / max_hp, 0.0, 1.0)
	_hp_bar.set_hp(frac, hp < _last_hp)   # flash when it's actual damage
	_last_hp = hp

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

	var btn_upgrades := _make_button("Upgrades")
	btn_upgrades.pressed.connect(func(): GameManager.go_to_menu("upgrades"))
	row.add_child(btn_upgrades)

	_btn_menu = _make_button("Menu")
	_btn_menu.pressed.connect(func(): GameManager.go_to_menu("main"))
	row.add_child(_btn_menu)

func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 48)
	b.add_theme_font_size_override("font_size", 20)
	return b

func _build_pause_menu() -> void:
	_menu_button = Button.new()
	_menu_button.text = "☰"
	_menu_button.tooltip_text = "Pause menu"
	_menu_button.position = Vector2(20, Config.ARENA_SIZE.y - 78.0)
	_menu_button.custom_minimum_size = Vector2(52, 52)
	_menu_button.add_theme_font_size_override("font_size", 28)
	_menu_button.pressed.connect(_open_pause_menu)
	add_child(_menu_button)

	_pause_panel = _make_modal_panel()
	var pause_box := _modal_box(_pause_panel, "PAUSED")
	var continue_button := _make_button("Continue")
	continue_button.pressed.connect(_close_pause_menu)
	pause_box.add_child(continue_button)
	var quit_button := _make_button("Quit")
	quit_button.pressed.connect(_open_quit_dialog)
	pause_box.add_child(quit_button)

	_quit_dialog = _make_modal_panel()
	var quit_box := _modal_box(_quit_dialog, "QUIT RUN?")
	var question := Label.new()
	question.text = "Your current run will be lost."
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.add_theme_font_size_override("font_size", 19)
	quit_box.add_child(question)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	quit_box.add_child(buttons)
	var cancel_button := _make_button("Cancel")
	cancel_button.pressed.connect(func(): _quit_dialog.visible = false)
	buttons.add_child(cancel_button)
	var confirm_button := _make_button("Quit")
	confirm_button.pressed.connect(_confirm_quit)
	buttons.add_child(confirm_button)

func _make_modal_panel() -> Control:
	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	add_child(panel)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.62)
	panel.add_child(dim)
	return panel

func _modal_box(panel: Control, title_text: String) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	box.add_child(title)
	return box

func _open_pause_menu() -> void:
	if not GameManager.is_playing() or _quit_dialog.visible:
		return
	get_tree().paused = true
	_pause_panel.visible = true

func _close_pause_menu() -> void:
	_pause_panel.visible = false
	get_tree().paused = false

func _open_quit_dialog() -> void:
	_quit_dialog.visible = true

func _confirm_quit() -> void:
	_quit_dialog.visible = false
	_pause_panel.visible = false
	get_tree().paused = false
	GameManager.go_to_menu("main")

# --- weapon picker -----------------------------------------------------------
func _build_picker() -> void:
	_picker = Control.new()
	_picker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_picker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picker.visible = false
	add_child(_picker)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picker.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_picker.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "CHOOSE A WEAPON"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	vbox.add_child(title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	vbox.add_child(row)

	for i in Config.ALLY_WEAPONS.size():
		var wid: String = Config.ALLY_WEAPONS[i]
		var col: Color = Config.WEAPONS[wid]["color"]
		var b := Button.new()
		b.text = "%d\n%s" % [i + 1, wid.to_upper()]
		b.custom_minimum_size = Vector2(150, 90)
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_color_override("font_color", col)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.pressed.connect(func(): GameManager.confirm_selection(wid))
		row.add_child(b)

	var hint := Label.new()
	hint.text = "Press 1–4 or click to pick · Esc to skip"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.modulate = Color(1, 1, 1, 0.7)
	vbox.add_child(hint)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		if _quit_dialog.visible:
			return
		if _pause_panel.visible:
			_close_pause_menu()
		else:
			_open_pause_menu()
		get_viewport().set_input_as_handled()
		return
	if not GameManager.is_choosing():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var handled := true
		match event.keycode:
			KEY_1: GameManager.confirm_selection(Config.ALLY_WEAPONS[0])
			KEY_2: GameManager.confirm_selection(Config.ALLY_WEAPONS[1])
			KEY_3: GameManager.confirm_selection(Config.ALLY_WEAPONS[2])
			KEY_4: GameManager.confirm_selection(Config.ALLY_WEAPONS[3])
			KEY_ESCAPE: GameManager.cancel_selection()
			_: handled = false
		if handled:
			get_viewport().set_input_as_handled()
