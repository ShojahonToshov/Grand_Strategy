class_name ResourceDistribution
extends Node

enum ResourceType { NONE, GOLD, WOOD, IRON }

var state_resources = {}

var seed_value: int = 0
var gold_count = 0
var wood_count = 0
var none_count = 0

func generate_distribution(fixed_seed: int = -1):
	var rng = RandomNumberGenerator.new()
	if fixed_seed != -1:
		rng.seed = fixed_seed
	else:
		rng.randomize()
	seed_value = rng.seed
	
	var geo_json = load("res://state_geography.json") as JSON
	var geo_data = {}
	if geo_json: geo_data = geo_json.data
	
	var state_ids = geo_data.keys()
	# Sort for stability
	state_ids.sort_custom(func(a, b): return str(a).to_int() < str(b).to_int())
	
	var noise = FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.005 # Large geological regions
	
	var candidates = []
	
	for s_id_str in state_ids:
		var cx = geo_data[s_id_str][0]
		var cy = geo_data[s_id_str][1]
		
		# Wood suitability based on latitude (cy)
		var wood_suitability = 0.1
		if cy < 500: wood_suitability = 0.8 # Boreal
		elif cy >= 500 and cy < 750: wood_suitability = 0.5 # Temperate
		elif cy >= 750 and cy < 950: wood_suitability = 0.05 # Deserts
		elif cy >= 950 and cy < 1250: wood_suitability = 0.9 # Tropics
		elif cy >= 1250 and cy < 1450: wood_suitability = 0.1 # Southern deserts
		else: wood_suitability = 0.4
		
		# Apply noise and state-level random factor
		var wood_noise = noise.get_noise_2d(cx, cy + 10000.0) * 0.5 + 0.5
		wood_suitability = (wood_suitability * 0.6 + wood_noise * 0.4) * rng.randf_range(0.7, 1.3)
		
		# Gold suitability (needs rare concentrated belts)
		var gold_noise = noise.get_noise_2d(cx, cy) * 0.5 + 0.5
		var gold_suitability = pow(gold_noise, 3.0) * rng.randf_range(0.7, 1.3)
		
		# Iron suitability (similar to gold but different offset and more common)
		var iron_noise = noise.get_noise_2d(cx + 5000.0, cy - 5000.0) * 0.5 + 0.5
		var iron_suitability = pow(iron_noise, 2.0) * rng.randf_range(0.8, 1.2)
		
		candidates.append({
			"id": s_id_str,
			"wood": wood_suitability,
			"gold": gold_suitability,
			"iron": iron_suitability
		})
		
	var total_states = candidates.size()
	var target_gold = int(total_states * rng.randf_range(0.03, 0.06))
	var target_iron = int(total_states * rng.randf_range(0.08, 0.12))
	var target_wood = int(total_states * rng.randf_range(0.25, 0.40))
	
	state_resources.clear()
	gold_count = 0
	var iron_count = 0
	wood_count = 0
	none_count = 0
	
	for c in candidates:
		state_resources[c.id] = ResourceType.NONE
		
	# Assign Gold
	candidates.sort_custom(func(a, b): return a.gold > b.gold)
	var actual_gold = min(target_gold, candidates.size())
	for i in range(actual_gold):
		state_resources[candidates[i].id] = ResourceType.GOLD
		gold_count += 1
		
	# Assign Iron
	var iron_candidates = candidates.filter(func(c): return state_resources[c.id] == ResourceType.NONE)
	iron_candidates.sort_custom(func(a, b): return a.iron > b.iron)
	var actual_iron = min(target_iron, iron_candidates.size())
	for i in range(actual_iron):
		state_resources[iron_candidates[i].id] = ResourceType.IRON
		iron_count += 1
		
	# Remove gold/iron from wood candidates
	var wood_candidates = candidates.filter(func(c): return state_resources[c.id] == ResourceType.NONE)
	wood_candidates.sort_custom(func(a, b): return a.wood > b.wood)
	
	var actual_wood = min(target_wood, wood_candidates.size())
	for i in range(actual_wood):
		state_resources[wood_candidates[i].id] = ResourceType.WOOD
		wood_count += 1
		
	none_count = total_states - gold_count - iron_count - wood_count
	
	print("--- Resource Distribution Generated ---")
	print("Seed: ", seed_value)
	print("Total States: ", total_states)
	print("GOLD: ", gold_count)
	print("IRON: ", iron_count)
	print("WOOD: ", wood_count)
	print("NONE: ", none_count)
	print("---------------------------------------")

func get_resource_for_state(state_id: String) -> ResourceType:
	if state_resources.has(state_id):
		return state_resources[state_id]
	return ResourceType.NONE

func get_resource_color(res_type: ResourceType) -> Color:
	match res_type:
		ResourceType.GOLD:
			return Color("#D9AC43")
		ResourceType.WOOD:
			return Color("#986744")
		ResourceType.IRON:
			return Color("#A0A5A9")
		ResourceType.NONE:
			return Color("#E8E9EA")
	return Color("#E8E9EA")

func get_resource_name(res_type: ResourceType) -> String:
	match res_type:
		ResourceType.GOLD:
			return "Золото"
		ResourceType.WOOD:
			return "Древесина"
		ResourceType.IRON:
			return "Железо"
		ResourceType.NONE:
			return "Нет ресурса"
	return "Нет ресурса"
