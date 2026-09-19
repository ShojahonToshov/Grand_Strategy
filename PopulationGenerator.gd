extends Node
class_name PopulationGenerator

static func generate_population(states_dict: Dictionary, geo_dict: Dictionary, capitals_dict: Dictionary) -> Dictionary:
	var result = {}
	var sources = _load_json("res://data/scenarios/1936/population_sources.json")
	if sources.is_empty():
		return result
		
	var owner_states = {}
	
	for sid in states_dict.keys():
		var sinfo = states_dict[sid]
		var owner = sinfo.get("owner", "")
		if owner == "":
			continue
			
		var x = 0.0
		var y = 0.0
		if geo_dict.has(sid):
			var coords = geo_dict[sid]
			x = coords[0]
			y = coords[1]
			
		if owner == "FRA":
			if x >= 2700 and x <= 3100 and y >= 500 and y <= 700:
				owner = "FRA_METRO"
			else:
				owner = "FRA_COLONY"
		elif owner == "ENG":
			if x >= 2700 and x <= 3000 and y >= 300 and y <= 550:
				owner = "ENG_METRO"
			else:
				owner = "ENG_COLONY"
				
		if not owner_states.has(owner):
			owner_states[owner] = []
		owner_states[owner].append(sid)
		
	for tag in owner_states.keys():
		var s_list = owner_states[tag]
		var target_pop: int = 0
		if sources.has(tag):
			target_pop = int(sources[tag]["population_1936"])
		elif tag == "FRA_METRO":
			target_pop = 41907056
		elif tag == "FRA_COLONY":
			target_pop = 65000000
		elif tag == "ENG_METRO":
			target_pop = 47100000
		elif tag == "ENG_COLONY":
			target_pop = 60000000
		else:
			continue
			
		var base_tag = tag.substr(0, 3)
		var capital_id = null
		if capitals_dict.has(base_tag):
			capital_id = capitals_dict[base_tag].get("state_id", null)
			
		var allocs = _distribute(target_pop, s_list, capital_id, "pop_" + tag + "_1936")
		for sid in allocs.keys():
			result[sid] = {
				"population": allocs[sid],
				"owner_group": tag,
				"owner": states_dict[sid]["owner"]
			}
			
	return result

static func _distribute(total_pop: int, state_ids: Array, capital_id, seed_str: String) -> Dictionary:
	var sorted_ids = state_ids.duplicate()
	sorted_ids.sort_custom(func(a, b): return int(a) < int(b))
	
	# simple hash for seed
	var seed_val = seed_str.hash()
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	
	var weights = {}
	var total_weight = 0.0
	
	for sid in sorted_ids:
		var w = rng.randf_range(0.85, 1.15)
		if str(sid) == str(capital_id):
			w *= 3.0
		weights[sid] = w
		total_weight += w
		
	var allocs = {}
	var remainders = []
	var allocated = 0
	
	for sid in sorted_ids:
		var exact = (weights[sid] / total_weight) * total_pop
		var floor_val = int(floor(exact))
		var rem = exact - floor_val
		allocs[sid] = floor_val
		allocated += floor_val
		remainders.append({"rem": rem, "sid": sid})
		
	var shortfall = total_pop - allocated
	remainders.sort_custom(func(a, b):
		if a["rem"] != b["rem"]:
			return a["rem"] > b["rem"]
		return int(a["sid"]) > int(b["sid"])
	)
	
	for i in range(shortfall):
		allocs[remainders[i]["sid"]] += 1
		
	return allocs

static func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(content) == OK:
		return json.data
	return {}
