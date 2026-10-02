shader_type canvas_item;

uniform sampler2D water_mask : filter_linear;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform bool water_animation_enabled = true;
uniform float zoom_level = 1.0;

// Colors
uniform vec4 color_water_main : source_color = vec4(0.1294, 0.2824, 0.3569, 1.0); // #21485B
uniform vec4 color_water_var : source_color = vec4(0.1569, 0.3451, 0.4157, 1.0);  // #28586A
uniform vec4 color_water_coast : source_color = vec4(0.2235, 0.4549, 0.5216, 1.0); // #397485

// Detail settings for Land (Paradox Style)
uniform float detail_scale = 8.0;
uniform float detail_intensity = 0.15;

float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise(vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 uv) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(uv * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

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
        // Land Rendering: Apply Paradox-style parchment map detail
        vec2 screen_detail = SCREEN_UV * detail_scale;
        float paper = fbm(screen_detail);
        
        // Blend map color with parchment texture
        float blend = 1.0 + (paper - 0.5) * detail_intensity * 2.0;
        
        // Optional: darken edges near coast slightly to give embossed feeling
        // (If mask.r is inverted or distance outside water, but we don't know mask generation here.
        // So just apply the paper blend).
        COLOR = vec4(base_color.rgb * blend, base_color.a);
    }
}
