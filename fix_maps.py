import re

files = ['PoliticalMapLayer.gd', 'DiplomacyMap.gd', 'ResourceMap.gd', 'HighlightSystem.gd']

def process_file(f):
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()
    
    # We will provide a unified function to draw safely in each file at the top or bottom, 
    # but since they are scripts we can just inject a helper function or inline it.
    
    helper = '''
func _draw_poly_safe(p: PackedVector2Array, color: Color, node: CanvasItem = self):
	var idx = Geometry2D.triangulate_polygon(p)
	if idx.size() == 0:
		var cleaned = Geometry2D.offset_polygon(p, 0.1, Geometry2D.JOIN_MITER)
		for c in cleaned:
			var c_idx = Geometry2D.triangulate_polygon(c)
			if c_idx.size() > 0:
				var cols = PackedColorArray()
				cols.resize(c.size())
				cols.fill(color)
				RenderingServer.canvas_item_add_triangle_array(node.get_canvas_item(), c_idx, c, cols)
	else:
		var cols = PackedColorArray()
		cols.resize(p.size())
		cols.fill(color)
		RenderingServer.canvas_item_add_triangle_array(node.get_canvas_item(), idx, p, cols)
'''
    
    if '_draw_poly_safe' not in content:
        content += helper
        
    # Replace the inner draw loops
    if f == 'PoliticalMapLayer.gd':
        content = re.sub(r'for p in polys:\s+draw_colored_polygon\(p, color\)', 
                         'for p in polys:\n\t\t\t_draw_poly_safe(p, color)', content)
    
    if f == 'DiplomacyMap.gd' or f == 'ResourceMap.gd':
        # They both have this structure:
        # for p in state_polys[state_id]:
        #    if Geometry2D.triangulate_polygon(p).size() == 0: ... draw_colored_polygon ...
        #    else: draw_colored_polygon ...
        
        # We can just replace the whole block starting from or p in state_polys[state_id]:
        pattern = r'for p in state_polys\[state_id\]:[\s\S]+?(?=\t\t#|\t\tfor|\Z|func)'
        
        replacement = 'for p in state_polys[state_id]:\n\t\t\t_draw_poly_safe(p, c_arr[0])\n\n'
        content = re.sub(pattern, replacement, content)

    if f == 'HighlightSystem.gd':
        pattern = r'for p in highlight_fill_polys:[\s\S]+?(?=\tfunc|\Z)'
        replacement = 'for p in highlight_fill_polys:\n\t\t_draw_poly_safe(p, fill_color, node)\n\n'
        content = re.sub(pattern, replacement, content)
        
    with open(f, 'w', encoding='utf-8') as file:
        file.write(content)

for f in files:
    process_file(f)
