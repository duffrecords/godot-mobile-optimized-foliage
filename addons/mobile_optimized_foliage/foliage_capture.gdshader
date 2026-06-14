shader_type spatial;
// No blend_mix → depth write is on. Back leaf cards that are fully occluded by
// front ones fail the depth test and are discarded, matching alpha_to_coverage
// behaviour in the live shader. blend_mix disabled depth write, causing all layers
// — including near-black bottom instances — to composite into the atlas.
render_mode unshaded, cull_disabled, ambient_light_disabled, fog_disabled;

uniform sampler2D albedo_texture : source_color;
uniform float alpha_scissor_threshold : hint_range(0,1) = 0.25;
uniform float alpha_antialiasing_edge : hint_range(0, 1) = 0.15;

uniform float stem_base_y = 0.0;
uniform float stem_tip_y = 0.2;
uniform float ao_affect : hint_range(0,1) = 0.9;

varying float v_shadow;
varying float v_stem_gradient;

void vertex() {
	v_shadow = INSTANCE_CUSTOM.r;
	float y = VERTEX.y;
	v_stem_gradient = clamp((y - stem_base_y) / (stem_tip_y - stem_base_y), 0.0, 1.0);
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	if (tex.a < alpha_scissor_threshold) discard;
	float ao_gradient = mix(1.0 - ao_affect, 1.0, v_stem_gradient);
	ALBEDO = tex.rgb * v_shadow * ao_gradient;
	ALPHA = 1.0;
}
