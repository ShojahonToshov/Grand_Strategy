extends Node2D

var capitals = []
var star_texture: Texture2D
var cap_alphas = {}

var frame_w = 28
var frame_h = 26

var fallback_texture: Texture2D

@export var diagnostic_mode = false

func _create_fallback_texture():
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(4, 12):
		for x in range(4, 12):
			img.set_pixel(x, y, Color(1, 0, 0, 1))
	return ImageTexture.create_from_image(img)

func setup():
	star_texture = load("res://onmap_victorypoints_strip.png") as Texture2D
	if star_texture:
		frame_w = star_texture.get_width() / 20
		frame_h = star_texture.get_height()
	else:
		print("ERROR: Failed to load onmap_victorypoints_strip.png. Using fallback.")
		star_texture = _create_fallback_texture()
		frame_w = 16
		frame_h = 16
		
	var json_res = load("res://capitals.json") as JSON
	if json_res:
		var data = json_res.data
		for tag in data:
			var c = data[tag]
			c["tag"] = tag
			capitals.append(c)
			cap_alphas[tag] = 1.0

func _process(delta):
	var mpc = get_parent().get_node_or_null("MapPresentationController")
	var target_fade = 1.0
	if mpc:
		target_fade = mpc.capital_stars_alpha
		
	var needs_redraw = false
	for cap in capitals:
		var current_alpha = cap_alphas[cap.tag]
		if abs(current_alpha - target_fade) > 0.01:
			current_alpha = move_toward(current_alpha, target_fade, delta * 4.0)
			cap_alphas[cap.tag] = current_alpha
			needs_redraw = true
			
	if needs_redraw:
		queue_redraw()

func _draw():
	var camera = get_viewport().get_camera_2d()
	if not camera: return
	
	var zoom = camera.zoom.x
	var inv_z = 1.0 / zoom
	var view_rect = get_viewport_rect()
	var ctrans = camera.get_canvas_transform().affine_inverse()
	var world_view_rect = Rect2(ctrans * view_rect.position, view_rect.size * inv_z).grow(100.0 * inv_z)
	
	var src_rect = Rect2(0, 0, frame_w, frame_h)
	
	var star_phys = clamp(14.0 + (zoom - 0.2) * (8.0 / 2.8), 14.0, 22.0)
	var world_star_w = star_phys * inv_z
	var world_star_h = star_phys * inv_z
	
	for cap in capitals:
		var text_alpha = cap_alphas[cap.tag]
		if text_alpha <= 0.01:
			continue
			
		var world_pos = Vector2(cap.x, cap.y)
		
		if not world_view_rect.has_point(world_pos):
			continue
			
		if star_texture:
			var dest_rect = Rect2(world_pos.x - world_star_w/2.0, world_pos.y - world_star_h/2.0, world_star_w, world_star_h)
			draw_texture_rect_region(star_texture, dest_rect, src_rect, Color(1, 1, 1, text_alpha))
			
		if diagnostic_mode:
			draw_rect(Rect2(world_pos.x - 0.5*inv_z, world_pos.y - 0.5*inv_z, 1.0*inv_z, 1.0*inv_z), Color(1, 0, 0, text_alpha))
