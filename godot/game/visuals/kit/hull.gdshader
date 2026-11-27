// The shared material of every baked model piece (player, enemies, bosses).
// Albedo comes from the vertex colour; the vertex colour's alpha marks glow
// (0 = full glow), which becomes emission so the Environment's glow blooms it.
// A rim term keeps silhouettes readable against any sky. Compatibility-safe.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

uniform float glow_energy : hint_range(0.0, 16.0) = 5.0;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.35;
uniform float rim_tint : hint_range(0.0, 1.0) = 0.6;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.55;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	float glow = 1.0 - COLOR.a;
	ALBEDO = COLOR.rgb;
	EMISSION = COLOR.rgb * glow * glow_energy;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value * (1.0 - glow);
	RIM = rim_amount;
	RIM_TINT = rim_tint;
}
