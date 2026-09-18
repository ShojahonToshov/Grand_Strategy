import os
import sys
import json
import numpy as np
from PIL import Image
from collections import defaultdict
import glob
import re
import colorsys

# Ensure Pillow has enough memory for large images
Image.MAX_IMAGE_PIXELS = None

def tokenize(text):
    # Remove comments
    text = re.sub(r'#.*', '', text)
    # Tokenize: find strings or symbols
    tokens = re.findall(r'\"[^\"]*\"|[{}={}]|[^\s{}={}\"]+', text)
    return tokens

def parse_pdx(tokens, index=0):
    node = defaultdict(list)
    while index < len(tokens):
        token = tokens[index]
        index += 1
        if token == '}':
            break
        if index < len(tokens) and tokens[index] == '=':
            key = token
            index += 1
            if index < len(tokens) and tokens[index] == '{':
                child, index = parse_pdx(tokens, index + 1)
                node[key].append(child)
            else:
                val = tokens[index]
                index += 1
                node[key].append(val)
        else:
            if '__list__' not in node:
                node['__list__'] = []
            node['__list__'].append(token)
    return node, index

def parse_date(date_str):
    parts = date_str.split('.')
    if len(parts) >= 3:
        try:
            return tuple(int(x) for x in parts)
        except:
            pass
    return None

def compare_dates(d1, d2):
    # d1 and d2 are tuples like (1936, 1, 1, 12)
    # Pads shorter date with 0s
    for i in range(max(len(d1), len(d2))):
        v1 = d1[i] if i < len(d1) else 0
        v2 = d2[i] if i < len(d2) else 0
        if v1 < v2: return -1
        if v1 > v2: return 1
    return 0

def parse_color(color_block):
    if '__list__' in color_block:
        lst = color_block['__list__']
        if len(lst) >= 3:
            return (int(lst[0]), int(lst[1]), int(lst[2]))
    return None

def parse_hsv_or_rgb(value_list, mode):
    try:
        if mode == 'hsv':
            h, s, v = float(value_list[0]), float(value_list[1]), float(value_list[2])
            r, g, b = colorsys.hsv_to_rgb(h, s, v)
            return (int(r*255), int(g*255), int(b*255))
        else:
            return (int(value_list[0]), int(value_list[1]), int(value_list[2]))
    except:
        return None

def main():
    if len(sys.argv) < 2:
        print("Usage: python converter.py <path_to_hoi4>")
        return
    game_path = sys.argv[1]
    
    # 1. Metadata
    version = "Unknown"
    launcher_path = os.path.join(game_path, 'launcher-settings.json')
    if os.path.exists(launcher_path):
        try:
            with open(launcher_path, 'r') as f:
                d = json.load(f)
                version = d.get('version', 'Unknown')
        except: pass
    
    start_date_str = '1936.1.1.12'
    target_date = parse_date(start_date_str)
    
    metadata = {
        'game_version': version,
        'start_date': start_date_str
    }
    print(f"Game Version: {version}, Target Date: {start_date_str}")
    
    # 2. Extract colors
    tags_to_file = {}
    country_tags_dir = os.path.join(game_path, 'common', 'country_tags')
    if os.path.exists(country_tags_dir):
        for tag_file in glob.glob(os.path.join(country_tags_dir, '*.txt')):
            with open(tag_file, 'r', encoding='utf-8', errors='ignore') as f:
                for line in f:
                    line = line.split('#')[0].strip()
                    if '=' in line:
                        parts = line.split('=')
                        tag = parts[0].strip()
                        path = parts[1].strip().strip('"')
                        tags_to_file[tag] = path
    
    country_colors = {}
    for tag, path in tags_to_file.items():
        p = os.path.join(game_path, 'common', path)
        if os.path.exists(p):
            with open(p, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                tokens = tokenize(content)
                data, _ = parse_pdx(tokens)
                if 'color' in data and len(data['color']) > 0:
                    cblock = data['color'][0]
                    if isinstance(cblock, dict):
                        c = parse_color(cblock)
                        if c: country_colors[tag] = c
                    elif isinstance(cblock, str):
                        # format could be color = rgb { 1 2 3 }
                        pass # handled by regex if needed, but in countries it's usually just color = { 1 2 3 }

    # Fallback to regex for tricky formats
    for tag, path in tags_to_file.items():
        p = os.path.join(game_path, 'common', path)
        if os.path.exists(p):
            content = open(p, 'r', encoding='utf-8', errors='ignore').read()
            m = re.search(r'color\s*=\s*(?:(rgb|hsv)\s*)?\{\s*([0-9\.]+)\s+([0-9\.]+)\s+([0-9\.]+)\s*\}', content, re.IGNORECASE)
            if m:
                mode = m.group(1).lower() if m.group(1) else 'rgb'
                c = parse_hsv_or_rgb([m.group(2), m.group(3), m.group(4)], mode)
                if c: country_colors[tag] = c

    print("Parsing common/countries/colors.txt...", flush=True)
    colors_file = os.path.join(game_path, 'common', 'countries', 'colors.txt')
    if os.path.exists(colors_file):
        content = open(colors_file, 'r', encoding='utf-8', errors='ignore').read()
        
        # Simpler regex without catastrophic backtracking
        for m in re.finditer(r'([A-Z0-9]{3})\s*=\s*\{.*?\}', content, re.IGNORECASE | re.DOTALL):
            tag = m.group(1).upper()
            block = m.group(0)
            m_c = re.search(r'color\s*=\s*(rgb|hsv)\s*\{\s*([0-9\.]+)\s+([0-9\.]+)\s+([0-9\.]+)\s*\}', block, re.IGNORECASE)
            if m_c:
                mode = m_c.group(1).lower()
                c = parse_hsv_or_rgb([m_c.group(2), m_c.group(3), m_c.group(4)], mode)
                if c: country_colors[tag] = c

    # 3. Parsing definition.csv
    print("Parsing definition.csv...")
    def_path = os.path.join(game_path, 'map', 'definition.csv')
    color_to_id = {}
    id_to_info = {}
    
    with open(def_path, 'r', encoding='utf-8', errors='ignore') as f:
        for line in f:
            line = line.strip()
            if not line: continue
            parts = line.split(';')
            if len(parts) >= 5:
                try:
                    prov_id = int(parts[0])
                    r, g, b = int(parts[1]), int(parts[2]), int(parts[3])
                    prov_type = parts[4]
                    if (r,g,b) in color_to_id:
                        print(f"Warning: Duplicate color in definition.csv: {r},{g},{b} for ID {prov_id} (already mapped to {color_to_id[(r,g,b)]})")
                    color_to_id[(r, g, b)] = prov_id
                    id_to_info[prov_id] = {'type': prov_type}
                except ValueError:
                    continue
    
    # 4. Parse history/states
    print("Parsing history/states...")
    states_dir = os.path.join(game_path, 'history', 'states')
    prov_to_state = {}
    state_to_owner = {}
    
    states_without_owner = []
    provinces_in_multiple_states = {}
    
    for state_file in glob.glob(os.path.join(states_dir, '*.txt')):
        try:
            with open(state_file, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            tokens = tokenize(content)
            data, _ = parse_pdx(tokens)
            for state_node in data.get('state', []):
                state_id = None
                if 'id' in state_node and state_node['id']:
                    state_id = int(state_node['id'][0])
                
                owner = None
                if 'history' in state_node and state_node['history']:
                    hist = state_node['history'][0]
                    # Base owner
                    if 'owner' in hist and hist['owner']:
                        owner = hist['owner'][0]
                        
                    # Check chronological changes
                    for key, val in hist.items():
                        if key == 'owner' or key == 'add_core_of' or key == 'victory_points': continue
                        if isinstance(val, list) and len(val) > 0 and isinstance(val[0], dict):
                            dt = parse_date(key)
                            if dt and compare_dates(dt, target_date) <= 0:
                                block = val[0]
                                if 'owner' in block and block['owner']:
                                    owner = block['owner'][0]
                                if 'transfer_state_to' in block or 'IF' in block:
                                    print(f"Diagnostic: Unhandled logical block or transfer_state_to in {state_file} at date {key}.")
                
                provinces = []
                if 'provinces' in state_node and state_node['provinces']:
                    provs = state_node['provinces'][0]
                    if '__list__' in provs:
                        for p in provs['__list__']:
                            if p.isdigit():
                                provinces.append(int(p))
                
                if state_id is not None:
                    if owner:
                        state_to_owner[state_id] = owner
                    else:
                        states_without_owner.append(state_id)
                    for p in provinces:
                        if p in prov_to_state:
                            if p not in provinces_in_multiple_states:
                                provinces_in_multiple_states[p] = [prov_to_state[p]]
                            provinces_in_multiple_states[p].append(state_id)
                        prov_to_state[p] = state_id
        except Exception as e:
            print(f"Error parsing {state_file}: {e}")

    # Output validations
    if provinces_in_multiple_states:
        print(f"Warning: {len(provinces_in_multiple_states)} provinces belong to multiple states.")
    if states_without_owner:
        print(f"Warning: {len(states_without_owner)} states have no owner.")
        
    owners_without_color = set()
    for o in state_to_owner.values():
        if o not in country_colors:
            owners_without_color.add(o)
    if owners_without_color:
        print(f"Warning: Owners without color: {', '.join(owners_without_color)}")

    # 5. Analyzing map
    print("Analyzing provinces.bmp...")
    prov_bmp_path = os.path.join(game_path, 'map', 'provinces.bmp')
    img = Image.open(prov_bmp_path).convert('RGB')
    pixels = np.array(img)
    height, width, _ = pixels.shape
    
    encoded_pixels = pixels[:,:,0].astype(np.uint32) << 16 | pixels[:,:,1].astype(np.uint32) << 8 | pixels[:,:,2].astype(np.uint32)
    
    encoded_to_id = np.zeros(16777216, dtype=np.int32) - 1
    for (r, g, b), pid in color_to_id.items():
        encoded_to_id[r << 16 | g << 8 | b] = pid
        
    prov_map = encoded_to_id[encoded_pixels]
    
    unknown_mask = prov_map == -1
    if np.any(unknown_mask):
        print(f"WARNING: Found unknown RGB colors in provinces.bmp!")
        prov_map[unknown_mask] = 0

    unique_on_map = np.unique(prov_map)
    prov_no_state = 0
    for pid in unique_on_map:
        if pid > 0 and id_to_info.get(pid, {}).get('type') == 'land' and pid not in prov_to_state:
            prov_no_state += 1
    if prov_no_state > 0:
        print(f"Warning: {prov_no_state} land provinces have no state.")

    # 6. Generate layers
    print("Generating layers...")
    type_map_arr = np.zeros(prov_map.max() + 1, dtype=np.uint8)
    for pid, info in id_to_info.items():
        if pid < len(type_map_arr):
            t = info.get('type', 'unknown')
            if t == 'land': type_map_arr[pid] = 1
            elif t == 'sea': type_map_arr[pid] = 2
            elif t == 'lake': type_map_arr[pid] = 3
    
    prov_types = type_map_arr[prov_map]
    
    # Flat base
    flat_img = np.zeros((height, width, 4), dtype=np.uint8)
    flat_img[prov_types == 1] = [210, 200, 180, 255]
    flat_img[prov_types == 2] = [150, 180, 200, 255]
    flat_img[prov_types == 3] = [170, 200, 220, 255]
    Image.fromarray(flat_img).save('map_flat.png')
    
    # Political base
    pol_img = np.zeros((height, width, 4), dtype=np.uint8)
    pol_img[prov_types == 2] = [150, 180, 200, 255]
    pol_img[prov_types == 3] = [170, 200, 220, 255]
    
    # Fill land with political colors
    NEUTRAL_COLOR = [180, 180, 180, 255]
    pol_colors = np.zeros((prov_map.max() + 1, 4), dtype=np.uint8)
    pol_colors[:] = [0, 0, 0, 0] # transparent default
    
    for pid in unique_on_map:
        if pid > 0 and type_map_arr[pid] == 1:
            sid = prov_to_state.get(pid)
            owner = state_to_owner.get(sid)
            if owner and owner in country_colors:
                c = country_colors[owner]
                pol_colors[pid] = [c[0], c[1], c[2], 255]
            else:
                pol_colors[pid] = NEUTRAL_COLOR
                
    # Fast indexing
    land_mask = (prov_types == 1)
    pol_img[land_mask] = pol_colors[prov_map[land_mask]]
    
    Image.fromarray(pol_img).save('map_political.png')
    
    # Borders
    prov_map_right = np.roll(prov_map, shift=-1, axis=1)
    prov_map_down = np.roll(prov_map, shift=-1, axis=0)
    
    diff_right = prov_map != prov_map_right
    diff_down = prov_map != prov_map_down
    diff_down[-1, :] = False
    
    coast_r = diff_right & ((prov_types == 1) != (type_map_arr[prov_map_right] == 1))
    coast_d = diff_down & ((prov_types == 1) != (type_map_arr[prov_map_down] == 1))
    coast = coast_r | coast_d
    coast_img = np.zeros((height, width, 4), dtype=np.uint8)
    coast_img[coast] = [0, 0, 0, 255]
    Image.fromarray(coast_img).save('borders_coast.png')
    
    prov_border_img = np.zeros((height, width, 4), dtype=np.uint8)
    # Province borders only on land
    prov_b_r = diff_right & (prov_types == 1) & (type_map_arr[prov_map_right] == 1)
    prov_b_d = diff_down & (prov_types == 1) & (type_map_arr[prov_map_down] == 1)
    prov_border_img[prov_b_r | prov_b_d] = [50, 50, 50, 80]
    Image.fromarray(prov_border_img).save('borders_province.png')
    
    state_arr = np.zeros(prov_map.max() + 1, dtype=np.int32)
    for pid, sid in prov_to_state.items():
        if pid < len(state_arr):
            state_arr[pid] = sid
            
    prov_states = state_arr[prov_map]
    prov_states_right = state_arr[prov_map_right]
    prov_states_down = state_arr[prov_map_down]
    
    land_r = (prov_types == 1) & (type_map_arr[prov_map_right] == 1)
    land_d = (prov_types == 1) & (type_map_arr[prov_map_down] == 1)
    
    state_border_r = land_r & diff_right & (prov_states != prov_states_right)
    state_border_d = land_d & diff_down & (prov_states != prov_states_down)
    state_border = state_border_r | state_border_d
    state_img = np.zeros((height, width, 4), dtype=np.uint8)
    state_img[state_border] = [100, 100, 100, 150]
    Image.fromarray(state_img).save('borders_state.png')
    
    country_to_int = {'': 0}
    next_cid = 1
    country_arr = np.zeros(prov_map.max() + 1, dtype=np.int32)
    for pid, sid in prov_to_state.items():
        if pid < len(country_arr):
            owner = state_to_owner.get(sid, '')
            if owner not in country_to_int:
                country_to_int[owner] = next_cid
                next_cid += 1
            country_arr[pid] = country_to_int[owner]
            
    prov_countries = country_arr[prov_map]
    prov_countries_right = country_arr[prov_map_right]
    prov_countries_down = country_arr[prov_map_down]
    
    country_border_r = land_r & diff_right & (prov_countries != prov_countries_right)
    country_border_d = land_d & diff_down & (prov_countries != prov_countries_down)
    country_border = country_border_r | country_border_d
    country_img = np.zeros((height, width, 4), dtype=np.uint8)
    country_img[country_border] = [200, 50, 50, 200]
    Image.fromarray(country_img).save('borders_country.png')
    
    prov_id_img = np.zeros((height, width, 4), dtype=np.uint8)
    prov_id_img[:,:,0] = prov_map & 0xFF
    prov_id_img[:,:,1] = (prov_map >> 8) & 0xFF
    prov_id_img[:,:,2] = (prov_map >> 16) & 0xFF
    prov_id_img[:,:,3] = 255
    Image.fromarray(prov_id_img).save('province_id.png')
    
    output_data = {}
    for pid in unique_on_map:
        if pid == 0: continue
        sid = prov_to_state.get(pid)
        owner = state_to_owner.get(sid, '') if sid else ''
        output_data[int(pid)] = {
            'type': id_to_info.get(pid, {}).get('type', 'unknown'),
            'state': sid,
            'owner': owner
        }
    with open('data.json', 'w') as f:
        json.dump(output_data, f)
        
    with open('metadata.json', 'w') as f:
        json.dump(metadata, f)
        
    with open('colors.json', 'w') as f:
        json.dump(country_colors, f)
        
    print("Done! Generated PNGs and data.")

if __name__ == '__main__':
    main()
