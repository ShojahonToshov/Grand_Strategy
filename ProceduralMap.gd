extends Node2D
class_name ProceduralMap

var state_polygons = {}
var state_nodes = {}
var country_colors = {}
var states_data = {}

@export var water_color: Color = Color(0.15, 0.25, 0.35, 1.0)

func _ready():
	# 1. Load Country Colors
	var color_res = load("res://colors.json") as JSON
	if color_res:
		country_colors = color_res.data
		
	# 2. Load States Ownership Data
	var states_res = load("res://states.json") as JSON
	if states_res:
		states_data = states_res.data
		
	# 3. Load Geometry
	var polys_res = load("res://state_polygons.json") as JSON
	if polys_res:
		state_polygons = polys_res.data
		_build_map()

func _build_map():
	for state_id in state_polygons.keys():
		var poly_data = state_polygons[state_id]
		if not poly_data.has("lod0"): continue
		
		# Determine state color
		var owner_tag = ""
		var state_color = Color(0.5, 0.5, 0.5, 1.0) # Fallback gray
		
		if states_data.has(state_id):
			owner_tag = states_data[state_id].get("owner", "")
			if owner_tag == "WATER" or owner_tag == "None" or owner_tag == "":
				# Let the ocean background show through
				state_color = Color(0, 0, 0, 0)
			elif country_colors.has(owner_tag):
				var color_data = country_colors[owner_tag]
				if typeof(color_data) == TYPE_ARRAY and color_data.size() >= 3:
					state_color = Color(color_data[0] / 255.0, color_data[1] / 255.0, color_data[2] / 255.0)
				elif typeof(color_data) == TYPE_STRING:
					state_color = Color(color_data)
		
		# Create a container for the state (in case of multiple polygons/islands)
		var state_node = Node2D.new()
		state_node.name = "State_" + str(state_id)
		
		for p_arr in poly_data["lod0"]:
			if p_arr.size() < 3: continue
			
			var polygon = Polygon2D.new()
			# Convert array of arrays to PackedVector2Array
			var vec_arr = PackedVector2Array()
			for pt in p_arr:
				vec_arr.append(Vector2(pt[0], pt[1]))
				
			polygon.polygon = vec_arr
			polygon.color = state_color
			polygon.antialiased = true # Crisp vector edges
			polygon.use_parent_material = true # Allow shaders (like paper texture) to apply!
			
			state_node.add_child(polygon)
			
		add_child(state_node)
		state_nodes[state_id] = state_node

# Pro Trick: Fast color update when ownership changes
func update_state_color(state_id: String, new_owner_tag: String):
	if not state_nodes.has(state_id): return
	if not country_colors.has(new_owner_tag): return
	
	var color_data = country_colors[new_owner_tag]
	var new_color = Color(0.5, 0.5, 0.5, 1.0)
	if typeof(color_data) == TYPE_ARRAY and color_data.size() >= 3:
		new_color = Color(color_data[0] / 255.0, color_data[1] / 255.0, color_data[2] / 255.0)
	elif typeof(color_data) == TYPE_STRING:
		new_color = Color(color_data)
		
	for child in state_nodes[state_id].get_children():
		if child is Polygon2D:
			child.color = new_color
