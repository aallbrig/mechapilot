// The "MECHA FIGHTER" lettering: a chrome gradient on the letter fill, a shine
// that sweeps across now and then, and the outline and shadow left as drawn.
// The fill is told apart from the outline by colour: the Label's font colour is
// white and its outline is dark.
shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 mid_color : source_color = vec4(0.55, 0.85, 1.0, 1.0);
uniform vec4 low_color : source_color = vec4(0.1, 0.3, 0.75, 1.0);
uniform vec4 shine_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Label height and width in pixels (set by TitleLogo when it resizes).
uniform vec2 text_size = vec2(800.0, 120.0);
// Seconds between the starts of two shine sweeps, and how long one sweep takes.
uniform float shine_period = 3.5;
uniform float shine_duration = 0.8;
uniform float shine_width = 0.08;
// 0 turns the sweep off (reduced motion), 1 shows it.
uniform float shine_amount : hint_range(0.0, 1.0) = 1.0;
// Skew of the shine band (it leans like the italic letters).
uniform float shine_slant = 0.35;

varying vec2 v_local;

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float luminance = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	float fill = step(0.5, luminance);
	vec2 uv = v_local / max(text_size, vec2(1.0));
	vec3 chrome = uv.y < 0.5
		? mix(top_color.rgb, mid_color.rgb, smoothstep(0.1, 0.5, uv.y))
		: mix(low_color.rgb, mid_color.rgb, smoothstep(0.95, 0.55, uv.y));
	// A hard chrome horizon line across the middle of the letters.
	chrome = mix(chrome, low_color.rgb, smoothstep(0.49, 0.5, uv.y) * smoothstep(0.58, 0.5, uv.y) * 0.6);
	float t = mod(TIME, shine_period) / shine_duration;
	float band = abs(uv.x + (1.0 - uv.y) * shine_slant - mix(-0.3, 1.3, t));
	float shine = smoothstep(shine_width, 0.0, band) * step(t, 1.0);
	vec3 lit = mix(chrome, shine_color.rgb, shine * shine_amount * 0.85);
	COLOR = vec4(mix(COLOR.rgb, lit, fill), COLOR.a * tex.a);
}
