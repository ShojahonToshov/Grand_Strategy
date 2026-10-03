extends Node2D

var state_id: String
var population: int
var owner_tag: String
var selected: bool = false
var target_pos: Vector2

var is_moving: bool = false
var move_speed: float = 150.0

signal clicked(army)

func _ready():
	z_index = 50
	target_pos = position
	scale = Vector2(0.25, 0.25)

func set_data(p_state_id, p_pop, p_owner):
	state_id = p_state_id
	population = p_pop
	owner_tag = p_owner
	
	var pop_str = ""
	if population >= 1000000:
		pop_str = "%.1fM" % (population / 1000000.0)
	elif population >= 1000:
		pop_str = "%dK" % (population / 1000)
	else:
		pop_str = str(population)
	
	var lbl = Label.new()
	lbl.name = "PopLabel"
	lbl.text = pop_str
	
	var ls = LabelSettings.new()
	ls.font_size = 10
	ls.font_color = Color(0.1, 0.1, 0.1)
	ls.outline_size = 1
	ls.outline_color = Color(1.0, 1.0, 1.0, 0.5)
	lbl.label_settings = ls
	
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Position exactly inside the white label box
	var flag_w = 40.0
	var label_top = -58.0
	var label_h = 14.0
	lbl.size = Vector2(flag_w - 2.0, label_h - 2.0)
	lbl.position = Vector2(-flag_w/2.0 + 1.0, label_top + 1.0)
	
	add_child(lbl)
	queue_redraw()

func _process(delta):
	if is_moving:
		var dist = position.distance_to(target_pos)
		if dist < 2.0:
			position = target_pos
			is_moving = false
		else:
			var dir = (target_pos - position).normalized()
			position += dir * move_speed * delta

func _draw():
	# Dimensions exactly matching the reference
	var flag_w = 40.0
	var flag_h = 24.0
	var flag_bottom = -20.0
	var flag_top = flag_bottom - flag_h # -44.0
	var label_h = 14.0
	var label_top = flag_top - label_h # -58.0
	var pole_top = label_top - 6.0 # -64.0
	var bar_w = 46.0
	
	# Concave side points for the flag
	var left_out = -flag_w/2.0
	var left_in = -flag_w/2.0 + 2.5
	var right_out = flag_w/2.0
	var right_in = flag_w/2.0 - 2.5
	var mid_y = flag_top + flag_h/2.0
	
	# 1. Main Pole (Central)
	draw_rect(Rect2(-1.5, pole_top, 3.0, -pole_top), Color(0.65, 0.65, 0.65))
	draw_rect(Rect2(-1.5, pole_top, 1.5, -pole_top), Color(0.9, 0.9, 0.9)) # metallic highlight
	
	# 2. The Flag (Cloth)
	var div1 = left_out + flag_w / 3.0
	var div2 = left_out + (flag_w * 2.0) / 3.0
	
	if owner_tag == "FRA":
		# Blue
		var blue_pts = PackedVector2Array([
			Vector2(left_out, flag_top), Vector2(div1, flag_top),
			Vector2(div1, flag_bottom), Vector2(left_out, flag_bottom),
			Vector2(left_in, mid_y)
		])
		draw_polygon(blue_pts, PackedColorArray([Color(0.12, 0.2, 0.45)]))
		# White
		var white_pts = PackedVector2Array([
			Vector2(div1, flag_top), Vector2(div2, flag_top),
			Vector2(div2, flag_bottom), Vector2(div1, flag_bottom)
		])
		draw_polygon(white_pts, PackedColorArray([Color(0.95, 0.95, 0.95)]))
		# Red
		var red_pts = PackedVector2Array([
			Vector2(div2, flag_top), Vector2(right_out, flag_top),
			Vector2(right_in, mid_y), Vector2(right_out, flag_bottom),
			Vector2(div2, flag_bottom)
		])
		draw_polygon(red_pts, PackedColorArray([Color(0.8, 0.15, 0.15)]))
	elif owner_tag == "ENG":
		var eng_pts = PackedVector2Array([
			Vector2(left_out, flag_top), Vector2(right_out, flag_top),
			Vector2(right_in, mid_y), Vector2(right_out, flag_bottom),
			Vector2(left_out, flag_bottom), Vector2(left_in, mid_y)
		])
		draw_polygon(eng_pts, PackedColorArray([Color(0.8, 0.1, 0.1)]))
	else:
		var gen_pts = PackedVector2Array([
			Vector2(left_out, flag_top), Vector2(right_out, flag_top),
			Vector2(right_in, mid_y), Vector2(right_out, flag_bottom),
			Vector2(left_out, flag_bottom), Vector2(left_in, mid_y)
		])
		draw_polygon(gen_pts, PackedColorArray([Color(0.5, 0.5, 0.5)]))
		
	# Flag Volume/Shading (darken edges to simulate curve)
	var shadow_left = PackedVector2Array([
		Vector2(left_out, flag_top), Vector2(div1, flag_top),
		Vector2(div1, flag_bottom), Vector2(left_out, flag_bottom),
		Vector2(left_in, mid_y)
	])
	draw_polygon(shadow_left, PackedColorArray([Color(0, 0, 0, 0.15)]))
	var shadow_right = PackedVector2Array([
		Vector2(div2, flag_top), Vector2(right_out, flag_top),
		Vector2(right_in, mid_y), Vector2(right_out, flag_bottom),
		Vector2(div2, flag_bottom)
	])
	draw_polygon(shadow_right, PackedColorArray([Color(0, 0, 0, 0.25)]))
	
	# 3. Label Box (Blue border, White center)
	draw_rect(Rect2(left_out, label_top, flag_w, label_h), Color(0.12, 0.2, 0.45))
	draw_rect(Rect2(left_out + 1.0, label_top + 1.0, flag_w - 2.0, label_h - 2.0), Color(0.95, 0.95, 0.95))
	
	# 4. Metal Crossbars
	var bar_x = -bar_w/2.0
	for y in [label_top, flag_top, flag_bottom]:
		# Main silver bar
		draw_rect(Rect2(bar_x, y - 1.5, bar_w, 3.0), Color(0.8, 0.8, 0.8))
		# Highlight (top edge)
		draw_rect(Rect2(bar_x, y - 1.5, bar_w, 1.0), Color(1.0, 1.0, 1.0))
		# Shadow (bottom edge)
		draw_rect(Rect2(bar_x, y + 0.5, bar_w, 1.0), Color(0.4, 0.4, 0.4))
		# Knobs
		draw_circle(Vector2(bar_x, y), 2.0, Color(0.8, 0.8, 0.8))
		draw_circle(Vector2(bar_x + bar_w, y), 2.0, Color(0.8, 0.8, 0.8))
		draw_circle(Vector2(bar_x, y - 0.5), 1.0, Color(1.0, 1.0, 1.0)) # knob highlight
		draw_circle(Vector2(bar_x + bar_w, y - 0.5), 1.0, Color(1.0, 1.0, 1.0)) # knob highlight
		
	# 5. Top Finial (French Cockade)
	var cockade_pos = Vector2(0, label_top - 4.5)
	draw_circle(cockade_pos, 4.0, Color(0.8, 0.15, 0.15)) # Red
	draw_circle(cockade_pos, 2.5, Color(0.95, 0.95, 0.95)) # White
	draw_circle(cockade_pos, 1.2, Color(0.12, 0.2, 0.45)) # Blue
	
	if selected:
		# Selection outline
		var sel_rect = Rect2(-bar_w/2.0 - 4, pole_top - 8, bar_w + 8, -pole_top + 12)
		draw_rect(sel_rect, Color(1.0, 1.0, 0.0, 0.8), false, 1.5)

func set_selected(val):
	selected = val
	queue_redraw()

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_mouse = get_local_mouse_position()
		var bar_w = 46.0
		var pole_top = -64.0
		var bounds = Rect2(-bar_w/2.0 - 4, pole_top - 8, bar_w + 8, -pole_top + 12)
		if bounds.has_point(local_mouse):
			get_viewport().set_input_as_handled()
			clicked.emit(self)
