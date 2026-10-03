extends Node2D

var precalc_polys = {} # state_id -> [PackedVector2Array]
var state_owners = {}  # state_id -> owner_tag
var country_colors = {} # tag -> Color
var show_political = true

func setup(states_data: Dictionary):
	# Load colors.json to get original colors
	var col_json = load("res://colors.json") as JSON
	if col_json:
		var colors_dict = col_json.data
		for tag in colors_dict.keys():
			var arr = colors_dict[tag]
			country_colors[tag] = Color(arr[0]/255.0, arr[1]/255.0, arr[2]/255.0, 1.0)
			
	# Extract owner for each state
	for sid in states_data.keys():
		var owner = states_data[sid].get("owner", "")
		state_owners[sid] = owner

	var s_json = load("res://state_polygons.json") as JSON
	if not s_json: return
	
	var data = s_json.data
	var lod = "lod0" 
	
	for sid in data.keys():
		var tag_data = data[sid]
		if not tag_data.has(lod): continue
		
		var rings_raw = tag_data[lod]
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
			
		precalc_polys[sid] = []
		for p in final_polys:
			if Geometry2D.triangulate_polygon(p).size() == 0:
				var cleaned = Geometry2D.offset_polygon(p, 0.1, Geometry2D.JOIN_MITER)
				for c in cleaned:
					precalc_polys[sid].append(c)
			else:
				precalc_polys[sid].append(p)

func _draw():
	if not show_political: return
	
	for sid in precalc_polys.keys():
		var tag = state_owners.get(sid, "")
		var color = country_colors.get(tag, Color(0.5, 0.5, 0.5, 1.0))
		var polys = precalc_polys[sid]
		var color_arr = PackedColorArray([color])
		
		for p in polys:
			draw_polygon(p, color_arr)
