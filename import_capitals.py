import os
import re
import json
from collections import defaultdict

HOI4_DIR = r"D:\Games\Hearts of Iron IV (2016)\Hearts of Iron IV"
SCENARIO_DATE = (1936, 1, 1)

def parse_date(date_str):
    try:
        parts = date_str.split('.')
        return (int(parts[0]), int(parts[1]), int(parts[2]))
    except:
        return (9999, 99, 99)

def read_script_file(filepath):
    # Simplistic parser for HOI4 script files
    try:
        with open(filepath, 'r', encoding='utf-8-sig') as f:
            content = f.read()
    except:
        try:
            with open(filepath, 'r', encoding='windows-1252') as f:
                content = f.read()
        except:
            return ""
            
    # Remove comments
    content = re.sub(r'#.*', '', content)
    return content

def get_capitals_from_countries():
    countries_dir = os.path.join(HOI4_DIR, "history", "countries")
    capitals = {} # tag -> state_id
    if not os.path.exists(countries_dir):
        print("HOI4 countries dir not found!")
        return capitals
        
    for filename in os.listdir(countries_dir):
        if not filename.endswith(".txt"): continue
        tag = filename[:3]
        content = read_script_file(os.path.join(countries_dir, filename))
        
        # Base capital
        match = re.search(r'\bcapital\s*=\s*(\d+)', content)
        capital = int(match.group(1)) if match else None
        
        # Check dated blocks
        date_blocks = re.finditer(r'(\d{4}\.\d{1,2}\.\d{1,2})\s*=\s*\{([^}]+)\}', content)
        for db in date_blocks:
            d_str = db.group(1)
            d_val = parse_date(d_str)
            if d_val <= SCENARIO_DATE:
                inner = db.group(2)
                cmatch = re.search(r'\bcapital\s*=\s*(\d+)', inner)
                if cmatch:
                    capital = int(cmatch.group(1))
                    
        if capital is not None:
            capitals[tag] = capital
            
    return capitals

def get_vp_from_states():
    states_dir = os.path.join(HOI4_DIR, "history", "states")
    vp_map = {} # state_id -> prov_id (largest vp)
    
    if not os.path.exists(states_dir):
        print("HOI4 states dir not found!")
        return vp_map
        
    for filename in os.listdir(states_dir):
        if not filename.endswith(".txt"): continue
        content = read_script_file(os.path.join(states_dir, filename))
        
        state_match = re.search(r'\bid\s*=\s*(\d+)', content)
        if not state_match: continue
        state_id = int(state_match.group(1))
        
        vps = []
        vp_blocks = re.finditer(r'\bvictory_points\s*=\s*\{\s*(\d+)\s+(\d+)', content)
        for vp in vp_blocks:
            prov = int(vp.group(1))
            score = int(vp.group(2))
            vps.append((score, prov))
            
        if vps:
            vps.sort(reverse=True)
            vp_map[state_id] = vps[0][1] # Highest VP
            
    return vp_map

def load_loc():
    loc = {}
    loc_dirs = [
        os.path.join(HOI4_DIR, "localisation", "english"),
        os.path.join(HOI4_DIR, "localisation", "russian") # Russian overwrites english if exists
    ]
    for ldir in loc_dirs:
        if not os.path.exists(ldir): continue
        for fname in os.listdir(ldir):
            if "victory_points" in fname.lower() and fname.endswith(".yml"):
                try:
                    with open(os.path.join(ldir, fname), 'r', encoding='utf-8-sig') as f:
                        for line in f:
                            match = re.match(r'^\s*VICTORY_POINTS_(\d+):\d*\s*\"(.*?)\"', line)
                            if match:
                                loc[int(match.group(1))] = match.group(2)
                except Exception as e:
                    pass
    return loc

def get_positions():
    # Attempt to read unitstacks.txt for city position
    pos_file = os.path.join(HOI4_DIR, "map", "unitstacks.txt")
    positions = {}
    if os.path.exists(pos_file):
        content = read_script_file(pos_file)
        # Format: province_id = { type = { x y } ... }
        # Let's extract the first xy for each province as a fallback
        blocks = re.finditer(r'(\d+)\s*=\s*\{([^}]+)\}', content)
        for b in blocks:
            prov = int(b.group(1))
            inner = b.group(2)
            # Match first pair of floats
            pmatch = re.search(r'\{\s*([\d\.]+)\s+([\d\.]+)\s+[^\}]+\}', inner)
            if pmatch:
                positions[prov] = (float(pmatch.group(1)), float(pmatch.group(2)))
    return positions

def main():
    print("Extracting capitals from history/countries...")
    capitals = get_capitals_from_countries()
    
    print("Extracting VPs from history/states...")
    vps = get_vp_from_states()
    
    print("Loading localisation...")
    loc = load_loc()
    
    print("Loading unitstacks.txt...")
    positions = get_positions()
    
    active_tags = set()
    try:
        with open("states.json", "r") as f:
            states_data = json.load(f)
            for sid, info in states_data.items():
                owner = info.get("owner")
                if owner:
                    active_tags.add(owner)
    except:
        pass
    
    # We also need prov_map to calculate fallback positions if unitstacks is empty or missing
    # Godot map coords: 5632x2048. HOI4 uses same?
    from PIL import Image
    import numpy as np
    print("Loading province_id.png for fallback centroids...")
    prov_img = Image.open("province_id.png").convert("RGB")
    prov_arr = np.array(prov_img)
    prov_map = prov_arr[:,:,0].astype(np.int32) + (prov_arr[:,:,1].astype(np.int32) << 8) + (prov_arr[:,:,2].astype(np.int32) << 16)
    
    prov_centroids = {}
    # Optimization: only compute centroids for capital provinces
    capital_provs = set()
    for tag, sid in capitals.items():
        if sid in vps:
            capital_provs.add(vps[sid])
            
    print(f"Calculating centroids for {len(capital_provs)} capital provinces...")
    # Find all coordinates for the needed provinces
    y_coords, x_coords = np.nonzero(np.isin(prov_map, list(capital_provs)))
    prov_pixels = defaultdict(list)
    for y, x in zip(y_coords, x_coords):
        p = prov_map[y, x]
        prov_pixels[p].append((x, y))
        
    for p, pixels in prov_pixels.items():
        avg_x = sum(x for x, y in pixels) / len(pixels)
        avg_y = sum(y for x, y in pixels) / len(pixels)
        prov_centroids[p] = (avg_x, avg_y)

    results = {}
    # We only care about countries present in data.json (which we can check, or just export all valid ones)
    for tag, state_id in capitals.items():
        if active_tags and tag not in active_tags:
            continue
        if state_id in vps:
            prov_id = vps[state_id]
            name = loc.get(prov_id, f"City {prov_id}")
            
            # Position: Try unitstacks, else centroid
            if prov_id in positions:
                # HOI4 coords: y is inverted! Godot map height = 2048
                x, y = positions[prov_id]
                y = 2048 - y
            elif prov_id in prov_centroids:
                x, y = prov_centroids[prov_id]
            else:
                continue
                
            results[tag] = {
                "state_id": state_id,
                "prov_id": prov_id,
                "name": name,
                "x": round(x, 2),
                "y": round(y, 2)
            }
            
    with open("capitals.json", "w", encoding='utf-8') as f:
        json.dump(results, f, ensure_ascii=False, indent=4)
        
    print(f"Exported {len(results)} capitals.")

if __name__ == "__main__":
    main()
