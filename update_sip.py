import re

with open('StateInfoPanel.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix translations
content = content.replace("Нефтяная Вышка", "Мануфактура Парусины")
content = content.replace("Нефть", "Парусина")
content = content.replace("Сталелитейный Завод", "Бронзолитейный Завод")
content = content.replace("Сталь", "Бронза")

# Add the new buildings to the _show_build_menu modal
card_insert = """	_create_build_card_modal("WEAVER_WORKSHOP", state_id, res_type == 4, cards_box, session, modal_layer)
	_create_build_card_modal("FARM", state_id, true, cards_box, session, modal_layer)
	_create_build_card_modal("POWDER_MILL", state_id, true, cards_box, session, modal_layer)"""
content = content.replace('_create_build_card_modal("WEAVER_WORKSHOP", state_id, res_type == 4, cards_box, session, modal_layer)', card_insert)

# Add the match cases
match_insert = """		"WEAVER_WORKSHOP":
			b_name = "Мануфактура Парусины"
			cost_m = BalanceConfig.WEAVER_WORKSHOP_COST_MONEY
			cost_w = BalanceConfig.WEAVER_WORKSHOP_COST_WOOD
			days = BalanceConfig.WEAVER_WORKSHOP_DAYS
			prod = BalanceConfig.WEAVER_WORKSHOP_PROD_CANVAS
			prod_name = "Парусина"
		"FARM":
			b_name = "Ферма Провизии"
			cost_m = BalanceConfig.FARM_COST_MONEY
			cost_w = BalanceConfig.FARM_COST_WOOD
			days = BalanceConfig.FARM_DAYS
			prod = BalanceConfig.FARM_PROD_PROVISIONS
			prod_name = "Провизия"
		"POWDER_MILL":
			b_name = "Пороховой Завод"
			cost_m = BalanceConfig.POWDER_MILL_COST_MONEY
			cost_w = BalanceConfig.POWDER_MILL_COST_WOOD
			days = BalanceConfig.POWDER_MILL_DAYS
			prod = BalanceConfig.POWDER_MILL_PROD_GUNPOWDER
			prod_name = "Порох" """

content = re.sub(r'\"WEAVER_WORKSHOP\":\s+b_name = \"[^\"]+\"\s+cost_m = BalanceConfig.WEAVER_WORKSHOP_COST_MONEY\s+cost_w = BalanceConfig.WEAVER_WORKSHOP_COST_WOOD\s+days = BalanceConfig.WEAVER_WORKSHOP_DAYS\s+prod = BalanceConfig.WEAVER_WORKSHOP_PROD_CANVAS\s+prod_name = \"[^\"]+\"', match_insert, content)

# Check if there are any old cyrillic mentions in the other places like Update Labels
# The user wants to ensure everything is correct.

# Also add them to the checking loop `var is_match = ...` just in case, but farms and powder mills can be built anywhere (like university), so `true` was passed.

with open('StateInfoPanel.gd', 'w', encoding='utf-8') as f:
    f.write(content)

print("StateInfoPanel updated")
