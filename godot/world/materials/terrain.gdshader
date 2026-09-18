// Grass that turns to rock on steep slopes and to loose dirt near the road.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://world/materials/noise.gdshaderinc"

uniform vec3 grass_dark : source_color = vec3(0.23, 0.31, 0.13);
uniform vec3 grass_light : source_color = vec3(0.45, 0.46, 0.22);
uniform vec3 rock_color : source_color = vec3(0.44, 0.42, 0.39);
uniform vec3 dirt_color : source_color = vec3(0.52, 0.42, 0.30);
// Normal.y where rock starts to show and where it takes over.
uniform float rock_start = 0.82;
uniform float rock_full = 0.66;

varying vec3 world_position;
varying vec3 world_normal;
varying float dirt;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	dirt = 1.0 - COLOR.r;
}

void fragment() {
	vec2 p = world_position.xz;
	float large = fbm(p * 0.015);
	float small = fbm(p * 0.4);
	vec3 grass = mix(grass_dark, grass_light, smoothstep(0.3, 0.7, large));
	grass *= 0.85 + 0.3 * small;

	float rockiness = smoothstep(rock_start, rock_full, world_normal.y + (small - 0.5) * 0.08);
	vec3 rock = rock_color * (0.75 + 0.5 * fbm(p * 0.6 + world_position.y * 0.4));
	vec3 color = mix(grass, rock, rockiness);

	float loose = clamp(dirt + (small - 0.5) * 0.5, 0.0, 1.0);
	color = mix(color, dirt_color * (0.85 + 0.3 * small), smoothstep(0.35, 0.75, loose));

	ALBEDO = color;
	ROUGHNESS = 0.92;
	SPECULAR = 0.3;
}
