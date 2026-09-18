import numpy as np
from PIL import Image

def generate_seamless_noise(size=256, scale=10.0):
    # We can create a simple seamless noise using Perlin/Simplex.
    # Since we don't want to add external deps like noise library,
    # let's just make a simple 3D noise (2D with Z offset) or use a precomputed one.
    # Actually, we can just use godot's noise if we create it in Godot, 
    # but let's just make a basic smooth noise in python by blurring white noise 
    # and wrapping.
    
    np.random.seed(42)
    # create white noise
    wn = np.random.randn(size, size)
    
    # gaussian blur with wrapping
    from scipy.ndimage import gaussian_filter
    
    # To make it seamless, tile it 3x3, blur, and take the middle.
    tiled = np.tile(wn, (3, 3))
    blurred = gaussian_filter(tiled, sigma=scale)
    
    # Extract middle
    noise = blurred[size:2*size, size:2*size]
    
    # Normalize to 0-255
    n_min, n_max = noise.min(), noise.max()
    noise_norm = (noise - n_min) / (n_max - n_min)
    
    out_arr = (noise_norm * 255).astype(np.uint8)
    # Let's save as RGBA so it's easy to load
    img_arr = np.zeros((size, size, 4), dtype=np.uint8)
    img_arr[:,:,0] = out_arr
    img_arr[:,:,1] = out_arr
    img_arr[:,:,2] = out_arr
    img_arr[:,:,3] = 255
    
    Image.fromarray(img_arr).save("water_noise.png")

if __name__ == "__main__":
    generate_seamless_noise(256, scale=4.0)
    print("Generated water_noise.png")
