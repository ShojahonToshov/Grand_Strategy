extends SceneTree

func _init():
	var json_res = JSON.new()
	var file = FileAccess.open("res://state_polygons.json", FileAccess.READ)
	json_res.parse(file.get_as_text())
	var data = json_res.data
	
	var streak_found = false
	for sid in data.keys():
		if not data[sid].has("lod0"): continue
		for p_raw in data[sid]["lod0"]:
			var p = PackedVector2Array()
			for pt in p_raw: p.append(Vector2(pt[0], pt[1]))
			
			var idx = Geometry2D.triangulate_polygon(p)
			if idx.size() == 0:
				var cleaned = Geometry2D.offset_polygon(p, 0.0, Geometry2D.JOIN_SQUARE)
				if cleaned.size() == 0:
					var p_rev = p.duplicate()
					p_rev.reverse()
					cleaned = Geometry2D.offset_polygon(p_rev, 0.0, Geometry2D.JOIN_SQUARE)
				for c in cleaned:
					for pt in c:
						if pt.x < -10000 or pt.x > 10000 or pt.y < -10000 or pt.y > 10000:
							print("WILD POINT IN OFFSET! ", pt)
							streak_found = true
	if not streak_found:
		print("No wild points found.")
	quit()
