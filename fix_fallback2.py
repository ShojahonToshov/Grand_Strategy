import re

files = ['PoliticalMapLayer.gd', 'DiplomacyMap.gd', 'ResourceMap.gd', 'HighlightSystem.gd']

new_func = '''func _draw_poly_safe(p: PackedVector2Array, color: Color, node: CanvasItem = self):
	var idx = Geometry2D.triangulate_polygon(p)
	if idx.size() > 0:
		var cols = PackedColorArray()
		cols.resize(p.size())
		cols.fill(color)
		RenderingServer.canvas_item_add_triangle_array(node.get_canvas_item(), idx, p, cols)
		return

	# Fallback 1: Clean the polygon with 0 delta (removes self-intersections without shrinking)
	var cleaned = Geometry2D.offset_polygon(p, 0.0, Geometry2D.JOIN_MITER)
	if cleaned.size() == 0:
		var p_rev = p.duplicate()
		p_rev.reverse()
		cleaned = Geometry2D.offset_polygon(p_rev, 0.0, Geometry2D.JOIN_MITER)
		
	var drew_anything = false
	for c in cleaned:
		var c_idx = Geometry2D.triangulate_polygon(c)
		if c_idx.size() > 0:
			var cols = PackedColorArray()
			cols.resize(c.size())
			cols.fill(color)
			RenderingServer.canvas_item_add_triangle_array(node.get_canvas_item(), c_idx, c, cols)
			drew_anything = true
			
	if drew_anything:
		return
		
	# Fallback 2: Expand slightly (merges very close vertices that might be causing EarClipping failure)
	var cleaned_01 = Geometry2D.offset_polygon(p, 0.1, Geometry2D.JOIN_MITER)
	if cleaned_01.size() == 0:
		var p_rev = p.duplicate()
		p_rev.reverse()
		cleaned_01 = Geometry2D.offset_polygon(p_rev, 0.1, Geometry2D.JOIN_MITER)
		
	for c in cleaned_01:
		var c_idx = Geometry2D.triangulate_polygon(c)
		if c_idx.size() > 0:
			var cols = PackedColorArray()
			cols.resize(c.size())
			cols.fill(color)
			RenderingServer.canvas_item_add_triangle_array(node.get_canvas_item(), c_idx, c, cols)
'''

for f in files:
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()
    
    # Replace the old _draw_poly_safe block
    pattern = r'func _draw_poly_safe\([\s\S]+'
    content = re.sub(pattern, new_func.strip() + '\n', content)
    
    with open(f, 'w', encoding='utf-8') as file:
        file.write(content)
