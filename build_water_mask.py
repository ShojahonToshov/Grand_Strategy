import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt

def main():
    print("Loading state_id.png...")
    img = Image.open("state_id.png")
    arr = np.array(img)
    
    # Check if RGB is all zeros (water)
    is_water = (arr[:,:,0] == 0) & (arr[:,:,1] == 0) & (arr[:,:,2] == 0)
    
    print("Computing distance transform...")
    distance = distance_transform_edt(is_water)
    
    max_dist = 50.0
    dist_norm = np.clip(distance / max_dist, 0.0, 1.0)
    
    out_arr = np.zeros((arr.shape[0], arr.shape[1], 4), dtype=np.uint8)
    out_arr[:,:,0] = (dist_norm * 255).astype(np.uint8)
    out_arr[:,:,1] = (is_water * 255).astype(np.uint8)
    out_arr[:,:,3] = 255
    
    print("Saving water_mask.png...")
    Image.fromarray(out_arr).save("water_mask.png")
    print("Done!")

if __name__ == "__main__":
    main()
