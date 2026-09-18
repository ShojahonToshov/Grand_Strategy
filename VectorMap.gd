extends Node2D

var internal_blocks = {}
var external_blocks = {}
var internal_pools = {"lod0": PackedVector2Array(), "lod1": PackedVector2Array(), "lod2": PackedVector2Array()}
var external_pools = {"lod0": PackedVector2Array(), "lod1": PackedVector2Array(), "lod2": PackedVector2Array()}
var block_size = 512.0

@export var state_width: float = 0.8
@export var state_color: Color = Color(0.2, 0.2, 0.2, 0.8)

var zoom: float = 1.0
var show_state = true
var current_lod = "lod0"
var last_view_rect = Rect2()

func load_data():
	var int_res = load("res://internal_lines.json") as JSON
	if int_res: _build_blocks(int_res.data, internal_blocks, internal_pools)
	
	var ext_res = load("res://external_lines.json") as JSON
	if ext_res: _build_blocks(ext_res.data, external_blocks, external_pools)
		
	update_zoom(zoom, true)

func _build_blocks(data: Dictionary, blocks: Dictionary, pools: Dictionary):
	blocks.clear()
	for lod_name in ["lod0", "lod1", "lod2"]:
		if not data.has(lod_name): continue
		pools[lod_name] = PackedVector2Array()
		var polylines = data[lod_name]
		
		var pool = pools[lod_name]
		var next_id = 0
		
		for line in polylines:
			if line.size() < 2: continue
			for i in range(line.size() - 1):
				var p1 = Vector2(line[i][0], line[i][1])
				var p2 = Vector2(line[i+1][0], line[i+1][1])
				
				var sid = next_id
				next_id += 1
				pool.append(p1)
				pool.append(p2)
				
				var min_x = floor(min(p1.x, p2.x) / block_size)
				var max_x = floor(max(p1.x, p2.x) / block_size)
				var min_y = floor(min(p1.y, p2.y) / block_size)
				var max_y = floor(max(p1.y, p2.y) / block_size)
				
				for bx in range(min_x, max_x + 1):
					for by in range(min_y, max_y + 1):
						var bpos = Vector2(bx, by)
						if not blocks.has(bpos):
							blocks[bpos] = {"lod0": PackedInt32Array(), "lod1": PackedInt32Array(), "lod2": PackedInt32Array()}
						blocks[bpos][lod_name].append(sid)

func _process(delta):
	if not show_state: return
	var camera = get_viewport().get_camera_2d()
	if not camera: return
	
	var view_rect = get_viewport_rect()
	var ctrans = camera.get_canvas_transform().affine_inverse()
	var tl = ctrans * view_rect.position
	var br = ctrans * (view_rect.position + view_rect.size)
	var new_rect = Rect2(tl, br - tl)
	
	if not new_rect.is_equal_approx(last_view_rect):
		last_view_rect = new_rect
		queue_redraw()
		
	# Re-draw every frame if we are transitioning to update alpha smoothly
	var mpc = get_parent().get_node_or_null("MapPresentationController")
	if mpc and mpc.overview_ratio >= 0.30 and mpc.overview_ratio <= 0.48:
		queue_redraw()

var cached_min_bx = -1
var cached_max_bx = -1
var cached_min_by = -1
var cached_max_by = -1
var cached_lod = ""
var cached_internal = PackedVector2Array()
var cached_external = PackedVector2Array()

func _rebuild_cache(min_bx, max_bx, min_by, max_by):
	cached_internal = _gather_lines(internal_blocks, internal_pools, min_bx, max_bx, min_by, max_by)
	cached_external = _gather_lines(external_blocks, external_pools, min_bx, max_bx, min_by, max_by)

func _gather_lines(blocks, pools, min_bx, max_bx, min_by, max_by):
	var active_ids = {}
	for bx in range(min_bx, max_bx + 1):
		for by in range(min_by, max_by + 1):
			var bpos = Vector2(bx, by)
			if blocks.has(bpos):
				for sid in blocks[bpos][current_lod]:
					active_ids[sid] = true
	
	var pool = pools[current_lod]
	var multiline = PackedVector2Array()
	multiline.resize(active_ids.size() * 2)
	
	var idx = 0
	for sid in active_ids:
		multiline[idx] = pool[sid*2]
		multiline[idx+1] = pool[sid*2+1]
		idx += 2
	return multiline

func _draw():
	if not show_state: return
	
	var view_rect = last_view_rect.grow(state_width / zoom * 2.0)
	
	var min_bx = floor(view_rect.position.x / block_size)
	var max_bx = floor(view_rect.end.x / block_size)
	var min_by = floor(view_rect.position.y / block_size)
	var max_by = floor(view_rect.end.y / block_size)
	
	if min_bx != cached_min_bx or max_bx != cached_max_bx or min_by != cached_min_by or max_by != cached_max_by or current_lod != cached_lod:
		cached_min_bx = min_bx
		cached_max_bx = max_bx
		cached_min_by = min_by
		cached_max_by = max_by
		cached_lod = current_lod
		_rebuild_cache(min_bx, max_bx, min_by, max_by)
		
	var width = max(1.0 / zoom, state_width / zoom)
	
	var internal_alpha = 1.0
	var mpc = get_parent().get_node_or_null("MapPresentationController")
	if mpc:
		internal_alpha = mpc.internal_borders_alpha
		
	var col_int = Color(0.2, 0.2, 0.2, internal_alpha * 0.7)
	var col_ext = Color(0.0, 0.0, 0.0, 0.85)
	
	if cached_external.size() > 0:
		draw_multiline(cached_external, state_color, width, true)
		
	if internal_alpha > 0.01 and cached_internal.size() > 0:
		var c = state_color
		c.a *= internal_alpha
		draw_multiline(cached_internal, c, width, true)

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
			queue_redraw()
		else:
			queue_redraw()
