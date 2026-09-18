shader_type canvas_item;

uniform sampler2D id_map : filter_nearest;
uniform int selected_id;

void fragment() {
    vec4 id_color = texture(id_map, UV);
    int r = int(round(id_color.r * 255.0));
    int g = int(round(id_color.g * 255.0));
    int b = int(round(id_color.b * 255.0));
    int p_id = r + (g << 8) + (b << 16);
    
    if (p_id == selected_id && selected_id != 0) {
        COLOR = vec4(1.0, 0.9, 0.0, 0.5); // Yellow highlight
    } else {
        COLOR = vec4(0.0);
    }
}
