shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float h = clamp(0.5 + wpos.y / 160.0, 0.0, 1.0);
	vec3 low = vec3(0.55, 0.78, 0.95);
	vec3 mid = vec3(0.18, 0.45, 0.85);
	vec3 high = vec3(0.03, 0.08, 0.3);
	vec3 c = h < 0.5 ? mix(low, mid, h * 2.0) : mix(mid, high, (h - 0.5) * 2.0);
	ALBEDO = c;
}
