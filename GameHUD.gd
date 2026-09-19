extends CanvasLayer

var ui_data = {}
var country_colors = {}

func _ready():
	var theme = load("res://game_theme.tres")
	if theme:
		$TopBar.theme = theme
		$StateInfoPanel.theme = theme
		
	var f = FileAccess.open("res://ui_data.json", FileAccess.READ)
	if f:
		var json = JSON.new()
		if json.parse(f.get_as_text()) == OK:
			ui_data = json.data
			
	var c = FileAccess.open("res://colors.json", FileAccess.READ)
	if c:
		var json = JSON.new()
		if json.parse(c.get_as_text()) == OK:
			country_colors = json.data
			
	$StateInfoPanel.hide()
	$StateInfoPanel.close_requested.connect(_on_panel_close)
	$MapModesPanel.mode_button_pressed.connect(_on_theme_button_pressed)

func show_state(state_id: int, owner_tag: String):
	var s_id_str = str(state_id)
	var state_name = "Регион " + s_id_str
	if ui_data.has("states") and ui_data["states"].has(s_id_str):
		state_name = ui_data["states"][s_id_str]
		
	var owner_name = owner_tag
	if ui_data.has("countries") and ui_data["countries"].has(owner_tag):
		owner_name = ui_data["countries"][owner_tag]
		
	var color = Color(0.4, 0.4, 0.4)
	if country_colors.has(owner_tag):
		var rgb = country_colors[owner_tag]
		color = Color(rgb[0]/255.0, rgb[1]/255.0, rgb[2]/255.0)
		
	var resource_name = ""
	var main = get_parent()
	if main.has_node("ResourceDistribution"):
		var dist = main.get_node("ResourceDistribution")
		var rt = dist.get_resource_for_state(s_id_str)
		resource_name = dist.get_resource_name(rt)
		
	$StateInfoPanel.update_data(state_name, owner_name, color, resource_name, s_id_str)
	$StateInfoPanel.show_panel()

func _on_theme_button_pressed(idx: int):
	var main = get_parent()
	var mpc = main.get_node_or_null("MapPresentationController")
	if mpc:
		if idx == 0:
			mpc.set_theme(mpc.MapTheme.POLITICAL)
			if $MapModesPanel.has_node("LegendPanel"): $MapModesPanel/LegendPanel.hide()
		elif idx == 1:
			mpc.set_theme(mpc.MapTheme.RESOURCES)
			if $MapModesPanel.has_node("LegendPanel"): $MapModesPanel/LegendPanel.show()

func hide_state():
	$StateInfoPanel.hide_panel()

func show_country_sidebar(owner_tag: String):
	var country_name = owner_tag
	if ui_data.has("countries") and ui_data["countries"].has(owner_tag):
		country_name = ui_data["countries"][owner_tag]
		
	var color = Color(0.4, 0.4, 0.4)
	if country_colors.has(owner_tag):
		var rgb = country_colors[owner_tag]
		color = Color(rgb[0]/255.0, rgb[1]/255.0, rgb[2]/255.0)
		
	$StateInfoPanel.update_country_data(owner_tag, country_name, color)
	$StateInfoPanel.show_panel()

func show_country_modal(tag: String):
	var country_name = tag
	if ui_data.has("countries") and ui_data["countries"].has(tag):
		country_name = ui_data["countries"][tag]
	$TopBar._show_country_modal(tag, country_name)

func _on_panel_close():
	# Notify main to clear selection
	var main = get_parent()
	if main.has_method("clear_state_selection"):
		main.clear_state_selection()
