extends Node2D

var main_node: Node2D

func _process(_delta):
	queue_redraw()

func draw_dashed_line_custom(points: PackedVector2Array, color: Color, width: float, dash_length: float, gap_length: float, offset: Vector2 = Vector2.ZERO):
	if points.size() < 2: return
	for i in range(points.size() - 1):
		var start = points[i]
		var end = points[i+1]
		var dist = start.distance_to(end)
		if dist < 0.1: continue
		var dir = (end - start).normalized()
		var current_dist = 0.0
		
		# Offset slightly based on time to make the dashes animate? (Optional, might be too complex)
		
		while current_dist < dist:
			var seg_start = start + dir * current_dist
			var next_dist = current_dist + dash_length
			if next_dist > dist:
				next_dist = dist
			var seg_end = start + dir * next_dist
			draw_line(seg_start + offset, seg_end + offset, color, width, true)
			current_dist = next_dist + gap_length

func _draw():
	if not main_node: return
	
	for army in main_node.active_armies:
		if army.is_moving:
			var pts = PackedVector2Array()
			pts.append(army.position)
			
			# The next immediate waypoint is target_pos
			if army.target_pos != Vector2.ZERO and army.position.distance_to(army.target_pos) > 1.0:
				pts.append(army.target_pos)
				
			# The rest of the waypoints are in path array
			for p in army.path:
				pts.append(p)
			
			if army.target_army and is_instance_valid(army.target_army):
				# The last point should actually be the enemy army position
				if pts.size() > 1:
					pts[pts.size() - 1] = army.target_army.position
				else:
					pts.append(army.target_army.position)
				
			# Determine color
			var final_pos = pts[-1] if pts.size() > 0 else army.target_pos
			var final_sid = str(main_node.get_state_at_pos(final_pos))
			var final_owner = main_node.get_state_owner(final_sid)
			
			var is_attack = (army.target_army != null)
			if main_node.has_node("GameSession"):
				var gs = main_node.get_node("GameSession")
				if gs.get_relation(army.owner_tag, final_owner) == "WAR":
					is_attack = true
					
			var color = Color(1.0, 1.0, 1.0, 0.6) # Default: White/Silver
			
			if is_attack:
				color = Color(1.0, 0.2, 0.2, 0.75) # Attack: Red
				
			# If army is selected, make it brighter
			if army.selected:
				color.a = 1.0
				
			if main_node.has_node("MapPresentationController"):
				var mpc = main_node.get_node("MapPresentationController")
				color.a *= mpc.army_flags_alpha
				
			var z_scale = 1.0
			if main_node.has_node("Camera2D"):
				var cam = main_node.get_node("Camera2D")
				z_scale = clamp(1.0 / cam.zoom.x, 0.2, 5.0)

			# Draw main dashed line
			draw_dashed_line_custom(pts, color, 2.0 * z_scale, 8.0 * z_scale, 6.0 * z_scale)
			
			# Draw military arrow head
			if pts.size() >= 2:
				var end = pts[-1]
				var prev = pts[-2]
				if prev.distance_to(end) > 0.1:
					var dir = (end - prev).normalized()
					var arrow_size = 12.0 * z_scale
					var p1 = end - dir * arrow_size + dir.orthogonal() * (arrow_size * 0.6)
					var p2 = end - dir * arrow_size - dir.orthogonal() * (arrow_size * 0.6)
					
					# Arrow fill
					var arrow_pts = PackedVector2Array([end, p1, p2])
					draw_polygon(arrow_pts, PackedColorArray([color]))
