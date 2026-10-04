extends Node2D

var state_polys = {}
var show_resources = false
var distribution_node: Node

func setup(dist: Node):
	distribution_node = dist
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
	if mpc and mpc.current_theme == mpc.MapTheme.RESOURCES:
		should_show = true
		
	if should_show != show_resources:
		show_resources = should_show
		queue_redraw()

func _draw():
	if not show_resources or not distribution_node: return
	
	print("ResourceMap is drawing!")
	var gold_color = distribution_node.get_resource_color(1) # GOLD
	var wood_color = distribution_node.get_resource_color(2) # WOOD
	var iron_color = distribution_node.get_resource_color(3) # IRON
	var canvas_color = distribution_node.get_resource_color(4) # CANVAS
	var none_color = distribution_node.get_resource_color(0) # NONE
	
	var gold_arr = PackedColorArray([gold_color])
	var wood_arr = PackedColorArray([wood_color])
	var iron_arr = PackedColorArray([iron_color])
	var canvas_arr = PackedColorArray([canvas_color])
	var none_arr = PackedColorArray([none_color])
	
	for state_id in state_polys.keys():
		var res = distribution_node.get_resource_for_state(state_id)
		var c_arr = none_arr
		if res == 1: c_arr = gold_arr
		elif res == 2: c_arr = wood_arr
		elif res == 3: c_arr = iron_arr
		elif res == 4: c_arr = canvas_arr
		
		for p in state_polys[state_id]:
			_draw_poly_safe(p, c_arr[0])


func _draw_poly_safe(p: PackedVector2Array, color: Color, node: CanvasItem = self):
	var idx = Geometry2D.triangulate_polygon(p)
	if idx.size() > 0:
		var cols = PackedColorArray()
		cols.resize(p.size())
		cols.fill(color)
		RenderingServer.canvas_item_add_triangle_array(node.get_canvas_item(), idx, p, cols)
		return

	# Fallback 1: Clean the polygon with 0 delta (removes self-intersections without shrinking)
	var cleaned = Geometry2D.offset_polygon(p, 0.0, Geometry2D.JOIN_SQUARE)
	if cleaned.size() == 0:
		var p_rev = p.duplicate()
		p_rev.reverse()
		cleaned = Geometry2D.offset_polygon(p_rev, 0.0, Geometry2D.JOIN_SQUARE)
		
	var drew_anything = false
	for c in cleaned:
		var c_idx = Geometry2D.triangulate_polygon(c)
		if c_idx.size() > 0:
			var cols = PackedColorArray()
			cols.resize(c.size())
			cols.fill(color)
			RenderingServer.canvas_item_add_triangle_array(node.get_canvas_item(), c_idx, c, cols)
			drew_anything = true
			
	if drew_anything:
		return
		
	# Fallback 2: Expand slightly (merges very close vertices that might be causing EarClipping failure)
	var cleaned_01 = Geometry2D.offset_polygon(p, 0.1, Geometry2D.JOIN_SQUARE)
	if cleaned_01.size() == 0:
		var p_rev = p.duplicate()
		p_rev.reverse()
		cleaned_01 = Geometry2D.offset_polygon(p_rev, 0.1, Geometry2D.JOIN_SQUARE)
		
	for c in cleaned_01:
		var c_idx = Geometry2D.triangulate_polygon(c)
		if c_idx.size() > 0:
			var cols = PackedColorArray()
			cols.resize(c.size())
			cols.fill(color)
			RenderingServer.canvas_item_add_triangle_array(node.get_canvas_item(), c_idx, c, cols)
