import os
import json

hoi4_path = r'D:\Games\Hearts of Iron IV (2016)\Hearts of Iron IV'

def parse_loc(path):
    d = {}
    if not os.path.exists(path): return d
    with open(path, 'r', encoding='utf-8-sig') as f:
        for line in f:
            if ':' not in line: continue
            k, v = line.split(':', 1)
            k = k.strip()
            v = v.strip().strip('\"').strip('0').strip('\"').strip()
            d[k] = v
    return d

ru_states = parse_loc(os.path.join(hoi4_path, r'localisation\russian\state_names_l_russian.yml'))
en_states = parse_loc(os.path.join(hoi4_path, r'localisation\english\state_names_l_english.yml'))

ru_countries = parse_loc(os.path.join(hoi4_path, r'localisation\russian\countries_l_russian.yml'))
en_countries = parse_loc(os.path.join(hoi4_path, r'localisation\english\countries_l_english.yml'))

state_keys = {}
states_dir = os.path.join(hoi4_path, 'history', 'states')
if os.path.exists(states_dir):
    for f in os.listdir(states_dir):
        if not f.endswith('.txt'): continue
        path = os.path.join(states_dir, f)
        sid = f.split('-')[0].strip()
        try: sid = int(sid)
        except: continue
        name_key = f'STATE_{sid}'
        with open(path, 'r', encoding='utf-8', errors='ignore') as sf:
            content = sf.read()
            for line in content.split('\n'):
                line = line.strip()
                if line.startswith('name'):
                    parts = line.split('=')
                    if len(parts) > 1:
                        val = parts[1].split('#')[0].strip().strip('\"')
                        name_key = val
                        break
        state_keys[sid] = name_key

state_names = {}
for sid, key in state_keys.items():
    if key in ru_states: name = ru_states[key]
    elif key in en_states: name = en_states[key]
    else: name = f'Регион {sid}'
    state_names[str(sid)] = name

def get_1936_name(tag, loc_dict):
    mapping = {
        'GER': 'GER_fascism',
        'SOV': 'SOV_communism',
        'USA': 'USA_democratic',
        'ENG': 'ENG_democratic',
        'FRA': 'FRA_democratic',
        'ITA': 'ITA_fascism',
        'JAP': 'JAP_fascism',
        'CHI': 'CHI_non_aligned',
    }
    if tag == 'RAJ':
        for k in ['RAJ_autonomy_integrated_puppet', 'RAJ_democratic', 'RAJ_fascism', 'RAJ']:
            if k in loc_dict: return loc_dict[k]
    target_key = mapping.get(tag, tag)
    if target_key in loc_dict: return loc_dict[target_key]
    if tag in loc_dict: return loc_dict[tag]
    if tag + '_def' in loc_dict: return loc_dict[tag + '_def']
    return tag

country_names = {}
with open('states.json', 'r', encoding='utf-8') as f:
    st_data = json.load(f)
tags = set(v.get('owner', 'None') for v in st_data.values())

for tag in tags:
    if tag in ['WATER', 'None']: continue
    name_ru = get_1936_name(tag, ru_countries)
    if name_ru == tag: name_ru = get_1936_name(tag, en_countries)
    country_names[tag] = name_ru

out = {'states': state_names, 'countries': country_names}
with open('ui_data.json', 'w', encoding='utf-8') as f:
    json.dump(out, f, ensure_ascii=False, indent=2)
print('Saved ui_data.json')
