import json
import random

# Base populations in millions for 1936
EMPIRES = {
    "FRA": {"tags": ["FRA", "SYR", "LEB"], "pop": 110_000_000, "capital": "16"},
    "ENG": {"tags": ["ENG", "RAJ", "MAL", "CAN", "AST", "NZL", "SAF"], "pop": 480_000_000, "capital": "120"},
    "SOV": {"tags": ["SOV", "MON", "TAN"], "pop": 165_000_000, "capital": "219"},
    "GER": {"tags": ["GER"], "pop": 67_000_000, "capital": "64"},
    "USA": {"tags": ["USA", "PHI"], "pop": 145_000_000, "capital": "361"}, # Maryland/DC approx
    "JAP": {"tags": ["JAP", "MAN", "MEN"], "pop": 135_000_000, "capital": "282"}, # Kanto approx
    "ITA": {"tags": ["ITA", "ETH"], "pop": 52_000_000, "capital": "158"},
    "HOL": {"tags": ["HOL", "INS"], "pop": 70_000_000, "capital": "7"},
    "CHI": {"tags": ["CHI"], "pop": 400_000_000, "capital": "59"}, # Nanjing approx
    "PRC": {"tags": ["PRC"], "pop": 30_000_000, "capital": None},
    "GXC": {"tags": ["GXC"], "pop": 35_000_000, "capital": None},
    "YUN": {"tags": ["YUN"], "pop": 12_000_000, "capital": None},
    "SHX": {"tags": ["SHX"], "pop": 15_000_000, "capital": None},
    "XSM": {"tags": ["XSM"], "pop": 5_000_000, "capital": None},
    "SIK": {"tags": ["SIK"], "pop": 4_000_000, "capital": None},
    "SPR": {"tags": ["SPR"], "pop": 25_000_000, "capital": "171"}, # Madrid
    "POL": {"tags": ["POL"], "pop": 34_000_000, "capital": "91"}, # Warsaw
    "BRA": {"tags": ["BRA"], "pop": 40_000_000, "capital": None},
    "TUR": {"tags": ["TUR"], "pop": 16_000_000, "capital": "339"},
    "ROM": {"tags": ["ROM"], "pop": 19_000_000, "capital": "78"},
    "YUG": {"tags": ["YUG"], "pop": 15_000_000, "capital": "107"},
    "HUN": {"tags": ["HUN"], "pop": 9_000_000, "capital": "155"},
    "CZE": {"tags": ["CZE"], "pop": 15_000_000, "capital": "74"},
    "SWE": {"tags": ["SWE"], "pop": 6_000_000, "capital": "139"},
    "ARG": {"tags": ["ARG"], "pop": 13_000_000, "capital": None},
    "MEX": {"tags": ["MEX"], "pop": 18_000_000, "capital": None}
}

# Default pop for tags not in EMPIRES
DEFAULT_POP = 3_000_000

def main():
    with open('states.json', 'r') as f:
        states = json.load(f)
    
    # Track assigned states to empires so we don't double count
    assigned_states = set()
    
    # 1. Map all tags to their states
    tag_to_states = {}
    for state_id, state_data in states.items():
        owner = state_data.get("owner")
        if owner:
            if owner not in tag_to_states:
                tag_to_states[owner] = []
            tag_to_states[owner].append(state_id)
            
    # Prepare population mapping for all tags (empires logic)
    for emp_id, emp_data in EMPIRES.items():
        emp_states = []
        for tag in emp_data["tags"]:
            if tag in tag_to_states:
                emp_states.extend(tag_to_states[tag])
                
        if not emp_states:
            continue
            
        capital = emp_data["capital"]
        if not capital or capital not in emp_states:
            capital = emp_states[0] # fallback
            
        total_pop = emp_data["pop"]
        cap_pop = int(total_pop * 0.2)
        rem_pop = total_pop - cap_pop
        
        states[capital]["population"] = cap_pop
        assigned_states.add(capital)
        
        other_states = [s for s in emp_states if s != capital]
        if other_states:
            # Distribute remaining randomly but somewhat evenly
            # We give each state a random weight between 0.5 and 1.5
            weights = [random.uniform(0.5, 1.5) for _ in other_states]
            total_weight = sum(weights)
            
            for s, w in zip(other_states, weights):
                s_pop = int(rem_pop * (w / total_weight))
                states[s]["population"] = s_pop
                assigned_states.add(s)

    # 2. Assign default population for any remaining states
    # Find tags that haven't been processed
    for tag, t_states in tag_to_states.items():
        unassigned = [s for s in t_states if s not in assigned_states]
        if unassigned:
            capital = unassigned[0]
            total_pop = DEFAULT_POP
            cap_pop = int(total_pop * 0.3)
            rem_pop = total_pop - cap_pop
            states[capital]["population"] = cap_pop
            
            other_states = unassigned[1:]
            if other_states:
                weights = [random.uniform(0.5, 1.5) for _ in other_states]
                total_weight = sum(weights)
                for s, w in zip(other_states, weights):
                    states[s]["population"] = int(rem_pop * (w / total_weight))

    # Add missing "population" key for unowned states (sea/lake) just in case
    for state_id in states:
        if "population" not in states[state_id]:
            states[state_id]["population"] = 0

    with open('states.json', 'w') as f:
        json.dump(states, f)
        
    print("Population distributed successfully.")

if __name__ == '__main__':
    main()
