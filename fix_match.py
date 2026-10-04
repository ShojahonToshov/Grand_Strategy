import re

with open('StateInfoPanel.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

for i in range(len(lines)):
    if '"WEAVER_WORKSHOP":' in lines[i] or '"FARM":' in lines[i] or '"POWDER_MILL":' in lines[i]:
        # They should have exactly 2 tabs
        lines[i] = re.sub(r'^\s+', '\t\t', lines[i])
    elif ('b_name = ' in lines[i] or 'cost_m = ' in lines[i] or 'cost_w = ' in lines[i] or 'days = ' in lines[i] or 'prod = ' in lines[i] or 'prod_name = ' in lines[i]) and ('BalanceConfig.WEAVER' in lines[i] or 'BalanceConfig.FARM' in lines[i] or 'BalanceConfig.POWDER' in lines[i] or 'Мануфактура' in lines[i] or 'Ферма' in lines[i] or 'Пороховой' in lines[i] or 'Парусина' in lines[i] or 'Провизия' in lines[i] or 'Порох' in lines[i]):
        
        # Check if it's inside the match block (which has exactly 3 tabs for contents)
        # We can just check if it's not the 'elif' lines which have 2 tabs
        if not 'elif' in lines[i] and not 'if ' in lines[i]:
            lines[i] = re.sub(r'^\s+', '\t\t\t', lines[i])

with open('StateInfoPanel.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('Fixed match block indentation.')
