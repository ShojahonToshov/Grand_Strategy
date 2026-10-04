extends Node2D

var state_polys = {}
var show_diplomacy = false
var game_session: Node
var player_tag = "FRA" # The current player tag, usually "FRA"

func setup():
	# game_session is fetched dynamically to avoid null reference on init
	var json_res = load("res://state_polygons.json") as JSON
	if not json_res: return
	
	var data = json_res.data
	for state_id in data.keys():
		var lod_data = data[state_id]
		var rings_raw = lod_data.get("lod0", [])
		
		var rings = []
		for r_raw in rings_raw:
			var pva = PackedVector2Array()
			for pt in r_raw: pva.append(Vector2(pt[0], pt[1]))
			rings.append(pva)
			
		var outers = []
		var holes = []
		
		for i in range(rings.size()):
			var is_hole = false
			var pt = rings[i][0]
			for j in range(rings.size()):
				if i == j: continue
				if Geometry2D.is_point_in_polygon(pt, rings[j]):
					is_hole = true
					break
			if is_hole:
				holes.append(rings[i])
			else:
				outers.append(rings[i])
				
		var final_polys = outers
		for h in holes:
			var next_polys = []
			for o in final_polys:
				var clipped = Geometry2D.clip_polygons(o, h)
				for c in clipped:
					next_polys.append(c)
			final_polys = next_polys
			
		state_polys[state_id] = final_polys

func _process(_delta):
	var mpc = get_parent().get_node_or_null("MapPresentationController")
	var should_show = false
	if mpc and mpc.current_theme == mpc.MapTheme.DIPLOMACY:
		should_show = true
		
	if should_show != show_diplomacy:
		show_diplomacy = should_show
		queue_redraw()
		
func _draw():
	if not show_diplomacy: return
	
	var main_node = get_parent()
	if not main_node or not main_node.has_method("get_state_owner"): return
	
	game_session = main_node.get_node_or_null("GameSession")
	if not game_session: return
	
	# Colors for diplomacy map mode
	var self_color = Color(0.1, 0.5, 0.3, 1.0) # Green for self
	var war_color = Color(0.8, 0.2, 0.2, 1.0) # Red for war
	var allied_color = Color(0.2, 0.4, 0.8, 1.0) # Blue for allies
	var neutral_color = Color(0.4, 0.4, 0.45, 1.0) # Gray for neutral
	
	var self_arr = PackedColorArray([self_color])
	var war_arr = PackedColorArray([war_color])
	var allied_arr = PackedColorArray([allied_color])
	var neutral_arr = PackedColorArray([neutral_color])
	
	for state_id in state_polys.keys():
		var owner = main_node.get_state_owner(state_id)
		
		var c_arr = neutral_arr
		if owner == player_tag:
			c_arr = self_arr
		elif owner != "None" and owner != "":
			var rel = game_session.get_relation(player_tag, owner)
			if rel == "WAR":
				c_arr = war_arr
			elif rel == "ALLIED":
				c_arr = allied_arr
			else:
				c_arr = neutral_arr
		
		# Skip drawing for water
		if owner == "None" or owner == "":
			continue
			
		for p in state_polys[state_id]:
			if Geometry2D.triangulate_polygon(p).size() == 0:
				var cleaned = Geometry2D.offset_polygon(p, 0.1, Geometry2D.JOIN_MITER)
				for c in cleaned:
					draw_polygon(c, c_arr)
			else:
				draw_polygon(p, c_arr)
