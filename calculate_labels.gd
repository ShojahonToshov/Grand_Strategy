extends SceneTree

func _init():
	print("Starting calculate_labels.gd...")
	
	var font = SystemFont.new()
	font.font_names = ["Garamond", "Georgia", "Times New Roman", "serif"]
	font.generate_mipmaps = true
	var base_size = 64
	
	var f = FileAccess.open("res://countries.json", FileAccess.READ)
	if not f:
		print("Failed to open countries.json")
		quit(1)
		return
	
	var json = JSON.new()
	if json.parse(f.get_as_text()) != OK:
		print("JSON parse error")
		quit(1)
		return
		
	var data = json.data
	var components = data["components"]
	
	var labels_out = []
	
	for comp in components:
		var owner = comp["owner"]
		var name = comp["name"]
		var label_id = comp["label_id"]
		var outer = PackedVector2Array()
		for p in comp["outer"]: outer.append(Vector2(p[0], p[1]))
		var holes = []
		for h in comp["holes"]:
			var ha = PackedVector2Array()
			for p in h: ha.append(Vector2(p[0], p[1]))
			holes.append(ha)
			
		var text_size = font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, base_size)
		# Add a bit of padding to the string size (halo + spacing)
		var text_w = text_size.x + base_size * 0.2
		var text_h = text_size.y + base_size * 0.2
		var text_aspect = text_w / max(1.0, text_h)
		
		# Find bounds
		var min_x = 999999.0
		var max_x = -999999.0
		var min_y = 999999.0
		var max_y = -999999.0
		for p in outer:
			if p.x < min_x: min_x = p.x
			if p.x > max_x: max_x = p.x
			if p.y < min_y: min_y = p.y
			if p.y > max_y: max_y = p.y
			
		# Single candidate point from Python
		var cand_data = comp["poi"]
		var cand = Vector2(cand_data[0], cand_data[1])
		
		var best_score = -1.0
		var best_placement = null
		
		# Test angles
		for deg in range(-80, 81, 15):
			var rad = deg_to_rad(deg)
			var dir = Vector2(cos(rad), sin(rad))
			
			var line = PackedVector2Array([cand - dir * 10000, cand + dir * 10000])
			var segments = Geometry2D.intersect_polyline_with_polygon(line, outer)
			var best_seg = null
			for seg in segments:
				# check if cand is on this segment
				var d1 = seg[0].distance_to(cand)
				var d2 = seg[1].distance_to(cand)
				var d12 = seg[0].distance_to(seg[1])
				if abs(d1 + d2 - d12) < 1.0:
					best_seg = seg
					break
			if not best_seg: continue
			
			var center = (best_seg[0] + best_seg[1]) / 2.0
			var avail_len = best_seg[0].distance_to(best_seg[1])
			
			# Target length is 55-70% of avail_len. Let's aim for 60%.
			var target_len = avail_len * 0.60
			var max_scale = target_len / text_w
			
			# Binary search for valid scale
			var low_scale = 0.0
			var high_scale = max_scale
			var valid_scale = 0.0
			
			# Try 5 iterations
			for iter in range(5):
				var test_scale = (low_scale + high_scale) / 2.0
				var box_w = text_w * test_scale
				var box_h = text_h * test_scale
				
				# Create rotated box
				var hw = box_w / 2.0
				var hh = box_h / 2.0
				var p1 = center + Vector2(-hw, -hh).rotated(rad)
				var p2 = center + Vector2(hw, -hh).rotated(rad)
				var p3 = center + Vector2(hw, hh).rotated(rad)
				var p4 = center + Vector2(-hw, hh).rotated(rad)
				var box = PackedVector2Array([p1, p2, p3, p4])
				
				# Check if box is inside outer
				var clipped = Geometry2D.clip_polygons(box, outer)
				var is_inside = (clipped.size() == 0)
				
				if is_inside:
					for h in holes:
						if Geometry2D.intersect_polygons(box, h).size() > 0:
							is_inside = false
							break
							
				if is_inside:
					valid_scale = test_scale
					low_scale = test_scale
				else:
					high_scale = test_scale
					
			if valid_scale > 0.0:
				if valid_scale > best_score:
					best_score = valid_scale
					best_placement = {
						"label_id": label_id,
						"owner": owner,
						"name": name,
						"x": center.x,
						"y": center.y,
						"angle": deg,
						"scale": valid_scale,
						"font_size": base_size,
						"target_len": text_w * valid_scale
					}

		if best_placement and best_placement.target_len >= 15.0:
			labels_out.append(best_placement)
		else:
			print("Failed to place label for: ", name)

	var out_data = {"labels": labels_out}
	var fo = FileAccess.open("res://labels.json", FileAccess.WRITE)
	fo.store_string(JSON.stringify(out_data))
	
	print("Saved labels.json with ", labels_out.size(), " labels.")
	quit(0)
