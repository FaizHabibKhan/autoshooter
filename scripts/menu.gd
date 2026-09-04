# =============================================================================
#  menu.gd  —  title screen on the wasteland battleground with a dedicated
#  upgrades page. Main menu and upgrades share the same background + deco, but
#  the upgrades page opens as a separate screen before/after battle.
# =============================================================================
extends Control

var _ground: Texture2D
var _road: Texture2D
var _vignette: Texture2D
var _cards: Array = []          # 5 level buttons
var _view_center: int = 1       # center level shown in the window

func _ready() -> void:
	_ground = load("res://art/ground_tile.png")
	_road = load("res://art/road_tile.png")
	_vignette = load("res://art/vignette.png")
	EventBus.upgrade_changed.connect(_on_upgrade_changed)
	EventBus.coins_changed.connect(_on_coins_changed)
	_build_page()
	queue_redraw()

func _on_upgrade_changed(_id: String, _level: int) -> void:
	if GameManager.menu_page == "upgrades":
		_build_page()

func _on_coins_changed(_coins: int) -> void:
	if GameManager.menu_page == "upgrades":
		_build_page()

func _clear_page() -> void:
	for child in get_children():
		child.queue_free()

func _build_page() -> void:
	_clear_page()
	if GameManager.menu_page == "upgrades":
		_build_upgrades_page()
		return
	_build_main_page()

func _build_main_page() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	_deco("ally_sniper", Vector2(150, 300), 1.0, -0.25)
	_deco("ally_railgun", Vector2(250, 470), 1.15, 0.15)
	_deco("player", Vector2(576, 500), 1.7, 0.0)
	_deco("ally_flame", Vector2(915, 480), 1.15, PI)
	_deco("ally_rocket", Vector2(1010, 300), 1.0, PI + 0.2)
	_deco("zombie", Vector2(1070, 120), 1.0, PI)
	_deco("zombie", Vector2(880, 150), 0.9, PI + 0.3)
	_deco("zombie", Vector2(120, 130), 0.95, 0.2)

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

	var coin_label := Label.new()
	coin_label.text = "Coins: %d" % GameManager.coins
	coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coin_label.add_theme_font_size_override("font_size", 18)
	coin_label.modulate = Color(1.0, 0.85, 0.35, 1.0)
	vbox.add_child(coin_label)

	vbox.add_child(_spacer(12))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	vbox.add_child(buttons)

	var upgrades_btn := Button.new()
	upgrades_btn.text = "UPGRADES"
	upgrades_btn.custom_minimum_size = Vector2(220, 56)
	upgrades_btn.add_theme_font_size_override("font_size", 24)
	upgrades_btn.pressed.connect(func(): GameManager.go_to_menu("upgrades"))
	buttons.add_child(upgrades_btn)

	var endless := Button.new()
	endless.text = "▶  ENDLESS MODE"
	endless.custom_minimum_size = Vector2(340, 64)
	endless.add_theme_font_size_override("font_size", 28)
	endless.pressed.connect(func(): GameManager.start_endless())
	buttons.add_child(endless)

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

func _build_upgrades_page() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var wrap := VBoxContainer.new()
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_theme_constant_override("separation", 14)
	center.add_child(wrap)

	var title := Label.new()
	title.text = "UPGRADES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Config.COL_PLAYER)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.08))
	wrap.add_child(title)

	var coin_label := Label.new()
	coin_label.text = "Coins: %d" % GameManager.coins
	coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coin_label.add_theme_font_size_override("font_size", 20)
	coin_label.modulate = Color(1.0, 0.85, 0.35, 1.0)
	wrap.add_child(coin_label)

	var list := VBoxContainer.new()
	list.alignment = BoxContainer.ALIGNMENT_CENTER
	list.add_theme_constant_override("separation", 12)
	wrap.add_child(list)

	for id in ["damage", "health", "magnet", "shield", "speed"]:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 16)
		list.add_child(row)

		var info := VBoxContainer.new()
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		info.custom_minimum_size = Vector2(180, 0)
		row.add_child(info)

		var label := Label.new()
		label.text = _upgrade_title(id)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.add_theme_font_size_override("font_size", 24)
		info.add_child(label)

		var desc := Label.new()
		desc.text = _upgrade_desc(id)
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		desc.modulate = Color(1, 1, 1, 0.75)
		desc.add_theme_font_size_override("font_size", 14)
		info.add_child(desc)

		var cells := _make_cells(id)
		row.add_child(cells)

		var buy := Button.new()
		buy.custom_minimum_size = Vector2(180, 44)
		buy.add_theme_font_size_override("font_size", 16)
		buy.pressed.connect(func(): _buy_upgrade(id))
		row.add_child(buy)

		var current_level := GameManager.get_upgrade_level(id)
		if current_level >= Config.UPGRADE_CAPS.get(id, Config.UPGRADE_LEVELS):
			buy.text = "MAXED"
			buy.disabled = true
		else:
			buy.text = "BUY %d" % GameManager.get_upgrade_cost(id)
			buy.disabled = GameManager.coins < GameManager.get_upgrade_cost(id)

		var level_label := Label.new()
		level_label.text = "%d / %d" % [current_level, Config.UPGRADE_LEVELS]
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_label.add_theme_font_size_override("font_size", 13)
		level_label.modulate = Color(1, 1, 1, 0.7)
		row.add_child(level_label)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 18)
	wrap.add_child(footer)

	var back := Button.new()
	back.text = "BACK TO MENU"
	back.custom_minimum_size = Vector2(180, 50)
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(func(): GameManager.go_to_menu("main"))
	footer.add_child(back)

func _make_cells(id: String) -> HBoxContainer:
	var level := GameManager.get_upgrade_level(id)
	var cells := HBoxContainer.new()
	cells.alignment = BoxContainer.ALIGNMENT_CENTER
	cells.add_theme_constant_override("separation", 8)
	for i in Config.UPGRADE_LEVELS:
		var cell := ColorRect.new()
		cell.custom_minimum_size = Vector2(18, 18)
		cell.color = Color(0.12, 0.14, 0.18, 1.0) if i >= level else Color(0.65, 0.85, 1.0, 1.0)
		if i < level:
			cell.color = Color(0.42, 0.88, 0.75, 1.0)
		cells.add_child(cell)
	return cells

func _buy_upgrade(id: String) -> void:
	if GameManager.buy_upgrade(id):
		_build_upgrades_page()

func _upgrade_title(id: String) -> String:
	match id:
		"damage": return "Damage"
		"health": return "Health"
		"magnet": return "Magnet"
		"shield": return "Shield"
		_: return "Speed"

func _upgrade_desc(id: String) -> String:
	match id:
		"damage": return "More shot power"
		"health": return "Higher max HP"
		"magnet": return "Collect nearby coins"
		"shield": return "Longer invincibility"
		_: return "Faster movement"

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
		b.text = str(lvl)
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
