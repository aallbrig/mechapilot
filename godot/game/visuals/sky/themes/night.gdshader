// Level 4, Night Raid: deep blue, twinkling stars, and searchlight beams that
// sweep up from the ground below the horizon.
shader_type sky;

#include "res://game/visuals/sky/sky_common.gdshaderinc"

uniform float star_density = 38.0;
uniform float star_amount = 0.22;
uniform vec3 star_color : source_color = vec3(0.9, 0.95, 1.0);
uniform vec3 beam_color : source_color = vec3(0.75, 0.85, 1.0);
uniform float beam_strength = 0.22;
uniform float beam_width = 0.035;
uniform float beam_sweep = 0.45;
uniform float beam_speed = 0.35;

// One beam rooted below the horizon at base_x, swinging with `phase`.
float beam(vec2 p, float base_x, float phase, float time) {
	vec2 base = vec2(base_x, horizon_height - 0.25);
	float angle = sin(time * beam_speed + phase) * beam_sweep;
	vec2 dir = vec2(sin(angle), cos(angle));
	vec2 rel = p - base;
	float along = dot(rel, dir);
	float across = abs(rel.x * dir.y - rel.y * dir.x);
	float width = beam_width * (0.3 + along);
	return smoothstep(width, 0.0, across) * step(0.0, along) * exp(-along * 0.9);
}

void sky() {
	vec2 p = sky_coords(EYEDIR, POSITION);
	float h = sky_height(p);
	vec3 color = sky_gradient(h);
	color += star_color * stars(p, star_density, star_amount, TIME) * smoothstep(0.02, 0.3, h);
	float beams = beam(p, -0.9, 0.0, TIME) + beam(p, -0.15, 2.1, TIME);
	beams += beam(p, 0.7, 4.2, TIME);
	color += beam_color * beams * beam_strength;
	COLOR = color;
}
