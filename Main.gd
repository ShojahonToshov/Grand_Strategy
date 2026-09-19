extends Node2D

@onready var camera = $Camera2D
@onready var highlight_system = $HighlightSystem
@onready var ui_panel = $CanvasLayer/Panel
@onready var info_label = $CanvasLayer/Panel/VBoxContainer/InfoLabel

var data_json = {}
var states_data = {}
var id_image: Image

var selected_prov_id = 0

var fps_label: Label
var fps_timer: float = 0.0
var frames_this_sec: int = 0
var game_hud
var resource_distribution
var game_session

func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if game_session:
			game_session.is_paused = true
			game_session.time_changed.emit()

func _ready():
	resource_distribution = load("res://ResourceDistribution.gd").new()
	add_child(resource_distribution)
	resource_distribution.generate_distribution()
	
	var resource_map = Node2D.new()
	resource_map.name = "ResourceMap"
	resource_map.set_script(load("res://ResourceMap.gd"))
	resource_map.set_process(true)
	add_child(resource_map)
	move_child(resource_map, $BaseMap.get_index() + 1)
	resource_map.setup(resource_distribution)
	
	# Load states.json and enrich with owner_group based on geography
	var json_res = load("res://states.json") as JSON
	if json_res:
		states_data = json_res.data
		data_json = json_res.data
		
	var geo_json = load("res://state_geography.json") as JSON
	var geo_data = {}
	if geo_json: geo_data = geo_json.data
	
	for sid in states_data.keys():
		var info = states_data[sid]
		var st_owner = info.get("owner", "")
		if geo_data.has(sid):
			var coords = geo_data[sid]
			var x = coords[0]
			var y = coords[1]
			if st_owner == "FRA":
				if x >= 2700 and x <= 3100 and y >= 500 and y <= 700:
					info["owner_group"] = "FRA_METRO"
				else:
					info["owner_group"] = "FRA_COLONY"
			elif st_owner == "ENG":
				if x >= 2700 and x <= 3000 and y >= 300 and y <= 550:
					info["owner_group"] = "ENG_METRO"
				else:
					info["owner_group"] = "ENG_COLONY"
			else:
				info["owner_group"] = st_owner
				
	_generate_country_lookup()
	
	var id_tex = load("res://state_id.png") as Texture2D
	if id_tex:
		id_image = id_tex.get_image()
	
	highlight_system.fill_node = $HighlightSystem/HighlightFill
	highlight_system.border_node = $HighlightSystem/HighlightBorder
	highlight_system.vector_map = $VectorMap
	
	highlight_system.fill_node.draw.connect(highlight_system._draw_fill.bind(highlight_system.fill_node))
	highlight_system.border_node.draw.connect(highlight_system._draw_border.bind(highlight_system.border_node))
	
	highlight_system.load_data()
	$VectorMap.load_data()
	
	var tex_political = load("res://map_political.png") as Texture2D
	var tex_flat = load("res://map_flat.png") as Texture2D
	
	var water_shader = load("res://Water.gdshader")
	if water_shader:
		var mat = ShaderMaterial.new()
		mat.shader = water_shader
		
		var w_mask_tex = load("res://water_mask.png")
		if not w_mask_tex:
			var w_mask_img = Image.load_from_file("res://water_mask.png")
			if w_mask_img:
				w_mask_tex = ImageTexture.create_from_image(w_mask_img)
		if w_mask_tex:
			mat.set_shader_parameter("water_mask", w_mask_tex)
			
		var w_noise_tex = load("res://water_noise.png")
		if not w_noise_tex:
			var w_noise_img = Image.load_from_file("res://water_noise.png")
			if w_noise_img:
				w_noise_tex = ImageTexture.create_from_image(w_noise_img)
		if w_noise_tex:
			mat.set_shader_parameter("noise_tex", w_noise_tex)
			
		$BaseMap.material = mat
	
	$CanvasLayer/Panel/VBoxContainer/CheckState.toggled.connect(func(t): 
		$VectorMap.show_state = t
		$VectorMap.queue_redraw())
	$CanvasLayer/Panel/VBoxContainer/CheckState.button_pressed = true
	$VectorMap.show_state = true
	
	var check_pol = CheckBox.new()
	check_pol.text = "Political / Flat"
	check_pol.button_pressed = true
	check_pol.toggled.connect(func(t): $BaseMap.texture = tex_political if t else tex_flat)
	$CanvasLayer/Panel/VBoxContainer.add_child(check_pol)
	check_pol.get_parent().move_child(check_pol, 0)
	
	var check_edge = CheckBox.new()
	check_edge.text = "Edge Scrolling"
	check_edge.button_pressed = true
	check_edge.toggled.connect(func(t): camera.edge_scroll_enabled = t)
	$CanvasLayer/Panel/VBoxContainer.add_child(check_edge)
	
	var check_water_anim = CheckBox.new()
	check_water_anim.text = "Water Animation"
	check_water_anim.button_pressed = true
	check_water_anim.toggled.connect(func(t): 
		if $BaseMap.material:
			$BaseMap.material.set_shader_parameter("water_animation_enabled", t))
	$CanvasLayer/Panel/VBoxContainer.add_child(check_water_anim)
	
	ui_panel.visible = false
	
	# Create GameHUD
	var hud_scene = load("res://GameHUD.tscn")
	if hud_scene:
		game_hud = hud_scene.instantiate()
		add_child(game_hud)
	
	var fps_container = Control.new()
	fps_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fps_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	$CanvasLayer.add_child(fps_container)
	
	var mpc = Node.new()
	mpc.name = "MapPresentationController"
	mpc.set_script(load("res://MapPresentationController.gd"))
	add_child(mpc)
	mpc.mode_changed.connect(_on_map_mode_changed)
	
	game_session = load("res://GameSession.gd").new()
	game_session.name = "GameSession"
	game_session.main_node = self
	add_child(game_session)
	
	var capitals_layer = Node2D.new()
	capitals_layer.name = "CapitalsLayer"
	capitals_layer.set_script(load("res://CapitalsLayer.gd"))
	capitals_layer.set_process(true)
	add_child(capitals_layer)
	capitals_layer.setup()
	
	var countries_layer = Node2D.new()
	countries_layer.name = "CountriesLayer"
	countries_layer.set_script(load("res://CountriesLayer.gd"))
	countries_layer.set_process(true)
	add_child(countries_layer)
	countries_layer.setup()
	
	fps_label = Label.new()
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fps_container.add_child(fps_label)
	fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	fps_label.offset_top = 60 # Below top bar
	fps_label.offset_right = -24
	fps_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	fps_label.add_theme_color_override("font_color", Color(1, 1, 0, 1))
	fps_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	fps_label.add_theme_constant_override("outline_size", 4)
	fps_label.text = "FPS: " + str(Engine.get_frames_per_second())

var country_lookup_image: Image
var country_lookup_tex: ImageTexture
var country_color_map = {}

func _generate_country_lookup():
	# Size is 16384x1 to fit all possible state IDs up to 16383
	country_lookup_image = Image.create(16384, 1, false, Image.FORMAT_RGBA8)
	country_lookup_image.fill(Color(0,0,0,0)) # default 0
	
	# Assign unique random colors to each tag
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345
	
	for sid_str in states_data.keys():
		var sid = sid_str.to_int()
		var owner = states_data[sid_str].get("owner_group", "")
		
		if owner == "":
			continue
			
		if not country_color_map.has(owner):
			country_color_map[owner] = Color(rng.randf(), rng.randf(), rng.randf(), 1.0)
			
		if sid >= 0 and sid < 16384:
			country_lookup_image.set_pixel(sid, 0, country_color_map[owner])
			
	country_lookup_tex = ImageTexture.create_from_image(country_lookup_image)
	if has_node("VectorMap"):
		$VectorMap.setup_lookup(country_lookup_tex)

func clear_state_selection():
	selected_prov_id = 0
	highlight_system.set_highlight(0, "lod0")

func get_state_owner(state_id: String) -> String:
	if data_json.has(state_id):
		return data_json[state_id].get("owner", "None")
	return "None"

func _unhandled_input(event):
	if event is InputEventKey:
		var focus_owner = get_viewport().gui_get_focus_owner()
		var in_text_input = focus_owner is LineEdit or focus_owner is TextEdit
		
		if not in_text_input and event.pressed:
			if event.keycode == KEY_SPACE:
				game_session.is_paused = not game_session.is_paused
				game_session.time_changed.emit()
			elif event.keycode >= KEY_1 and event.keycode <= KEY_5:
				game_session.speed_idx = event.keycode - KEY_1
				game_session.time_changed.emit()
				
		if event.pressed and event.keycode == KEY_F3:
			ui_panel.visible = not ui_panel.visible
		elif event.pressed and event.keycode == KEY_ESCAPE:
			if selected_prov_id != 0:
				clear_state_selection()
				if game_hud: game_hud.hide_state()
			
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			handle_click(get_global_mouse_position())

func handle_click(world_pos: Vector2):
	if not id_image:
		return
		
	var px = int(floor(world_pos.x))
	var py = int(floor(world_pos.y))
	
	if px >= 0 and px < id_image.get_width() and py >= 0 and py < id_image.get_height():
		var candidates = []
		var search_radius = 4 # Search a 9x9 pixel grid for candidates
		for dx in range(-search_radius, search_radius + 1):
			for dy in range(-search_radius, search_radius + 1):
				var cx = px + dx
				var cy = py + dy
				if cx >= 0 and cx < id_image.get_width() and cy >= 0 and cy < id_image.get_height():
					var col = id_image.get_pixel(cx, cy)
					var sid = int(round(col.r * 255.0)) + (int(round(col.g * 255.0)) << 8) + (int(round(col.b * 255.0)) << 16)
					if sid > 0 and not candidates.has(sid):
						candidates.append(sid)
						
		var final_s_id = 0
		# Try geometric hit testing among candidates
		if highlight_system.state_polygons_data.size() > 0:
			for cand in candidates:
				var c_str = str(cand)
				if highlight_system.state_polygons_data.has(c_str):
					var c_data = highlight_system.state_polygons_data[c_str]
					if c_data.has("lod0"):
						var found_in_cand = false
						for poly in c_data["lod0"]:
							var pva = PackedVector2Array()
							for pt in poly: pva.append(Vector2(pt[0], pt[1]))
							if Geometry2D.is_point_in_polygon(world_pos, pva):
								final_s_id = cand
								found_in_cand = true
								break
						if found_in_cand:
							break
							
		# Fallback to direct pixel if no geometry match
		if final_s_id == 0:
			var col = id_image.get_pixel(px, py)
			final_s_id = int(round(col.r * 255.0)) + (int(round(col.g * 255.0)) << 8) + (int(round(col.b * 255.0)) << 16)
			
		if final_s_id > 0:
			var sid_str = str(final_s_id)
			if data_json.has(sid_str):
				var info = data_json[sid_str]
				var st_owner = info.get("owner", "None")
				
				selected_prov_id = final_s_id
				var mpc = get_node_or_null("MapPresentationController")
				var mode_str = "STATES"
				if mpc and mpc.current_mode == mpc.MapMode.COUNTRIES:
					mode_str = "COUNTRIES"
					
				if mode_str == "STATES":
					highlight_system.set_highlight(selected_prov_id, $VectorMap.current_lod, "STATES")
					if game_hud: game_hud.show_state(final_s_id, st_owner)
				else:
					highlight_system.set_highlight(st_owner, $VectorMap.current_lod, "COUNTRIES")
					if game_hud:
						game_hud.show_country_sidebar(st_owner)
				
				if ui_panel.visible:
					info_label.text = "State ID: %d\nOwner: %s\nMode: %s" % [final_s_id, str(st_owner), mode_str]
			else:
				if ui_panel.visible:
					ui_panel.visible = false
				clear_state_selection()
				if game_hud: game_hud.hide_state()
		else:
			# Clicked water
			clear_state_selection()
			if game_hud: game_hud.hide_state()
			if ui_panel.visible:
				ui_panel.visible = false

func _on_map_mode_changed(new_mode):
	# Clear selection when mode changes
	clear_state_selection()
	if game_hud: game_hud.hide_state()
	if ui_panel.visible:
		ui_panel.visible = false

var _last_highlight_zoom: float = -1.0

func _process(delta):
	if camera and has_node("VectorMap"):
		var cur_zoom = camera.zoom.x
		$VectorMap.update_zoom(cur_zoom)
		if selected_prov_id > 0:
			var mpc = get_node_or_null("MapPresentationController")
			var mode_str = "STATES"
			if mpc and mpc.current_mode == mpc.MapMode.COUNTRIES:
				mode_str = "COUNTRIES"
				
			var sid_str = str(selected_prov_id)
			if mode_str == "STATES":
				highlight_system.set_highlight(selected_prov_id, $VectorMap.current_lod, "STATES")
			elif data_json.has(sid_str):
				highlight_system.set_highlight(data_json[sid_str].get("owner", "None"), $VectorMap.current_lod, "COUNTRIES")
				
			if highlight_system.border_node and abs(cur_zoom - _last_highlight_zoom) > 0.001:
				highlight_system.border_node.queue_redraw()
				_last_highlight_zoom = cur_zoom
	
	fps_timer += delta
	frames_this_sec += 1
	if fps_timer >= 0.5:
		var frame_time = (fps_timer / frames_this_sec) * 1000.0
		if fps_label:
			fps_label.text = "FPS: %d (%.1f ms)" % [Engine.get_frames_per_second(), frame_time]
		fps_timer = 0.0
		frames_this_sec = 0
