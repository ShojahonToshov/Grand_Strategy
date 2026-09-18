import json
import numpy as np
from PIL import Image
from collections import defaultdict
import math

def simplify_segment(seg, epsilon=0.5):
    if len(seg) < 3: return seg
    pts = np.array(seg)
    line_vec = pts[-1] - pts[0]
    line_len = np.linalg.norm(line_vec)
    if line_len == 0:
        dists = np.linalg.norm(pts - pts[0], axis=1)
    else:
        line_unit = line_vec / line_len
        p_vecs = pts - pts[0]
        projs = np.dot(p_vecs, line_unit)
        projs = np.clip(projs, 0, line_len)
        closest = pts[0] + np.outer(projs, line_unit)
        dists = np.linalg.norm(pts - closest, axis=1)
    dmax = np.max(dists)
    index = np.argmax(dists)
    if dmax > epsilon:
        res1 = simplify_segment(seg[:index+1], epsilon)
        res2 = simplify_segment(seg[index:], epsilon)
        return res1[:-1] + res2
    else:
        return [seg[0], seg[-1]]

def smooth_segment(seg, iterations=2, window=3):
    if len(seg) < 3: return seg
    res = np.array(seg, dtype=float)
    for _ in range(iterations):
        smoothed = np.copy(res)
        for i in range(1, len(res)-1):
            smoothed[i] = np.mean(res[max(0, i-window//2) : min(len(res), i+window//2+1)], axis=0)
        res = smoothed
    return res.tolist()

print("Loading state_id.png...")
state_img = Image.open('state_id.png').convert('RGB')
state_arr = np.array(state_img)
state_map = state_arr[:,:,0].astype(np.int32) + (state_arr[:,:,1].astype(np.int32) << 8) + (state_arr[:,:,2].astype(np.int32) << 16)

h, w = state_map.shape
padded = np.zeros((h + 2, w + 2), dtype=np.int32) - 1
padded[1:-1, 1:-1] = state_map

# Extract edges with orientation. 
# Edge format: ( (x1,y1), (x2,y2) ) where state on RIGHT is state_right, state on LEFT is state_left
# For horizontal borders (between y and y+1):
# if padded[y, x] = S1 and padded[y+1, x] = S2
# edge goes from (x, y+1) to (x+1, y+1). S2 is on RIGHT, S1 is on LEFT.
# For vertical borders (between x and x+1):
# if padded[y, x] = S1 and padded[y, x+1] = S2
# edge goes from (x+1, y+1) to (x+1, y). S2 is on RIGHT, S1 is on LEFT.

edges = {} # (p1, p2) -> (state_left, state_right)
adj = defaultdict(list)
# We want edges where AT LEAST ONE state is > 0. If both are 0, it's water-water, ignore.
# Vertical edges:
for y in range(h+1):
    for x in range(w+1):
        s1 = padded[y, x]
        s2 = padded[y, x+1]
        if s1 != s2 and (s1 > 0 or s2 > 0):
            # Edge from (x+1, y+1) to (x+1, y)
            p1 = (x+1, y+1)
            p2 = (x+1, y)
            edges[(p1, p2)] = (s1, s2)
            edges[(p2, p1)] = (s2, s1)
            adj[p1].append(p2)
            adj[p2].append(p1)
            
# Horizontal edges:
for y in range(h+1):
    for x in range(w+1):
        s1 = padded[y, x]
        s2 = padded[y+1, x]
        if s1 != s2 and (s1 > 0 or s2 > 0):
            # Edge from (x, y+1) to (x+1, y+1)
            p1 = (x, y+1)
            p2 = (x+1, y+1)
            edges[(p1, p2)] = (s1, s2)
            edges[(p2, p1)] = (s2, s1)
            adj[p1].append(p2)
            adj[p2].append(p1)

# Find junctions (degree != 2)
junctions = {v for v, neighbors in adj.items() if len(neighbors) != 2}

# Trace segments
# A segment is a path between two junctions. If there's a closed loop without junctions, one point is chosen as a junction.
visited_edges = set()
segments = []

# Tracing efficiently
junction_set = set(junctions)
unvisited_edges = set()
for u in adj:
    for v in adj[u]:
        unvisited_edges.add((u, v))

# We also need a fast way to find unvisited edges from junctions
# Actually, we can just iterate over all junctions, and for each, process all its unvisited outgoing edges!
for start_v in list(junction_set):
    # For each outgoing edge from start_v
    for nxt in list(adj[start_v]):
        if (start_v, nxt) not in visited_edges:
            # We found an unvisited segment starting from start_v
            path = [start_v, nxt]
            visited_edges.add((start_v, nxt))
            visited_edges.add((nxt, start_v))
            unvisited_edges.discard((start_v, nxt))
            unvisited_edges.discard((nxt, start_v))
            
            s_left, s_right = edges[(start_v, nxt)]
            curr = nxt
            
            while curr not in junction_set:
                nxts = [n for n in adj[curr] if (curr, n) not in visited_edges]
                if not nxts: break
                nxt = nxts[0]
                visited_edges.add((curr, nxt))
                visited_edges.add((nxt, curr))
                unvisited_edges.discard((curr, nxt))
                unvisited_edges.discard((nxt, curr))
                path.append(nxt)
                curr = nxt
                
            segments.append({
                "path": path,
                "state_left": s_left,
                "state_right": s_right
            })

# Any remaining unvisited edges belong to isolated loops without any junctions.
while unvisited_edges:
    u, v = unvisited_edges.pop()
    unvisited_edges.add((u, v)) # put it back to start loop
    start_v = u
    path = [start_v]
    curr = start_v
    
    while True:
        nxts = [n for n in adj[curr] if (curr, n) not in visited_edges]
        if not nxts: break
        nxt = nxts[0]
        visited_edges.add((curr, nxt))
        visited_edges.add((nxt, curr))
        unvisited_edges.discard((curr, nxt))
        unvisited_edges.discard((nxt, curr))
        path.append(nxt)
        curr = nxt
        if curr == start_v:
            break
            
    # For isolated loops, the first edge dictates left/right
    s_left, s_right = edges[(path[0], path[1])]
    segments.append({
        "path": path,
        "state_left": s_left,
        "state_right": s_right
    })

print(f"Traced {len(segments)} segments.")

# Smooth and LOD
print("Applying LODs...")
for seg in segments:
    path = seg["path"]
    smoothed = smooth_segment(path)
    # shift padding by -1
    smoothed = [[float(round(p[0]-1, 2)), float(round(p[1]-1, 2))] for p in smoothed]
    seg["lod0"] = smoothed
    seg["lod1"] = simplify_segment(smoothed, 1.0)
    seg["lod2"] = simplify_segment(smoothed, 5.0)

# Build state boundaries
# For each state, we want to construct closed polygons.
# A state is formed by segments where state_right == S or state_left == S.
# If state_right == S, the segment (as is) goes around S counter-clockwise (wait, let's verify).
# For top-left pixel (0,0), S1 is inside, S2 is right. Edge goes (1,1)->(1,0). Right is S2.
# Standard: if state is on RIGHT, the path bounds it.
# We will collect all directed paths that have S on RIGHT.
# If a segment has state_left == S, we reverse it, so S is on RIGHT.

state_arcs = defaultdict(list)
for seg in segments:
    s_left = seg["state_left"]
    s_right = seg["state_right"]
    
    if s_right > 0:
        state_arcs[s_right].append({ "lod0": seg["lod0"], "lod1": seg["lod1"], "lod2": seg["lod2"] })
    if s_left > 0:
        state_arcs[s_left].append({ "lod0": seg["lod0"][::-1], "lod1": seg["lod1"][::-1], "lod2": seg["lod2"][::-1] })

# We want to connect the arcs into closed rings for each LOD
def build_rings(arcs, lod_key):
    # build a map from start_point to arc
    # due to float rounding, use a tight tolerance or exact string/tuple
    def pt_key(p): return (round(p[0], 2), round(p[1], 2))
    
    next_arc = defaultdict(list)
    for i, arc in enumerate(arcs):
        start_pt = pt_key(arc[lod_key][0])
        next_arc[start_pt].append(i)
        
    used = set()
    rings = []
    
    for i in range(len(arcs)):
        if i in used: continue
        
        ring = []
        curr = i
        while True:
            used.add(curr)
            arc_pts = arcs[curr][lod_key]
            # append all points except the last (which is the first of next)
            ring.extend(arc_pts[:-1])
            
            end_pt = pt_key(arc_pts[-1])
            nxts = next_arc.get(end_pt, [])
            # Find an unused next arc
            nxt_unused = [n for n in nxts if n not in used]
            if not nxt_unused:
                break
            curr = nxt_unused[0]
            if curr == i:
                break
                
        # Close the ring
        if ring:
            ring.append(ring[0])
            rings.append(ring)
            
    return rings

state_polygons = {}
for sid, arcs in state_arcs.items():
    state_polygons[str(sid)] = {
        "lod0": build_rings(arcs, "lod0"),
        "lod1": build_rings(arcs, "lod1"),
        "lod2": build_rings(arcs, "lod2")
    }

print("Saving state_polygons.json...")
with open("state_polygons.json", "w") as f:
    json.dump(state_polygons, f, separators=(',', ':'))

print("Loading states.json to check owners...")
with open("states.json", "r", encoding="utf-8") as f:
    states_data = json.load(f)

def get_owner(sid):
    if sid <= 0: return "WATER"
    return states_data.get(str(sid), {}).get("owner", "None")

internal_lines = {"lod0": [], "lod1": [], "lod2": []}
external_lines = {"lod0": [], "lod1": [], "lod2": []}

for seg in segments:
    o_left = get_owner(seg["state_left"])
    o_right = get_owner(seg["state_right"])
    
    if o_left == o_right and o_left not in ["WATER", "None"]:
        internal_lines["lod0"].append(seg["lod0"])
        internal_lines["lod1"].append(seg["lod1"])
        internal_lines["lod2"].append(seg["lod2"])
    else:
        external_lines["lod0"].append(seg["lod0"])
        external_lines["lod1"].append(seg["lod1"])
        external_lines["lod2"].append(seg["lod2"])

print("Saving internal_lines.json...")
with open("internal_lines.json", "w") as f:
    json.dump(internal_lines, f, separators=(',', ':'))

print("Saving external_lines.json...")
with open("external_lines.json", "w") as f:
    json.dump(external_lines, f, separators=(',', ':'))

print("Done!")
