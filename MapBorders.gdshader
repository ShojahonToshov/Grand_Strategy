shader_type canvas_item;

uniform sampler2D state_id_map : filter_nearest;
uniform vec4 internal_border_color : source_color = vec4(0.2, 0.2, 0.2, 0.7);
uniform float state_alpha = 1.0;
uniform float internal_width = 1.5;

void fragment() {
	vec2 uv = UV;
	
	// Determine screen-pixel size in UV coordinates
	vec2 dx = dFdx(uv);
	vec2 dy = dFdy(uv);
	
	// Sample state ID map
	vec4 s_center = texture(state_id_map, uv);
	vec4 s_right  = texture(state_id_map, uv + dx * internal_width);
	vec4 s_up     = texture(state_id_map, uv + dy * internal_width);
    vec4 s_left   = texture(state_id_map, uv - dx * internal_width);
    vec4 s_down   = texture(state_id_map, uv - dy * internal_width);
	
	float s_diff1 = distance(s_center.rgb, s_right.rgb);
	float s_diff2 = distance(s_center.rgb, s_up.rgb);
    float s_diff3 = distance(s_center.rgb, s_left.rgb);
	float s_diff4 = distance(s_center.rgb, s_down.rgb);
	
	bool is_state_border = (s_diff1 > 0.001 || s_diff2 > 0.001 || s_diff3 > 0.001 || s_diff4 > 0.001);
	
	if (is_state_border) {
		COLOR = internal_border_color;
		COLOR.a *= state_alpha;
	} else {
		COLOR = vec4(0.0);
	}
}
