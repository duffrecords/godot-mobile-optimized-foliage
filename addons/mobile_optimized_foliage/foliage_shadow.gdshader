shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, alpha_to_coverage_and_one, ambient_light_disabled, fog_disabled;

uniform sampler2D albedo_texture : source_color;
uniform float alpha_scissor_threshold : hint_range(0,1) = 0.25;
uniform float alpha_antialiasing_edge : hint_range(0, 1) = 0.15;

uniform float stem_base_y = 0.0;   // local y of base
uniform float stem_tip_y = 0.2;    // local y of tip
uniform float ao_affect : hint_range(0,1) = 0.9;

varying float v_shadow;
varying float v_stem_gradient;

void vertex() {
	v_shadow = INSTANCE_CUSTOM.r;

	// Compute a normalized [0,1] "along stem" parameter per-vertex
	float y = VERTEX.y;
	v_stem_gradient = clamp((y - stem_base_y) / (stem_tip_y - stem_base_y), 0.0, 1.0);
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);

	// Example: AO gets darker near the base of the stem
	float ao_gradient = mix(1.0-ao_affect, 1.0, v_stem_gradient); // 0.5 at base, 1.0 at tip

	ALBEDO = tex.rgb * v_shadow * ao_gradient; // use ALBEDO, per your note
	// Sharpen alpha to the width of a single pixel, using the sum of the pixel's partial derivatives
	tex.a = (tex.a - alpha_scissor_threshold) / max(fwidth(tex.a), 0.0001) + 0.5;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	ALPHA_ANTIALIASING_EDGE = alpha_antialiasing_edge;
}
