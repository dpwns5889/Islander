extends Control
## 메인 메뉴: 시작 / 최고 웨이브 / 종료 (기획서 9.1)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	var title: Label = Label.new()
	title.text = "BiomeDefender"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var best: Label = Label.new()
	best.text = "최고 웨이브: %s" % (str(SaveManager.best_wave) if SaveManager.best_wave > 0 else "-")
	best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(best)
	var start: Button = Button.new()
	start.text = "시작"
	start.custom_minimum_size = Vector2(220, 44)
	start.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://assets/scenes/main.tscn"))
	box.add_child(start)
	var quit_b: Button = Button.new()
	quit_b.text = "종료"
	quit_b.custom_minimum_size = Vector2(220, 44)
	quit_b.pressed.connect(get_tree().quit)
	box.add_child(quit_b)
	add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
