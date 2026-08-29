# =============================================================================
#  menu.gd  —  title screen on the wasteland battleground: tiled ground, a road,
#  decorative animated soldiers/zombies, a bold outlined title, and the mode
#  buttons (Endless + 10 levels). Built in code.
# =============================================================================
extends Control

var _ground: Texture2D
var _road: Texture2D
var _vignette: Texture2D
var _cards: Array = []          # 5 level buttons
var _view_center: int = 1       # center level shown in the window

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_ground = load("res://art/ground_tile.png")
	_road = load("res://art/road_tile.png")
	_vignette = load("res://art/vignette.png")

	# Decorative characters (animate on their own; drawn above the background).
	_deco("ally_sniper", Vector2(150, 300), 1.0, -0.25)
	_deco("ally_railgun", Vector2(250, 470), 1.15, 0.15)
	_deco("player", Vector2(576, 500), 1.7, 0.0)
	_deco("ally_flame", Vector2(915, 480), 1.15, PI)
	_deco("ally_rocket", Vector2(1010, 300), 1.0, PI + 0.2)
	_deco("zombie", Vector2(1070, 120), 1.0, PI)
	_deco("zombie", Vector2(880, 150), 0.9, PI + 0.3)
	_deco("zombie", Vector2(120, 130), 0.95, 0.2)

	# --- UI (title + buttons), centered ---
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "AUTO SHOOTER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Config.COL_PLAYER)
	title.add_theme_constant_override("outline_size", 14)
	title.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.08))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "THE AUTO-BATTLEGROUNDS"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	subtitle.add_theme_constant_override("outline_size", 8)
	subtitle.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.08))
	vbox.add_child(subtitle)

	vbox.add_child(_spacer(14))

	var endless := Button.new()
	endless.text = "▶  ENDLESS MODE"
	endless.custom_minimum_size = Vector2(340, 64)
	endless.add_theme_font_size_override("font_size", 28)
	endless.pressed.connect(func(): GameManager.start_endless())
	vbox.add_child(endless)

	if GameManager.endless_best > 0:
		var best := Label.new()
		best.text = "Best: Wave %d" % GameManager.endless_best
		best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		best.add_theme_font_size_override("font_size", 15)
		best.modulate = Color(1, 1, 1, 0.65)
		vbox.add_child(best)

	var levels_label := Label.new()
	levels_label.text = "CAMPAIGN"
	levels_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	levels_label.add_theme_font_size_override("font_size", 22)
	levels_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	levels_label.add_theme_constant_override("outline_size", 6)
	levels_label.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.08))
	vbox.add_child(levels_label)

	# Windowed level picker: 2 previous · current · 2 upcoming.
	_view_center = GameManager.campaign_level
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	vbox.add_child(row)

	var left := Button.new()
	left.text = "◀"
	left.custom_minimum_size = Vector2(44, 64)
	left.add_theme_font_size_override("font_size", 22)
	left.pressed.connect(func(): _shift(-1))
	row.add_child(left)

	_cards.clear()
	for i in 5:
		var b := Button.new()
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(_on_card_pressed.bind(i))
		row.add_child(b)
		_cards.append(b)

	var right := Button.new()
	right.text = "▶"
	right.custom_minimum_size = Vector2(44, 64)
	right.add_theme_font_size_override("font_size", 22)
	right.pressed.connect(func(): _shift(1))
	row.add_child(right)

	_refresh_levels()
	queue_redraw()

func _shift(dir: int) -> void:
	_view_center = clampi(_view_center + dir, 1, GameManager.campaign_level)
	_refresh_levels()

func _on_card_pressed(i: int) -> void:
	var lvl := _view_center - 2 + i
	if lvl >= 1 and lvl <= GameManager.campaign_level:
		GameManager.start_level(lvl)

func _refresh_levels() -> void:
	for i in _cards.size():
		var b: Button = _cards[i]
		var lvl := _view_center - 2 + i
		var is_center := (i == 2)
		b.custom_minimum_size = Vector2(78, 78) if is_center else Vector2(58, 58)
		if lvl < 1:
			b.visible = false
			continue
		b.visible = true
		var unlocked := lvl <= GameManager.campaign_level
		b.disabled = not unlocked
		b.text = str(lvl)   # upcoming levels show dimmed + disabled
		b.modulate = Color(1, 1, 1, 1) if is_center else Color(1, 1, 1, 0.75 if unlocked else 0.4)

func _deco(kind: String, pos: Vector2, sc: float, rot: float) -> void:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = SpriteLib.get_frames(kind)
	if a.sprite_frames != null:
		a.play("walk")
	a.position = pos
	a.scale = Vector2.ONE * sc
	a.rotation = rot
	add_child(a)

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _draw() -> void:
	var vp := get_viewport_rect().size
	if _ground != null:
		draw_texture_rect(_ground, Rect2(Vector2.ZERO, vp), true)
	else:
		draw_rect(Rect2(Vector2.ZERO, vp), Config.COL_BG, true)
	if _road != null:
		draw_texture_rect(_road, Rect2(0.0, vp.y * 0.60, vp.x, 150.0), true)
	if _vignette != null:
		draw_texture_rect(_vignette, Rect2(Vector2.ZERO, vp), false)
