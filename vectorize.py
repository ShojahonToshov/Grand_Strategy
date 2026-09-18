import json
import numpy as np
from PIL import Image
from collections import defaultdict
import time

def smooth_segment(seg, iterations=2, window=3):
    if len(seg) < 3: return seg
    res = np.array(seg, dtype=float)
    for _ in range(iterations):
        smoothed = np.copy(res)
        for i in range(1, len(res)-1):
            smoothed[i] = np.mean(res[max(0, i-window//2) : min(len(res), i+window//2+1)], axis=0)
        res = smoothed
    return res.tolist()

def trace_segments(adj):
    junctions = {v for v, neighbors in adj.items() if len(neighbors) != 2}
    if not junctions:
        if not adj: return []
        v = next(iter(adj.keys()))
        junctions.add(v)

    segments = []
    visited_edges = set()
    
    for v in list(junctions):
        for n in adj[v]:
            edge = tuple(sorted((v, n)))
            if edge in visited_edges: continue
            segment = [v, n]
            visited_edges.add(edge)
            curr = n
            while curr not in junctions:
                nxts = [x for x in adj[curr] if tuple(sorted((curr, x))) not in visited_edges]
                if not nxts: break
                nxt = nxts[0]
                visited_edges.add(tuple(sorted((curr, nxt))))
                segment.append(nxt)
                curr = nxt
            segments.append(segment)
            
    for v, neighbors in adj.items():
        for n in neighbors:
            edge = tuple(sorted((v, n)))
            if edge not in visited_edges:
                segment = [v, n]
                visited_edges.add(edge)
                curr = n
                while True:
                    nxts = [x for x in adj[curr] if tuple(sorted((curr, x))) not in visited_edges]
                    if not nxts: break
                    nxt = nxts[0]
                    visited_edges.add(tuple(sorted((curr, nxt))))
                    segment.append(nxt)
                    curr = nxt
                segments.append(segment)
                
    return segments

print("Loading data...")
with open("data.json", "r", encoding="utf-8") as f:
    data = json.load(f)
    prov_to_owner = {int(k): v.get("owner", "") for k, v in data.items()}
    prov_to_state = {int(k): v.get("state", 0) for k, v in data.items()}
    prov_to_type = {int(k): (1 if v.get("type")=="land" else 0) for k, v in data.items()}

prov_img = Image.open('province_id.png').convert('RGB')
prov_arr = np.array(prov_img)
prov_map = prov_arr[:,:,0].astype(np.int32) + (prov_arr[:,:,1].astype(np.int32) << 8) + (prov_arr[:,:,2].astype(np.int32) << 16)

h, w = prov_map.shape
padded = np.zeros((h + 2, w + 2), dtype=np.int32) - 1
padded[1:-1, 1:-1] = prov_map

print("Finding edges...")
diff_v = padded[:, :-1] != padded[:, 1:] 
diff_h = padded[:-1, :] != padded[1:, :]

y_v, x_v = np.nonzero(diff_v)
y_h, x_h = np.nonzero(diff_h)

adj = defaultdict(list)
for y, x in zip(y_v, x_v):
    adj[(x+1, y)].append((x+1, y+1))
    adj[(x+1, y+1)].append((x+1, y))
for y, x in zip(y_h, x_h):
    adj[(x, y+1)].append((x+1, y+1))
    adj[(x+1, y+1)].append((x, y+1))

print("Tracing segments...")
segments = trace_segments(adj)
print(f"Found {len(segments)} segments")

print("Classifying and smoothing...")
coast_lines = []
country_lines = []
state_lines = []
prov_lines = []

for seg in segments:
    v1, v2 = seg[0], seg[1]
    if v1[0] == v2[0]:
        x = v1[0]; y = min(v1[1], v2[1])
        p1 = padded[y, x-1]; p2 = padded[y, x]
    else:
        y = v1[1]; x = min(v1[0], v2[0])
        p1 = padded[y-1, x]; p2 = padded[y, x]
        
    if p1 == -1 or p2 == -1:
        continue
        
    smoothed = smooth_segment(seg)
    # Convert to 1 decimal place to save space
    smoothed = [[float(round(p[0]-1, 1)), float(round(p[1]-1, 1))] for p in smoothed] # subtract 1 because of padding!
    
    t1 = prov_to_type.get(p1, 0)
    t2 = prov_to_type.get(p2, 0)
    
    if t1 != t2:
        coast_lines.append(smoothed)
    elif t1 == 1 and t2 == 1:
        o1 = prov_to_owner.get(p1, "")
        o2 = prov_to_owner.get(p2, "")
        if o1 != o2:
            country_lines.append(smoothed)
        else:
            s1 = prov_to_state.get(p1, 0)
            s2 = prov_to_state.get(p2, 0)
            if s1 != s2:
                state_lines.append(smoothed)
            else:
                prov_lines.append(smoothed)

print("Saving lines.json...")
with open("lines.json", "w") as f:
    json.dump({"coast": coast_lines, "country": country_lines, "state": state_lines, "prov": prov_lines}, f, separators=(',', ':'))
print("Done!")
