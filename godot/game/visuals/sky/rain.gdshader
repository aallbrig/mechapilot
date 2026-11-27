// Storm rain: two layers of slanted streaks drawn over the scene in clip space
// (one draw), falling with time and shifting with the camera so it has depth.
shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled, blend_mix, shadows_disabled;

uniform vec3 rain_color : source_color = vec3(0.75, 0.8, 0.9);
uniform float opacity : hint_range(0.0, 1.0) = 0.3;
uniform float slant = 0.25;
uniform float speed = 3.5;
uniform vec2 parallax = vec2(0.02, 0.02);

varying vec2 v_ndc;

void vertex() {
	v_ndc = VERTEX.xy;
	POSITION = vec4(VERTEX.xy, 0.0, 1.0);
}

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float streaks(vec2 p, float columns, float length_ratio, float time) {
	p.x += p.y * slant;
	float column = floor(p.x * columns);
	float offset = hash11(column);
	float y = fract(p.y * 1.5 + time * speed * (0.8 + offset * 0.4) + offset * 10.0);
	float x = fract(p.x * columns);
	float line = smoothstep(0.5, 0.3, abs(x - 0.5));
	return line * step(1.0 - length_ratio, y) * step(0.35, hash11(column + 17.0));
}

void fragment() {
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec2 p = vec2(v_ndc.x / PROJECTION_MATRIX[0][0], v_ndc.y / PROJECTION_MATRIX[1][1]);
	float near = streaks(p + cam.xy * parallax, 70.0, 0.12, TIME);
	float far = streaks(p * 1.7 + cam.xy * parallax * 0.5 + 3.0, 120.0, 0.08, TIME * 0.8);
	ALBEDO = rain_color;
	ALPHA = clamp(near + far * 0.5, 0.0, 1.0) * opacity;
}
