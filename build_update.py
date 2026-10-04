import re

# 1. Update BalanceConfig.gd
with open('BalanceConfig.gd', 'r', encoding='utf-8') as f:
    bc = f.read()

if 'FARM_COST_MONEY' not in bc:
    bc += '''
const FARM_COST_MONEY = 100000.0
const FARM_COST_WOOD = 50.0
const FARM_DAYS = 30
const FARM_PROD_PROVISIONS = 50.0

const POWDER_MILL_COST_MONEY = 800000.0
const POWDER_MILL_COST_WOOD = 150.0
const POWDER_MILL_DAYS = 90
const POWDER_MILL_PROD_GUNPOWDER = 5.0
'''
    with open('BalanceConfig.gd', 'w', encoding='utf-8') as f:
        f.write(bc)

# 2. Update GameSession.gd
with open('GameSession.gd', 'r', encoding='utf-8') as f:
    gs = f.read()

if 'b.type == "FARM"' not in gs:
    gs = gs.replace(
        'elif b.type == "UNIVERSITY":\n\t\t\tincome_science += BalanceConfig.UNIVERSITY_PROD_SCIENCE',
        'elif b.type == "UNIVERSITY":\n\t\t\tincome_science += BalanceConfig.UNIVERSITY_PROD_SCIENCE\n\t\telif b.type == "FARM":\n\t\t\tincome_provisions += BalanceConfig.FARM_PROD_PROVISIONS\n\t\telif b.type == "POWDER_MILL":\n\t\t\tincome_gunpowder += BalanceConfig.POWDER_MILL_PROD_GUNPOWDER'
    )
    with open('GameSession.gd', 'w', encoding='utf-8') as f:
        f.write(gs)

print('Done Step 1 and 2.')
