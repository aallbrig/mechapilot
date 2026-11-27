// The hit-flash material: swapped onto a model's pieces while it flashes.
// One shared material, so flashing never adds a draw call.
shader_type spatial;
render_mode unshaded, cull_back;

uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	ALBEDO = flash_color.rgb;
}
