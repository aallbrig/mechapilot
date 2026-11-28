// The shared material of every regular enemy's baked pieces (#135). It keeps
// the hull's faceted, palette-coloured look but sets each enemy's brightness
// against the sky behind it, so a hostile never melts into a Level's sky:
//  - The Level's sky gradient (SkyEnvironment copies its sky material's
//    gradient here) gives the sky's luminance in the enemy's direction.
//  - In front of a bright sky the enemy is drawn dark, in front of a dark one
//    light, at least contrast_goal (a WCAG ratio) away from the sky. Brightness,
//    not hue, carries the contrast, so it holds for colour-blind players too.
//  - Its colours lean toward the Level's hostile accent, chosen against that
//    sky and away from the player mech's blue and white; a fresnel rim of the
//    accent outlines the silhouette at the same brightness.
// Unshaded and unfogged, so neither the sun nor the haze can wash an enemy back
// into the sky; a fixed key light keeps the facets. Glowing parts (vertex alpha
// 0) still glow. One material for every enemy: no extra draw calls.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back;

#include "res://game/visuals/sky/sky_common.gdshaderinc"

uniform vec3 hostile_accent : source_color = vec3(1.0, 0.35, 0.1);
uniform float accent_amount : hint_range(0.0, 1.0) = 0.8;
uniform float contrast_goal : hint_range(1.0, 21.0) = 5.0;
uniform float light_floor : hint_range(0.0, 1.0) = 0.65;
// Light enemies stop short of white, so they keep their accent's hue.
uniform float light_ceiling : hint_range(0.0, 1.0) = 0.88;
// Above this sky luminance (as the gradient estimates it) enemies go dark. At
// 0.179 dark and light reach the same contrast; a sky whose gradient overstates
// it (the storm's churn darkens its gradient) sets its own.
uniform float dark_above : hint_range(0.0, 1.0) = 0.179;
uniform float facet_amount : hint_range(0.0, 0.5) = 0.15;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.6;
uniform float glow_energy : hint_range(0.0, 16.0) = 2.0;

// WCAG relative luminance weights (linear RGB).
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
// The key light, in view space: from the upper left, toward the screen.
const vec3 KEY = vec3(-0.36, 0.8, 0.48);

// The Compatibility renderer shows colours as they are written (the palette's
// and the sky's are sRGB, see MeshBaker), so luminance is worked out in linear
// light and the result is written back as sRGB.
vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 to_srgb(vec3 c) {
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

// `c`'s hue at luminance `l` (0..1): scaled, then blended toward grey (which
// keeps the luminance) as far as needed to stay within 0..1.
vec3 at_luminance(vec3 c, float l) {
	vec3 scaled = c * (l / max(dot(c, LUMA), 1e-4));
	float top = max(max(scaled.r, scaled.g), scaled.b);
	if (top > 1.0) {
		scaled = vec3(l) + (scaled - vec3(l)) * ((1.0 - l) / max(top - l, 1e-4));
	}
	return clamp(scaled, 0.0, 1.0);
}

void fragment() {
	// The sky behind the whole enemy (its origin), so one enemy never splits
	// into a dark and a light half.
	vec3 toward = normalize(NODE_POSITION_WORLD - CAMERA_POSITION_WORLD);
	vec3 sky = sky_gradient(sky_height(sky_coords(toward, CAMERA_POSITION_WORLD)));
	float sky_l = dot(to_linear(sky), LUMA);
	// Dark enemies go as dark as the goal needs; light ones never dimmer than
	// light_floor, which covers the clouds, haze and stars the gradient leaves out.
	float target = sky_l > dark_above
		? max((sky_l + 0.05) / contrast_goal - 0.05, 0.0)
		: clamp((sky_l + 0.05) * contrast_goal - 0.05, light_floor, light_ceiling);
	float facet = 1.0 + facet_amount * clamp(dot(NORMAL, normalize(KEY)), -1.0, 1.0);
	vec3 accent = to_linear(hostile_accent);
	vec3 base = mix(to_linear(COLOR.rgb), accent, accent_amount);
	vec3 body = at_luminance(base, clamp(target * facet, 0.0, 1.0));
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * rim_amount;
	body = mix(body, at_luminance(accent, target), rim);
	float glow = 1.0 - COLOR.a;
	ALBEDO = mix(to_srgb(body), COLOR.rgb * glow_energy, glow);
}
