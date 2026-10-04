import re

with open('StateInfoPanel.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix completed building names
content = re.sub(
    r'elif b\.type == "WEAVER_WORKSHOP": b_name = "Мануфактура Парусины"',
    r'elif b.type == "WEAVER_WORKSHOP": b_name = "Мануфактура Парусины"\n\t\telif b.type == "FARM": b_name = "Ферма Провизии"\n\t\telif b.type == "POWDER_MILL": b_name = "Пороховой Завод"',
    content
)

# Fix in-progress building names
content = re.sub(
    r'elif order\.type == "WEAVER_WORKSHOP": b_name = "Мануфактура Парусины"',
    r'elif order.type == "WEAVER_WORKSHOP": b_name = "Мануфактура Парусины"\n\t\t\telif order.type == "FARM": b_name = "Ферма Провизии"\n\t\t\telif order.type == "POWDER_MILL": b_name = "Пороховой Завод"',
    content
)

# Fix is_match 
content = content.replace(
    'or b.type == "BRONZE_FOUNDRY" or b.type == "UNIVERSITY"',
    'or b.type == "BRONZE_FOUNDRY" or b.type == "UNIVERSITY" or b.type == "FARM" or b.type == "POWDER_MILL"'
)

# Fix prod_val for completed buildings
content = re.sub(
    r'elif b\.type == "WEAVER_WORKSHOP": prod_val = BalanceConfig\.WEAVER_WORKSHOP_PROD_CANVAS',
    r'elif b.type == "WEAVER_WORKSHOP": prod_val = BalanceConfig.WEAVER_WORKSHOP_PROD_CANVAS\n\t\t\telif b.type == "FARM": prod_val = BalanceConfig.FARM_PROD_PROVISIONS\n\t\t\telif b.type == "POWDER_MILL": prod_val = BalanceConfig.POWDER_MILL_PROD_GUNPOWDER',
    content
)

# Write it back
with open('StateInfoPanel.gd', 'w', encoding='utf-8') as f:
    f.write(content)

print("Done")
