shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, alpha_to_coverage_and_one, ambient_light_disabled, fog_disabled;

uniform sampler2D albedo_texture : source_color;
uniform float alpha_scissor_threshold : hint_range(0,1) = 0.25;
uniform float alpha_antialiasing_edge : hint_range(0, 1) = 0.15;

uniform float stem_base_y = 0.0;
uniform float stem_tip_y = 0.2;
uniform float ao_affect : hint_range(0,1) = 0.9;

// LOD fade-out: leaf cards dither-discard as the camera approaches lod_switch_distance.
// Uniforms are pushed from baked_foliage.gd alongside the other shader params.
uniform float lod_switch_distance = 30.0;
uniform float lod_fade_range = 5.0;

varying float v_shadow;
varying float v_stem_gradient;
varying float v_lod_fade; // 1.0 = fully visible, 0.0 = fully transparent

void vertex() {
	v_shadow = INSTANCE_CUSTOM.r;

	float y = VERTEX.y;
	v_stem_gradient = clamp((y - stem_base_y) / (stem_tip_y - stem_base_y), 0.0, 1.0);

	// Distance from camera to this instance's centre (not per-vertex, so spread is zero).
	vec3 inst_world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 cam_world  = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float dist = length(cam_world - inst_world);
	v_lod_fade = 1.0 - clamp((dist - (lod_switch_distance - lod_fade_range)) / lod_fade_range, 0.0, 1.0);
}

float dither(vec2 pos) {
	return fract(52.9829189 * fract(dot(pos, vec2(0.06711056, 0.00583715))));
}

void fragment() {
	// Dithered LOD fade-out — works on Mobile renderer without VISIBILITY_RANGE_FADE_SELF.
	if (dither(FRAGCOORD.xy) > v_lod_fade) discard;

	vec4 tex = texture(albedo_texture, UV);

	float ao_gradient = mix(1.0 - ao_affect, 1.0, v_stem_gradient);

	ALBEDO = tex.rgb * v_shadow * ao_gradient;
	tex.a = (tex.a - alpha_scissor_threshold) / max(fwidth(tex.a), 0.0001) + 0.5;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	ALPHA_ANTIALIASING_EDGE = alpha_antialiasing_edge;
}
