shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, alpha_to_coverage_and_one, ambient_light_disabled, fog_disabled;

uniform sampler2D albedo_texture : source_color;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.25;

uniform float lod_switch_distance = 30.0;
uniform float lod_fade_range = 5.0;
uniform float lod_cull_distance = 150.0;

// Passed from vertex to fragment: which atlas cell (0–3) is the primary view,
// how far (0–1) we are toward the next cell, and the camera distance.
varying float v_view_a;
varying float v_blend_t;
varying float v_distance;

void vertex() {
	// World-space pivot and camera position.
	vec3 world_pos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 cam_world = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;

	vec3 to_cam_3d = cam_world - world_pos;
	v_distance = length(to_cam_3d);

	// Camera direction projected onto XZ — used for billboard orientation and view selection.
	vec3 to_cam = to_cam_3d;
	to_cam.y = 0.0;
	float dist_xz = length(to_cam);
	to_cam = (dist_xz > 0.001) ? to_cam / dist_xz : vec3(0.0, 0.0, 1.0);

	// Map camera azimuth to a continuous 0–4 view index in the node's local frame.
	// View 0 = camera from node's local +Z, 1 = +X, 2 = −Z, 3 = −X (clockwise from above).
	// Using local axes from MODEL_MATRIX so rotated nodes pick the correct baked cell
	// without needing a rebake — FoliageImpostorData stays rotation-agnostic.
	vec3 local_fwd   = normalize(mat3(MODEL_MATRIX) * vec3(0.0, 0.0, 1.0));
	vec3 local_right = normalize(mat3(MODEL_MATRIX) * vec3(1.0, 0.0, 0.0));
	float angle = atan(dot(to_cam, local_right), dot(to_cam, local_fwd)); // −PI to PI
	float normalized = fract(angle / TAU + 1.0); // 0 to 1
	float view_f = normalized * 4.0;
	v_view_a = mod(floor(view_f), 4.0); // primary cell index (0–3)
	v_blend_t = fract(view_f);          // blend fraction toward the next cell

	// Y-axis billboard: right stays in the XZ plane, up stays world-vertical.
	vec3 world_up = vec3(0.0, 1.0, 0.0);
	vec3 bill_right = normalize(cross(-to_cam, world_up));
	vec3 bill_vertex = bill_right * VERTEX.x + world_up * VERTEX.y;

	// Write clip position directly, bypassing the normal MVP chain.
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world_pos + bill_vertex, 1.0);
}

// Interleaved gradient noise — textureless dither pattern, works on Mobile renderer.
float dither(vec2 pos) {
	return fract(52.9829189 * fract(dot(pos, vec2(0.06711056, 0.00583715))));
}

// UV origin of each atlas cell in the 2×2 grid:
// cell 0 → (0.0, 0.0), cell 1 → (0.5, 0.0), cell 2 → (0.0, 0.5), cell 3 → (0.5, 0.5)
vec2 cell_origin(int v) {
	return vec2(float(v % 2) * 0.5, float(v / 2) * 0.5);
}

void fragment() {
	float fade_in  = clamp((v_distance - (lod_switch_distance - lod_fade_range)) / lod_fade_range, 0.0, 1.0);
	float fade_out = 1.0 - clamp((v_distance - (lod_cull_distance - lod_fade_range)) / lod_fade_range, 0.0, 1.0);

	// Near fade-in: inverted dither so this shader keeps exactly the screen pixels
	// that foliage_shadow.gdshader discards. Both evaluate dither(FRAGCOORD.xy) to
	// the same value D; the leaf card keeps D ≤ leaf_fade and this impostor keeps
	// D ≥ 1 − fade_in. Those two ranges partition [0, 1) at every transition step,
	// giving 100% combined coverage with no gap regardless of lod_fade_range.
	if ((1.0 - dither(FRAGCOORD.xy)) > fade_in) discard;
	// Far fade-out: no leaf cards present, regular dither suffices.
	if (dither(FRAGCOORD.xy) > fade_out) discard;

	int view_a = int(v_view_a);
	int view_b = int(mod(v_view_a + 1.0, 4.0));

	// Each cell occupies a 0.5×0.5 region; UV runs 0–1 across the quad.
	vec2 uv_a = cell_origin(view_a) + UV * 0.5;
	vec2 uv_b = cell_origin(view_b) + UV * 0.5;

	// Blend both color and alpha linearly between the two views. Dithered switching
	// was rejected here because it assigns each fragment fully to one view: a fragment
	// in a transparent region of view A that lands on an opaque region of view B
	// becomes fully opaque, making the impostor completely solid at the 45° midpoint
	// where blend_t = 0.5. Blending alpha avoids this — boundary pixels that are
	// opaque in one view and transparent in the other settle at alpha ≈ 0.5, which
	// the alpha scissor threshold clips away cleanly.
	vec4 col = mix(texture(albedo_texture, uv_a), texture(albedo_texture, uv_b), v_blend_t);
	// The linear mix premultiplies RGB by alpha: a leaf pixel blended with a
	// transparent pixel yields RGB = t * leaf_color but alpha = t, so dividing
	// recovers the original leaf colour regardless of the blend fraction.
	ALBEDO = col.a > 0.001 ? col.rgb / col.a : col.rgb;
	ALPHA = col.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
}
