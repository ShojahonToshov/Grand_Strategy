extends Node

signal resources_changed
signal time_changed
signal building_updated(state_id)

var is_paused: bool = true
var speed_idx: int = 0
var speed_hours_per_sec = [1, 3, 6, 12, 24]

var current_hours: int = 0
var fractional_hours: float = 0.0

var money: float = BalanceConfig.START_MONEY
var wood: float = BalanceConfig.START_WOOD
var gold: float = BalanceConfig.START_GOLD
var science: float = BalanceConfig.START_SCIENCE
var iron: float = BalanceConfig.START_IRON
var steel: float = BalanceConfig.START_STEEL
var oil: float = 0.0

var building_orders: Dictionary = {}
var completed_buildings: Dictionary = {}

var main_node: Node
var last_payout_day: int = 0

func _process(delta: float):
	if is_paused:
		return
		
	var speed = speed_hours_per_sec[speed_idx]
	fractional_hours += delta * speed
	
	# Limit iterations per frame to avoid lag spikes
	var steps = int(floor(fractional_hours))
	if steps > 24:
		# If extreme lag, still process, but limit to prevent freeze.
		# The prompt says: "Все пройденные сутки должны обрабатываться ровно один раз, в том числе при низком FPS и высокой скорости. Ограничивай работу за кадр без потери накопленных шагов."
		steps = min(steps, 48) # max 48 hours per frame
		
	if steps > 0:
		for i in range(steps):
			tick_hour()
		fractional_hours -= steps
		time_changed.emit()

func tick_hour():
	current_hours += 1
	
	# Check day boundary
	var current_day = current_hours / 24
	if current_day > last_payout_day:
		do_daily_payout()
		last_payout_day = current_day
		
	# Update building progress
	var to_complete = []
	for state_id in building_orders.keys():
		var order = building_orders[state_id]
		# Only progress if the state is still owned by FRA
		var st_owner = main_node.get_state_owner(state_id)
		if st_owner == "FRA":
			order.hours_left -= 1
			if order.hours_left <= 0:
				to_complete.append(state_id)
				
	for state_id in to_complete:
		var order = building_orders[state_id]
		building_orders.erase(state_id)
		completed_buildings[state_id] = {
			"type": order.type,
			"completed_hour": current_hours
		}
		building_updated.emit(state_id)

var tax_rate: float = BalanceConfig.DEFAULT_TAX_RATE

func do_daily_payout():
	var income_money = 0.0
	
	# Calculate tax income from population using owner_group classification
	if main_node and main_node.get("states_data") != null:
		var st_data = main_node.states_data
		for k in st_data.keys():
			var state_info = st_data[k]
			if state_info.has("owner") and state_info["owner"] == "FRA":
				var pop = state_info.get("population", 0)
				var o_group = state_info.get("owner_group", "DEFAULT")
				var base_tax = BalanceConfig.TAX_BASE_PER_CAPITA.get(o_group, BalanceConfig.TAX_BASE_PER_CAPITA["DEFAULT"])
				var daily_tax_per_person = (base_tax / 365.0) * (tax_rate / 100.0)
				income_money += pop * daily_tax_per_person
	
	var income_wood = 0
	var income_gold = 0
	var income_iron = 0
	var income_steel = 0
	var income_science = 0
	
	for state_id in completed_buildings.keys():
		var st_owner = main_node.get_state_owner(state_id)
		if st_owner != "FRA":
			continue # Stop payouts if not FRA
			
		var b = completed_buildings[state_id]
		# Must have worked full past day (24 hours prior to this 00:00 boundary)
		if b.completed_hour > (current_hours - 24):
			continue
			
		var res_type = main_node.resource_distribution.get_resource_for_state(state_id)
		if b.type == "LOGGING_CAMP" and res_type == ResourceDistribution.ResourceType.WOOD:
			income_wood += BalanceConfig.LOGGING_CAMP_PROD_WOOD
		elif b.type == "GOLD_MINE" and res_type == ResourceDistribution.ResourceType.GOLD:
			income_gold += BalanceConfig.GOLD_MINE_PROD_GOLD
		elif b.type == "IRON_MINE" and res_type == ResourceDistribution.ResourceType.IRON:
			income_iron += BalanceConfig.IRON_MINE_PROD_IRON
		elif b.type == "UNIVERSITY":
			income_science += BalanceConfig.UNIVERSITY_PROD_SCIENCE
			
	# Process Steel Mills after everything else to ensure we have iron first
	for state_id in completed_buildings.keys():
		var st_owner = main_node.get_state_owner(state_id)
		if st_owner != "FRA": continue
		
		var b = completed_buildings[state_id]
		if b.completed_hour > (current_hours - 24): continue
		
		if b.type == "STEEL_MILL":
			if (iron + income_iron) >= BalanceConfig.STEEL_MILL_CONS_IRON:
				income_iron -= BalanceConfig.STEEL_MILL_CONS_IRON
				income_steel += BalanceConfig.STEEL_MILL_PROD_STEEL
			
	# Apply incomes
	money += income_money
	wood += income_wood
	gold += income_gold
	iron += income_iron
	steel += income_steel
	science += income_science
	
	resources_changed.emit()

func get_date_string() -> String:
	# Starts 1936-01-01
	var total_days = current_hours / 24
	var year = 1936
	var month = 1
	var day = 1
	
	while true:
		var days_in_y = 366 if is_leap_year(year) else 365
		if total_days >= days_in_y:
			total_days -= days_in_y
			year += 1
		else:
			break
			
	var days_in_months = [31, 29 if is_leap_year(year) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	for m in range(12):
		if total_days >= days_in_months[m]:
			total_days -= days_in_months[m]
			month += 1
		else:
			break
			
	day += total_days
	var h = current_hours % 24
	return "%02d.%02d.%04d, %02d:00" % [day, month, year, h]

func get_completion_date_string(hours_from_now: int) -> String:
	var target_hours = current_hours + hours_from_now
	var total_days = target_hours / 24
	var year = 1936
	var month = 1
	var day = 1
	
	while true:
		var days_in_y = 366 if is_leap_year(year) else 365
		if total_days >= days_in_y:
			total_days -= days_in_y
			year += 1
		else:
			break
			
	var days_in_months = [31, 29 if is_leap_year(year) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	for m in range(12):
		if total_days >= days_in_months[m]:
			total_days -= days_in_months[m]
			month += 1
		else:
			break
			
	day += total_days
	return "%02d.%02d.%04d" % [day, month, year]

func is_leap_year(y: int) -> bool:
	if y % 400 == 0: return true
	if y % 100 == 0: return false
	return y % 4 == 0

func can_build(state_id: String, type: String) -> bool:
	if main_node.get_state_owner(state_id) != "FRA": return false
	if building_orders.has(state_id) or completed_buildings.has(state_id): return false
	
	if type == "LOGGING_CAMP":
		return money >= BalanceConfig.LOGGING_CAMP_COST_MONEY and wood >= BalanceConfig.LOGGING_CAMP_COST_WOOD and gold >= BalanceConfig.LOGGING_CAMP_COST_GOLD
	elif type == "GOLD_MINE":
		return money >= BalanceConfig.GOLD_MINE_COST_MONEY and wood >= BalanceConfig.GOLD_MINE_COST_WOOD and gold >= BalanceConfig.GOLD_MINE_COST_GOLD
	elif type == "IRON_MINE":
		return money >= BalanceConfig.IRON_MINE_COST_MONEY and wood >= BalanceConfig.IRON_MINE_COST_WOOD and gold >= BalanceConfig.IRON_MINE_COST_GOLD
	elif type == "STEEL_MILL":
		return money >= BalanceConfig.STEEL_MILL_COST_MONEY and wood >= BalanceConfig.STEEL_MILL_COST_WOOD and gold >= BalanceConfig.STEEL_MILL_COST_GOLD
	elif type == "UNIVERSITY":
		return money >= BalanceConfig.UNIVERSITY_COST_MONEY and wood >= BalanceConfig.UNIVERSITY_COST_WOOD and gold >= BalanceConfig.UNIVERSITY_COST_GOLD
	return false

func start_building(state_id: String, type: String):
	if not can_build(state_id, type): return
	
	var cost_m = 0
	var cost_w = 0
	var cost_g = 0
	var days = 0
	
	if type == "LOGGING_CAMP":
		cost_m = BalanceConfig.LOGGING_CAMP_COST_MONEY
		cost_w = BalanceConfig.LOGGING_CAMP_COST_WOOD
		cost_g = BalanceConfig.LOGGING_CAMP_COST_GOLD
		days = BalanceConfig.LOGGING_CAMP_DAYS
	elif type == "GOLD_MINE":
		cost_m = BalanceConfig.GOLD_MINE_COST_MONEY
		cost_w = BalanceConfig.GOLD_MINE_COST_WOOD
		cost_g = BalanceConfig.GOLD_MINE_COST_GOLD
		days = BalanceConfig.GOLD_MINE_DAYS
	elif type == "IRON_MINE":
		cost_m = BalanceConfig.IRON_MINE_COST_MONEY
		cost_w = BalanceConfig.IRON_MINE_COST_WOOD
		cost_g = BalanceConfig.IRON_MINE_COST_GOLD
		days = BalanceConfig.IRON_MINE_DAYS
	elif type == "STEEL_MILL":
		cost_m = BalanceConfig.STEEL_MILL_COST_MONEY
		cost_w = BalanceConfig.STEEL_MILL_COST_WOOD
		cost_g = BalanceConfig.STEEL_MILL_COST_GOLD
		days = BalanceConfig.STEEL_MILL_DAYS
	elif type == "UNIVERSITY":
		cost_m = BalanceConfig.UNIVERSITY_COST_MONEY
		cost_w = BalanceConfig.UNIVERSITY_COST_WOOD
		cost_g = BalanceConfig.UNIVERSITY_COST_GOLD
		days = BalanceConfig.UNIVERSITY_DAYS
		
	money -= cost_m
	wood -= cost_w
	gold -= cost_g
	
	building_orders[state_id] = {
		"type": type,
		"hours_left": days * 24,
		"total_hours": days * 24,
		"cost_m": cost_m,
		"cost_w": cost_w,
		"cost_g": cost_g
	}
	resources_changed.emit()
	building_updated.emit(state_id)

func cancel_building(state_id: String):
	if main_node.get_state_owner(state_id) != "FRA": return
	if not building_orders.has(state_id): return
	
	var order = building_orders[state_id]
	var progress = 1.0 - (float(order.hours_left) / float(order.total_hours))
	
	money += int(floor(order.cost_m * (1.0 - progress)))
	wood += int(floor(order.cost_w * (1.0 - progress)))
	gold += int(floor(order.cost_g * (1.0 - progress)))
	
	building_orders.erase(state_id)
	resources_changed.emit()
	building_updated.emit(state_id)

func demolish_building(state_id: String):
	if main_node.get_state_owner(state_id) != "FRA": return
	if completed_buildings.has(state_id):
		completed_buildings.erase(state_id)
		building_updated.emit(state_id)
