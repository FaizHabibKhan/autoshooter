# =============================================================================
#  menu.gd  —  start screen. Pick Endless or one of the 10 levels. Built in
#  code (no fragile .tscn wiring) and adapts to Config.level_count().
# =============================================================================
extends Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Config.COL_BG
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "AUTO SHOOTER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Config.COL_PLAYER)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Collect allies · Survive the swarm"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.modulate = Color(1, 1, 1, 0.7)
	vbox.add_child(subtitle)

	vbox.add_child(_spacer(10))

	var endless := Button.new()
	endless.text = "▶  ENDLESS MODE"
	endless.custom_minimum_size = Vector2(320, 60)
	endless.add_theme_font_size_override("font_size", 26)
	endless.pressed.connect(func(): GameManager.start_endless())
	vbox.add_child(endless)

	var levels_label := Label.new()
	levels_label.text = "LEVELS"
	levels_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	levels_label.add_theme_font_size_override("font_size", 22)
	levels_label.modulate = Color(1, 1, 1, 0.85)
	vbox.add_child(levels_label)

	# Grid of level buttons (5 per row), driven by Config.level_count().
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(grid)

	for n in range(1, Config.level_count() + 1):
		var b := Button.new()
		b.text = str(n)
		b.custom_minimum_size = Vector2(60, 52)
		b.add_theme_font_size_override("font_size", 22)
		var lvl := n   # capture by value
		b.pressed.connect(func(): GameManager.start_level(lvl))
		grid.add_child(b)

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
