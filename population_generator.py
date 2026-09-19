import json
import random

def distribute_population(total_pop, state_ids, capital_id, seed_str):
    if not state_ids:
        return {}
    
    sorted_states = sorted(list(state_ids), key=lambda x: int(x))
    rng = random.Random(seed_str)
    
    weights = {}
    total_weight = 0.0
    
    for sid in sorted_states:
        w = rng.uniform(0.85, 1.15)
        if str(sid) == str(capital_id):
            w *= 3.0
        weights[sid] = w
        total_weight += w
        
    allocations = {}
    remainders = []
    
    allocated = 0
    for sid in sorted_states:
        exact = (weights[sid] / total_weight) * total_pop
        floor_val = int(exact)
        rem = exact - floor_val
        allocations[sid] = floor_val
        allocated += floor_val
        remainders.append((rem, sid))
        
    shortfall = total_pop - allocated
    remainders.sort(key=lambda x: (-x[0], int(x[1])))
    
    for i in range(shortfall):
        allocations[remainders[i][1]] += 1
        
    return allocations

def main():
    with open('states.json', 'r', encoding='utf-8') as f:
        states = json.load(f)
        
    with open('state_geography.json', 'r', encoding='utf-8') as f:
        geo = json.load(f)

    try:
        with open('capitals.json', 'r', encoding='utf-8') as f:
            capitals = json.load(f)
    except FileNotFoundError:
        capitals = {}

    with open('data/scenarios/1936/population_sources.json', 'r', encoding='utf-8') as f:
        sources = json.load(f)

    # Group states by owner, with split for FRA/ENG metropoles
    owner_states = {}
    
    for sid, sinfo in states.items():
        owner = sinfo.get("owner", "")
        if not owner: continue
        
        # Check coordinates
        coords = geo.get(sid, [0, 0])
        x, y = coords[0], coords[1]
        
        # Split FRA
        if owner == "FRA":
            if 2700 <= x <= 3100 and 500 <= y <= 700:
                owner = "FRA_METRO"
            else:
                owner = "FRA_COLONY"
        elif owner == "ENG":
            if 2700 <= x <= 3000 and 300 <= y <= 550:
                owner = "ENG_METRO"
            else:
                owner = "ENG_COLONY"
                
        owner_states.setdefault(owner, []).append(sid)

    result = {}
    
    missing_data_tags = []
    
    for tag, s_list in owner_states.items():
        if tag in sources:
            target_pop = sources[tag]["population_1936"]
        elif tag == "FRA_METRO":
            target_pop = 41907056 # 1936 census
        elif tag == "FRA_COLONY":
            target_pop = 65000000 # Estimate
        elif tag == "ENG_METRO":
            target_pop = 47100000
        elif tag == "ENG_COLONY":
            target_pop = 60000000
        else:
            missing_data_tags.append(tag)
            continue
            
        capital_id = capitals.get(tag[:3], {}).get("state_id", None)
        
        allocs = distribute_population(target_pop, s_list, capital_id, f"pop_{tag}_1936")
        
        for sid, pop in allocs.items():
            result[sid] = {
                "population": pop,
                "owner_group": tag,
                "owner": states[sid]["owner"]
            }

    with open('data/scenarios/1936/population_mapping.json', 'w', encoding='utf-8') as f:
        json.dump(result, f, indent=2)

    if missing_data_tags:
        print(f"Warning: Missing population data for tags: {', '.join(missing_data_tags)}")

if __name__ == '__main__':
    main()
