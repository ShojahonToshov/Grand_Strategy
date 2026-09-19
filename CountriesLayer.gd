extends Node2D

@export var debug_mode: bool = false
var font: SystemFont

func setup():
	font = SystemFont.new()
	font.font_names = ["Garamond", "Georgia", "Times New Roman", "serif"]
	font.generate_mipmaps = true # Better scaling
	
	var json_res = load("res://labels.json") as JSON
	if json_res:
		var labels_data = json_res.data["labels"]
		for cap in labels_data:
			var holder = Node2D.new()
			holder.position = Vector2(cap.x, cap.y)
			holder.rotation = deg_to_rad(cap.angle)
			holder.scale = Vector2(cap.scale, cap.scale)
			add_child(holder)
			
			var label = Label.new()
			label.text = cap.name
			label.add_theme_font_override("font", font)
			label.add_theme_font_size_override("font_size", int(cap.font_size))
			label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.95, 1.0))
			label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
			label.add_theme_constant_override("outline_size", 3)
			
			# Center the label
			var text_size = font.get_string_size(cap.name, HORIZONTAL_ALIGNMENT_LEFT, -1, int(cap.font_size))
			label.position = Vector2(-text_size.x / 2.0, -text_size.y / 2.0)
			holder.add_child(label)

func _process(_delta):
	var mpc = get_parent().get_node_or_null("MapPresentationController")
	var target_fade = 1.0
	if mpc:
		target_fade = mpc.country_labels_alpha
		
	if target_fade <= 0.01:
		self.visible = false
	else:
		self.visible = true
		self.modulate.a = target_fade
