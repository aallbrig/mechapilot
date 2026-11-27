// Level 1, Dawn Patrol: sunrise pinks, a low rising sun with a wide warm halo.
shader_type sky;

#include "res://game/visuals/sky/sky_common.gdshaderinc"

uniform vec2 sun_position = vec2(0.45, 0.07);
uniform vec3 sun_color : source_color = vec3(1.0, 0.8, 0.6);
uniform float sun_radius = 0.05;
uniform float sun_halo = 0.22;
uniform vec3 streak_color : source_color = vec3(1.0, 0.55, 0.65);

void sky() {
	vec2 p = sky_coords(EYEDIR, POSITION);
	float h = sky_height(p);
	vec3 color = sky_gradient(h);
	// Thin streaks of high cloud catching the sunrise.
	float streak = value_noise(vec2(p.x * 3.0, p.y * 28.0));
	color += streak_color * smoothstep(0.62, 0.9, streak) * smoothstep(0.75, 0.15, h) * 0.18;
	color += sun_glow(p, sun_position, sun_radius, sun_color, sun_halo);
	COLOR = color;
}
