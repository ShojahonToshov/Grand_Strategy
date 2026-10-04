import re

with open('HighlightSystem.gd', 'r', encoding='utf-8') as file:
    content = file.read()

pattern = r'for p in highlight_fill_polys:[\s\S]+?(?=func _draw_border)'
replacement = 'for p in highlight_fill_polys:\n\t\t_draw_poly_safe(p, fill_color, node)\n\n'
content = re.sub(pattern, replacement, content)

new_func = '''func _draw_poly_safe(p: PackedVector2Array, color: Color, node: CanvasItem = self):
	var idx = Geometry2D.triangulate_polygon(p)
	if idx.size() > 0:
		var cols = PackedColorArray()
		cols.resize(p.size())
		cols.fill(color)
		RenderingServer.canvas_item_add_triangle_array(node.get_canvas_item(), idx, p, cols)
		return

	# Fallback: Clean the polygon with 0 delta (removes self-intersections without shrinking)
	var cleaned = Geometry2D.offset_polygon(p, 0.0, Geometry2D.JOIN_MITER)
	if cleaned.size() == 0:
		var p_rev = p.duplicate()
		p_rev.reverse()
		cleaned = Geometry2D.offset_polygon(p_rev, 0.0, Geometry2D.JOIN_MITER)
		
	for c in cleaned:
		var c_idx = Geometry2D.triangulate_polygon(c)
		if c_idx.size() > 0:
			var cols = PackedColorArray()
			cols.resize(c.size())
			cols.fill(color)
			RenderingServer.canvas_item_add_triangle_array(node.get_canvas_item(), c_idx, c, cols)
		else:
			# If everything fails, use Godot's internal draw_colored_polygon 
			# It might drop it if it's too broken, but we tried our best.
			node.draw_colored_polygon(c, color)
'''

content += '\n' + new_func

with open('HighlightSystem.gd', 'w', encoding='utf-8') as file:
    file.write(content)
