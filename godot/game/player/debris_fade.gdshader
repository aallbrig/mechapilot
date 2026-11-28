// A baked model piece breaking off in the death ragdoll, fading out. Colours as
// the shared hull shader reads them: albedo from the vertex colour, and the
// vertex colour's alpha marks glow (0 = full glow), so eyes and nozzles keep
// glowing instead of turning transparent. `fade` is the whole piece's opacity.
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, diffuse_lambert;

uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float glow_energy : hint_range(0.0, 16.0) = 5.0;

void fragment() {
	float glow = 1.0 - COLOR.a;
	ALBEDO = COLOR.rgb;
	EMISSION = COLOR.rgb * glow * glow_energy;
	ALPHA = fade;
}
