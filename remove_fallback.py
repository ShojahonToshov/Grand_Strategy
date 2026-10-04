import re

files = ['PoliticalMapLayer.gd', 'DiplomacyMap.gd', 'ResourceMap.gd', 'HighlightSystem.gd']

for f in files:
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()
    
    # Remove the else block and node.draw_colored_polygon
    content = re.sub(r'else:\s*# If everything fails[\s\S]+?node\.draw_colored_polygon\(c, color\)', 'pass', content)
    
    with open(f, 'w', encoding='utf-8') as file:
        file.write(content)
