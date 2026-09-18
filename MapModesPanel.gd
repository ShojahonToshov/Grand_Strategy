extends Control

signal mode_button_pressed(theme_id)

var btn_political: Button
var btn_resources: Button
var btn_diplomacy: Button

func _ready():
	var hbox = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_STOP
	hbox.add_theme_constant_override("separation", 10)
	hbox.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hbox.offset_right = -20
	hbox.offset_bottom = -20
	hbox.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hbox.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(hbox)
	
	btn_political = _create_mode_button(load("res://assets/ui/icons/map.svg"), "Политическая карта")
	btn_resources = _create_mode_button(load("res://assets/ui/icons/resources.svg"), "Ресурсы")
	btn_diplomacy = _create_mode_button(load("res://assets/ui/icons/diplomacy.svg"), "Дипломатия — скоро")
	
	btn_diplomacy.disabled = true
	
	hbox.add_child(btn_political)
	hbox.add_child(btn_resources)
	hbox.add_child(btn_diplomacy)
	
	# Create Legend
	var legend_panel = PanelContainer.new()
	var l_style = StyleBoxFlat.new()
	l_style.bg_color = Color("#1c222ba0")
	l_style.corner_radius_bottom_left = 8
	l_style.corner_radius_bottom_right = 8
	l_style.corner_radius_top_left = 8
	l_style.corner_radius_top_right = 8
	l_style.content_margin_bottom = 8
	l_style.content_margin_top = 8
	l_style.content_margin_left = 12
	l_style.content_margin_right = 12
	legend_panel.add_theme_stylebox_override("panel", l_style)
	
	legend_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	legend_panel.offset_right = -20
	legend_panel.offset_bottom = -78 # above buttons
	legend_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	legend_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(legend_panel)
	
	var vbox = VBoxContainer.new()
	legend_panel.add_child(vbox)
	
	vbox.add_child(_create_legend_item("res://assets/ui/resources/gold.png", "Золото", Color("#D9AC43")))
	vbox.add_child(_create_legend_item("res://assets/ui/resources/wood.png", "Древесина", Color("#986744")))
	vbox.add_child(_create_legend_item("", "Нет ресурса", Color("#E8E9EA")))
	
	legend_panel.name = "LegendPanel"
	legend_panel.hide()
	
	btn_political.pressed.connect(func(): _on_button_pressed(0))
	btn_resources.pressed.connect(func(): _on_button_pressed(1))
	btn_diplomacy.pressed.connect(func(): _on_button_pressed(2))
	
	_update_active(0)

func _create_legend_item(icon_path: String, text: String, color: Color) -> Control:
	var h = HBoxContainer.new()
	
	var tr = TextureRect.new()
	tr.custom_minimum_size = Vector2(16, 16)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if icon_path != "":
		tr.texture = load(icon_path)
	else:
		# gray sample
		var cr = ColorRect.new()
		cr.color = color
		cr.custom_minimum_size = Vector2(12, 12)
		cr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(cr)
	
	if icon_path != "":
		h.add_child(tr)
		
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	h.add_child(lbl)
	return h


func _create_mode_button(icon_tex: Texture2D, tooltip: String) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(48, 48)
	btn.icon = icon_tex
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.expand_icon = true
	btn.tooltip_text = tooltip
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color("#1c222b")
	style_normal.border_width_bottom = 1
	style_normal.border_width_top = 1
	style_normal.border_width_left = 1
	style_normal.border_width_right = 1
	style_normal.border_color = Color(1, 1, 1, 0.2)
	style_normal.corner_radius_bottom_left = 24
	style_normal.corner_radius_bottom_right = 24
	style_normal.corner_radius_top_left = 24
	style_normal.corner_radius_top_right = 24
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color("#2a3340")
	style_hover.border_color = Color(1, 1, 1, 0.4)
	
	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = Color("#11151a")
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	var style_disabled = style_normal.duplicate()
	style_disabled.bg_color = Color("#1c222b")
	style_disabled.border_color = Color(1, 1, 1, 0.05)
	btn.add_theme_stylebox_override("disabled", style_disabled)
	
	return btn

func _on_button_pressed(idx: int):
	_update_active(idx)
	if idx == 0:
		mode_button_pressed.emit(0) # POLITICAL
	elif idx == 1:
		mode_button_pressed.emit(1) # RESOURCES

func _update_active(idx: int):
	var btns = [btn_political, btn_resources, btn_diplomacy]
	for i in range(btns.size()):
		var btn = btns[i]
		var style = btn.get_theme_stylebox("normal").duplicate()
		if i == idx:
			style.border_color = Color("#D9AC43")
			style.border_width_bottom = 2
			style.border_width_top = 2
			style.border_width_left = 2
			style.border_width_right = 2
			style.bg_color = Color("#2a3340")
		else:
			style.border_color = Color(1, 1, 1, 0.2)
			style.border_width_bottom = 1
			style.border_width_top = 1
			style.border_width_left = 1
			style.border_width_right = 1
			style.bg_color = Color("#1c222b")
		btn.add_theme_stylebox_override("normal", style)
