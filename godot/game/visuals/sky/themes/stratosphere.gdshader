// Level 5, Stratosphere: violet thin air, a bright high sun, the first faint
// stars overhead and a glowing magenta haze band at the horizon.
shader_type sky;

#include "res://game/visuals/sky/sky_common.gdshaderinc"

uniform vec2 sun_position = vec2(0.55, 0.75);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 1.0);
uniform float sun_radius = 0.035;
uniform float sun_halo = 0.12;
uniform vec3 haze_color : source_color = vec3(1.0, 0.45, 0.85);
uniform float star_density = 30.0;
uniform float star_amount = 0.12;

void sky() {
	vec2 p = sky_coords(EYEDIR, POSITION);
	float h = sky_height(p);
	vec3 color = sky_gradient(h);
	color += haze_color * exp(-abs(h) * 9.0) * 0.35;
	color += vec3(1.0) * stars(p, star_density, star_amount, TIME) * smoothstep(0.45, 0.9, h) * 0.8;
	color += sun_glow(p, sun_position, sun_radius, sun_color, sun_halo);
	COLOR = color;
}
