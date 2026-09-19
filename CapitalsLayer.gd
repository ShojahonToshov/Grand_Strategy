extends Node2D

var star_texture: Texture2D
var fallback_texture: Texture2D
var frame_w = 28
var frame_h = 26

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
			
			var sprite = Sprite2D.new()
			sprite.texture = star_texture
			sprite.region_enabled = true
			sprite.region_rect = Rect2(0, 0, frame_w, frame_h)
			sprite.position = Vector2(c.x, c.y)
			add_child(sprite)

func _process(_delta):
	var mpc = get_parent().get_node_or_null("MapPresentationController")
	var target_fade = 1.0
	if mpc:
		target_fade = mpc.capital_stars_alpha
		
	if target_fade <= 0.01:
		self.visible = false
	else:
		self.visible = true
		self.modulate.a = target_fade
		
	var camera = get_viewport().get_camera_2d()
	if camera:
		var zoom = camera.zoom.x
		var star_phys = clamp(14.0 + (zoom - 0.2) * (8.0 / 2.8), 14.0, 22.0)
		var world_star_scale = (star_phys / frame_w) / zoom
		for child in get_children():
			if child is Sprite2D:
				child.scale = Vector2(world_star_scale, world_star_scale)
