// Level 6, Edge of Orbit: near-black space full of stars above the curve of
// the Earth, with a thin glowing atmosphere along its limb.
shader_type sky;

#include "res://game/visuals/sky/sky_common.gdshaderinc"

uniform float star_density = 44.0;
uniform float star_amount = 0.3;
uniform float earth_radius = 6.0;
uniform vec3 ocean_color : source_color = vec3(0.04, 0.16, 0.42);
uniform vec3 land_color : source_color = vec3(0.12, 0.3, 0.2);
uniform vec3 cloud_color : source_color = vec3(0.85, 0.9, 0.95);
uniform vec3 atmosphere_color : source_color = vec3(0.35, 0.65, 1.0);
uniform float atmosphere_width = 0.06;

void sky() {
	vec2 p = sky_coords(EYEDIR, POSITION);
	float h = sky_height(p);
	vec3 color = sky_gradient(h);
	color += vec3(1.0) * stars(p, star_density, star_amount, TIME);
	// The Earth: a huge circle whose top touches the horizon line.
	vec2 center = vec2(0.0, horizon_height - earth_radius);
	float d = length(p - center) - earth_radius;
	vec2 surface = p * vec2(2.5, 9.0) + vec2(TIME * 0.004, 0.0);
	float land = smoothstep(0.55, 0.62, value_noise(surface));
	float cloud = smoothstep(0.5, 0.8, value_noise(surface * 2.3 + 5.0));
	vec3 earth = mix(ocean_color, land_color, land);
	earth = mix(earth, cloud_color, cloud * 0.7);
	earth *= mix(1.0, 0.45, smoothstep(0.0, -0.6, d));
	float inside = smoothstep(0.002, -0.002, d);
	color = mix(color, earth, inside);
	color += atmosphere_color * exp(-abs(d) / atmosphere_width) * 0.9;
	COLOR = color;
}
