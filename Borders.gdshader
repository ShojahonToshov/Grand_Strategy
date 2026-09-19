shader_type canvas_item;

uniform sampler2D state_id_map : filter_nearest, repeat_disable;
uniform sampler2D country_lookup : filter_nearest, repeat_disable;

uniform vec4 internal_border_color : source_color = vec4(0.2, 0.2, 0.2, 0.7);
uniform vec4 external_border_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

uniform float zoom = 1.0;
uniform vec2 map_size = vec2(5632.0, 2048.0);

// Helper to decode RGB to integer ID
int color_to_id(vec4 color) {
    int r = int(round(color.r * 255.0));
    int g = int(round(color.g * 255.0));
    int b = int(round(color.b * 255.0));
    return r + (g << 8) + (b << 16);
}

void fragment() {
    vec2 map_uv = UV;
    vec4 current_color = texture(state_id_map, map_uv);
    int state_id = color_to_id(current_color);
    
    vec2 lookup_uv = vec2((float(state_id) + 0.5) / 16384.0, 0.5);
    vec4 current_country = texture(country_lookup, lookup_uv);
    vec2 pixel_size = vec2(1.0) / map_size;
    
    vec2 offsets[4] = vec2[](
        vec2(0.0, -pixel_size.y), vec2(0.0, pixel_size.y),
        vec2(-pixel_size.x, 0.0), vec2(pixel_size.x, 0.0)
    );
    
    bool is_internal_border = false;
    bool is_external_border = false;
    
    // Check 2-pixel radius for thick country borders
    for (int r = 1; r <= 2; r++) {
        for (int i = 0; i < 4; i++) {
            vec2 neighbor_uv = map_uv + offsets[i] * float(r);
            if (neighbor_uv.x < 0.0 || neighbor_uv.x > 1.0 || neighbor_uv.y < 0.0 || neighbor_uv.y > 1.0) continue;
            
            vec4 neighbor_color = texture(state_id_map, neighbor_uv);
            int neighbor_state_id = color_to_id(neighbor_color);
            
            if (state_id != neighbor_state_id) {
                if (r == 1) { // Only thin internal borders
                    is_internal_border = true;
                }
                
                if (state_id != 0 && neighbor_state_id != 0) {
                    vec2 n_lookup_uv = vec2((float(neighbor_state_id) + 0.5) / 16384.0, 0.5);
                    vec4 neighbor_country = texture(country_lookup, n_lookup_uv);
                    if (distance(current_country.rgb, neighbor_country.rgb) > 0.01) {
                        is_external_border = true;
                    }
                }
            }
        }
    }
    
    if (is_external_border) {
        COLOR = external_border_color;
    } else if (is_internal_border) {
        COLOR = internal_border_color;
    } else {
        COLOR = vec4(0.0);
    }
}
