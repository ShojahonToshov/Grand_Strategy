import json
from PIL import Image

def is_water(px):
    # Depending on format, water is 0,0,0
    return px[0] == 0 and px[1] == 0 and px[2] == 0

def extract_coastlines():
    print("Loading image...")
    img = Image.open('state_id.png')
    pixels = img.load()
    
    print("Loading external_lines.json...")
    with open('external_lines.json') as f:
        ext_data = json.load(f)
        
    coast_data = {"lod0": [], "lod1": [], "lod2": []}
    
    for lod in ["lod0", "lod1", "lod2"]:
        if lod not in ext_data: continue
        for line in ext_data[lod]:
            if len(line) < 2: continue
            # Sample a few points along the line to check if they touch water
            # A line is a coast if ANY part of it touches water in the state_id map
            # We can check the midpoint of the first segment
            p1 = line[0]
            p2 = line[1]
            mx, my = int((p1[0] + p2[0])/2), int((p1[1] + p2[1])/2)
            
            # Look at a 3x3 neighborhood around the midpoint
            touches_water = False
            for dy in range(-2, 3):
                for dx in range(-2, 3):
                    nx, ny = mx + dx, my + dy
                    if 0 <= nx < img.width and 0 <= ny < img.height:
                        if is_water(pixels[nx, ny]):
                            touches_water = True
                            break
                if touches_water: break
                
            if touches_water:
                coast_data[lod].append(line)
                
    with open('coast_lines.json', 'w') as f:
        json.dump(coast_data, f)
    print("Saved coast_lines.json!")

if __name__ == "__main__":
    extract_coastlines()
