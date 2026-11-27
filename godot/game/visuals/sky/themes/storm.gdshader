// Level 2, Storm Front: grey, churning storm clouds. Lightning brightens the
// whole sky and draws a jagged bolt (SkyEnvironment drives `flash`, `bolt_x`).
shader_type sky;

#include "res://game/visuals/sky/sky_common.gdshaderinc"

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float bolt_x = 0.2;
uniform vec3 flash_color : source_color = vec3(0.75, 0.8, 1.0);
uniform float churn_speed = 0.03;

void sky() {
	vec2 p = sky_coords(EYEDIR, POSITION);
	float h = sky_height(p);
	vec3 color = sky_gradient(h);
	vec2 drift = vec2(TIME * churn_speed, 0.0);
	float churn = value_noise(p * 4.0 + drift) * 0.6 + value_noise(p * 9.0 - drift * 2.0) * 0.4;
	color *= mix(0.7, 1.15, churn);
	// The bolt: a jagged vertical line that only shows while the flash is high.
	float jag = (value_noise(vec2(p.y * 14.0, bolt_x * 31.0)) - 0.5) * 0.08;
	float bolt = smoothstep(0.012, 0.0, abs(p.x - bolt_x - jag)) * step(horizon_height, p.y);
	float glow = flash * 0.55 * (0.6 + churn);
	color += flash_color * (glow + bolt * smoothstep(0.5, 1.0, flash) * 2.0);
	COLOR = color;
}
