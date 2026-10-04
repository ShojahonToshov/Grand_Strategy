extends Node2D

@onready var camera = $Camera2D
@onready var highlight_system = $HighlightSystem
@onready var ui_panel = $CanvasLayer/Panel
@onready var info_label = $CanvasLayer/Panel/VBoxContainer/InfoLabel

var data_json = {}
var states_data = {}
var id_image: Image
var state_neighbors = {}

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
	# True AAA Map Rendering: We use the raster map (to keep lakes and perfect geometry)
	# but apply a Subpixel Anti-Aliasing (Smooth Pixel) shader. 
	# This mathematically eliminates pixelation without making the map blurry.
	if has_node("BaseMap"):
		var base_map = $BaseMap as Sprite2D
		base_map.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		base_map.modulate = Color(1.0, 1.0, 1.0, 1.0) # Restore original colors
		
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
	
	var diplomacy_map = Node2D.new()
	diplomacy_map.name = "DiplomacyMap"
	diplomacy_map.set_script(load("res://DiplomacyMap.gd"))
	diplomacy_map.set_process(true)
	add_child(diplomacy_map)
	move_child(diplomacy_map, resource_map.get_index() + 1)
	diplomacy_map.setup()
	
	# Load states.json and enrich with owner_group based on geography
	var json_res = load("res://states.json") as JSON
	if json_res:
		states_data = json_res.data
		data_json = json_res.data
		
	var n_file = FileAccess.open("res://state_neighbors.json", FileAccess.READ)
	if n_file:
		var n_text = n_file.get_as_text()
		var n_json_inst = JSON.new()
		if n_json_inst.parse(n_text) == OK:
			state_neighbors = n_json_inst.data
		
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
	
	var pol_layer = Node2D.new()
	pol_layer.name = "PoliticalMapLayer"
	pol_layer.set_script(load("res://PoliticalMapLayer.gd"))
	add_child(pol_layer)
	move_child(pol_layer, $BaseMap.get_index() + 1)
	pol_layer.setup(states_data)
	
	if has_node("BaseMap"):
		$BaseMap.texture = load("res://map_flat.png") as Texture2D
	
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
			
		# Apply shader to BOTH BaseMap (for water/flat) and PolLayer (for parchment land)
		$BaseMap.material = mat
		pol_layer.material = mat
	
	$CanvasLayer/Panel/VBoxContainer/CheckState.toggled.connect(func(t): 
		$VectorMap.show_state = t
		$VectorMap.queue_redraw())
	$CanvasLayer/Panel/VBoxContainer/CheckState.button_pressed = true
	$VectorMap.show_state = true
	
	var check_pol = CheckBox.new()
	check_pol.text = "Political / Flat"
	check_pol.button_pressed = true
	check_pol.toggled.connect(func(t): 
		pol_layer.show_political = t
		pol_layer.queue_redraw()
	)
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
	
	var paths_layer = Node2D.new()
	paths_layer.name = "ArmyPathsLayer"
	paths_layer.z_index = 40
	paths_layer.set_script(load("res://ArmyPathsLayer.gd"))
	add_child(paths_layer)
	paths_layer.set("main_node", self)
	
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
	
	_generate_initial_ai_armies()

func _generate_initial_ai_armies():
	var ger_states = []
	for sid in states_data.keys():
		var owner = states_data[sid].get("owner", "")
		if owner == "GER":
			var pop = states_data[sid].get("population", 0)
			if pop >= 1000:
				ger_states.append(sid)
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	ger_states.shuffle()
	
	var armies_to_spawn = min(5, ger_states.size())
	for i in range(armies_to_spawn):
		var state_id = ger_states[i]
		var pop = states_data[state_id].get("population", 0)
		var mobilized_pop = int(pop * 0.05)
		states_data[state_id]["population"] = max(0, pop - mobilized_pop)
		spawn_army(state_id, mobilized_pop, "GER")

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

func get_state_at_pos(world_pos: Vector2) -> int:
	if not id_image:
		return 0
		
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
			
		return final_s_id
	return 0

func handle_click(world_pos: Vector2):
	var final_s_id = get_state_at_pos(world_pos)
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
				
			if highlight_system.border_node:
				var settled = abs(cur_zoom - camera.target_zoom.x) < 0.005
				var pct_change = 0.0
				if _last_highlight_zoom > 0.0:
					pct_change = abs(_last_highlight_zoom - cur_zoom) / _last_highlight_zoom
					
				if settled or pct_change > 0.15:
					_last_highlight_zoom = camera.target_zoom.x if settled else cur_zoom
					highlight_system.border_node.queue_redraw()
	
	fps_timer += delta
	frames_this_sec += 1
	if fps_timer >= 0.5:
		var frame_time = (fps_timer / frames_this_sec) * 1000.0
		if fps_label:
			fps_label.text = "FPS: %d (%.1f ms)" % [Engine.get_frames_per_second(), frame_time]
		fps_timer = 0.0
		frames_this_sec = 0
		
	var mpc = get_node_or_null("MapPresentationController")
	if mpc:
		var flags_alpha = mpc.army_flags_alpha
		var flags_visible = flags_alpha > 0.01
		for army in active_armies:
			army.visible = flags_visible
			if flags_visible:
				army.modulate.a = flags_alpha
				
	# Cursor logic
	var cursor_is_attack = false
	if selected_army != null and selected_army.owner_tag == "FRA":
		for army in active_armies:
			if army.owner_tag != "FRA" and army.is_visible_in_tree():
				var local_mouse = army.get_local_mouse_position()
				var bar_w = 46.0
				var pole_top = -64.0
				var click_rect = Rect2(-bar_w/2.0 - 4, pole_top - 8, bar_w + 8, -pole_top + 12)
				if click_rect.has_point(local_mouse):
					cursor_is_attack = true
					break
					
	if cursor_is_attack:
		if attack_cursor_tex == null:
			_create_attack_cursor()
		Input.set_custom_mouse_cursor(attack_cursor_tex, Input.CURSOR_ARROW, Vector2(16, 16))
	else:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)

var attack_cursor_tex: ImageTexture

func _create_attack_cursor():
	var svg = """<svg width="32" height="32" xmlns="http://www.w3.org/2000/svg">
  <g transform="translate(16,16) rotate(45) translate(-16,-16)">
    <!-- Sword 1 -->
	<rect x="14" y="2" width="4" height="22" fill="#d32f2f" stroke="black" stroke-width="1" />
	<rect x="10" y="24" width="12" height="2" fill="black" />
	<rect x="14" y="26" width="4" height="4" fill="#555" stroke="black" stroke-width="1" />
  </g>
  <g transform="translate(16,16) rotate(-45) translate(-16,-16)">
    <!-- Sword 2 -->
	<rect x="14" y="2" width="4" height="22" fill="#d32f2f" stroke="black" stroke-width="1" />
	<rect x="10" y="24" width="12" height="2" fill="black" />
	<rect x="14" y="26" width="4" height="4" fill="#555" stroke="black" stroke-width="1" />
  </g>
</svg>"""
	var img = Image.new()
	img.load_svg_from_string(svg)
	attack_cursor_tex = ImageTexture.create_from_image(img)

var active_armies = []
var selected_army = null

func spawn_army(state_id: String, population: int, owner_tag: String):
	var army = load("res://ArmyBanner.gd").new()
	army.set_script(load("res://ArmyBanner.gd"))
	army.set_data(state_id, population, owner_tag)
	
	# Find position for the army. We can average the polygon points for the state
	var pos = Vector2(0, 0)
	if highlight_system.state_polygons_data.has(state_id):
		var c_data = highlight_system.state_polygons_data[state_id]
		if c_data.has("lod0") and c_data["lod0"].size() > 0:
			var poly = c_data["lod0"][0] # Just use the first polygon
			var pt_count = poly.size()
			for pt in poly:
				pos += Vector2(pt[0], pt[1])
			pos /= pt_count
			
	army.position = pos
	army.clicked.connect(_on_army_clicked)
	add_child(army)
	active_armies.append(army)

func _on_army_clicked(army):
	if selected_army:
		selected_army.set_selected(false)
	selected_army = army
	selected_army.set_selected(true)
	
var active_battles = []

func get_battle_for_army(army) -> Node:
	for b in active_battles:
		if is_instance_valid(b) and b.has_method("has_army") and b.has_army(army) and not b.is_ending:
			return b
	return null

func join_or_start_combat(attacker, defender):
	# Clean up invalid battles first
	for i in range(active_battles.size() - 1, -1, -1):
		if not is_instance_valid(active_battles[i]) or active_battles[i].is_ending:
			active_battles.remove_at(i)

	var b_def = get_battle_for_army(defender)
	if b_def:
		b_def.add_army(attacker)
		return
		
	var b_att = get_battle_for_army(attacker)
	if b_att:
		b_att.add_army(defender)
		return
		
	var battle = load("res://Battle.gd").new()
	battle.setup(attacker, defender)
	add_child(battle)
	active_battles.append(battle)
	
func get_state_center(state_id: String) -> Vector2:
	var pos = Vector2(0, 0)
	if highlight_system.state_polygons_data.has(state_id):
		var c_data = highlight_system.state_polygons_data[state_id]
		if c_data.has("lod0") and c_data["lod0"].size() > 0:
			var poly = c_data["lod0"][0]
			for pt in poly: pos += Vector2(pt[0], pt[1])
			pos /= poly.size()
	return pos

func force_diplomacy_redraw():
	var dmap = get_node_or_null("DiplomacyMap")
	if dmap:
		dmap.queue_redraw()

func find_path_to_home(start_sid: String, owner_tag: String, allowed_passage_tag: String) -> Array:
	var owner = get_state_owner(start_sid)
	if owner == owner_tag: return [] # Already home
	
	if not state_neighbors.has(start_sid): return []
	
	var q = [start_sid]
	var visited = {start_sid: true}
	var parent = {}
	
	var head = 0
	var found_target = ""
	
	while head < q.size():
		var curr = q[head]
		head += 1
		
		if get_state_owner(curr) == owner_tag:
			found_target = curr
			break
			
		if state_neighbors.has(curr):
			for n in state_neighbors[curr]:
				var n_str = str(n)
				if not visited.has(n_str):
					var n_owner = get_state_owner(n_str)
					# Realism: Army can only march through the country they just made peace with (allowed_passage_tag)
					# or their own country. They cannot violate neutrality of third parties.
					if n_owner == owner_tag or n_owner == allowed_passage_tag:
						visited[n_str] = true
						parent[n_str] = curr
						q.append(n_str)
					
	if found_target == "": return []
	
	var path = []
	var curr = found_target
	while curr != start_sid:
		path.append(curr)
		curr = parent[curr]
	path.reverse()
	
	var path_vectors = []
	for s in path:
		path_vectors.append(get_state_center(s))
		
	return path_vectors

func find_path(start_sid: String, target_sid: String, owner_tag: String, allowed_passage_tag: String = "") -> Array:
	if start_sid == target_sid: return []
	
	if not state_neighbors.has(start_sid) or not state_neighbors.has(target_sid): return []
	
	var q = [start_sid]
	var visited = {start_sid: true}
	var parent = {}
	
	var head = 0
	var found = false
	while head < q.size():
		var curr = q[head]
		head += 1
		if curr == target_sid:
			found = true
			break
			
		if state_neighbors.has(curr):
			for n in state_neighbors[curr]:
				var n_str = str(n)
				if not visited.has(n_str):
					var n_owner = get_state_owner(n_str)
					var rel = game_session.get_relation(owner_tag, n_owner)
					if rel == "OWN" or rel == "WAR" or (allowed_passage_tag != "" and n_owner == allowed_passage_tag):
						visited[n_str] = true
						parent[n_str] = curr
						q.append(n_str)
	if not found:
		return []
		
	var path = []
	var curr = target_sid
	while curr != start_sid:
		path.append(curr)
		curr = parent[curr]
	path.reverse()
	
	var path_vectors = []
	for s in path:
		path_vectors.append(get_state_center(s))
		
	return path_vectors

func _unhandled_input(event):
	# Move selected army on right click
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if selected_army and not selected_army.in_combat:
			var target_pos = get_global_mouse_position()
			var target_sid = get_state_at_pos(target_pos)
			
			if target_sid == 0:
				# Clicked on water or void
				return
				
			var target_sid_str = str(target_sid)
			var start_sid = str(get_state_at_pos(selected_army.position))
			
			var target_owner = get_state_owner(target_sid_str)
			var owner_tag = selected_army.owner_tag
			
			# Ensure we can enter the target state at all
			var target_rel = game_session.get_relation(owner_tag, target_owner)
			if target_rel != "OWN" and target_rel != "WAR":
				# Not allowed to enter
				var dialog = AcceptDialog.new()
				if target_owner == "None" or target_owner == "":
					dialog.dialog_text = "Флот пока не реализован. Нельзя перемещать армию по воде или пустошам."
				else:
					dialog.dialog_text = "Дипломатический инцидент!\nНельзя вторгаться на территорию страны " + target_owner + " без объявления войны."
				add_child(dialog)
				dialog.popup_centered()
				return
				
			var allowed_passage = ""
			var start_owner = get_state_owner(start_sid)
			if start_owner != owner_tag and start_owner != "None" and start_owner != "":
				allowed_passage = start_owner
				
			var path = find_path(start_sid, target_sid_str, owner_tag, allowed_passage)
			
			if path.is_empty() and start_sid != target_sid_str:
				# No route
				var dialog = AcceptDialog.new()
				dialog.dialog_text = "Нет пути к цели! Армия заблокирована нейтральными территориями или водой."
				add_child(dialog)
				dialog.popup_centered()
				return
				
			var target_found = null
			for army in active_armies:
				if army != selected_army and army.owner_tag != selected_army.owner_tag and army.is_visible_in_tree():
					var local_mouse = army.get_local_mouse_position()
					var bar_w = 46.0
					var pole_top = -64.0
					var click_rect = Rect2(-bar_w/2.0 - 4, pole_top - 8, bar_w + 8, -pole_top + 12)
					if click_rect.has_point(local_mouse):
						target_found = army
						break
			
			if target_found:
				selected_army.target_army = target_found
			else:
				selected_army.target_army = null
				
			selected_army.path = path
			if selected_army.path.size() > 0:
				selected_army.target_pos = selected_army.path.pop_front()
			else:
				selected_army.target_pos = target_pos
				
			selected_army.is_moving = true
			selected_army.in_combat = false
	# Original unhandled input
	var focus_owner = get_viewport().gui_get_focus_owner()
	var in_text_input = focus_owner is LineEdit or focus_owner is TextEdit
	
	if event is InputEventKey:
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
			if selected_army:
				selected_army.set_selected(false)
				selected_army = null
			elif selected_prov_id != 0:
				clear_state_selection()
				if game_hud: game_hud.hide_state()
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			handle_click(get_global_mouse_position())
