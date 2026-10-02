shader_type canvas_item;

uniform float detail_scale = 10.0;
uniform float detail_intensity = 0.15;
uniform float zoom = 1.0;

// Simple random function
float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

// Basic value noise
float noise(vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);
    
    // Smooth interpolation
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Fractal Brownian Motion for parchment feel
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
    // 1. Read the base map color
    vec4 base_color = texture(TEXTURE, UV);
    
    // 2. Generate detail based on SCREEN_UV so it never pixelates
    // We adjust aspect ratio to avoid stretching the paper texture
    vec2 screen_detail = SCREEN_UV * detail_scale;
    
    float paper = fbm(screen_detail);
    
    // 3. Blend them (Multiply / Soft Light approach)
    // Map paper to [1.0 - intensity, 1.0 + intensity]
    float blend = 1.0 + (paper - 0.5) * detail_intensity * 2.0;
    
    COLOR = vec4(base_color.rgb * blend, base_color.a);
}
