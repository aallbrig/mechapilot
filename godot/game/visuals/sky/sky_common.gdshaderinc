// Shared by the six sky shaders (the Environment's background). They work in
// "sky coordinates": the tangent of the view angle as seen by the side-on
// camera looking down -Z (so any field of view and aspect, portrait to 4K, is
// respected), shifted by the camera's world position for a slow parallax as the
// player climbs and turns. The radiance cubemap pass only needs the gradient.

uniform vec3 zenith_color : source_color = vec3(0.05, 0.1, 0.3);
uniform vec3 upper_color : source_color = vec3(0.2, 0.45, 0.85);
uniform vec3 horizon_color : source_color = vec3(0.6, 0.8, 0.95);
uniform vec3 low_color : source_color = vec3(0.5, 0.65, 0.8);
// Sky-coordinate height of the horizon at camera altitude 0.
uniform float horizon_height = -0.35;
// How far (in sky coordinates) the gradient spans above the horizon.
uniform float gradient_span = 1.6;
// Sky-coordinate shift per world unit of camera movement (x, y).
uniform vec2 parallax = vec2(0.0015, 0.004);
// World distance the scene's origin has been moved back by (SkyEnvironment.
// shift_origin), added to the camera so re-origining never jumps the sky.
uniform vec2 world_offset = vec2(0.0, 0.0);

// Directions this close to sideways (or behind the camera) are clamped.
const float MIN_FORWARD = 0.05;

vec2 sky_coords(vec3 eyedir, vec3 camera) {
	vec2 view = eyedir.xy / max(-eyedir.z, MIN_FORWARD);
	return view + (camera.xy + world_offset) * parallax;
}

// 0 at the horizon, 1 at the top of the gradient, negative below the horizon.
float sky_height(vec2 p) {
	return (p.y - horizon_height) / gradient_span;
}

vec3 sky_gradient(float h) {
	vec3 below = mix(horizon_color, low_color, smoothstep(0.0, -0.6, h));
	vec3 above = mix(horizon_color, upper_color, smoothstep(0.0, 0.35, h));
	above = mix(above, zenith_color, smoothstep(0.35, 1.0, h));
	return h < 0.0 ? below : above;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// A sun disc with a soft halo, at sky-coordinate position `at`.
vec3 sun_glow(vec2 p, vec2 at, float radius, vec3 color, float halo) {
	float d = length(p - at);
	float disc = smoothstep(radius, radius * 0.85, d);
	float glow = exp(-d / max(halo, 1e-4));
	return color * (disc * 1.5 + glow * 0.6);
}

// Twinkling stars: `density` cells per sky unit, `amount` = fraction lit.
float stars(vec2 p, float density, float amount, float time) {
	vec2 cell = floor(p * density);
	float rnd = hash12(cell);
	vec2 jitter = vec2(hash12(cell + 7.0), hash12(cell + 13.0)) - 0.5;
	vec2 center = (cell + 0.5 + jitter * 0.6) / density;
	float d = length(p - center) * density;
	float star = smoothstep(0.12, 0.0, d) * step(1.0 - amount, rnd);
	float twinkle = 0.65 + 0.35 * sin(time * (1.5 + rnd * 3.0) + rnd * 40.0);
	return star * twinkle;
}
