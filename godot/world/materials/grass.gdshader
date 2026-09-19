// Grass tufts by the road: color from the vertices (dark base, light tip) tinted per instance,
// tips swaying in the wind. They cast no shadows.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform float sway = 0.05;
uniform float speed = 1.8;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float phase = origin.x * 0.31 + origin.z * 0.27;
	float bend = clamp(VERTEX.y / 0.5, 0.0, 1.0);
	float gust = sin(TIME * speed + phase) + 0.4 * sin(TIME * speed * 2.7 + phase * 1.3);
	VERTEX.x += gust * sway * bend * bend;
	VERTEX.z += gust * sway * 0.5 * bend * bend;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
