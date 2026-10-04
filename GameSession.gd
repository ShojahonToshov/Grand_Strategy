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
var mobilization_orders: Dictionary = {}
var armies: Array = []

var diplomacy_relations: Dictionary = {} # tag -> { tag2: "WAR" / "PEACE" }

func get_relation(tag1: String, tag2: String) -> String:
	if tag1 == tag2: return "OWN"
	if diplomacy_relations.has(tag1) and diplomacy_relations[tag1].has(tag2):
		return diplomacy_relations[tag1][tag2]
	return "PEACE"

func declare_war(attacker: String, defender: String):
	if not diplomacy_relations.has(attacker): diplomacy_relations[attacker] = {}
	if not diplomacy_relations.has(defender): diplomacy_relations[defender] = {}
	diplomacy_relations[attacker][defender] = "WAR"
	diplomacy_relations[defender][attacker] = "WAR"
	# emit signal if needed, e.g., diplomacy_changed
	print("WAR DECLARED: ", attacker, " vs ", defender)

func make_peace(attacker: String, defender: String):
	if diplomacy_relations.has(attacker) and diplomacy_relations[attacker].has(defender):
		diplomacy_relations[attacker][defender] = "PEACE"
	if diplomacy_relations.has(defender) and diplomacy_relations[defender].has(attacker):
		diplomacy_relations[defender][attacker] = "PEACE"
	print("PEACE MADE: ", attacker, " and ", defender)
	
	if main_node and main_node.get("active_armies") != null:
		for army in main_node.active_armies:
			if army.owner_tag == attacker or army.owner_tag == defender:
				if army.target_army and (army.target_army.owner_tag == attacker or army.target_army.owner_tag == defender):
					army.target_army = null
				
				army.in_combat = false
				
				var current_sid = army.state_id
				var current_owner = main_node.get_state_owner(current_sid)
				if current_owner != army.owner_tag and current_owner != "None" and current_owner != "":
					# Stranded in foreign territory - EXILE RETURN!
					if main_node.has_method("find_path_to_home"):
						# Pass current_owner so they can only walk through the country they were just fighting.
						var escape_path = main_node.find_path_to_home(current_sid, army.owner_tag, current_owner)
						if escape_path.size() > 0:
							army.path = escape_path
							army.target_pos = escape_path.pop_front()
							army.is_moving = true
							print("EXILE: Routing army home for ", army.owner_tag)
						else:
							army.path.clear()
							army.target_pos = army.position
							army.is_moving = false
					else:
						army.path.clear()
						army.target_pos = army.position
						army.is_moving = false
				else:
					army.path.clear()
					army.target_pos = army.position
					army.is_moving = false

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
	
	# Army Exile Attrition Logic
	if main_node and main_node.get("active_armies") != null:
		for army in main_node.active_armies:
			if army.get("is_dying") and army.is_dying: continue
			
			var current_sid = army.state_id
			var current_owner = main_node.get_state_owner(current_sid)
			
			# If on water or own territory, reset exile. 
			if current_owner == army.owner_tag or current_owner == "None" or current_owner == "":
				if "exile_hours" in army: army.exile_hours = 0
			else:
				var rel = get_relation(army.owner_tag, current_owner)
				# If at war or allied, they are supplied. If peace, they are in exile.
				if rel == "PEACE":
					if "exile_hours" in army:
						army.exile_hours += 1
						
						# Grace period of 14 days = 336 hours
						if army.exile_hours > 336:
							# Suffer 0.5% attrition per hour (about 12% per day)
							var attrition = max(1, int(army.population * 0.005))
							if army.has_method("apply_attrition"):
								army.apply_attrition(attrition)
				else:
					if "exile_hours" in army: army.exile_hours = 0
	
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

	# Update mobilization progress
	var mob_to_complete = []
	for state_id in mobilization_orders.keys():
		var order = mobilization_orders[state_id]
		var st_owner = main_node.get_state_owner(state_id)
		if st_owner == "FRA":
			order.hours_left -= 1
			if order.hours_left <= 0:
				mob_to_complete.append(state_id)
				
	for state_id in mob_to_complete:
		var order = mobilization_orders[state_id]
		mobilization_orders.erase(state_id)
		if main_node.has_method("spawn_army"):
			main_node.spawn_army(state_id, order.population, "FRA")
		building_updated.emit(state_id)

var tax_rate: float = BalanceConfig.DEFAULT_TAX_RATE

func do_daily_payout():
	var income_money: float = 0.0
	
	# Calculate tax income from population using owner_group classification
	if main_node and main_node.get("states_data") != null:
		var st_data = main_node.states_data
		if typeof(st_data) == TYPE_DICTIONARY:
			for k in st_data.keys():
				var state_info = st_data[k]
				if typeof(state_info) == TYPE_DICTIONARY and state_info.get("owner", "") == "FRA":
					var pop: float = float(state_info.get("population", 0))
					var o_group: String = state_info.get("owner_group", "DEFAULT")
					var base_tax: float = BalanceConfig.TAX_BASE_PER_CAPITA.get(o_group, BalanceConfig.TAX_BASE_PER_CAPITA["DEFAULT"])
					var daily_tax_per_person: float = (base_tax / 365.0) * (tax_rate / 100.0)
					income_money += pop * daily_tax_per_person
	
	var income_wood: float = 0.0
	var income_gold: float = 0.0
	var income_iron: float = 0.0
	var income_steel: float = 0.0
	var income_science: float = 0.0
	var income_oil: float = 0.0
	
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
		elif b.type == "OIL_RIG" and res_type == ResourceDistribution.ResourceType.OIL:
			income_oil += BalanceConfig.OIL_RIG_PROD_OIL
			
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
	oil += income_oil
	
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
	elif type == "OIL_RIG":
		return money >= BalanceConfig.OIL_RIG_COST_MONEY and wood >= BalanceConfig.OIL_RIG_COST_WOOD and gold >= BalanceConfig.OIL_RIG_COST_GOLD
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
	elif type == "OIL_RIG":
		cost_m = BalanceConfig.OIL_RIG_COST_MONEY
		cost_w = BalanceConfig.OIL_RIG_COST_WOOD
		cost_g = BalanceConfig.OIL_RIG_COST_GOLD
		days = BalanceConfig.OIL_RIG_DAYS
		
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

func can_mobilize(state_id: String) -> bool:
	if main_node.get_state_owner(state_id) != "FRA": return false
	if mobilization_orders.has(state_id): return false
	
	if main_node.get("states_data") and main_node.states_data.has(state_id):
		var pop = main_node.states_data[state_id].get("population", 0)
		if pop >= 1000: # Min population to mobilize
			return true
	return false

func start_mobilization(state_id: String):
	if not can_mobilize(state_id): return
	
	var pop = main_node.states_data[state_id].get("population", 0)
	var mobilized_pop = int(pop * 0.05) # 5%
	main_node.states_data[state_id]["population"] -= mobilized_pop
	
	mobilization_orders[state_id] = {
		"hours_left": 48, # 2 days
		"total_hours": 48,
		"population": mobilized_pop
	}
	resources_changed.emit()
	building_updated.emit(state_id)
