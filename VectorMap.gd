extends Node2D

@export var state_width: float = 0.8
@export var state_color: Color = Color(0.2, 0.2, 0.2, 0.8)

var chunk_size = 512.0
var internal_lines = {"lod0": {}, "lod1": {}, "lod2": {}}
var external_lines = {"lod0": {}, "lod1": {}, "lod2": {}}

var internal_nodes = {}
var external_nodes = {}
var internal_layer = Node2D.new()
var external_layer = Node2D.new()

var zoom: float = 1.0
var show_state = true
var current_lod = "lod0"

func setup_lookup(country_lookup: ImageTexture):
	pass

func _ready():
	add_child(internal_layer)
	add_child(external_layer)

func load_data():
	var int_res = load("res://state_lines.json") as JSON
	if int_res: _build_blocks(int_res.data, internal_lines, internal_nodes, internal_layer, true)
	
	# All lines are now rendered uniformly as internal_lines (region borders)
	# external_lines is disabled per user request.
		
	update_zoom(zoom, true)

func _build_blocks(data: Dictionary, lines_dict: Dictionary, nodes_dict: Dictionary, layer: Node2D, is_internal: bool):
	var all_bpos = {}
	
	for lod_name in ["lod0", "lod1", "lod2"]:
		if not data.has(lod_name): continue
		lines_dict[lod_name].clear()
		var polylines = data[lod_name]
		var lod_lines = lines_dict[lod_name]
		
		for line in polylines:
			if line.size() < 2: continue
			for i in range(line.size() - 1):
				var p1 = Vector2(line[i][0], line[i][1])
				var p2 = Vector2(line[i+1][0], line[i+1][1])
				
				var center = (p1 + p2) * 0.5
				var bx = floor(center.x / chunk_size)
				var by = floor(center.y / chunk_size)
				var bpos = Vector2(bx, by)
				all_bpos[bpos] = true
				
				if not lod_lines.has(bpos):
					lod_lines[bpos] = PackedVector2Array()
					
				lod_lines[bpos].append(p1)
				lod_lines[bpos].append(p2)
				
	# Create a physical Node2D for each chunk so Godot culls them automatically when off-screen
	for bpos in all_bpos.keys():
		if not nodes_dict.has(bpos):
			var chunk_node = Node2D.new()
			if is_internal:
				chunk_node.draw.connect(_on_internal_chunk_draw.bind(bpos, chunk_node))
			else:
				chunk_node.draw.connect(_on_external_chunk_draw.bind(bpos, chunk_node))
			layer.add_child(chunk_node)
			nodes_dict[bpos] = chunk_node

func _process(_delta):
	if not show_state:
		internal_layer.visible = false
		external_layer.visible = false
		return
	else:
		internal_layer.visible = true
		external_layer.visible = true
	
	var mpc = get_parent().get_node_or_null("MapPresentationController")
	if mpc:
		internal_layer.modulate.a = mpc.internal_borders_alpha
		
	var camera = get_viewport().get_camera_2d()
	if camera:
		var ctrans = camera.get_canvas_transform().affine_inverse()
		var view_rect = get_viewport_rect()
		var world_rect = Rect2(ctrans * view_rect.position, view_rect.size * ctrans.get_scale()).grow(chunk_size * 0.5)
		
		for bpos in internal_nodes.keys():
			var chunk_rect = Rect2(bpos.x * chunk_size, bpos.y * chunk_size, chunk_size, chunk_size)
			var is_vis = world_rect.intersects(chunk_rect)
			internal_nodes[bpos].visible = is_vis
			if external_nodes.has(bpos):
				external_nodes[bpos].visible = is_vis

func _on_internal_chunk_draw(bpos: Vector2, node: Node2D):
	if not show_state: return
	var width = state_width * 0.5 # Fixed width based on max zoom!
	var col_int = Color(0.2, 0.2, 0.2, 0.7)
	var arr = internal_lines[current_lod].get(bpos)
	if arr and arr.size() > 0:
		node.draw_multiline(arr, col_int, width, false)

func _on_external_chunk_draw(bpos: Vector2, node: Node2D):
	if not show_state: return
	var width = state_width * 0.8 # Slightly thicker for external borders
	var col_ext = Color(0.0, 0.0, 0.0, 0.85)
	var arr = external_lines[current_lod].get(bpos)
	if arr and arr.size() > 0:
		node.draw_multiline(arr, col_ext, width, false)

func update_zoom(z: float, force: bool = false):
	if abs(zoom - z) > 0.001 or force:
		zoom = z
		
		var new_lod = current_lod
		if force:
			if zoom < 0.3: new_lod = "lod2"
			elif zoom < 0.8: new_lod = "lod1"
			else: new_lod = "lod0"
		else:
			if current_lod == "lod0" and zoom < 0.7:
				new_lod = "lod1"
			elif current_lod == "lod1":
				if zoom > 0.9: new_lod = "lod0"
				elif zoom < 0.25: new_lod = "lod2"
			elif current_lod == "lod2" and zoom > 0.35:
				new_lod = "lod1"
				
		if current_lod != new_lod:
			current_lod = new_lod
			# Only redraw chunks when LOD level changes physically
			for node in internal_nodes.values():
				node.queue_redraw()
			for node in external_nodes.values():
				node.queue_redraw()
