import json
import numpy as np
from PIL import Image

print("Loading data.json...")
with open("data.json", "r", encoding="utf-8") as f:
    prov_data = json.load(f)

print("Loading province_id.png...")
prov_img = Image.open('province_id.png').convert('RGB')
prov_arr = np.array(prov_img)
prov_map = prov_arr[:,:,0].astype(np.int32) + (prov_arr[:,:,1].astype(np.int32) << 8) + (prov_arr[:,:,2].astype(np.int32) << 16)

state_data = {}
prov_to_state = {0: 0} # 0 is edge or unknown

conflicts = 0
for pid_str, info in prov_data.items():
    pid = int(pid_str)
    ptype = info.get("type")
    if ptype in ("sea", "lake"):
        prov_to_state[pid] = 0
    else:
        sid = info.get("state")
        if sid is None:
            prov_to_state[pid] = 0
            continue
            
        prov_to_state[pid] = sid
        owner = info.get("owner", "")
        
        if sid not in state_data:
            state_data[sid] = {"owner": set()}
            
        if owner:
            state_data[sid]["owner"].add(owner)

# Resolve sets to strings
print("Checking for conflicting owners...")
for sid, info in state_data.items():
    owners = info["owner"]
    if len(owners) > 1:
        conflicts += 1
        print(f"State {sid} has multiple owners: {owners}")
        info["owner"] = ", ".join(sorted(list(owners)))
    elif len(owners) == 1:
        info["owner"] = next(iter(owners))
    else:
        info["owner"] = "None"

print(f"Found {conflicts} states with conflicting owners.")

print("Saving states.json...")
with open("states.json", "w", encoding="utf-8") as f:
    json.dump(state_data, f, indent=2)

print("Generating state_id.png...")
# Map prov_map to state_map
# Create a vectorized lookup
max_pid = np.max(prov_map)
lookup = np.zeros(max_pid + 1, dtype=np.int32)
for pid, sid in prov_to_state.items():
    if pid <= max_pid:
        lookup[pid] = sid

state_map = lookup[prov_map]

state_img_arr = np.zeros((state_map.shape[0], state_map.shape[1], 4), dtype=np.uint8)
state_img_arr[:,:,0] = state_map & 0xFF
state_img_arr[:,:,1] = (state_map >> 8) & 0xFF
state_img_arr[:,:,2] = (state_map >> 16) & 0xFF
state_img_arr[:,:,3] = 255

state_img = Image.fromarray(state_img_arr, 'RGBA')
state_img.save("state_id.png")
print("Done!")
