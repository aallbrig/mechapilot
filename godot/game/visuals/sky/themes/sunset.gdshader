// Level 3, Sunset Strike: orange and gold, a big sun sinking into the haze.
shader_type sky;

#include "res://game/visuals/sky/sky_common.gdshaderinc"

uniform vec2 sun_position = vec2(-0.4, -0.2);
uniform vec3 sun_color : source_color = vec3(1.0, 0.65, 0.25);
uniform float sun_radius = 0.09;
uniform float sun_halo = 0.3;
uniform vec3 haze_tint : source_color = vec3(0.85, 0.55, 0.5);

void sky() {
	vec2 p = sky_coords(EYEDIR, POSITION);
	float h = sky_height(p);
	vec3 color = sky_gradient(h);
	// Horizontal bands of haze cut across the sun.
	float band = smoothstep(0.4, 0.6, value_noise(vec2(p.x * 1.5, p.y * 18.0)));
	vec3 sun = sun_glow(p, sun_position, sun_radius, sun_color, sun_halo);
	color += sun * mix(1.0, 0.55, band * smoothstep(0.2, 0.0, abs(p.y - sun_position.y)));
	color = mix(color, color * haze_tint, band * smoothstep(0.1, -0.3, h) * 0.5);
	COLOR = color;
}
