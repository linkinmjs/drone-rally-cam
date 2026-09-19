// Tree canopies: the color comes from the vertices (light gradient) tinted by the MultiMesh
// instance color, and the top sways a little in the wind (more the higher the vertex).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Sway at the top of a 7 m tree, in meters.
uniform float sway = 0.12;
uniform float speed = 1.1;
// Local height where the canopy starts to move and where it moves the most.
uniform float rooted = 1.5;
uniform float top = 7.0;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float phase = origin.x * 0.13 + origin.z * 0.17;
	float bend = clamp((VERTEX.y - rooted) / (top - rooted), 0.0, 1.0);
	bend *= bend;
	float gust = sin(TIME * speed + phase) + 0.35 * sin(TIME * speed * 2.3 + phase * 1.7);
	VERTEX.x += gust * sway * bend;
	VERTEX.z += gust * sway * 0.6 * bend;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.88;
	SPECULAR = 0.25;
}
