extends SceneTree

var passed_count = 0
var failed_count = 0
var skipped_count = 0
var checks_total = 0

class MockMain extends Node:
	var states_data = {}
	var owners = {}
	var resources = {}
	var resource_distribution: Object
	
	func get_state_owner(id: String) -> String:
		return owners.get(id, "None")

class MockResourceDist extends Node:
	var mock_main: Node
	func get_resource_for_state(id: String) -> int:
		return mock_main.resources.get(id, 0)

func run_test(test_name: String, callable: Callable):
	print("\n--- Running: " + test_name + " ---")
	var result = callable.call()
	if result == true:
		print("[PASS] " + test_name)
		passed_count += 1
	else:
		print("[FAIL] " + test_name)
		failed_count += 1
		
func check_eq(actual, expected, msg: String) -> bool:
	checks_total += 1
	if typeof(actual) == TYPE_FLOAT and typeof(expected) == TYPE_FLOAT:
		if abs(actual - expected) > 0.001:
			print("  -> ERROR: " + msg + " | Expected: " + str(expected) + ", Actual: " + str(actual))
			return false
	else:
		if actual != expected:
			print("  -> ERROR: " + msg + " | Expected: " + str(expected) + ", Actual: " + str(actual))
			return false
	return true

func create_test_session() -> Node:
	var main = MockMain.new()
	var dist = MockResourceDist.new()
	dist.mock_main = main
	main.resource_distribution = dist
	
	main.states_data = {
		"FRA_wood": {"owner": "FRA", "population": 1000},
		"FRA_gold": {"owner": "FRA", "population": 1000},
		"FRA_iron": {"owner": "FRA", "population": 1000},
		"FRA_none": {"owner": "FRA", "population": 1000},
		"FRA_steel": {"owner": "FRA", "population": 1000},
		"FRA_uni": {"owner": "FRA", "population": 1000},
		"GER_wood": {"owner": "GER", "population": 1000},
		"FRA_iron2": {"owner": "FRA", "population": 1000},
		"FRA_steel2": {"owner": "FRA", "population": 1000}
	}
	for k in main.states_data.keys():
		main.owners[k] = main.states_data[k]["owner"]
		
	main.resources["FRA_wood"] = 2 
	main.resources["GER_wood"] = 2 
	main.resources["FRA_gold"] = 1 
	main.resources["FRA_iron"] = 3 
	main.resources["FRA_iron2"] = 3 
	main.resources["FRA_steel"] = 0 
	main.resources["FRA_steel2"] = 0 
	main.resources["FRA_uni"] = 0 
	main.resources["FRA_none"] = 0 
	
	var session = load("res://GameSession.gd").new()
	session.main_node = main
	return session

func _init():
	print("Starting GameSession tests...")
	
	var BalanceConfig = load("res://BalanceConfig.gd")
	
	run_test("Initial state", func():
		var session = create_test_session()
		var ok = true
		ok = check_eq(session.money, BalanceConfig.START_MONEY, "Start money") and ok
		ok = check_eq(session.wood, BalanceConfig.START_WOOD, "Start wood") and ok
		ok = check_eq(session.gold, BalanceConfig.START_GOLD, "Start gold") and ok
		ok = check_eq(session.iron, BalanceConfig.START_IRON, "Start iron") and ok
		ok = check_eq(session.steel, BalanceConfig.START_STEEL, "Start steel") and ok
		ok = check_eq(session.science, BalanceConfig.START_SCIENCE, "Start science") and ok
		ok = check_eq(session.is_paused, true, "Start paused") and ok
		ok = check_eq(session.get_date_string(), "01.01.1936, 00:00", "Start date") and ok
		
		session.main_node.resource_distribution.free()
		session.main_node.free(); session.free()
		return ok
	)
	
	run_test("Building - foreign region rejected", func():
		var session = create_test_session()
		var ok = true
		ok = check_eq(session.can_build("GER_wood", "LOGGING_CAMP"), false, "Cannot build in GER") and ok
		session.start_building("GER_wood", "LOGGING_CAMP")
		ok = check_eq(session.building_orders.has("GER_wood"), false, "Order shouldn't exist") and ok
		
		session.main_node.resource_distribution.free()
		session.main_node.free(); session.free()
		return ok
	)
	
	run_test("Building - lacks resources", func():
		var session = create_test_session()
		var ok = true
		# Gold mine costs wood and money. Iron mine too. Steel mill too.
		var cost_m = BalanceConfig.GOLD_MINE_COST_MONEY
		var cost_w = BalanceConfig.GOLD_MINE_COST_WOOD
		var cost_g = BalanceConfig.GOLD_MINE_COST_GOLD
		
		# Test Money shortage
		session.money = cost_m - 1
		session.wood = cost_w
		session.gold = cost_g
		ok = check_eq(session.can_build("FRA_gold", "GOLD_MINE"), false, "Cannot build without money") and ok
		session.start_building("FRA_gold", "GOLD_MINE")
		ok = check_eq(session.building_orders.has("FRA_gold"), false, "Order not created (no money)") and ok
		ok = check_eq(session.money, cost_m - 1, "Money unchanged (no money)") and ok
		ok = check_eq(session.wood, cost_w, "Wood unchanged (no money)") and ok
		
		# Test Wood shortage
		session.money = cost_m
		session.wood = cost_w - 1
		session.gold = cost_g
		ok = check_eq(session.can_build("FRA_gold", "GOLD_MINE"), false, "Cannot build without wood") and ok
		session.start_building("FRA_gold", "GOLD_MINE")
		ok = check_eq(session.building_orders.has("FRA_gold"), false, "Order not created (no wood)") and ok
		ok = check_eq(session.money, cost_m, "Money unchanged (no wood)") and ok
		ok = check_eq(session.wood, cost_w - 1, "Wood unchanged (no wood)") and ok
		
		# Test Gold shortage (Currently no building requires gold, so check if not applicable)
		if cost_g > 0:
			session.money = cost_m
			session.wood = cost_w
			session.gold = cost_g - 1
			ok = check_eq(session.can_build("FRA_gold", "GOLD_MINE"), false, "Cannot build without gold") and ok
		else:
			print("  -> Info: Gold shortage check not applicable (cost is 0)")
			
		# Test Iron/Steel shortage (not applicable for construction per BalanceConfig, but checking if there's any building that uses it)
		# No building uses iron or steel for construction right now.
		print("  -> Info: Iron/Steel shortage check not applicable")
			
		
		session.main_node.resource_distribution.free()
		session.main_node.free(); session.free()
		return ok
	)
	
	run_test("Building - occupy slot and consume resources once", func():
		var session = create_test_session()
		var ok = true
		var cost_m = BalanceConfig.GOLD_MINE_COST_MONEY
		var cost_w = BalanceConfig.GOLD_MINE_COST_WOOD
		session.money = cost_m * 2 
		session.wood = cost_w * 2
		var start_m = session.money
		var start_w = session.wood
		
		ok = check_eq(session.can_build("FRA_gold", "GOLD_MINE"), true, "Should build") and ok
		session.start_building("FRA_gold", "GOLD_MINE")
		ok = check_eq(session.money, start_m - cost_m, "Money deducted") and ok
		ok = check_eq(session.wood, start_w - cost_w, "Wood deducted") and ok
		ok = check_eq(session.can_build("FRA_gold", "GOLD_MINE"), false, "Slot occupied by pending order") and ok
		
		# Double click simulation
		session.start_building("FRA_gold", "GOLD_MINE")
		ok = check_eq(session.money, start_m - cost_m, "Money NOT deducted twice") and ok
		ok = check_eq(session.wood, start_w - cost_w, "Wood NOT deducted twice") and ok
		
		# Now check completed building occupying slot
		session.building_orders.erase("FRA_gold")
		session.completed_buildings["FRA_gold"] = {"type": "GOLD_MINE", "completed_hour": 0}
		ok = check_eq(session.can_build("FRA_gold", "GOLD_MINE"), false, "Slot occupied by completed building") and ok
		
		
		session.main_node.resource_distribution.free()
		session.main_node.free(); session.free()
		return ok
	)
	
	run_test("Building - cancel (immediate and partial)", func():
		var session = create_test_session()
		var ok = true
		session.tax_rate = 0.0 # Disable taxes for exact math
		
		var cost_m = BalanceConfig.GOLD_MINE_COST_MONEY
		var cost_w = BalanceConfig.GOLD_MINE_COST_WOOD
		session.money = cost_m
		session.wood = cost_w
		
		session.start_building("FRA_gold", "GOLD_MINE")
		session.cancel_building("FRA_gold")
		ok = check_eq(session.money, cost_m, "Full money refund on immediate cancel") and ok
		ok = check_eq(session.wood, cost_w, "Full wood refund on immediate cancel") and ok
		
		# Partial cancel (half time)
		session.start_building("FRA_gold", "GOLD_MINE")
		session.is_paused = false
		session.speed_idx = 0 
		var total_hours = BalanceConfig.GOLD_MINE_DAYS * 24
		var half_hours = total_hours / 2
		
		for i in range(half_hours / 10): 
			session._process(10.0)
		session.cancel_building("FRA_gold")
		
		var exp_m_refund = floor(cost_m * 0.5)
		var exp_w_refund = floor(cost_w * 0.5)
		ok = check_eq(session.money, exp_m_refund, "Half money refund on partial cancel") and ok
		ok = check_eq(session.wood, exp_w_refund, "Half wood refund on partial cancel") and ok
		
		var m_after = session.money
		var w_after = session.wood
		session.cancel_building("FRA_gold")
		ok = check_eq(session.money, m_after, "Repeat cancel ignored (money)") and ok
		ok = check_eq(session.wood, w_after, "Repeat cancel ignored (wood)") and ok
		
		
		session.main_node.resource_distribution.free()
		session.main_node.free(); session.free()
		return ok
	)
	
	run_test("Building - exact completion and output", func():
		var session = create_test_session()
		var ok = true
		session.tax_rate = 0.0
		var start_gold = session.gold
		var days = BalanceConfig.GOLD_MINE_DAYS
		var total_hours = days * 24
		
		session.money = BalanceConfig.GOLD_MINE_COST_MONEY
		session.wood = BalanceConfig.GOLD_MINE_COST_WOOD
		session.start_building("FRA_gold", "GOLD_MINE")
		session.is_paused = false
		
		# Process up to 1 hour before completion
		for i in range(total_hours - 1): 
			session._process(1.0)
		ok = check_eq(session.completed_buildings.has("FRA_gold"), false, "Not completed yet") and ok
		
		# Exact hour of completion
		session._process(1.0) 
		ok = check_eq(session.completed_buildings.has("FRA_gold"), true, "Completed exactly on hour") and ok
		ok = check_eq(session.gold, start_gold, "No gold produced exactly on completion hour") and ok
		
		# Wait for the next 24 hour boundary
		for i in range(24): 
			session._process(1.0)
		
		var expected_gold = start_gold + BalanceConfig.GOLD_MINE_PROD_GOLD
		ok = check_eq(session.gold, expected_gold, "Gold paid on next boundary") and ok
		
		# Demolish
		session.demolish_building("FRA_gold")
		for i in range(24): 
			session._process(1.0)
		ok = check_eq(session.gold, expected_gold, "Demolished building stops producing") and ok
		
		
		session.main_node.resource_distribution.free()
		session.main_node.free(); session.free()
		return ok
	)
	
	run_test("Building - inappropriate resource (Current behavior check)", func():
		var session = create_test_session()
		var ok = true
		session.tax_rate = 0.0
		session.money = BalanceConfig.GOLD_MINE_COST_MONEY
		session.wood = BalanceConfig.GOLD_MINE_COST_WOOD
		
		# Start gold mine on wood region (current logic allows this but yields 0, UI shows warning modal)
		session.start_building("FRA_wood", "GOLD_MINE")
		session.is_paused = false
		
		var total_hours = BalanceConfig.GOLD_MINE_DAYS * 24
		for i in range(total_hours / 24): 
			session._process(24.0)
			
		ok = check_eq(session.completed_buildings.has("FRA_wood"), true, "Gold mine completed") and ok
		var g = session.gold
		session._process(24.0)
		ok = check_eq(session.gold, g, "Inappropriate resource produces 0 (behavior check)") and ok
		
		
		session.main_node.resource_distribution.free()
		session.main_node.free(); session.free()
		return ok
	)
	
	run_test("Pause action", func():
		var session = create_test_session()
		var ok = true
		session.is_paused = true
		
		session.money = BalanceConfig.GOLD_MINE_COST_MONEY
		session.wood = BalanceConfig.GOLD_MINE_COST_WOOD
		session.start_building("FRA_gold", "GOLD_MINE")
		
		var hours_left_start = session.building_orders["FRA_gold"].hours_left
		
		# Process multiple frames
		session._process(10.0)
		session._process(10.0)
		
		ok = check_eq(session.current_hours, 0, "Time shouldn't change") and ok
		ok = check_eq(session.fractional_hours, 0.0, "Fraction shouldn't accumulate") and ok
		ok = check_eq(session.money, 0.0, "Resources unchanged") and ok # we spent them above
		ok = check_eq(session.building_orders["FRA_gold"].hours_left, hours_left_start, "Building progress paused") and ok
		
		
		session.main_node.resource_distribution.free()
		session.main_node.free(); session.free()
		return ok
	)
	
	run_test("Time Speeds", func():
		var expected_speeds = [1, 3, 6, 12, 24]
		var ok = true
		
		for idx in range(expected_speeds.size()):
			var session = create_test_session()
			session.is_paused = false
			session.speed_idx = idx
			
			session._process(1.0)
			var expected_fraction = expected_speeds[idx]
			var whole_ticks = floor(expected_fraction)
			var fraction_rem = expected_fraction - whole_ticks
			
			if not check_eq(session.current_hours, whole_ticks, "Speed idx " + str(idx) + " ticks"): ok = false
			if not check_eq(session.fractional_hours, fraction_rem, "Speed idx " + str(idx) + " fraction"): ok = false
			
			
			session.main_node.resource_distribution.free()
			session.main_node.free(); session.free()
			
		return ok
	)
	
	run_test("Economy - Taxes", func():
		var session = create_test_session()
		var ok = true
		var start_m = session.money
		
		# Total population of FRA is 8000 (8 regions * 1000).
		var total_pop = 8000.0
		var annual_per_capita = BalanceConfig.TAX_BASE_PER_CAPITA["DEFAULT"]
		
		session.tax_rate = 0.0
		session.is_paused = false
		session._process(24.0)
		ok = check_eq(session.money, start_m, "0% tax = 0 income") and ok
		
		session.tax_rate = 100.0
		var m2 = session.money
		session._process(24.0)
		var expected = m2 + (total_pop * (annual_per_capita / 365.0) * 1.0)
		ok = check_eq(session.money, expected, "100% tax") and ok
		
		
		session.main_node.resource_distribution.free()
		session.main_node.free(); session.free()
		return ok
	)
	
	run_test("Economy - Mining & Science Production", func():
		var session = create_test_session()
		var ok = true
		session.tax_rate = 0.0
		
		session.completed_buildings["FRA_wood"] = {"type": "LOGGING_CAMP", "completed_hour": 0}
		session.completed_buildings["FRA_gold"] = {"type": "GOLD_MINE", "completed_hour": 0}
		session.completed_buildings["FRA_iron"] = {"type": "IRON_MINE", "completed_hour": 0}
		session.completed_buildings["FRA_uni"] = {"type": "UNIVERSITY", "completed_hour": 0}
		
		var w = session.wood
		var g = session.gold
		var ir = session.iron
		var s = session.science
		
		session.is_paused = false
		session._process(24.0)
		
		ok = check_eq(session.wood, w + BalanceConfig.LOGGING_CAMP_PROD_WOOD, "Wood prod") and ok
		ok = check_eq(session.gold, g + BalanceConfig.GOLD_MINE_PROD_GOLD, "Gold prod") and ok
		ok = check_eq(session.iron, ir + BalanceConfig.IRON_MINE_PROD_IRON, "Iron prod") and ok
		ok = check_eq(session.science, s + BalanceConfig.UNIVERSITY_PROD_SCIENCE, "Science prod") and ok
		
		
		session.main_node.resource_distribution.free()
		session.main_node.free(); session.free()
		return ok
	)
	
	run_test("Economy - Steel Mill Consumption", func():
		var session = create_test_session()
		var ok = true
		session.tax_rate = 0.0
		
		session.completed_buildings["FRA_steel"] = {"type": "STEEL_MILL", "completed_hour": 0}
		
		session.iron = 0.0
		session.steel = 0.0
		
		session.is_paused = false
		session._process(24.0)
		
		ok = check_eq(session.iron, 0.0, "Iron should not go negative") and ok
		ok = check_eq(session.steel, 0.0, "No steel produced without iron") and ok
		
		session.iron = BalanceConfig.STEEL_MILL_CONS_IRON
		session._process(24.0)
		ok = check_eq(session.iron, 0.0, "Iron consumed exactly") and ok
		ok = check_eq(session.steel, BalanceConfig.STEEL_MILL_PROD_STEEL, "Steel produced") and ok
		
		session.completed_buildings["FRA_steel2"] = {"type": "STEEL_MILL", "completed_hour": session.current_hours}
		session.iron = BalanceConfig.STEEL_MILL_CONS_IRON
		session.steel = 0.0
		session._process(24.0)
		ok = check_eq(session.iron, 0.0, "Iron consumed once") and ok
		ok = check_eq(session.steel, BalanceConfig.STEEL_MILL_PROD_STEEL, "Only one mill produced") and ok
		
		session.iron = BalanceConfig.STEEL_MILL_CONS_IRON * 2
		session.steel = 0.0
		session._process(24.0)
		ok = check_eq(session.iron, 0.0, "Iron consumed twice") and ok
		ok = check_eq(session.steel, BalanceConfig.STEEL_MILL_PROD_STEEL * 2, "Both mills produced") and ok
		
		
		session.main_node.resource_distribution.free()
		session.main_node.free(); session.free()
		return ok
	)
	
	run_test("Delta Limits - Large Delta vs Small Deltas", func():
		var session_large = create_test_session()
		var session_small = create_test_session()
		var ok = true
		
		# Set up identical state with tax and building
		session_large.tax_rate = 20.0
		session_small.tax_rate = 20.0
		session_large.is_paused = false
		session_small.is_paused = false
		session_large.speed_idx = 0 # 1 hour / sec
		session_small.speed_idx = 0 
		
		session_large.money = BalanceConfig.GOLD_MINE_COST_MONEY
		session_large.wood = BalanceConfig.GOLD_MINE_COST_WOOD
		session_large.start_building("FRA_gold", "GOLD_MINE")
		
		session_small.money = BalanceConfig.GOLD_MINE_COST_MONEY
		session_small.wood = BalanceConfig.GOLD_MINE_COST_WOOD
		session_small.start_building("FRA_gold", "GOLD_MINE")
		
		# Large delta (lag spike) - e.g. 100 seconds
		# 1st frame gets 48 hours processed, 52 hours remainder
		session_large._process(100.0)
		# 2nd frame processes another 48 hours, 4 remainder
		session_large._process(0.0)
		# 3rd frame processes the final 4 hours
		session_large._process(0.0)
		
		# Small deltas - 100 frames of 1.0 second each
		for i in range(100):
			session_small._process(1.0)
			
		ok = check_eq(session_large.current_hours, session_small.current_hours, "Hours match") and ok
		ok = check_eq(session_large.fractional_hours, session_small.fractional_hours, "Fractional hours match") and ok
		ok = check_eq(session_large.money, session_small.money, "Money matches") and ok
		ok = check_eq(session_large.wood, session_small.wood, "Wood matches") and ok
		ok = check_eq(session_large.gold, session_small.gold, "Gold matches") and ok
		
		var hl_large = session_large.building_orders["FRA_gold"].hours_left
		var hl_small = session_small.building_orders["FRA_gold"].hours_left
		ok = check_eq(hl_large, hl_small, "Building progress matches") and ok
		
		# Check exact payout boundary
		# Currently at hour 100. Payout days are at hours 24, 48, 72, 96. Total 4 payouts.
		ok = check_eq(session_large.last_payout_day, 4, "4 payouts done") and ok
		ok = check_eq(session_small.last_payout_day, 4, "4 payouts done (small)") and ok
		
		
		session_large.main_node.resource_distribution.free()
		session_large.main_node.free(); session_large.free()
		
		session_small.main_node.resource_distribution.free()
		session_small.main_node.free(); session_small.free()
		return ok
	)
	
	run_test("Time - Dates and Leap Years", func():
		var session = create_test_session()
		var ok = true
		session.is_paused = false
		
		# Feb 28 1936 -> day 58. (Jan=31 + 27 = 58)
		session.current_hours = 58 * 24 
		ok = check_eq(session.get_date_string(), "28.02.1936, 00:00", "Feb 28") and ok
		
		session.current_hours += 24
		ok = check_eq(session.get_date_string(), "29.02.1936, 00:00", "Feb 29 (Leap year)") and ok
		
		session.current_hours += 24
		ok = check_eq(session.get_date_string(), "01.03.1936, 00:00", "Mar 1") and ok
		
		session.current_hours = 366 * 24 - 24
		ok = check_eq(session.get_date_string(), "31.12.1936, 00:00", "Dec 31") and ok
		
		session.current_hours += 24
		ok = check_eq(session.get_date_string(), "01.01.1937, 00:00", "Jan 1, 1937") and ok
		
		
		session.main_node.resource_distribution.free()
		session.main_node.free(); session.free()
		return ok
	)
	
	print("\n=== SUMMARY ===")
	print("Passed: " + str(passed_count))
	print("Failed: " + str(failed_count))
	print("Skipped: " + str(skipped_count))
	print("Total Checks: " + str(checks_total))
	
	if failed_count == 0:
		print("SUCCESS")
		quit(0)
	else:
		print("FAILED")
		quit(1)
