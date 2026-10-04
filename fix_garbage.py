import re

for f in ['DiplomacyMap.gd', 'ResourceMap.gd']:
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()
    
    # Remove the garbage lines that were left behind
    content = re.sub(r'\t\tfor c in cleaned:[\s\S]+?draw_colored_polygon\(p, c_arr\[0\]\)\n', '', content)
    
    with open(f, 'w', encoding='utf-8') as file:
        file.write(content)
