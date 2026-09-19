// Grass with a slow macro variation and bands of dry grass, cooler and darker in the valleys and
// warmer on the hills, darker in the folds, rock on steep slopes and loose dirt near the road.
// The noise is read from a precomputed texture (world/materials/noise_macro.tres) instead of
// being computed per pixel.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D macro_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 grass_dark : source_color = vec3(0.22, 0.31, 0.13);
uniform vec3 grass_light : source_color = vec3(0.47, 0.48, 0.22);
uniform vec3 grass_dry : source_color = vec3(0.66, 0.56, 0.30);
uniform vec3 valley_tint : source_color = vec3(0.70, 0.80, 0.84);
uniform vec3 hill_tint : source_color = vec3(1.06, 1.0, 0.86);
uniform vec3 rock_color : source_color = vec3(0.46, 0.43, 0.39);
uniform vec3 dirt_color : source_color = vec3(0.54, 0.43, 0.30);
// Heights (m) of the valley floors and of the hilltops, for the tint.
uniform float valley_height = -14.0;
uniform float hill_height = 18.0;
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

float noise_at(vec2 p) {
	return texture(macro_noise, p).r;
}

void fragment() {
	vec2 p = world_position.xz;
	float large = noise_at(p * 0.0018);
	float medium = noise_at(p * 0.011 + vec2(0.37, 0.61));
	float small = noise_at(p * 0.21 + vec2(0.13, 0.77));
	float fine = noise_at(p * 0.9);

	vec3 grass = mix(grass_dark, grass_light, smoothstep(0.2, 0.8, large));
	grass = mix(grass, grass_dry, smoothstep(0.5, 0.85, medium) * 0.35);
	grass *= 0.9 + 0.12 * small + 0.06 * fine;
	float height = smoothstep(valley_height, hill_height, world_position.y);
	grass *= mix(valley_tint, hill_tint, height);
	// Folds: slopes that are not rock yet are a little darker.
	grass *= 1.0 - 0.22 * smoothstep(0.985, 0.86, world_normal.y);

	float rockiness = smoothstep(rock_start, rock_full, world_normal.y + (small - 0.5) * 0.08);
	vec3 rock = rock_color * (0.78 + 0.44 * noise_at(p * 0.05 + world_position.y * 0.01));
	vec3 color = mix(grass, rock, rockiness);

	float loose = clamp(dirt + (small - 0.5) * 0.5, 0.0, 1.0);
	color = mix(color, dirt_color * (0.86 + 0.28 * fine), smoothstep(0.35, 0.75, loose));

	ALBEDO = color;
	ROUGHNESS = 0.92;
	SPECULAR = 0.3;
}
