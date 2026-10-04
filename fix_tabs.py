with open('StateInfoPanel.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

for i in range(len(lines)):
    line = lines[i]
    if 'b_name = "Мануфактура Парусины"' in line and 'elif b.type ==' in line:
        lines[i] = '\t\t\telif b.type == "WEAVER_WORKSHOP": b_name = "Мануфактура Парусины"\n'
    elif 'b_name = "Ферма Провизии"' in line and 'elif b.type ==' in line:
        lines[i] = '\t\t\telif b.type == "FARM": b_name = "Ферма Провизии"\n'
    elif 'b_name = "Пороховой Завод"' in line and 'elif b.type ==' in line:
        lines[i] = '\t\t\telif b.type == "POWDER_MILL": b_name = "Пороховой Завод"\n'
        
    elif 'b_name = "Мануфактура Парусины"' in line and 'elif order.type ==' in line:
        lines[i] = '\t\t\telif order.type == "WEAVER_WORKSHOP": b_name = "Мануфактура Парусины"\n'
    elif 'b_name = "Ферма Провизии"' in line and 'elif order.type ==' in line:
        lines[i] = '\t\t\telif order.type == "FARM": b_name = "Ферма Провизии"\n'
    elif 'b_name = "Пороховой Завод"' in line and 'elif order.type ==' in line:
        lines[i] = '\t\t\telif order.type == "POWDER_MILL": b_name = "Пороховой Завод"\n'

    elif 'prod_val = BalanceConfig.WEAVER_WORKSHOP_PROD_CANVAS' in line:
        lines[i] = '\t\t\telif b.type == "WEAVER_WORKSHOP": prod_val = BalanceConfig.WEAVER_WORKSHOP_PROD_CANVAS\n'
    elif 'prod_val = BalanceConfig.FARM_PROD_PROVISIONS' in line:
        lines[i] = '\t\t\telif b.type == "FARM": prod_val = BalanceConfig.FARM_PROD_PROVISIONS\n'
    elif 'prod_val = BalanceConfig.POWDER_MILL_PROD_GUNPOWDER' in line:
        lines[i] = '\t\t\telif b.type == "POWDER_MILL": prod_val = BalanceConfig.POWDER_MILL_PROD_GUNPOWDER\n'

with open('StateInfoPanel.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('Fixed tabs to 3.')
