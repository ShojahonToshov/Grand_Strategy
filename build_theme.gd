extends SceneTree

func _init():
	var theme = Theme.new()
	
	# Font
	var font = SystemFont.new()
	font.font_names = ["Garamond", "Georgia", "Times New Roman", "serif"]
	theme.default_font = font
	theme.default_font_size = 16
	
	# Panel background
	var panel_bg = StyleBoxFlat.new()
	panel_bg.bg_color = Color(0.1, 0.12, 0.15, 0.95)
	panel_bg.border_width_left = 1
	panel_bg.border_width_top = 1
	panel_bg.border_width_right = 1
	panel_bg.border_width_bottom = 1
	panel_bg.border_color = Color(0.3, 0.35, 0.4, 0.8)
	panel_bg.corner_radius_top_left = 4
	panel_bg.corner_radius_top_right = 4
	panel_bg.corner_radius_bottom_right = 4
	panel_bg.corner_radius_bottom_left = 4
	
	theme.set_stylebox("panel", "PanelContainer", panel_bg)
	
	# Button
	var btn_normal = panel_bg.duplicate()
	btn_normal.bg_color = Color(0.15, 0.18, 0.22, 0.95)
	theme.set_stylebox("normal", "Button", btn_normal)
	
	var btn_hover = panel_bg.duplicate()
	btn_hover.bg_color = Color(0.2, 0.25, 0.3, 0.95)
	btn_hover.border_color = Color(0.5, 0.55, 0.6, 1.0)
	theme.set_stylebox("hover", "Button", btn_hover)
	
	var btn_pressed = panel_bg.duplicate()
	btn_pressed.bg_color = Color(0.1, 0.1, 0.12, 0.95)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	
	ResourceSaver.save(theme, "res://game_theme.tres")
	print("Saved theme")
	quit(0)
