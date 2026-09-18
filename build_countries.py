import json
import numpy as np
from PIL import Image
from collections import defaultdict
import math
import os

def smooth_segment(seg, iterations=2, window=3):
    if len(seg) < 3: return seg
    res = np.array(seg, dtype=float)
    for _ in range(iterations):
        smoothed = np.copy(res)
        for i in range(1, len(res)-1):
            smoothed[i] = np.mean(res[max(0, i-window//2) : min(len(res), i+window//2+1)], axis=0)
        res = smoothed
    return res.tolist()

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

def polygon_signed_area(poly):
    n = len(poly)
    if n < 3: return 0
    area = 0.0
    for i in range(n):
        x0, y0 = poly[i]
        x1, y1 = poly[(i + 1) % n]
        area += (x0 * y1 - x1 * y0)
    return area * 0.5

def point_in_polygon(x, y, poly):
    n = len(poly)
    inside = False
    p1x, p1y = poly[0]
    for i in range(1, n + 1):
        p2x, p2y = poly[i % n]
        if y > min(p1y, p2y):
            if y <= max(p1y, p2y):
                if x <= max(p1x, p2x):
                    if p1y != p2y:
                        xinters = (y - p1y) * (p2x - p1x) / (p2y - p1y) + p1x
                    if p1x == p2x or x <= xinters:
                        inside = not inside
        p1x, p1y = p2x, p2y
    return inside

def parse_hoi4_names():
    res = {}
    path = r"D:\Games\Hearts of Iron IV (2016)\Hearts of Iron IV\localisation\english\countries_l_english.yml"
    if not os.path.exists(path):
        return res
        
    with open(path, "r", encoding="utf-8-sig") as f:
        for line in f:
            if ":" not in line: continue
            k, v = line.split(":", 1)
            k = k.strip()
            v = v.strip().strip('"').strip('0').strip('"').strip()
            res[k] = v
            
    return res

def get_1936_name(tag, loc_dict):
    mapping = {
        "GER": "GER_fascism",
        "SOV": "SOV_communism",
        "USA": "USA_democratic",
        "ENG": "ENG_democratic",
        "FRA": "FRA_democratic",
        "ITA": "ITA_fascism",
        "JAP": "JAP_fascism",
        "CHI": "CHI_non_aligned",
    }
    
    if tag == "RAJ":
        for k in ["RAJ_autonomy_integrated_puppet", "RAJ_democratic", "RAJ_fascism", "RAJ"]:
            if k in loc_dict: return loc_dict[k]
            
    target_key = mapping.get(tag, tag)
    if target_key in loc_dict: return loc_dict[target_key]
    
    if tag in loc_dict: return loc_dict[tag]
    if tag + "_def" in loc_dict: return loc_dict[tag + "_def"]
    return tag

print("Loading states.json...")
with open("states.json", "r", encoding="utf-8") as f:
    states_data = json.load(f)

state_to_owner = {0: "WATER"}
for sid_str, info in states_data.items():
    state_to_owner[int(sid_str)] = info.get("owner", "None")

print("Loading state_id.png...")
state_img = Image.open('state_id.png').convert('RGB')
state_arr = np.array(state_img)
state_map = state_arr[:,:,0].astype(np.int32) + (state_arr[:,:,1].astype(np.int32) << 8) + (state_arr[:,:,2].astype(np.int32) << 16)

h, w = state_map.shape
padded = np.zeros((h + 2, w + 2), dtype=np.int32) - 1
padded[1:-1, 1:-1] = state_map

owner_to_id = {"WATER": 0, "None": -1}
next_oid = 1
for owner in set(state_to_owner.values()):
    if owner not in owner_to_id:
        owner_to_id[owner] = next_oid
        next_oid += 1
id_to_owner = {v: k for k, v in owner_to_id.items()}

state_to_oid = np.zeros(max(state_to_owner.keys()) + 2, dtype=np.int32)
for sid, owner in state_to_owner.items():
    state_to_oid[sid] = owner_to_id[owner]

valid_mask = (padded >= 0) & (padded < len(state_to_oid))
owner_map = np.zeros_like(padded, dtype=np.int32) - 1
owner_map[valid_mask] = state_to_oid[padded[valid_mask]]

print("Extracting country edges...")
edges = {}
adj = defaultdict(list)

for y in range(h+1):
    for x in range(w+1):
        o1 = owner_map[y, x]
        o2 = owner_map[y, x+1]
        if o1 != o2 and (o1 > 0 or o2 > 0):
            edges[((x+1, y+1), (x+1, y))] = (o1, o2)
            edges[((x+1, y), (x+1, y+1))] = (o2, o1)
            adj[(x+1, y+1)].append((x+1, y))
            adj[(x+1, y)].append((x+1, y+1))

for y in range(h+1):
    for x in range(w+1):
        o1 = owner_map[y, x]
        o2 = owner_map[y+1, x]
        if o1 != o2 and (o1 > 0 or o2 > 0):
            edges[((x, y+1), (x+1, y+1))] = (o1, o2)
            edges[((x+1, y+1), (x, y+1))] = (o2, o1)
            adj[(x, y+1)].append((x+1, y+1))
            adj[(x+1, y+1)].append((x, y+1))

print("Tracing segments...")
junctions = {v for v, neighbors in adj.items() if len(neighbors) != 2}
junction_set = set(junctions)
unvisited_edges = set((u, v) for u in adj for v in adj[u])

visited_edges = set()
segments = []

for start_v in list(junction_set):
    for nxt in list(adj[start_v]):
        if (start_v, nxt) not in visited_edges:
            path = [start_v, nxt]
            visited_edges.add((start_v, nxt))
            visited_edges.add((nxt, start_v))
            unvisited_edges.discard((start_v, nxt))
            unvisited_edges.discard((nxt, start_v))
            
            o_left, o_right = edges[(start_v, nxt)]
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
                
            segments.append({"path": path, "o_left": o_left, "o_right": o_right})

while unvisited_edges:
    u, v = unvisited_edges.pop()
    unvisited_edges.add((u, v))
    path = [u]
    curr = u
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
        if curr == u: break
            
    o_left, o_right = edges[(path[0], path[1])]
    segments.append({"path": path, "o_left": o_left, "o_right": o_right})

for seg in segments:
    path = seg["path"]
    smoothed = smooth_segment(path)
    smoothed = [[float(round(p[0]-1, 2)), float(round(p[1]-1, 2))] for p in smoothed]
    seg["lod0"] = smoothed
    seg["lod1"] = simplify_segment(smoothed, 1.0)
    seg["lod2"] = simplify_segment(smoothed, 5.0)

country_arcs = defaultdict(list)
for seg in segments:
    o_left, o_right = seg["o_left"], seg["o_right"]
    if o_right > 0:
        country_arcs[id_to_owner[o_right]].append({ "lod0": seg["lod0"], "lod1": seg["lod1"], "lod2": seg["lod2"] })
    if o_left > 0:
        country_arcs[id_to_owner[o_left]].append({ "lod0": seg["lod0"][::-1], "lod1": seg["lod1"][::-1], "lod2": seg["lod2"][::-1] })

def pt_key(p): return (round(p[0], 2), round(p[1], 2))

def build_rings(arcs, lod_key):
    next_arc = defaultdict(list)
    for i, arc in enumerate(arcs):
        next_arc[pt_key(arc[lod_key][0])].append(i)
        
    used = set()
    rings = []
    for i in range(len(arcs)):
        if i in used: continue
        ring = []
        curr = i
        while True:
            used.add(curr)
            arc_pts = arcs[curr][lod_key]
            ring.extend(arc_pts[:-1])
            nxts = [n for n in next_arc.get(pt_key(arc_pts[-1]), []) if n not in used]
            if not nxts: break
            curr = nxts[0]
            if curr == i: break
        if ring:
            ring.append(ring[0])
            rings.append(ring)
    return rings

country_polygons = {}
for owner, arcs in country_arcs.items():
    if owner in ["WATER", "None"]: continue
    country_polygons[owner] = {
        "lod0": build_rings(arcs, "lod0"),
        "lod1": build_rings(arcs, "lod1"),
        "lod2": build_rings(arcs, "lod2")
    }

country_lines = {"lod0": [s["lod0"] for s in segments], "lod1": [s["lod1"] for s in segments], "lod2": [s["lod2"] for s in segments]}

def find_pole_of_inaccessibility(poly, step_count=20):
    min_x = min(p[0] for p in poly)
    max_x = max(p[0] for p in poly)
    min_y = min(p[1] for p in poly)
    max_y = max(p[1] for p in poly)
    
    step_x = (max_x - min_x) / step_count
    step_y = (max_y - min_y) / step_count
    if step_x == 0 or step_y == 0: return (min_x, min_y), 0
    
    best_pt = (min_x, min_y)
    best_dist = -1
    for x in np.arange(min_x, max_x, step_x):
        for y in np.arange(min_y, max_y, step_y):
            if point_in_polygon(x, y, poly):
                # Approximation of distance to edge for speed, using segment distances
                # Actually dist_to_poly might be slow in python if N=10000, 
                # but we can subsample the polygon for distance check!
                # Since we already have lod2 (highly simplified), we can use lod2 for POI!
                pass
                
# Wait, let's use the Python POI logic we already had!
def point_to_segment_dist_sq(px, py, x1, y1, x2, y2):
    l2 = (x2 - x1)**2 + (y2 - y1)**2
    if l2 == 0: return (px - x1)**2 + (py - y1)**2
    t = max(0, min(1, ((px - x1)*(x2 - x1) + (py - y1)*(y2 - y1)) / l2))
    proj_x = x1 + t * (x2 - x1)
    proj_y = y1 + t * (y2 - y1)
    return (px - proj_x)**2 + (py - proj_y)**2

def dist_to_poly(px, py, poly):
    min_d2 = float('inf')
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i+1)%n]
        d2 = point_to_segment_dist_sq(px, py, x1, y1, x2, y2)
        if d2 < min_d2: min_d2 = d2
    return math.sqrt(min_d2)

def find_pole_of_inaccessibility(poly, step_count=15):
    # use a simplified poly for distance check to save time
    if len(poly) > 100:
        simple_poly = poly[::len(poly)//100]
    else:
        simple_poly = poly
        
    min_x = min(p[0] for p in poly)
    max_x = max(p[0] for p in poly)
    min_y = min(p[1] for p in poly)
    max_y = max(p[1] for p in poly)
    
    step_x = (max_x - min_x) / step_count
    step_y = (max_y - min_y) / step_count
    if step_x == 0 or step_y == 0: return (min_x, min_y), 0
    
    best_pt = (min_x, min_y)
    best_dist = -1
    for x in np.arange(min_x, max_x, step_x):
        for y in np.arange(min_y, max_y, step_y):
            if point_in_polygon(x, y, poly):
                d = dist_to_poly(x, y, simple_poly)
                if d > best_dist:
                    best_dist = d
                    best_pt = (x, y)
    return best_pt, best_dist

print("Grouping components...")
loc_dict = parse_hoi4_names()

country_components = []
label_id_counter = 1

for owner, poly_data in country_polygons.items():
    rings = poly_data["lod0"]
    if not rings: continue
    
    owner_name = get_1936_name(owner, loc_dict)
    
    ring_areas = [(polygon_signed_area(r), r) for r in rings]
    if not ring_areas: continue
    max_abs_area = max(abs(a) for a, r in ring_areas)
    
    min_area_thresh = max(400, max_abs_area * 0.05)
    sign_val = 1 if next(a for a, r in ring_areas if abs(a) == max_abs_area) > 0 else -1
    
    outer_rings = []
    holes = []
    for a, r in ring_areas:
        if (a * sign_val) > 0:
            if abs(a) > min_area_thresh:
                outer_rings.append(r)
        else:
            holes.append(r)
            
    for outer in outer_rings:
        comp_holes = []
        for h in holes:
            if point_in_polygon(h[0][0], h[0][1], outer):
                comp_holes.append(h)
                
        pt, dist = find_pole_of_inaccessibility(outer, step_count=15)
        
        country_components.append({
            "label_id": label_id_counter,
            "owner": owner,
            "name": owner_name.upper(),
            "poi": pt,
            "outer": outer,
            "holes": comp_holes
        })
        label_id_counter += 1

countries_json = {
    "components": country_components,
    "lines": country_lines,
    "polygons": country_polygons
}

# Write to temp file first to prevent corruption
with open("countries.tmp.json", "w", encoding="utf-8") as f:
    json.dump(countries_json, f, separators=(',', ':'))
    
os.replace("countries.tmp.json", "countries.json")

print(f"Done! Built countries.json with {len(country_components)} components.")
