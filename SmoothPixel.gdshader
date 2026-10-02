shader_type canvas_item;

// This shader creates perfect "Vector-like" smooth borders for low-res pixel maps
// without making the whole image blurry (like Linear) or blocky (like Nearest).
// It's the AAA standard for zooming into ID maps or political maps.

void fragment() {
    vec2 tex_size = vec2(textureSize(TEXTURE, 0));
    vec2 uv = UV * tex_size;
    
    // Calculate the derivatives to know how fast UV changes per screen pixel
    vec2 duv = fwidth(uv);
    
    // Smoothstep the fractional part of the UV to create a sharp but anti-aliased edge
    vec2 fractional = fract(uv);
    vec2 smooth_frac = clamp(0.5 + (fractional - 0.5) / duv, 0.0, 1.0);
    
    // Reconstruct the UV
    vec2 final_uv = (floor(uv) + smooth_frac - 0.5) / tex_size;
    
    // Sample the texture with the modified UV (requires TEXTURE_FILTER_LINEAR on the node)
    COLOR = texture(TEXTURE, final_uv);
}
