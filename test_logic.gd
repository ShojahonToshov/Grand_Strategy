extends SceneTree

func _init():
	print("Running tests...")
	
	# Mock Main and ResourceDistribution
	var main = Node.new()
	var dist = load("res://ResourceDistribution.gd").new()
	main.add_child(dist)
	# Set a fixed seed to guarantee specific region types
	dist.generate_distribution(12345) 
	
	# Mock getting owner
	main.set_script(GDScript.new())
	main.set_meta("test_owners", {})
	
	# Find regions with specific resources for FRA
	var fra_gold = ""
	var fra_wood = ""
	var fra_none = ""
	var foreign_region = ""
	
	for s_id in dist.state_resources.keys():
		var res = dist.state_resources[s_id]
		if res == ResourceDistribution.ResourceType.GOLD and fra_gold == "":
			fra_gold = s_id
		elif res == ResourceDistribution.ResourceType.WOOD and fra_wood == "":
			fra_wood = s_id
		elif res == ResourceDistribution.ResourceType.NONE and fra_none == "":
			fra_none = s_id
		elif res == ResourceDistribution.ResourceType.WOOD and foreign_region == "":
			foreign_region = s_id
			
	var owners = {
		fra_gold: "FRA",
		fra_wood: "FRA",
		fra_none: "FRA",
		foreign_region: "GER"
	}
	
	# Attach method using a hack with Object.set_meta or just create a script string
	var script = GDScript.new()
	script.source_code = """
extends Node
var owners = {}
var resource_distribution
func get_state_owner(id):
	return owners.get(id, "None")
"""
	script.reload()
	main.set_script(script)
	main.owners = owners
	main.resource_distribution = dist
	
	var session = load("res://GameSession.gd").new()
	session.main_node = main
	
	# Test 1: Initial state
	assert(session.money == 3000, "Start money should be 3000")
	assert(session.wood == 150, "Start wood should be 150")
	assert(session.gold == 0, "Start gold should be 0")
	assert(session.get_date_string() == "01.01.1936, 00:00", "Start date wrong")
	
	# Test 2: Foreign region checks
	assert(not session.can_build(foreign_region, "LOGGING_CAMP"), "Should not build on foreign")
	
	# Test 3: Multiple clicks / lack of resources
	assert(session.can_build(fra_wood, "LOGGING_CAMP"), "FRA should build on own wood")
	session.start_building(fra_wood, "LOGGING_CAMP")
	assert(not session.can_build(fra_wood, "LOGGING_CAMP"), "Slot should be occupied")
	# Double click simulation
	session.start_building(fra_wood, "LOGGING_CAMP")
	assert(session.money == 3000 - 150, "Money should be deducted only once")
	
	# Test 4: Cancel building
	session.cancel_building(fra_wood)
	assert(session.money == 3000, "Money should be returned fully")
	
	# Cancel partially progressed
	session.start_building(fra_wood, "LOGGING_CAMP")
	session.is_paused = false
	session.speed_idx = 0 # 1 hour per sec
	
	# Tick exactly half the building time (LOGGING = 720h)
	for i in range(36):
		session._process(10.0) # 360 hours -> half
	assert(session.building_orders[fra_wood].hours_left == 360, "Should have 360 hours left")
	session.cancel_building(fra_wood)
	# 15 days of base budget (+10/day) = +150
	assert(session.money == 3000 - 150 + 75 + 150, "Should return 75 money + 150 base income")
	
	# Reset money
	session.money = 3000
	session.current_hours = 0
	session.last_payout_day = 0
	session.fractional_hours = 0.0
	
	# Test 5: Exact payout boundary (start at hour 0, finishes at hour 720)
	session.start_building(fra_wood, "LOGGING_CAMP")
	for i in range(72): session._process(10.0)
	assert(not session.building_orders.has(fra_wood), "Should be completed")
	assert(session.completed_buildings.has(fra_wood), "Should be completed")
	# At hour 720 (Day 30, 00:00). Day boundary just passed, but building just finished.
	# Should NOT get paid yet.
	assert(session.wood == 150, "No wood on completion day")
	
	# Next day 00:00 (hour 744)
	for i in range(3): session._process(8.0)
	assert(session.wood == 160, "Wood +10 paid on next boundary")
	
	# Test 6: Inappropriate resource
	session.start_building(fra_none, "GOLD_MINE")
	for i in range(216): session._process(10.0) # 90 days
	var old_gold = session.gold
	for i in range(3): session._process(8.0) # 1 day work
	assert(session.gold == old_gold, "Inappropriate resource should give 0")
	
	# Test 7: Frame time differences (consistency)
	var session1 = load("res://GameSession.gd").new()
	session1.main_node = main
	session1.is_paused = false
	session1.speed_idx = 0
	
	var session2 = load("res://GameSession.gd").new()
	session2.main_node = main
	session2.is_paused = false
	session2.speed_idx = 0
	
	session1.start_building(fra_wood, "LOGGING_CAMP")
	session2.start_building(fra_wood, "LOGGING_CAMP")
	
	# Session 1: 10 ticks of 100 hours (each gets clamped to 48, so we do 50 ticks of 20 hours)
	for i in range(50):
		session1._process(20.0)
	
	# Session 2: 1000 ticks of 1 hour
	for i in range(1000):
		session2._process(1.0)
		
	assert(session1.current_hours == session2.current_hours, "Hours should match")
	assert(session1.money == session2.money, "Money should match exactly")
	assert(session1.wood == session2.wood, "Wood should match exactly")
	
	# Leap year test: 28 Feb 1936 -> 29 Feb 1936
	# 1936 is a leap year. Feb has 29 days.
	# 31 days (Jan) + 27 days (Feb) = 58 days. 58 * 24 = 1392
	var session3 = load("res://GameSession.gd").new()
	session3.main_node = main
	session3.current_hours = 1392
	assert(session3.get_date_string().begins_with("28.02.1936"), "Should be 28.02.1936")
	session3.current_hours += 24
	assert(session3.get_date_string().begins_with("29.02.1936"), "Should be 29.02.1936")
	session3.current_hours += 24
	assert(session3.get_date_string().begins_with("01.03.1936"), "Should be 01.03.1936")
	
	# Test demolish
	session.demolish_building(fra_wood)
	var pre_wood = session.wood
	session._process(24.0)
	assert(session.wood == pre_wood, "Demolished building shouldn't produce")
	
	print("ALL TESTS PASSED")
	quit(0)
