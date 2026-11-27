// Cloud puffs: soft and unshaded, lit from above by two theme colours, with the
// layer's opacity in each instance's colour alpha. One draw per cloud layer.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_back, blend_mix, shadows_disabled;

uniform vec3 lit_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 shade_color : source_color = vec3(0.6, 0.65, 0.8);
uniform float softness : hint_range(0.0, 1.0) = 0.55;

varying float v_up;

void vertex() {
	v_up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
}

void fragment() {
	ALBEDO = mix(shade_color, lit_color, smoothstep(-0.6, 0.8, v_up));
	float rim = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALPHA = COLOR.a * mix(1.0, rim, softness);
}
