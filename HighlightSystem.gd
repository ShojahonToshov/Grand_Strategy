extends Node2D

var state_polygons_data = {}
var country_polygons_data = {}

var current_highlight_id = ""
var current_lod = "lod0"
var current_mode = "STATES" # or "COUNTRIES"

var highlight_fill_polys = []
var highlight_border_lines = []

@export var fill_color = Color(1.0, 1.0, 1.0, 0.3)
@export var outline_color = Color(1.0, 1.0, 1.0, 0.8)

# References to nodes to control draw order
var fill_node: Node2D
var border_node: Node2D
var vector_map: Node2D

func load_data():
	var json_res = load("res://state_polygons.json") as JSON
	if json_res:
		state_polygons_data = json_res.data
		
	var c_json = load("res://countries.json") as JSON
	if c_json:
		country_polygons_data = c_json.data["polygons"]

func set_highlight(id, lod, mode = "STATES"):
	if current_highlight_id == str(id) and current_lod == lod and current_mode == mode:
		return
	current_highlight_id = str(id)
	current_lod = lod
	current_mode = mode
	_rebuild_highlight()
	if fill_node: fill_node.queue_redraw()
	if border_node: border_node.queue_redraw()

func _rebuild_highlight():
	highlight_fill_polys.clear()
	highlight_border_lines.clear()
	
	if current_highlight_id == "" or current_highlight_id == "0" or current_highlight_id == "WATER": return
	
	var data_source = state_polygons_data if current_mode == "STATES" else country_polygons_data
	if not data_source.has(current_highlight_id): return
	var data = data_source[current_highlight_id]
	if not data.has(current_lod): return
	
	var rings_raw = data[current_lod]
	var rings = []
	for r_raw in rings_raw:
		var pva = PackedVector2Array()
		for pt in r_raw: pva.append(Vector2(pt[0], pt[1]))
		highlight_border_lines.append(pva)
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
		
	highlight_fill_polys = final_polys

func _draw_fill(node: Node2D):
	if current_highlight_id == "" or current_highlight_id == "0" or current_highlight_id == "WATER": return
	var colors = PackedColorArray([fill_color])
	for p in highlight_fill_polys:
		if Geometry2D.triangulate_polygon(p).size() == 0:
			var cleaned = Geometry2D.offset_polygon(p, 0.1, Geometry2D.JOIN_MITER)
			for c in cleaned:
				node.draw_polygon(c, colors)
		else:
			node.draw_polygon(p, colors)

func _draw_border(node: Node2D):
	if current_highlight_id == "" or current_highlight_id == "0" or current_highlight_id == "WATER": return
	if not vector_map: return
	
	var zoom = vector_map.zoom
	var base_width = vector_map.state_width
	var width = max(2.0 / zoom, (base_width * 2.0) / zoom)
	
	for line in highlight_border_lines:
		node.draw_polyline(line, outline_color, width, true)
