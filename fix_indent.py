import re

with open('StateInfoPanel.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

for i in range(len(lines)):
    # Fix order type
    if 'elif order.type == "FARM":' in lines[i] or 'elif order.type == "POWDER_MILL":' in lines[i]:
        lines[i] = re.sub(r'^\s+elif', '\t\telif', lines[i])
        
    # Fix b type (completed building titles)
    if 'elif b.type == "FARM": b_name =' in lines[i] or 'elif b.type == "POWDER_MILL": b_name =' in lines[i]:
        lines[i] = re.sub(r'^\s+elif', '\t\telif', lines[i])

with open('StateInfoPanel.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('Fixed indentation.')
