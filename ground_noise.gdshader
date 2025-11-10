shader_type spatial;

render_mode unshaded;

uniform float height_scale = 0.5;
uniform sampler2D noise_texture_1;
uniform sampler2D noise_texture_2;

//varying vec4 noise;

vec4 overlay(vec4 base, vec4 blend){
	vec4 limit = step(0.5, base);
	return mix(2.0 * base * blend, 1.0 - 2.0 * (1.0 - base) * (1.0 - blend), limit);
}

void vertex() {
	// Called for every vertex the material is visible on.
	vec4 noise1 = texture(noise_texture_1, UV);
	//vec4 noise2 = texture(noise_texture_2, UV*4.0);
	//noise = overlay(noise1, noise2);
	//vec2 tex_position = VERTEX.xz / 2.0 + 0.5;
	//float height = texture(noise_texture_1, tex_position*1.5).x;
	float height = (noise1.xy * UV).x;
	VERTEX.y += height * height_scale;
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec4 noise1 = texture(noise_texture_1, UV);
	vec4 noise2 = texture(noise_texture_2, UV);
	//ALBEDO = overlay(noise1, noise2).rgb;
	ALBEDO = overlay(noise1, noise2).rgb;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
