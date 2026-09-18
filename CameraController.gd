extends Camera2D

# Settings
var base_speed = 900.0 # Screen pixels per second
var acceleration_time = 0.15
var deceleration_time = 0.10
var edge_scroll_margin = 24.0
var edge_scroll_enabled = true

var map_size = Vector2(5632, 2048)

var current_velocity = Vector2.ZERO
var dragging = false
var last_mouse_pos = Vector2()

var target_zoom = Vector2(1, 1)
var zoom_speed = 10.0

var mouse_in_window = true
var app_focused = true

@export var max_physical_pixels_per_map_pixel: float = 2.5

var min_zoom_limit = 0.1
var max_zoom_limit = 2.5

func _ready():
	target_zoom = zoom
	# Ensure the window opens in borderless fullscreen initially
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	get_tree().root.size_changed.connect(calc_limits)
	calc_limits()

func calc_limits():
	var vsize = get_viewport_rect().size
	var physical_size = DisplayServer.window_get_size()
	var scale_factor = float(physical_size.x) / float(vsize.x)
	if scale_factor <= 0.0: scale_factor = 1.0
	
	var min_z = max(vsize.x / map_size.x, vsize.y / map_size.y)
	
	# X physical pixels per map pixel. zoom * scale_factor = max_physical
	var max_z = max_physical_pixels_per_map_pixel / scale_factor
	
	if min_z > max_z:
		max_z = min_z # resolve conflict
		
	min_zoom_limit = min_z
	max_zoom_limit = max_z
	
	target_zoom.x = clamp(target_zoom.x, min_zoom_limit, max_zoom_limit)
	target_zoom.y = target_zoom.x
	zoom.x = clamp(zoom.x, min_zoom_limit, max_zoom_limit)
	zoom.y = zoom.x
	
	clamp_position()

func _notification(what):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		app_focused = false
		current_velocity = Vector2.ZERO
		dragging = false
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		app_focused = true
	elif what == NOTIFICATION_WM_MOUSE_EXIT:
		mouse_in_window = false
	elif what == NOTIFICATION_WM_MOUSE_ENTER:
		mouse_in_window = true

func _input(event):
	if event is InputEventKey:
		if event.pressed and not event.echo and event.physical_keycode == KEY_F11:
			var current_mode = DisplayServer.window_get_mode()
			if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = false

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				dragging = true
				last_mouse_pos = event.position
				
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			do_zoom(1.1, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			do_zoom(1.0 / 1.1, event.position)
			
	elif event is InputEventMouseMotion and dragging:
		var diff = event.position - last_mouse_pos
		position -= diff / zoom
		last_mouse_pos = event.position
		clamp_position()

func do_zoom(factor, mouse_pos):
	target_zoom *= factor
	target_zoom = target_zoom.clamp(Vector2(min_zoom_limit, min_zoom_limit), Vector2(max_zoom_limit, max_zoom_limit))

func _process(delta):
	# Smooth zoom around current mouse position
	if zoom.distance_to(target_zoom) > 0.001:
		var prev_zoom = zoom
		zoom = zoom.lerp(target_zoom, 1.0 - exp(-zoom_speed * delta))
		
		# Keep the point under the cursor stationary
		var mouse_pos = get_viewport().get_mouse_position()
		var world_mouse = position + mouse_pos / prev_zoom
		var new_world_mouse = position + mouse_pos / zoom
		position += world_mouse - new_world_mouse
		clamp_position()
	else:
		zoom = target_zoom
		
	if not app_focused:
		return
		
	var input_dir = Vector2.ZERO
	var ui_focused = get_viewport().gui_get_focus_owner()
	var typing = ui_focused is LineEdit or ui_focused is TextEdit
	
	if not typing:
		if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			input_dir.y -= 1
		if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			input_dir.y += 1
		if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			input_dir.x -= 1
		if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			input_dir.x += 1
			
	input_dir = input_dir.normalized()
	
	# Edge scrolling (only if no keyboard input and not dragging)
	var edge_dir = Vector2.ZERO
	if input_dir == Vector2.ZERO and not dragging and edge_scroll_enabled and mouse_in_window and not is_mouse_over_ui():
		var mpos = get_viewport().get_mouse_position()
		var vsize = get_viewport_rect().size
		
		var x_factor = 0.0
		var y_factor = 0.0
		
		if mpos.x < edge_scroll_margin:
			x_factor = - (edge_scroll_margin - mpos.x) / edge_scroll_margin
		elif mpos.x > vsize.x - edge_scroll_margin:
			x_factor = (mpos.x - (vsize.x - edge_scroll_margin)) / edge_scroll_margin
			
		if mpos.y < edge_scroll_margin:
			y_factor = - (edge_scroll_margin - mpos.y) / edge_scroll_margin
		elif mpos.y > vsize.y - edge_scroll_margin:
			y_factor = (mpos.y - (vsize.y - edge_scroll_margin)) / edge_scroll_margin
			
		edge_dir = Vector2(x_factor, y_factor)
		if edge_dir.length() > 1.0:
			edge_dir = edge_dir.normalized()
			
		input_dir = edge_dir
		
	var shift_mult = 2.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	var target_speed = (base_speed * shift_mult) / zoom.x # adjust by zoom
	var target_velocity = input_dir * target_speed
	
	if target_velocity != Vector2.ZERO:
		var accel = target_speed / acceleration_time
		current_velocity = current_velocity.move_toward(target_velocity, accel * delta)
	else:
		var max_speed = (base_speed * 2.0) / zoom.x
		var decel = max_speed / deceleration_time
		current_velocity = current_velocity.move_toward(Vector2.ZERO, decel * delta)
		
	if current_velocity != Vector2.ZERO and not dragging:
		position += current_velocity * delta
		clamp_position()

func clamp_position():
	var vsize = get_viewport_rect().size / zoom
	var limits_min = Vector2.ZERO
	var limits_max = map_size - vsize
	
	var overstep_x = false
	var overstep_y = false
	
	if map_size.x < vsize.x:
		position.x = (map_size.x - vsize.x) / 2.0
		overstep_x = true
	else:
		if position.x < limits_min.x:
			position.x = limits_min.x
			overstep_x = true
		elif position.x > limits_max.x:
			position.x = limits_max.x
			overstep_x = true
			
	if map_size.y < vsize.y:
		position.y = (map_size.y - vsize.y) / 2.0
		overstep_y = true
	else:
		if position.y < limits_min.y:
			position.y = limits_min.y
			overstep_y = true
		elif position.y > limits_max.y:
			position.y = limits_max.y
			overstep_y = true
			
	# Remove velocity component if we hit a wall
	if overstep_x:
		current_velocity.x = 0
	if overstep_y:
		current_velocity.y = 0

func is_mouse_over_ui() -> bool:
	var mouse_pos = get_viewport().get_mouse_position()
	
	var panel = get_node("../CanvasLayer/Panel")
	if panel and panel.visible:
		var rect = Rect2(panel.global_position, panel.size)
		if rect.has_point(mouse_pos):
			return true
			
	var hud = get_node_or_null("../GameHUD")
	if hud:
		var top = hud.get_node_or_null("TopBar")
		if top and top.visible:
			var rect = Rect2(top.global_position, top.size)
			if rect.has_point(mouse_pos): return true
		var side = hud.get_node_or_null("StateInfoPanel")
		if side and side.visible:
			var rect = Rect2(side.global_position, side.size)
			if rect.has_point(mouse_pos): return true
		var modes = hud.get_node_or_null("MapModesPanel")
		if modes:
			for child in modes.get_children():
				if child is Control and child.visible:
					var r = Rect2(child.global_position, child.size)
					if r.has_point(mouse_pos): return true
			
	return false
