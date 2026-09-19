extends Control

signal mode_button_pressed(theme_id)

var btn_political: Button
var btn_resources: Button
var btn_diplomacy: Button

func _ready():
	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_STOP
	vbox.add_theme_constant_override("separation", 12)
	vbox.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	vbox.offset_right = -24
	vbox.offset_bottom = -24
	vbox.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	vbox.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(vbox)
	
	btn_political = _create_mode_button(load("res://assets/ui/icons/map.svg"), "Политическая карта")
	btn_resources = _create_mode_button(load("res://assets/ui/icons/resources.svg"), "Ресурсы")
	btn_diplomacy = _create_mode_button(load("res://assets/ui/icons/diplomacy.svg"), "Дипломатия")
	
	btn_diplomacy.disabled = true
	
	vbox.add_child(btn_political)
	vbox.add_child(btn_resources)
	vbox.add_child(btn_diplomacy)
	
	# Create Legend
	var legend_panel = PanelContainer.new()
	var l_style = StyleBoxFlat.new()
	l_style.bg_color = Color("#1c222bf0") # Slightly more opaque
	l_style.corner_radius_bottom_left = 12
	l_style.corner_radius_bottom_right = 12
	l_style.corner_radius_top_left = 12
	l_style.corner_radius_top_right = 12
	l_style.content_margin_bottom = 12
	l_style.content_margin_top = 12
	l_style.content_margin_left = 16
	l_style.content_margin_right = 16
	l_style.shadow_size = 8
	l_style.shadow_color = Color(0, 0, 0, 0.4)
	l_style.shadow_offset = Vector2(0, 4)
	legend_panel.add_theme_stylebox_override("panel", l_style)
	
	legend_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	# Position it to the left of the vertical button column
	legend_panel.offset_right = -90 
	legend_panel.offset_bottom = -24
	legend_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	legend_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(legend_panel)
	
	var lvbox = VBoxContainer.new()
	lvbox.add_theme_constant_override("separation", 6)
	legend_panel.add_child(lvbox)
	
	lvbox.add_child(_create_legend_item("res://assets/ui/resources/gold.png", "Золото", Color("#D9AC43")))
	lvbox.add_child(_create_legend_item("res://assets/ui/resources/wood.png", "Древесина", Color("#986744")))
	lvbox.add_child(_create_legend_item("res://assets/ui/resources/iron.png", "Железо", Color("#A0A5A9")))
	lvbox.add_child(_create_legend_item("", "Нет ресурсов", Color("#E8E9EA")))
	
	legend_panel.name = "LegendPanel"
	legend_panel.hide()
	
	btn_political.pressed.connect(func(): _on_button_pressed(0))
	btn_resources.pressed.connect(func(): _on_button_pressed(1))
	btn_diplomacy.pressed.connect(func(): _on_button_pressed(2))
	
	_update_active(0)

func _create_legend_item(icon_path: String, text: String, color: Color) -> Control:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	
	var tr = TextureRect.new()
	tr.custom_minimum_size = Vector2(20, 20)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if icon_path != "":
		tr.texture = load(icon_path)
	else:
		var cr = ColorRect.new()
		cr.color = color
		cr.custom_minimum_size = Vector2(14, 14)
		cr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(cr)
	
	if icon_path != "":
		h.add_child(tr)
		
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	h.add_child(lbl)
	return h

func _create_mode_button(icon_tex: Texture2D, tooltip: String) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(56, 56)
	btn.icon = icon_tex
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.expand_icon = true
	btn.tooltip_text = tooltip
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color("#1e252f")
	style_normal.border_width_bottom = 2
	style_normal.border_width_top = 2
	style_normal.border_width_left = 2
	style_normal.border_width_right = 2
	style_normal.border_color = Color(1, 1, 1, 0.15)
	style_normal.corner_radius_bottom_left = 28
	style_normal.corner_radius_bottom_right = 28
	style_normal.corner_radius_top_left = 28
	style_normal.corner_radius_top_right = 28
	style_normal.content_margin_left = 12
	style_normal.content_margin_right = 12
	style_normal.content_margin_top = 12
	style_normal.content_margin_bottom = 12
	style_normal.shadow_size = 4
	style_normal.shadow_color = Color(0, 0, 0, 0.4)
	style_normal.shadow_offset = Vector2(0, 2)
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color("#2a3545")
	style_hover.border_color = Color(1, 1, 1, 0.5)
	style_hover.shadow_size = 6
	style_hover.shadow_offset = Vector2(0, 3)
	
	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = Color("#13171e")
	style_pressed.shadow_size = 0
	style_pressed.shadow_offset = Vector2(0, 0)
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	var style_disabled = style_normal.duplicate()
	style_disabled.bg_color = Color("#171c24")
	style_disabled.border_color = Color(1, 1, 1, 0.05)
	style_disabled.shadow_size = 0
	# Modulate icon alpha for disabled state inside Button natively
	btn.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.3))
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
			style.border_color = Color("#e5c158") # Elegant gold
			style.bg_color = Color("#252e3b")
			style.shadow_color = Color("#e5c15840") # Gold glow
			style.shadow_size = 8
			style.shadow_offset = Vector2(0, 0)
		else:
			style.border_color = Color(1, 1, 1, 0.15)
			style.bg_color = Color("#1e252f")
			style.shadow_color = Color(0, 0, 0, 0.4)
			style.shadow_size = 4
			style.shadow_offset = Vector2(0, 2)
		btn.add_theme_stylebox_override("normal", style)
