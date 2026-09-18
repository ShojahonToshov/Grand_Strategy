extends Node2D

@export var debug_mode: bool = false

var labels_data = []
var drawn_alphas = {}
var font: SystemFont

# For debug drawing
var debug_polygons = []

func setup():
	font = SystemFont.new()
	font.font_names = ["Garamond", "Georgia", "Times New Roman", "serif"]
	font.generate_mipmaps = true # Better scaling
	
	var json_res = load("res://labels.json") as JSON
	if json_res:
		labels_data = json_res.data["labels"]
		for cap in labels_data:
			drawn_alphas[str(cap.label_id)] = 0.0
			
	if debug_mode:
		var c_res = load("res://countries.json") as JSON
		if c_res:
			for comp in c_res.data["components"]:
				var poly = PackedVector2Array()
				for p in comp["outer"]: poly.append(Vector2(p[0], p[1]))
				debug_polygons.append(poly)

func _process(delta):
	var camera = get_viewport().get_camera_2d()
	if not camera: return
	
	var mpc = get_parent().get_node_or_null("MapPresentationController")
	var target_fade = 1.0
	if mpc:
		target_fade = mpc.country_labels_alpha
		
	var needs_redraw = false
	
	if target_fade <= 0.01:
		for cap in labels_data:
			var id_str = str(cap.label_id)
			if drawn_alphas[id_str] != 0.0:
				drawn_alphas[id_str] = 0.0
				needs_redraw = true
		if needs_redraw:
			queue_redraw()
		return
		
	var zoom = camera.zoom.x
	var inv_z = 1.0 / zoom
	var view_rect = get_viewport_rect()
	var ctrans = camera.get_canvas_transform().affine_inverse()
	var world_view_rect = Rect2(ctrans * view_rect.position, view_rect.size * inv_z).grow(100.0 * inv_z)
	
	for cap in labels_data:
		var id_str = str(cap.label_id)
		var world_pos = Vector2(cap.x, cap.y)
		
		if not world_view_rect.has_point(world_pos):
			drawn_alphas[id_str] = 0.0
			continue
			
		var target_alpha = target_fade
		var current_alpha = drawn_alphas[id_str]
		if current_alpha != target_alpha:
			current_alpha = move_toward(current_alpha, target_alpha, delta * 4.0)
			drawn_alphas[id_str] = current_alpha
			needs_redraw = true
			
	if needs_redraw or debug_mode:
		queue_redraw()

func _draw():
	if debug_mode:
		for poly in debug_polygons:
			draw_polyline(poly, Color(1, 0, 0, 0.5), 2.0)
			
	var camera = get_viewport().get_camera_2d()
	if not camera: return
	
	var zoom = camera.zoom.x
	var inv_z = 1.0 / zoom
	var view_rect = get_viewport_rect()
	var ctrans = camera.get_canvas_transform().affine_inverse()
	var world_view_rect = Rect2(ctrans * view_rect.position, view_rect.size * inv_z).grow(100.0 * inv_z)
	
	var mpc = get_parent().get_node_or_null("MapPresentationController")
	if mpc and mpc.country_labels_alpha <= 0.01:
		return
	
	for cap in labels_data:
		var id_str = str(cap.label_id)
		var text_alpha = drawn_alphas[id_str]
		if text_alpha <= 0.01:
			continue
			
		var world_pos = Vector2(cap.x, cap.y)
		if not world_view_rect.has_point(world_pos):
			continue
			
		var text = cap.name
		var angle_rad = deg_to_rad(cap.angle)
		var valid_scale = cap.scale
		var base_size = int(cap.font_size)
		
		var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, base_size)
		
		var draw_scale = Vector2(valid_scale, valid_scale)
		draw_set_transform(world_pos, angle_rad, draw_scale)
		
		var offset_x = -text_size.x / 2.0
		var offset_y = (font.get_ascent(base_size) - text_size.y / 2.0)
		var text_draw_pos = Vector2(offset_x, offset_y)
		
		if debug_mode:
			var tw = text_size.x + base_size * 0.2
			var th = text_size.y + base_size * 0.2
			var box = Rect2(-tw/2.0, -th/2.0, tw, th)
			draw_rect(box, Color(0, 1, 0, 0.3), true)
			draw_circle(Vector2.ZERO, 10.0 / valid_scale, Color(0,0,1))
		
		var out_color = Color(0, 0, 0, text_alpha * 0.5)
		draw_string_outline(font, text_draw_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, base_size, 6, out_color)
		draw_string_outline(font, text_draw_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, base_size, 3, Color(0,0,0,text_alpha * 0.8))
		
		var fill_color = Color(1.0, 1.0, 0.95, text_alpha)
		draw_string(font, text_draw_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, base_size, fill_color)
		
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
