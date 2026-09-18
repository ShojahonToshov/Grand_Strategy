shader_type canvas_item;

uniform sampler2D water_mask : filter_linear;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform bool water_animation_enabled = true;
uniform float zoom_level = 1.0;

// Colors
uniform vec4 color_water_main : source_color = vec4(0.1294, 0.2824, 0.3569, 1.0); // #21485B
uniform vec4 color_water_var : source_color = vec4(0.1569, 0.3451, 0.4157, 1.0);  // #28586A
uniform vec4 color_water_coast : source_color = vec4(0.2235, 0.4549, 0.5216, 1.0); // #397485

void fragment() {
    vec4 base_color = texture(TEXTURE, UV);
    vec4 mask = texture(water_mask, UV);
    
    // Green channel is 1.0 for water, 0.0 for land.
    // Red channel is distance to coast (0.0 at coast, 1.0 at max_dist (50px)).
    float is_water = mask.g;
    
    if (is_water > 0.01) {
        float dist = mask.r;
        
        // Soft coast gradient (lighter near land)
        float coast_factor = 1.0 - smoothstep(0.0, 0.25, dist); 
        
        vec4 water_color = mix(color_water_main, color_water_coast, coast_factor);
        
        // UV is 0..1 over the map.
        // Map is 5632x2048. We want noise scale independent of screen.
        vec2 noise_uv = UV * vec2(5632.0 / 256.0, 2048.0 / 256.0) * 0.4;
        
        float noise_val = texture(noise_tex, noise_uv).r;
        
        if (water_animation_enabled) {
            float n1 = texture(noise_tex, noise_uv + vec2(TIME * 0.003, TIME * 0.002)).r;
            float n2 = texture(noise_tex, noise_uv * 1.4 - vec2(TIME * 0.002, -TIME * 0.001)).r;
            noise_val = mix(n1, n2, 0.5);
        }
        
        // Soft variation mixing
        float var_factor = smoothstep(0.3, 0.7, noise_val);
        water_color = mix(water_color, color_water_var, var_factor * 0.6);
        
        // Small brightness change for animation (1-2%)
        if (water_animation_enabled) {
            water_color.rgb *= 1.0 + (noise_val - 0.5) * 0.02;
        }
        
        COLOR = mix(base_color, water_color, is_water);
    } else {
        COLOR = base_color;
    }
}
