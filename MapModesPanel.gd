extends Control

signal mode_button_pressed(theme_id)
signal zoom_set(value: float)

var btn_political: Button
var btn_resources: Button
var btn_diplomacy: Button

var zoom_slider: VSlider
var lbl_zoom: Label

func _ready():
	var main_hbox = HBoxContainer.new()
	main_hbox.mouse_filter = Control.MOUSE_FILTER_STOP
	main_hbox.add_theme_constant_override("separation", 16)
	main_hbox.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	main_hbox.offset_right = -24
	main_hbox.offset_bottom = -24
	main_hbox.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	main_hbox.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(main_hbox)
	
	var legend_panel = _create_legend_panel()
	main_hbox.add_child(legend_panel)
	
	var zoom_panel = _create_zoom_panel()
	main_hbox.add_child(zoom_panel)
	
	var modes_vbox = VBoxContainer.new()
	modes_vbox.add_theme_constant_override("separation", 12)
	modes_vbox.alignment = BoxContainer.ALIGNMENT_END
	
	btn_political = _create_mode_button(load("res://assets/ui/icons/map.svg"), "Политическая карта")
	btn_resources = _create_mode_button(load("res://assets/ui/icons/resources.svg"), "Ресурсы")
	btn_diplomacy = _create_mode_button(load("res://assets/ui/icons/diplomacy.svg"), "Дипломатия")
	
	# Settings/Editor Button
	var btn_editor = Button.new()
	btn_editor.text = "⚙"
	btn_editor.custom_minimum_size = Vector2(56, 56)
	_style_zoom_btn(btn_editor) # Use same style as zoom buttons for simplicity
	btn_editor.pressed.connect(func(): _open_camera_editor())
	
	modes_vbox.add_child(btn_editor)
	modes_vbox.add_child(btn_political)
	modes_vbox.add_child(btn_resources)
	modes_vbox.add_child(btn_diplomacy)
	main_hbox.add_child(modes_vbox)
	
	btn_political.pressed.connect(func(): _on_button_pressed(0))
	btn_resources.pressed.connect(func(): _on_button_pressed(1))
	btn_diplomacy.pressed.connect(func(): _on_button_pressed(2))
	
	_update_active(0)

func _open_camera_editor():
	var main = get_tree().root.get_node_or_null("Main")
	if not main: return
	
	var cam = main.get_node_or_null("Camera2D")
	var mpc = main.get_node_or_null("MapPresentationController")
	
	var editor = main.get_node_or_null("CameraEditorPanel")
	if not editor:
		var EditorClass = load("res://CameraEditorPanel.gd")
		if EditorClass:
			editor = EditorClass.new()
			editor.name = "CameraEditorPanel"
			main.add_child(editor)
	
	if editor and editor.has_method("setup"):
		editor.setup(cam, mpc)
		editor.popup_centered()

func _create_legend_panel() -> Control:
	var legend_panel = PanelContainer.new()
	var l_style = StyleBoxFlat.new()
	l_style.bg_color = Color("#1c222bf0")
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
	
	legend_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	
	var lvbox = VBoxContainer.new()
	lvbox.add_theme_constant_override("separation", 6)
	legend_panel.add_child(lvbox)
	
	lvbox.add_child(_create_legend_item("res://assets/ui/resources/gold.png", "Золото", Color("#D9AC43")))
	lvbox.add_child(_create_legend_item("res://assets/ui/resources/wood.png", "Древесина", Color("#986744")))
	lvbox.add_child(_create_legend_item("res://assets/ui/resources/iron.png", "Железо", Color("#A0A5A9")))
	lvbox.add_child(_create_legend_item("res://assets/ui/resources/canvas.png", "Парусина", Color("#1A1A1A")))
	lvbox.add_child(_create_legend_item("", "Нет ресурсов", Color("#E8E9EA")))
	
	legend_panel.name = "LegendPanel"
	legend_panel.hide()
	return legend_panel

func _create_zoom_panel() -> Control:
	var panel = PanelContainer.new()
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color("#1c222be0")
	p_style.corner_radius_bottom_left = 12
	p_style.corner_radius_bottom_right = 12
	p_style.corner_radius_top_left = 12
	p_style.corner_radius_top_right = 12
	p_style.content_margin_bottom = 12
	p_style.content_margin_top = 12
	p_style.content_margin_left = 8
	p_style.content_margin_right = 8
	p_style.shadow_size = 8
	p_style.shadow_color = Color(0, 0, 0, 0.3)
	p_style.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", p_style)
	
	panel.size_flags_vertical = Control.SIZE_SHRINK_END
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	
	var btn_plus = Button.new()
	btn_plus.text = "+"
	btn_plus.custom_minimum_size = Vector2(32, 32)
	_style_zoom_btn(btn_plus)
	vbox.add_child(btn_plus)
	
	zoom_slider = VSlider.new()
	zoom_slider.custom_minimum_size = Vector2(16, 100)
	zoom_slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	zoom_slider.step = 0.01
	
	var slider_grabber = StyleBoxFlat.new()
	slider_grabber.bg_color = Color("#e5c158")
	slider_grabber.corner_radius_top_left = 4
	slider_grabber.corner_radius_top_right = 4
	slider_grabber.corner_radius_bottom_left = 4
	slider_grabber.corner_radius_bottom_right = 4
	
	var slider_bg = StyleBoxFlat.new()
	slider_bg.bg_color = Color("#13171e")
	slider_bg.border_width_left = 2
	slider_bg.border_width_right = 2
	slider_bg.border_width_top = 2
	slider_bg.border_width_bottom = 2
	slider_bg.border_color = Color(1, 1, 1, 0.1)
	slider_bg.corner_radius_top_left = 4
	slider_bg.corner_radius_top_right = 4
	slider_bg.corner_radius_bottom_left = 4
	slider_bg.corner_radius_bottom_right = 4
	
	zoom_slider.add_theme_stylebox_override("slider", slider_bg)
	zoom_slider.add_theme_stylebox_override("grabber_area", StyleBoxEmpty.new())
	zoom_slider.add_theme_stylebox_override("grabber_area_highlight", StyleBoxEmpty.new())
	
	vbox.add_child(zoom_slider)
	
	var btn_minus = Button.new()
	btn_minus.text = "-"
	btn_minus.custom_minimum_size = Vector2(32, 32)
	_style_zoom_btn(btn_minus)
	vbox.add_child(btn_minus)
	
	lbl_zoom = Label.new()
	lbl_zoom.text = "100%"
	lbl_zoom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_zoom.add_theme_font_size_override("font_size", 12)
	lbl_zoom.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(lbl_zoom)
	
	zoom_slider.value_changed.connect(_on_zoom_slider_changed)
	btn_plus.pressed.connect(func(): zoom_slider.value += (zoom_slider.max_value - zoom_slider.min_value)*0.1)
	btn_minus.pressed.connect(func(): zoom_slider.value -= (zoom_slider.max_value - zoom_slider.min_value)*0.1)
	
	return panel

func _style_zoom_btn(btn: Button):
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color("#1e252f")
	style_normal.corner_radius_top_left = 6
	style_normal.corner_radius_top_right = 6
	style_normal.corner_radius_bottom_left = 6
	style_normal.corner_radius_bottom_right = 6
	style_normal.border_width_left = 1
	style_normal.border_width_right = 1
	style_normal.border_width_top = 1
	style_normal.border_width_bottom = 1
	style_normal.border_color = Color(1, 1, 1, 0.15)
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color("#2a3545")
	style_hover.border_color = Color(1, 1, 1, 0.5)
	
	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = Color("#13171e")
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func set_zoom_value(val: float, min_val: float, max_val: float):
	if zoom_slider:
		zoom_slider.set_block_signals(true)
		zoom_slider.min_value = min_val
		zoom_slider.max_value = max_val
		zoom_slider.value = val
		zoom_slider.set_block_signals(false)
		
		# Map 1.0 to 100% roughly, or just scale between min and max.
		# Since 1.0 is default, we can just do val * 100
		lbl_zoom.text = str(round(val * 100)) + "%"

func _on_zoom_slider_changed(val: float):
	lbl_zoom.text = str(round(val * 100)) + "%"
	zoom_set.emit(val)

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
	btn.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.3))
	btn.add_theme_stylebox_override("disabled", style_disabled)
	
	return btn

func _on_button_pressed(idx: int):
	_update_active(idx)
	if idx == 0:
		mode_button_pressed.emit(0) # POLITICAL
	elif idx == 1:
		mode_button_pressed.emit(1) # RESOURCES
	elif idx == 2:
		mode_button_pressed.emit(2) # DIPLOMACY

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

func set_legend_visible(is_visible: bool):
	var legend = find_child("LegendPanel")
	if legend:
		legend.visible = is_visible

