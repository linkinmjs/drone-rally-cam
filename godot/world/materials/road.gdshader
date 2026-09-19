// Gravel rally road: two darker wheel tracks, loose stones between them, and shoulders of loose
// dirt that melt into the terrain. UV.x is the distance from the centre line in meters (negative
// on the left), UV.y the distance along the road / 4.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D macro_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 gravel_color : source_color = vec3(0.60, 0.52, 0.41);
uniform vec3 track_color : source_color = vec3(0.40, 0.33, 0.25);
uniform vec3 stone_color : source_color = vec3(0.74, 0.70, 0.64);
// Same as the terrain's loose dirt, so the shoulder melts into it.
uniform vec3 edge_color : source_color = vec3(0.54, 0.43, 0.30);
uniform float half_width = 3.5;
// Distance of each wheel track from the centre line.
uniform float track_offset = 0.85;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float noise_at(vec2 p) {
	return texture(macro_noise, p).r;
}

void fragment() {
	vec2 p = world_position.xz;
	float n = noise_at(p * 0.03);
	float grain = noise_at(p * 0.8 + vec2(0.3, 0.1));
	float speckle = noise_at(p * 2.7 + vec2(0.61, 0.23));
	float x = abs(UV.x);

	vec3 color = gravel_color * (0.84 + 0.26 * n) * (0.9 + 0.2 * grain);
	float tracks = smoothstep(0.42, 0.05, abs(x - track_offset)) * (0.55 + 0.45 * n);
	color = mix(color, track_color * (0.9 + 0.2 * grain), clamp(tracks, 0.0, 1.0) * 0.75);
	// Loose stones, thrown out of the tracks.
	float stones = smoothstep(0.66, 0.72, speckle) * (1.0 - clamp(tracks, 0.0, 1.0));
	color = mix(color, stone_color * (0.85 + 0.3 * grain), stones * 0.7);
	// Shoulders: loose dirt, ragged edge.
	float shoulder = smoothstep(half_width - 0.35, half_width + 0.3, x + (n - 0.5) * 0.6);
	color = mix(color, edge_color * (0.85 + 0.3 * grain), shoulder);

	ALBEDO = color;
	ROUGHNESS = 0.95;
	SPECULAR = 0.25;
}
