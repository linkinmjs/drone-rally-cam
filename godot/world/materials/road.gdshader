// Gravel rally road with two darker wheel tracks.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://world/materials/noise.gdshaderinc"

uniform vec3 gravel_color : source_color = vec3(0.58, 0.50, 0.40);
uniform vec3 track_color : source_color = vec3(0.40, 0.33, 0.25);
// Same as the terrain's loose dirt, so the road edge melts into it.
uniform vec3 edge_color : source_color = vec3(0.52, 0.42, 0.30);

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = fbm(world_position.xz * 0.6);
	float grain = value_noise(world_position.xz * 11.0);
	vec3 color = gravel_color * (0.85 + 0.25 * n) * (0.9 + 0.2 * grain);
	float u = UV.x;
	float tracks = smoothstep(0.09, 0.0, abs(u - 0.3)) + smoothstep(0.09, 0.0, abs(u - 0.7));
	tracks *= 0.55 + 0.45 * n;
	color = mix(color, track_color, clamp(tracks, 0.0, 1.0) * 0.7);
	// Edges fade into the loose dirt of the terrain.
	float edge = smoothstep(0.0, 0.08, u) * smoothstep(1.0, 0.92, u);
	color = mix(edge_color, color, edge);
	ALBEDO = color;
	ROUGHNESS = 0.95;
	SPECULAR = 0.25;
}
